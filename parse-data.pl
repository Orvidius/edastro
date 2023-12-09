#!/usr/bin/perl
use strict;

# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

#####################################################################

use utf8;
use feature qw( unicode_strings );

use JSON;
use Text::CSV;
use POSIX ":sys_wait_h";
use Data::Dumper;
use Time::HiRes qw(sleep);
use File::Basename;

use lib "/home/bones/perl";
use DB qw(rows_mysql db_mysql);
use ATOMS qw(epoch2date date2epoch);

use lib "/home/bones/elite";
use EDSM qw(object_newer import_field import_directly update_object load_objects add_object object_exists dump_objects 
	$edsm_use_names $large_check $allow_updates $force_updates edsm_debug check_updates %typekey %columns $allow_bodyID_deletion
	codex_entry codex_ok get_id64_by_name);

#####################################################################

my $debug		= 0;
my $verbose		= 0;
my $edsm_verbose	= 1;
my $disable_keys	= 0;
my $use_forking		= 0;
my $use_splitting	= 1;
my $drop_index		= 0;
my $fork_verbose	= 0;
   $large_check		= 0;
   $allow_updates	= 1;
   $force_updates	= 0;

my $maxlines_singlethread	= 255;

my $cache_expire	= 86400*7;	# 1 week

my $max_children 	= 8; #24;

my $cache_path		= '/home/bones/elite/cache';
my $wc			= '/usr/bin/wc';
my $rm			= '/usr/bin/rm';
my $nohup		= '/usr/bin/nohup';
my $sync		= '/usr/bin/sync';

#####################################################################

edsm_debug($debug,$edsm_verbose);
$use_forking = 0 if ($debug);

my $params = '';

if ($ARGV[0] =~ /^\-(\S+)/) {
	$params = shift @ARGV;
}

if (!@ARGV) {
	die "Usage: $0 [-params] <filename.json|csv> [filename2...]\n\t-b = Batch inserts (no updates, bulk pulling dates)\n\t-u = Updates (default)\n\t-f = Force/allow updates with past dates\n\t-i = Insert only, no updates. No bulk dates.\n\t-n = favor names over IDs for matching updates\n\t-d = drop indexes\n\t-s = single chunk / no split\n";
}

if ($params =~ /i/) {
	$large_check = 0;
	$allow_updates = 0;
	$force_updates = 0;
}

if ($params =~ /u/) {
	$large_check = 0;
	$allow_updates = 1;
	$force_updates = 0;
}

if ($params =~ /b/) {
	$large_check = 1;
	$allow_updates = 0;
	$force_updates = 0;
	$disable_keys = 1;
}

if ($params =~ /l/) {
	$large_check = 1;
	$allow_updates = 1;
	$force_updates = 0;
	$disable_keys = 1;
}

if ($params =~ /n/) {
	$edsm_use_names = 1;
}

if ($params =~ /f/) {
	$force_updates = 1;
}

if ($params =~ /k/) {
	$disable_keys = 1;
}

if ($params =~ /d/) {
	$drop_index = 1;
}

if ($params =~ /s/) {
	$use_splitting = 0;
}

if ($params =~ /x/) {
	$allow_bodyID_deletion = 0;
}

if ($params =~ /(\d)/) {
	$max_children = $1+0;
}

print "File list: ".join(', ',@ARGV)."\n\n";

my $amChild   = 0;
my %child      = ();;
my %subchild   = ();;
$SIG{CHLD} = \&REAPER;

# clear bucket cache

opendir DIR, $cache_path;
while (my $fn = readdir DIR) {
	if ($fn =~ /^\d+/i && !-d "$cache_path/$fn") {
		my $file = "$cache_path/$fn";
		my $epoch = (stat($file))[9];
		unlink $file if (time - $epoch >= $cache_expire);
	}
}
closedir DIR;

my %list_loaded = ();

foreach my $fn (@ARGV) {
	if ($fn =~ /\.(jsonl?|csv)(\.used)?$/i) {
		parse_file($fn);
	} else {
		print "Unknown filetype: $fn\n";
	}
}


