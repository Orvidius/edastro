#!/usr/bin/perl
use strict; $|=1;

###########################################################################

use LWP::Simple;
use HTML::TableExtract;
use JSON;
use POSIX qw(floor);
use Data::Dumper;

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);
use ATOMS qw(btrim parse_csv epoch2date date2epoch);

###########################################################################

show_queries(0);

# Administator's list:  https://docs.google.com/spreadsheets/d/1aiWGXeFUojFnDkBG9UezKqZUMWZZCjYKO0Fj028fI_E/edit#gid=494694841

my $te = undef;

my $url  = 'https://docs.google.com/spreadsheets/d/e/2PACX-1vTevQUcLThqo4emXE4nowJeasI07gFio4fETwevAXKIA18NhlDzbnZzRMVUOAT26OROfHG7fCXvTLgY/pubhtml?gid=0&single=true';
my $html = get $url;

system('wget -O DSSA.csv "https://docs.google.com/spreadsheets/d/1aiWGXeFUojFnDkBG9UezKqZUMWZZCjYKO0Fj028fI_E/gviz/tq?tqx=out:csv&sheet=DSSA"') if (!@ARGV);

my @column_patterns = qw(CALLSIGN VESSEL DESTINATION SERVICES OWNER # CURRENT REGION STATUS LAUNCH UNTIL SERIAL);

my %carrier = ();
my %sector = ();
my %oldID = ();

my @monthlist = ('JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC');
my %month = ();
my $i=0;
foreach my $m (@monthlist) {
	$i++;
	$month{$m} = sprintf("%02u",$i);
}

open TSV, "</home/bones/elite/DSSA-carriers.tsv.20200617";
while (<TSV>) {
	chomp;
	my @v = split /\t/, $_;

	next if ($v[1] =~ /DSSA#/);

	$oldID{$v[0]} = $v[1];
	#print "OLD DSSA#$v[0] = $v[1]\n";
}
close TSV;

open CSV, "</home/bones/elite/scripts/sector-list.csv";
my $CSVheader = <CSV>;
while (<CSV>) {
	chomp;
	my @v = parse_csv($_);
	my $s = uc(btrim($v[0]));

	$sector{$s}{avgx} = $v[2];
	$sector{$s}{avgy} = $v[3];
	$sector{$s}{avgz} = $v[4];
	$sector{$s}{minx} = $v[5];
	$sector{$s}{miny} = $v[6];
	$sector{$s}{minz} = $v[7];
	$sector{$s}{maxx} = $v[8];
	$sector{$s}{maxy} = $v[9];
	$sector{$s}{maxz} = $v[10];
}
close CSV;

print int(keys %sector)." sectors.\n";

db_mysql('elite',"update carriers set isDSSA=0");

my $today = epoch2date(time);
$today =~ s/\s.+$//s;

# Get status overrides
my %override = ();
open CSV, "<DSSA-status-override.csv";
while (<CSV>) {
	my @v = parse_csv($_);
	$override{uc($v[0])} = $v[1];
}
close CSV;

my @rows = ();
my @data = ();
my %col  = ();

open CSV, "<DSSA.csv";

while (<CSV>) {
	chomp;
	my @v = parse_csv($_);

	if (!keys(%col)) {

		foreach my $key (@column_patterns) {
			for (my $i=0; $i<@v; $i++) {
				if (!$col{$key} && $v[$i] =~ /$key/i) {
					$col{$key} = $i;
					last;
				}
				if (!$col{$key} && $key eq '#' && $v[$i] =~ /DSSA\s+\#/) {
					$col{$key} = $i;
					last;
				}
			}

			$col{$key} = 0 if ($key eq '#' && !$col{$key});

			print $key.'['.$col{$key}."], ";
		}
		print "\n\n";

		$carrier{0} = {
			callsign	=> 'V6W-63K',
			owner		=> 'Antikythera67',
			name		=> '[DSSA-HQ] Procul Umbra',
			services	=> 'Repair, Armoury, Universal Cartographics, Refuel, Redemption Office, Shipyard, Outfitting, Vista Genomics (required for Odyssey CMDRs), Bar, Pioneer Services',
			num		=> 0,
			status		=> 'Carrier Operational',
			until		=> 'September 1, 2032',
			serial		=> '',
			region		=> 'Formorian Frontier',
			systemORIG	=> 'Sol',
			system		=> 'Smootoae QY-S d3-202',
			current		=> 'Smootoae QY-S d3-202',
			sector		=> 'Smootoae',
		};

	} else {
		my $id = $v[$col{'#'}];
		next if (!$id);

		print "TABLE[$id]: ".join(' +|+ ', @v), "\n";

		# qw(CALLSIGN VESSEL DESTINATION SERVICES OWNER # CURRENT REGION STATUS LAUNCH UNTIL SERIAL);

		$carrier{$id}{callsign} = uc($v[$col{CALLSIGN}]);
		$carrier{$id}{callsign} = "DSSA#$v[$col{'#'}]" if (!$carrier{$id}{callsign});
		$carrier{$id}{name} = $v[$col{VESSEL}];
		$carrier{$id}{services} = $v[$col{SERVICES}];
		$carrier{$id}{services} =~ s/\s*\([^,]*\)//gs;
		$carrier{$id}{owner} = $v[$col{OWNER}];
		$carrier{$id}{num} = $v[$col{'#'}];
		$carrier{$id}{region} = $v[$col{REGION}];
		$carrier{$id}{status} = $v[$col{STATUS}];
		$carrier{$id}{status} = $override{$carrier{$id}{callsign}} if ($carrier{$id}{callsign} && $override{$carrier{$id}{callsign}});
		$carrier{$id}{until} = $v[$col{UNTIL}];
		$carrier{$id}{serial} = $v[$col{SERIAL}];

		if ($v[$col{LAUNCH}] =~ /(\w+)\s+(\d+),\s+(\d+)/) {
			$carrier{$id}{launchdate} = sprintf("%04u-%02u-%02u",$3,$month{uc(substr($1,0,3))},$2);
		}

		if ($v[$col{DESTINATION}] =~ /^\s*(((\S+\s+)+)[A-Za-z][A-Za-z]-[A-Za-z]\s+[A-Za-z]\d+(-\d+)?)\s*/) {
			$carrier{$id}{systemORIG} = $v[$col{DESTINATION}];
			$carrier{$id}{system} = $1;
			$carrier{$id}{sector} = btrim($2);
		} else {
			$carrier{$id}{system} = $carrier{$id}{systemORIG} = $v[$col{DESTINATION}];
		}

		if ($v[$col{CURRENT}] =~ /^\s*((\S+\s+)+[A-Za-z][A-Za-z]-[A-Za-z]\s+[A-Za-z]\d+(-\d+)?)\s*/) {
			$carrier{$id}{current} = $1;
		} else {
			$carrier{$id}{current} = $v[$col{CURRENT}];
		}

		$carrier{$id}{owner} =~ s/[^\x00-\x7f]//g;
		$carrier{$id}{name} =~ s/[^\x00-\x7f]//g;

		$carrier{$id}{system} = $carrier{$id}{current} if (!$carrier{$id}{system} && $carrier{$id}{status}=~/operational/i);

		if ($carrier{$id}{system} =~ /^\s*((\w+\s+)+[A-Z][A-Z]-[A-Z]\s+[a-z](\d+\-)?\d+)(.*)$/i) {
			$carrier{$id}{system} = $1;
		}

	}

#warn "#11 $carrier{$id}{system}\n" if ($$row[5] == 11);
}
close CSV;

open TSV, ">DSSA-carriers.tsv";

my $count = 0;
foreach my $id (sort {$a <=> $b || $a cmp $b} keys %carrier) {
	my ($x,$y,$z,$sys) = get_coords($carrier{$id}{system},$carrier{$id}{sector});

	#print 'Dumper[$id]: '.Dumper($carrier{$id})."\n";

	if (!defined($x) || !defined($y) || !defined($z)) {
	
		print TSV join("\t",$carrier{$id}{num},$carrier{$id}{callsign},$carrier{$id}{name},$carrier{$id}{owner},$carrier{$id}{system},undef,undef,undef,$carrier{$id}{services},$carrier{$id}{current},$carrier{$id}{status},$carrier{$id}{region},$carrier{$id}{until})."\r\n";

		next;
	} 

	$carrier{$id}{coords}{x} = $x;
	$carrier{$id}{coords}{y} = $y;
	$carrier{$id}{coords}{z} = $z;

	if ($carrier{$id}{launchdate} && $carrier{$id}{launchdate} lt $today && $carrier{$id}{status} =~ /PLANNING|PREPARATION/i) {
		warn "Skipping unprepared carrier #$carrier{$id}{num} \"$carrier{$id}{name}\" [$carrier{$id}{callsign}] (owner: $carrier{$id}{owner}) $x,$y,$z ($carrier{$id}{system})\n";
	}

	my $show_sys = $carrier{$id}{system};
	$show_sys = $sys if (uc(btrim($sys)) eq uc(btrim($carrier{$id}{system})));

	print "$carrier{$id}{callsign} \"$carrier{$id}{name}\" [$carrier{$id}{owner}] #$carrier{$id}{num}\n";
	print "\t$show_sys ($x,$y,$z)\n";
	print "\t$carrier{$id}{services}\n\n";
	$count++;

	my @IDcheck1 = db_mysql('elite',"select ID from carriers where (converted is null or converted=0) and callsign=?",[($oldID{$carrier{$id}{num}})]) if ($oldID{$carrier{$id}{num}});
	my @IDcheck2 = db_mysql('elite',"select ID from carriers where converted=1 and callsign=?",[($carrier{$id}{callsign})]);
	if (@IDcheck1 && !@IDcheck2 && uc($carrier{$id}{callsign}) ne uc($oldID{$carrier{$id}{num}}) && $oldID{$carrier{$id}{num}} && $carrier{$id}{callsign} =~ /^[\w\d]{3,4}\-[\w\d]{3,4}$/) {
		# Carrier exists with old ID. Rename to preserve info.
		db_mysql('elite',"delete from carriers where callsign=?",[($carrier{$id}{callsign})]);
		db_mysql('elite',"update carriers set callsign=?,converted=1,callsign_old=? where callsign=?",[($carrier{$id}{callsign},$oldID{$carrier{$id}{num}},$oldID{$carrier{$id}{num}})]);
		db_mysql('elite',"update carrierlog set callsign=? where callsign=?",[($carrier{$id}{callsign},$oldID{$carrier{$id}{num}})]);
	}

	db_mysql('elite',"update carriers set commander=? where callsign=? and (commander is null or commander='')",
		[($carrier{$id}{owner},$carrier{$id}{callsign})]) 
		if ($carrier{$id}{callsign} =~ /^[\w\d]{3,4}\-[\w\d]{3,4}$/ && $carrier{$id}{owner});

	db_mysql('elite',"update carriers set name=?,isDSSA=1 where callsign=?", [($carrier{$id}{name},$carrier{$id}{callsign})]) 
		if ($carrier{$id}{callsign} =~ /^[\w\d]{3,4}\-[\w\d]{3,4}$/ && $carrier{$id}{name});

	print TSV join("\t",$carrier{$id}{num},$carrier{$id}{callsign},$carrier{$id}{name},$carrier{$id}{owner},$show_sys,$x,$y,$z,$carrier{$id}{services},$carrier{$id}{current},$carrier{$id}{status},$carrier{$id}{region},$carrier{$id}{until},$carrier{$id}{serial})."\r\n";
}
print "$count carriers shown\n";

close TSV;


open JS, ">DSSA-carriers.json";
my @list = ();
foreach my $n (sort {$a <=> $b} keys %carrier) {
	#next if (!$n);

	my %hash = %{$carrier{$n}};
	delete($hash{systemORIG});
	delete($hash{current});
	delete($hash{system});
	delete($hash{num});
	delete($hash{services});

	@{$hash{services}} = split /[,\s]+/, $carrier{$n}{services};
	$hash{id} = $carrier{$n}{num};
	$hash{designatedSystem} = $carrier{$n}{system};
	$hash{currentReportedSystem} = $carrier{$n}{current};

	my @rows = db_mysql('elite',"select systemName,lastEvent,FSSdate from carriers where callsign=?",[($carrier{$n}{callsign})]);
	foreach my $r (@rows) {
		$hash{lastSeenSystem} = $$r{systemName};
		$hash{lastSeenDate} = $$r{lastEvent};
		$hash{lastSeenDate} = $$r{FSSdate} if ($$r{FSSdate} && $$r{FSSdate} gt $$r{lastEvent});
	}

	push @list, \%hash;
}
print JS JSON->new->encode(\@list);
close JS;

system('/usr/bin/scp','DSSA-carriers.json','www@services:/www/edastro.com/json/');

exit;

###########################################################################

sub get_coords {
	my $sys = shift;
	my $sect = shift;
	my $next = '';
	my @rows = ();
	my $systemName = $sys;

#print "LOOKUP $sys\n";

	while ($sys && !@rows) {
		$sys = $next if ($next);
		@rows = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where deletionState=0 and name=?",[($sys)]);

		if (!@rows) {
			my @s = split /\s+/,$sys;
			last if (@s == 1);
			pop @s;
			$next = join(' ',@s);
		}
	}

	if (!@rows) {
		@rows = db_mysql('elite',"select name,coord_x,coord_y,coord_z from navsystems where name=?",[($sys)]);
	}

	if (@rows) {
		return (${$rows[0]}{coord_x}, ${$rows[0]}{coord_y}, ${$rows[0]}{coord_z}, ${$rows[0]}{name});
	} else {
		if ($sect) {
			if (exists($sector{uc($sect)})) {
				my ($x,$y,$z) = estimated_coords($systemName);
				if (defined($x) && defined($y) && defined($z)) {
					return ($x,$y,$z,$sect);
				} else {
					return($sector{uc($sect)}{avgx},$sector{uc($sect)}{avgy},$sector{uc($sect)}{avgz},$sect);
				}
			}

#print "Digging DB: $systemName / $sect\n";

			# Got to here? Try DB lookup.

			my ($ax, $ay, $az, $num);
			my $sec = $sect;
			$sec =~ s/[^\w\d\_\-\.]+//gs;
	
			my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where deletionState=0 and name like '$sec\%'");
			foreach my $r (@rows) {
				$num++;
				$ax += $$r{coord_x};
				$ay += $$r{coord_y};
				$az += $$r{coord_z};
			}
			
			if ($num && (sqrt($ax**2 + $az**2)>500)) {
				return (floor($ax/$num),floor($ay/$num),floor($az/$num),$sec);
			}
		}

		return (undef,undef,undef,$sys);
	}
}

###########################################################################

sub estimated_coords {
	my $system = shift;

#print "ESTIMATE COORDs: $system = ";

        my ($sectorname,$l1,$l2,$l3,$masscode,$n,$num) = ();

        if ($system =~ /^(\S.*\S)\s+([A-Z])([A-Z])\-([A-Z])\s+([a-z])(\d*)\-(\d+)/i) {
                ($sectorname,$l1,$l2,$l3,$masscode,$n,$num) = (uc($1),$2,$3,$4,$5,$6,$7);
        } elsif ($system =~ /^(\S.*\S)\s+([A-Z])([A-Z])\-([A-Z])\s+([a-z])(\d*)$/i) {
                ($sectorname,$l1,$l2,$l3,$masscode,$n,$num) = (uc($1),$2,$3,$4,$5,0,$7);
        }

        if (exists($sector{uc($sectorname)}) && $sectorname && $l1 && $l2 && $l3 && $masscode) {
                my $subsector = ($n*17576) + (letter_ord($l3)*676) + (letter_ord($l2)*26) + letter_ord($l1);

		my $bitcount = letter_ord(uc($masscode));
		my $size = 1 << $bitcount;
                my $width = 128 >> $bitcount;
                my $mask = $width-1;

                my $x = ($subsector & $mask)*$size;
                my $y = (($subsector >> $bitcount) & $mask)*$size;
                my $z = (($subsector >> ($bitcount*2)) & $mask)*$size;

		my $estx = $sector{uc($sectorname)}{minx} + $x*10 + $width*5;
                my $esty = $sector{uc($sectorname)}{miny} + $y*10 + $width*5;
                my $estz = $sector{uc($sectorname)}{minz} + $z*10 + $width*5;

#print "$estx,$esty,$estz\n";
		return ($estx,$esty,$estz);
	}
#print "not found '$sectorname'\n";
	return (undef,undef,undef);

}


sub letter_ord {
        return ord(uc(shift))-ord('A');
}

###########################################################################



