#!/usr/bin/perl
use strict; $|=1;

###########################################################################

use LWP 5.64;
use JSON;
use Data::Dumper;

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);
use ATOMS qw(date2epoch epoch2date make_csv parse_csv);

use lib "/home/bones/elite";
use EDSM qw(object_newer import_field import_directly update_object load_objects add_object object_exists dump_objects 
        $edsm_use_names $large_check $allow_updates $force_updates edsm_debug check_updates %typekey %columns);

###########################################################################

my $debug       = 0;
my $verbose     = 0;

my $db		= 'elite';

my $apiDomain   = 'https://www.edsm.net';
my $ratefile	= '/home/bones/elite/edsm/ratelimit.txt';
my $id64converter	= 'https://www.edsm.net/en/system?systemID64=';

my $systemsURL	= "$apiDomain/api-v1/systems";
my $systemURL	= "$apiDomain/api-v1/system";
my $bodiesURL	= "$apiDomain/api-system-v1/bodies";

###########################################################################


show_queries($debug);

my $time = time;
my $epoch = time;
my %systems = ();
my %bodies = ();
my $ratelimit = 0;
my $ratelimitmax = 0;
my $count = 0;

die "Usage: $0 <SystemName> [SystemName..]\n" if (!@ARGV);

print "-----\n";

open TXT, "<$ratefile";
$ratelimit = <TXT>; chomp $ratelimit; $ratelimit+=0;
$ratelimitmax = <TXT>; chomp $ratelimitmax; $ratelimitmax+=0;
close TXT;
$count = 1 if ($ratelimit && $ratelimitmax && @ARGV>1);

print "Ratelimit: $ratelimit / $ratelimitmax\n";

get_systems();

open TXT, ">$ratefile";
print TXT "$ratelimit\n$ratelimitmax\n";
close TXT;

exit;

###########################################################################