exit;

#####################################################################

sub parse_file {
	my $fn = shift;

	if ($fn =~ /\.csv(\.used)?$/) {
		parse_csv($fn);
	} else {
		parse_json($fn);
	}
}


sub parse_csv {
	my $fn = shift;

	print "\n-----\nCSV: $fn\n";

	my $csv = Text::CSV->new ({ binary => 1 });
	open my $io, '<', $fn;
	my $row = $csv->getline ($io);
	my @columns = @$row;

	my $type = get_type($fn);

	if ($type eq 'unknown' || !$type) {
		warn "Unknown data category.\n";
		return;
	}

	while (my $row = $csv->getline($io)) {
		my @fields = @$row;
		my %input  = ();

		for (my $i=0; $i<@fields; $i++) {
			$input{$columns[$i]} = $fields[$i];
		}

		my %hash = ();

		if ($type eq 'system') {
			import_field(\%hash,'edsm_id',\%input,'edsm_id');
			import_field(\%hash,'eddb_id',\%input,'id');
			import_field(\%hash,'name',\%input,'name');
			import_field(\%hash,'coord_x',\%input,'x');
			import_field(\%hash,'coord_y',\%input,'y');
			import_field(\%hash,'coord_z',\%input,'z');
			$hash{eddb_date} = epoch2date($input{updated_at}) if ($input{updated_at});

			update_object($type,\%hash);
		}
		exit if ($amChild);
	}
	exit if ($amChild);
	#close $io;
}

sub parse_json {
	my $fn = shift;

	print "\n-----\nJSON: $fn\n";

	my $type = get_type($fn);

	if ($type eq 'unknown' || !$type) {
		warn "Unknown data category.\n";
		return;
	}

	if ($use_splitting) {
		open EXEC, "$wc -l $fn |";
		my $linecount = <EXEC>;
		print "WC: $linecount\n";
		$linecount =~ s/\s\w+.*$//s;
		$linecount += 0;
		close EXEC;
		print "LINECOUNT = $linecount\n";

		if ($linecount > $maxlines_singlethread) {
			my %fh = ();
			my %fname = ();
			my %exec = ();

			system($sync);
			
			for (my $i=0; $i<$max_children; $i++) {
				my $ii = sprintf("%06u-%03u",$$,$i);
				$fname{$i} = "$cache_path/$ii-".basename($fn);
				print "SPLIT: $fname{$i}\n";
				open $fh{$i}, '>', $fname{$i};
			}

			open INDATA, "<$fn";
			my $i = 0;
			while (<INDATA>) {
				my $handle = $fh{$i};
				print $handle $_;
				$i++;
				$i = 0 if ($i >= $max_children || !exists($fh{$i}));
			}
			close INDATA;

			foreach my $i (keys %fh) {
				close $fh{$i};
				$exec{$i} = "$0 -s$params '$fname{$i}'";
			}

			system($sync);
			
			foreach my $i (keys %exec) {
				my $pid = fork();
				if ($pid==0) { # child
					print "EXEC# $exec{$i}\n";
					exec($exec{$i});
					die "Exec $i failed: $!\n";
				} elsif (!defined $pid) {
					warn "Fork $i failed: $!\n";
				}
			}
		
			1 while wait() >= 0;

			foreach my $i (keys %fname) {
				print "CLEANUP $fname{$i}\n";
				unlink $fname{$i};
			}

			return; # Parent doesn't do anything more.
		} else {
			$disable_keys = 0;
		}
	}

	if ($type eq 'body') {
		eval {
			if ($drop_index) {
				print "Dropping indexes.\n";
				eval_mysql('elite',"drop index systemID on stars");
				eval_mysql('elite',"drop index systemID on planets");
				eval_mysql('elite',"drop index starName on stars");
				eval_mysql('elite',"drop index planetName on planets");
				eval_mysql('elite',"drop index starParents on stars");
				eval_mysql('elite',"drop index planetParents on planets");
				eval_mysql('elite',"drop index starDates on stars");
				eval_mysql('elite',"drop index planetDates on planets");
				eval_mysql('elite',"drop index starDisco on stars");
				eval_mysql('elite',"drop index planetDisco on planets");
			}

			foreach my $table (qw(stars planets)) {
				eval_mysql('elite',"ALTER TABLE $table DISABLE KEYS") if ($disable_keys);
			}
			#eval_mysql('elite',"SET FOREIGN_KEY_CHECKS = 0; SET UNIQUE_CHECKS = 0; SET AUTOCOMMIT = 0");
			#eval_mysql('elite',"SET FOREIGN_KEY_CHECKS = 0; SET UNIQUE_CHECKS = 0; SET AUTOCOMMIT = 1");
		};
	}

	print "TYPE: $type\n";

	open DATA, '<', $fn;

	my $line_count = 0;

	while (my $line = <DATA>) {
		chomp $line;

		$line_count++;
		warn "$line_count\n" if ($line_count % 100000 == 0);

		$line =~ s/^\s+//;
		$line =~ s/,\s*$//;

		next if ($line !~ /\{.+\}/);

		my ($name, $edsm_id, $bodyType, $checktype) = (undef, undef, undef, $type);

		my $copy = $line;
		$copy =~ s/"rings"\s*:\s*\[[^\]]*\]\s*,?//;
		$copy =~ s/"belts"\s*:\s*\[[^\]]*\]\s*,?//;
		$copy =~ s/"stations"\s*:\s*\[[^\]]*\]\s*,?//;

		if ($copy =~ /"id"\s*:\s*"([^"]+)"\s*(,|\})/) {
			$edsm_id = $1;
		}
		if (!$edsm_id && $copy =~ /"id"\s*:\s*(\d+)\s*(,|\})/) {
			$edsm_id = $1;
		}

		if ($copy =~ /"type"\s*:\s*"([^"]+)"\s*(,|\})/) {
			$bodyType = lc($1);
			$checktype = $bodyType;
		}

		if ($large_check && !$allow_updates && (!$edsm_id || object_exists($checktype,$edsm_id))) {

			# Saves time by not properly parsing the JSON
			# Spammy:
			#print "# Changes not permitted for '$edsm_id', early detection\n" if ($verbose || $debug);
			next;
		}

		if ($large_check && $allow_updates) {
			my $date = '';
			if ($copy =~ /"(updateDate|updateTime|date)"\s*:\s*"([^"]+)"\s*(,|\})/) {
				$date = $2;
				$date =~ s/\+\d\d//;
			}

			if ($date && !object_newer($checktype,$edsm_id,$date)) {
				print "# Changes are not newer for '$edsm_id'\n" if ($verbose || $debug);
				next;
			}
		}

		if ($copy =~ /"name"\s*:\s*"([^"]+)"\s*(,|\})/) {
			$name = $1;
		}

		my $pid = 0;
		my $do_anyway = 0;
	
		while (int(keys %child) >= $max_children) {
			#sleep 1;
			sleep 0.1;
		}

		# Do a FORK before parsing the JSON properly. Child processes can deal with
		# the JSON decoding, and subsequent DB interaction.
	
		if (0 && $use_forking) {	# Disabled
			FORK: {
				if ($pid = fork) {
					# Parent here
					$child{$pid}{start} = time;
					info("FORK: Child spawned on PID $pid for $type [$edsm_id] '$name'\n") if ($fork_verbose);
					next;
				} elsif (defined $pid) {
					# Child here
					$amChild = 1;   # I AM A CHILD!!!
					info("FORK: $$ ready for $type [$edsm_id] '$name'.\n") if ($fork_verbose);
					$0 =~ s/^.*\s+(\S+\.pl)\s+.*$/$1/;
					$0 .= " -- \"$name\"";
				} elsif ($! =~ /No more process/) {
					info("FORK: Could not fork a child for $type [$edsm_id] '$name', retrying in 3 seconds\n");
					sleep 3;
					redo FORK;
				} else {
					info("FORK: Could not fork a child for $type [$edsm_id] '$name'.\n");
					$do_anyway = 1;
				}
			}
		} else {
			$do_anyway = 1;
		}
	
		if (!$amChild && !$do_anyway) {
			add_object($checktype,$typekey{$checktype},$edsm_id);
			next;
		}

		my $inputref = undef;
		eval {
			if ($fn =~ /POIlist\.jsonl/) {
				$inputref = JSON->new->utf8->decode($line);
			} else { 
				$inputref = JSON->new->utf8->decode($line) if ($type ne 'POI');
				$inputref = JSON->new->decode($line) if ($type eq 'POI');
			}
		};

		exit if (ref($inputref) ne 'HASH' && $amChild);
		next if (ref($inputref) ne 'HASH');

		my %input = %$inputref;
		my %hash  = ();

		foreach my $k (keys %input) {
			if (JSON::is_bool($input{$k})) {
				if ($input{$k}) {
					$input{$k} = 1;
				} else {
					$input{$k} = 0;
				}
			}
		}

		if ($type eq 'POI' || $type eq 'GEC') {
			import_field(\%hash,'edsm_id',\%input,'id') if ($type eq 'POI');
			import_field(\%hash,'gec_id',\%input,'id') if ($type eq 'GEC');
			import_field(\%hash,'name',\%input,'name');
			import_field(\%hash,'type',\%input,'type');
			import_field(\%hash,'type',\%input,'type');
			import_field(\%hash,'iconoverride',\%input,'iconOverride');
			import_field(\%hash,'galMapUrl',\%input,'galMapUrl');
			import_field(\%hash,'galMapSearch',\%input,'galMapSearch');
			import_field(\%hash,'poiUrl',\%input,'poiUrl') if ($type eq 'GEC');
			import_field(\%hash,'descriptionHtml',\%input,'descriptionHtml');
			import_field(\%hash,'coord_x',\%input,'coordinates',0);
			import_field(\%hash,'coord_y',\%input,'coordinates',1);
			import_field(\%hash,'coord_z',\%input,'coordinates',2);
			import_field(\%hash,'score',\%input,'rating') if ($type eq 'GEC');
			import_field(\%hash,'summary',\%input,'summary') if ($type eq 'GEC');
			import_field(\%hash,'callsign',\%input,'callsign') if ($type eq 'GEC');

			$hash{name} = to_ascii($hash{name});
			$hash{hidden} = 0;

			$hash{systemId64} = get_id64_by_name($hash{galMapSearch});
			delete($hash{systemId64}) if (!$hash{systemId64});
	
			delete($hash{coord_x}) if (!defined($hash{coord_x}));
			delete($hash{coord_y}) if (!defined($hash{coord_y}));
			delete($hash{coord_z}) if (!defined($hash{coord_z}));

			if (ref($hash{coord_x}) ne 'ARRAY') {
				#print JSON->new->pretty->encode(\%hash)."\n";
				print "POI $hash{name} = $hash{coord_x},$hash{coord_y},$hash{coord_z} - $hash{poiUrl}\n";
				update_object($type,\%hash);
			}
		}
		if ($type eq 'codex_edsm') {
			my %codex = ();
			foreach my $k (qw(systemId systemId64 systemName type name region reportedOn)) {
				import_directly(\%hash,\%input,$k);
			}

			import_field(\%codex,'SystemAddress',\%input,'systemId64');
			import_field(\%codex,'SystemName',\%input,'System');
			import_field(\%codex,'timestamp',\%input,'reportedOn');
			import_field(\%codex,'Region_Localised',\%input,'region');
			import_field(\%codex,'Name',\%input,'type');
			import_field(\%codex,'Name_Localised',\%input,'name');

			update_object($type,\%hash,\%input);
			codex_entry(\%codex);
		}
		if ($type eq 'station') {
			#{"id":49922,"marketId":3527482624,"type":"Planetary Outpost","name":"Mackenzie Vision","body":{"id":172488,"name":"Col 285 Sector TE-Q d5-104 A 5"},"distanceToArrival":252,"allegiance":"Independent","government":"Dictatorship","economy":"Colony","secondEconomy":null,"haveMarket":false,"haveShipyard":false,"haveOutfitting":false,"otherServices":[],"controllingFaction":{"id":80019,"name":"No Myoin Focus"},"updateTime":{"information":"2017-11-06 16:08:06","market":null,"shipyard":null,"outfitting":null},"systemId":2713296,"systemId64":3583873386867,"systemName":"Col 285 Sector TE-Q d5-104"},

			import_field(\%hash,'edsmID',\%input,'id');
			import_field(\%hash,'marketID',\%input,'marketId');
			import_field(\%hash,'bodyID',\%input,'body/id');
			import_field(\%hash,'bodyName',\%input,'body/name');
			import_field(\%hash,'updateTime',\%input,'updateTime/information');

			$hash{updateTime} =~ s/\+\d\d//s;

			foreach my $k (qw(systemId systemId64 systemName type name distanceToArrival 
				allegiance government economy secondEconomy haveMarket haveShipyard haveOutfitting)) {

				import_directly(\%hash,\%input,$k);
			}

			if ($input{date} =~ /^\d+$/) {
				$hash{edsm_date} = epoch2date($input{date});
			} else {
				$hash{edsm_date} = $input{date} if ($input{date});
			}

			update_object($type,\%hash,\%input);
		}
		if ($type eq 'system') {
			import_field(\%hash,'edsm_id',\%input,'id');
			import_field(\%hash,'id64',\%input,'id64');
			import_field(\%hash,'name',\%input,'name');
			import_field(\%hash,'coord_x',\%input,'coords/x');
			import_field(\%hash,'coord_y',\%input,'coords/y');
			import_field(\%hash,'coord_z',\%input,'coords/z');

#                        import_field(\%hash,'SystemGovernment',\%event,'SystemGovernment');
#                        import_field(\%hash,'SystemSecurity',\%event,'SystemSecurity');
#                        import_field(\%hash,'SystemEconomy',\%event,'SystemEconomy');
#                        import_field(\%hash,'SystemSecondEconomy',\%event,'SystemSecondEconomy');

			if ($input{date} =~ /^\d+$/) {
				$hash{updateTime} = epoch2date($input{date});
			} else {
				$hash{updateTime} = $input{date} if ($input{date});
			}
			#$hash{eddn_date} = $hash{edsm_date} if ($hash{edsm_date});

			$hash{eddn_date} =~ s/\+\d\d//s;
			$hash{edsm_date} =~ s/\+\d\d//s;
			$hash{updateTime} =~ s/\+\d\d//s;

			update_object($type,\%hash,\%input) if ($hash{id64});	# 2021-10-20: require id64 now
		}
		if ($type eq 'body' && $typekey{$bodyType}) {

			if ($input{discovery}{commander}) {
				import_field(\%hash,'commanderName',\%input,'discovery/commander');
			}
			if ($input{discovery}{date}) {
				import_field(\%hash,'discoveryDate',\%input,'discovery/date');
			}

			foreach my $k (@{$columns{$bodyType}}) {
				next if ($k eq 'parents' || $k eq 'id64');
				import_directly(\%hash,\%input,$k);
			}

			import_field(\%hash,'edsmID',\%input,'id');
			import_field(\%hash,'bodyId64',\%input,'id64');
			import_field(\%hash,'isMainStar',\%input,'mainStar') if (defined($input{mainStar}) && !defined($input{isMainStar}));

			foreach my $k (qw(rings belts materials parents)) {
				if (ref($input{$k})) {
					$hash{$k} = $input{$k};
				}
			}
			if (ref($input{atmosphereComposition}) eq 'HASH') {
				$hash{atmospheres} = $input{atmosphereComposition};
			}
			$hash{edsmID} = $hash{id} if ($hash{id} && !$hash{edsmID});
			#$hash{eddn_date} = $hash{updateTime} if ($hash{updateTime});

			$hash{eddn_date} =~ s/\+\d\d//s;
			$hash{edsm_date} =~ s/\+\d\d//s;
			$hash{updateTime} =~ s/\+\d\d//s;

			#print ">> $hash{name}\n";
			update_object($bodyType,\%hash) if ($hash{systemId64});	# 2021-10-20: require id64 now
		}
		exit if ($amChild);
	}
	
	close DATA;
	exit if ($amChild);


	if (!$amChild) {
		if ($type eq 'body') {
			eval {
				if ($drop_index) {
					print "Re-adding indexes.\n";
					eval_mysql('elite',"create index systemID on stars (systemId)");
					eval_mysql('elite',"create index systemID on planets (systemId)");
					eval_mysql('elite',"create index starName on stars (name)");
					eval_mysql('elite',"create index planetName on planets (name)");
					eval_mysql('elite',"create index starParents on stars (parents)");
					eval_mysql('elite',"create index planetParents on planets (parents)");
					eval_mysql('elite',"create index starDates on stars (updateTime)");
					eval_mysql('elite',"create index planetDates on planets (updateTime)");
					eval_mysql('elite',"create index starDisco on stars (discoveryDate)");
					eval_mysql('elite',"create index planetDisco on planets (discoveryDate)");
				}

				foreach my $table (qw(stars planets)) {
					eval_mysql('elite',"ALTER TABLE $table ENABLE KEYS") if ($disable_keys);
				}
				#eval_mysql('elite',"SET FOREIGN_KEY_CHECKS = 1; SET UNIQUE_CHECKS = 1; SET AUTOCOMMIT = 1; COMMIT");
			};
		}
	}
}