sub get_systems {

	my $browser = LWP::UserAgent->new;
	$browser->ssl_opts(verify_hostname => 0);
	my %retrieved = ();
	my %getlist = ();
	my %namelist = ();

	foreach my $argID (@ARGV) {
		my $sysname = $argID;

		next if (!$argID);

		if ($argID =~ /^\d+$/) {
			# We have an id64 already
			$getlist{$argID} = 1;

		} else {
			$sysname =~ s/'/\\'/gs;

			my @rows = db_mysql('elite',"select id64,edsm_id from systems where name=?",[($sysname)]);
			if (@rows) {
				if (${$rows[0]}{edsm_id} && ${$rows[0]}{id64}) {
					$retrieved{${$rows[0]}{id64}} = ${$rows[0]}{edsm_id};
				} else {
					$namelist{$sysname}=1 if (!${$rows[0]}{id64});
					$getlist{${$rows[0]}{id64}}=1 if (${$rows[0]}{id64});
				}
			}
		}
	}

	if ($count) {
		my $delay = get_delay($epoch,$ratelimit,$ratelimitmax);
		if ($delay > 0 && $ratelimit && $ratelimitmax) {
			print "Sleeping: $delay ($ratelimit/$ratelimitmax)\n";
			sleep $delay;
		}
	}
	$epoch = time;
	$count++;

	print "Needed: ".(int(keys(%getlist))+int(keys(%namelist))).", Pre-fetched: ".int(keys(%retrieved))."\n";

	if (keys %getlist) {

		my $url = "$systemsURL?showId=1\&showCoordinates=1";

		foreach my $sys (sort keys %getlist) {
			$url .= "\&systemId64\[\]=$sys";
		}

		foreach my $sys (sort keys %namelist) {
			$url .= "\&systemName\[\]=$sys";
		}

		print "GET $url\n" ;#if ($verbose);
		my $response = $browser->get($url);
	
		$ratelimit = $response->header('X-Rate-Limit-Remaining');
		$ratelimitmax = $response->header('X-Rate-Limit-Limit');
		
		if (!$response->is_success) {
			warn "Could not retrieve systems.\n";
			print $response->status_line()."\n";
		} else {
			my $json = JSON->new->allow_nonref;
			my $ref = $json->decode( $response->content );
	
			#print Dumper($ref)."\n\n";
	
			if (ref($ref) ne 'ARRAY') {
				print "\tnone found.\n";
			} else {
				print "\tfound: ".int(@$ref)."\n";
				foreach my $s (@$ref) {
					if (ref($s) eq 'HASH') {
						if ($$s{id}) {
							$systems{$$s{id}} = $json->encode($s);
							print "$$s{id} = $systems{$$s{id}}\n" if ($verbose);
							$retrieved{$$s{name}} = $$s{id} if ($$s{name} && !$$s{id64});
							$retrieved{$$s{id64}} = $$s{id} if ($$s{id64});
						}
					}
				}
			}
	
		}
	}


	foreach my $id64 (keys %retrieved) {
		my $edsmID = $retrieved{$id64};

		my $delay = get_delay($epoch,$ratelimit,$ratelimitmax);
		if ($delay > 0 && $ratelimit && $ratelimitmax) {
			print "Sleeping: $delay ($ratelimit/$ratelimitmax)\n";
			sleep $delay;
		}

		my $url = undef;
		$url = "$bodiesURL?systemName=$id64" if ($id64 !~ /^\d+$/);
		$url = "$bodiesURL?systemId64=$id64" if ($id64 =~ /^\d+$/);
		next if (!$url);

		print "GET $url\n" ;# if ($verbose);
		my $response = $browser->get($url);
		$ratelimit = $response->header('X-Rate-Limit-Remaining');
		$ratelimitmax = $response->header('X-Rate-Limit-Limit');

		print "$id64 - ";

		if (!$response->is_success) {
			warn "Could not retrieve bodies from '$id64'.\n";
			print $response->status_line()."\n";
			next;
		} else {

			my $json = JSON->new->allow_nonref;
			my $ref = $json->decode( $response->content );

			next if (ref($ref) ne 'HASH' || !$$ref{bodies});

			print "$$ref{name} - ";

			if (ref($$ref{bodies}) eq 'ARRAY' && @{$$ref{bodies}}) {
				print "($edsmID) ".int(@{$$ref{bodies}})."\n";

				my %names = ();
				my %id64s = ();

				foreach my $body (@{$$ref{bodies}}) {
					$$body{systemId} = $$ref{id};
					$$body{systemId64} = $id64;
					delete($$body{updateTime});
#					if ($$body{discovery}{date} =~ /\d{4}-\d{2}-\d{2}/) {
#						$$body{updateTime} = $$body{discovery}{date};
#					}

					$bodies{$$body{id}} = $json->encode($body);
					$names{$$body{name}} = 1 if ($$body{name});
					$id64s{$$body{id64}} = 1 if ($$body{id64});
					print "$$body{id} = $bodies{$$body{id}}\n" if ($verbose);

					if ($$body{type} =~ /^(star|planet)$/i && $$body{id64}) {
						my $table = lc($$body{type}).'s';
						my $IDfield = 'starID';
						$IDfield = 'planetID' if ($table eq 'planets');
						my @rows = db_mysql('elite',"select $IDfield from $table where systemId64=? and bodyId64=? and deletionState=0 order by $IDfield",
							[($id64,$$body{id64})]);
						if (@rows>1) {
							my $id_list = '';
							for(my $i=1; $i<@rows; $i++) {
								$id_list .= ','.${$rows[$i]}{$IDfield};
							}
							$id_list =~ s/^,+//;

							if ($id_list) {
								print "Mark to delete: $id64: $$body{name} [$$body{id64}]: $id_list (Save: ${$rows[0]}{$IDfield})\n";
								db_mysql('elite',"update $table set deletionState=1 where $IDfield in ($id_list)");
							}
						}
					}
				}

				my $delete = '';
				my @rows = db_mysql('elite',"select planetID,name,bodyId64 from planets where systemId64=? and deletionState=0",[($id64)]);
				foreach my $r (@rows) {
					if (($$r{bodyId64} && !$id64s{$$r{bodyId64}}) && !$names{$$r{name}}) {
						$delete .= ',' if ($delete);
						$delete .= $$r{planetID};
					}
				}
				if ($delete) {
					open TXT, ">>delete-planets.txt\n";
					print TXT "$id64:$delete\n";
					db_mysql('elite',"update planets set deletionState=1 where planetID in ($delete)");
					close TXT;
				}

				my $delete = '';
				my @rows = db_mysql('elite',"select starID,name,bodyId64 from stars where systemId64=? and deletionState=0",[($id64)]);
				foreach my $r (@rows) {
					if (($$r{bodyId64} && !$id64s{$$r{bodyId64}}) && !$names{$$r{name}}) {
						$delete .= ',' if ($delete);
						$delete .= $$r{starID};
					}
				}
				if ($delete) {
					open TXT, ">>delete-stars.txt\n";
					print TXT "$id64:$delete\n";
					db_mysql('elite',"update stars set deletionState=1 where starID in ($delete)");
					close TXT;
				}
			} else {
				print "not found.\n";
			}
		}

	}

	if (keys %systems || keys %bodies) {

		my $b_file = "/home/bones/elite/edsm/bodies-$$.jsonl";
		my $s_file = "/home/bones/elite/edsm/systems-$$.jsonl";

		open SYSTEMS, ">$s_file";
		foreach my $id (keys %systems) {
			print SYSTEMS "$systems{$id}\n";
		}
		close SYSTEMS;
	
		open BODIES, ">$b_file";
		foreach my $id (keys %bodies) {
			print BODIES "$bodies{$id}\n";
		}
		close BODIES;
	
		if (!$debug) {
			system("/home/bones/elite/parse-data.pl -ux $s_file");
			system("/home/bones/elite/parse-data.pl -ux $b_file");
			unlink $s_file;
			unlink $b_file;
		}
	}

	my $list = '';
	foreach my $id64 (keys %retrieved) {
		$list .= " $id64" if ($id64 =~ /^\d+$/);
	}
	$list =~ s/^\s+//;

	system("~bones/elite/scripts/update-numbodies.pl $list") if ($list);
}

sub get_delay {
	my $epoch = shift;
	my $ratelimit = shift;
	my $ratelimitmax = shift;

	my $delay = 12 - (time - $epoch);       # default

	if ($ratelimit =~ /^\d+$/ && $ratelimitmax =~ /^\d+$/ && $ratelimit && $ratelimitmax) {
		if ($ratelimit/$ratelimitmax < 0.05) {
			$delay = 45;
		} elsif ($ratelimit/$ratelimitmax < 0.1) {
			$delay = 25;
		} elsif ($ratelimit/$ratelimitmax < 0.3) {
			$delay = 10;
		} elsif ($ratelimit/$ratelimitmax < 0.5) {
			$delay = 5;
		} elsif ($ratelimit/$ratelimitmax < 0.7) {
			$delay = 3;
		} elsif ($ratelimit/$ratelimitmax < 0.8) {
			$delay = 2;
		} elsif ($ratelimit/$ratelimitmax < 0.9) {
			$delay = 1;
		} else {
			$delay = 0;
		}
	} elsif ($ratelimit =~ /^\d+$/) {
		$delay = 1;
	}
	return $delay;
}

sub get_edsmID {
	my $id64 = shift;
	my $browser = LWP::UserAgent->new;
}

###########################################################################