sub get_type {
	my $fn = shift;
	my $type = 'unknown';

	$type = 'POI' if ($fn =~ /POI/);
	$type = 'GEC' if ($fn =~ /GEC/);
	$type = 'system' if ($fn =~ /system/);
	$type = 'body' if ($fn =~ /body|bodies/);
	$type = 'station' if ($fn =~ /station/);
	$type = 'codex_edsm' if ($fn =~ /codex/);

	load_objects($type) if ($type ne 'codex_edsm' && $large_check && !$list_loaded{$type});
	$list_loaded{$type} = 1;

	return $type;
}

sub REAPER {
	while ((my $pid = waitpid(-1, &WNOHANG)) > 0) {
		info("FORK: Child on PID $pid terminated.\n") if ($fork_verbose);
		delete($child{$pid});
	}
	$SIG{CHLD} = \&REAPER;
}

sub info {
	warn @_;
}


sub to_ascii {
	my $text = shift;

	# Unicode and ISO-8859‑Latin-1, to ASCII.

	$text =~ s/\x{0020}|\x{00A0}|\x{2000}|\x{2001}|\x{2002}|\x{2003}|\x{2004}|\x{2005}|\x{2006}|\x{2007}/ /g;
	$text =~ s/\x{2008}|\x{2009}|\x{200A}|\x{200B}|\x{202F}|\x{205F}|\x{3000}|\x{FEFF}/ /g;
	$text =~ s/\x{02BA}|\x{2033}|\x{201C}|\x{201D}|\x{3003}|\x93|\x94|\x84/"/g;
	$text =~ s/\x{2018}|\x{2019}|\x{02B9}|\x{02BC}|\x{0027}|�\x{0080}\x{0099}/'/g;
	$text =~ s/\x{2010}|\x{2011}|\x{2012}|\x{2013}|\x{2212}|\x96|\x97/-/g;
	$text =~ s/\x{266F}/#/g;
	$text =~ s/\x88/^/g;
	$text =~ s/\x8B/</g;
	$text =~ s/\x9C/</g;
	$text =~ s/\x99/~/g;
	$text =~ s/\x91|\x92|\x82|\x60/'/g;
	$text =~ s/(\x85)/.../g;
	$text =~ s/(\x97)/x/g;
	$text =~ s/×/x/g;
	$text =~ s/\&#64257;/fi/g;
	$text =~ s/\&#64258;/fl/g;

	return $text;
}

sub eval_mysql {
	eval {
		db_mysql(@_);
	};
}



