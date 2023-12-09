#!/usr/bin/perl
use strict; $|=1;

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);
use ATOMS qw(date2epoch epoch2date btrim parse_csv);

use LWP::Simple;
use HTML::TableExtract;
use POSIX qw(floor);

###########################################################################
my $path	= '/home/bones/elite/inara';

###########################################################################

show_queries(0);
my $commanders = 0;

# NOTE: Inara-scraper moved to "scrape-inara-carriers.pl"

my %carrier = ();

open CSV, "<inara-carriers-roster.csv";

#"Name","Callsign","System","User","Date","2020/08/12"
my $header = <CSV>;

while (my $line = <CSV>) {
	chomp $line;
	my @v = parse_csv($line);
	
	for (my $i=0; $i<@v; $i++) {
		$v[$i] =~ s/\s+/ /gs;
		$v[$i] =~ s/[^\x00-\x7f]//g;
	}

	my $callsign = btrim($v[1]);
	my $name = btrim($v[0]);

	next if (!$callsign);

	print "$callsign: ".join(',', @v), "\n";

	$carrier{$callsign}{name} = $name;
	$carrier{$callsign}{system} = btrim($v[2]);
	$carrier{$callsign}{commander} = btrim($v[3]);
	$commanders++ if ($carrier{$callsign}{commander} =~ /\S/);
}

print int(keys %carrier)." carriers found.\n";
print "$commanders commanders found.\n";

my $delete_date = epoch2date(time-86400);

foreach my $callsign (sort keys %carrier) {
	my ($x,$y,$z,$sys,$id64) = get_coords($carrier{$callsign}{system});
	print "$carrier{$callsign}{name} [$callsign] $sys ($x, $y, $z) \"$carrier{$callsign}{commander}\" - ";

	my $updated = 0;

	my @check = db_mysql('elite',"select ID,name,commander,lastEvent from carriers where callsign=?",[($callsign)]);

	if (@check) {
		print "FOUND!\n";
	} else {
		print "NOT found.\n";
	}

	if (!@check) {
		db_mysql('elite',"insert into carriers (callsign,name,commander,systemName,systemId64,coord_x,coord_y,coord_z,created,updated) values (?,?,?,?,?,?,?,?,NOW(),NOW())",
			[($callsign,$carrier{$callsign}{name},$carrier{$callsign}{commander},$carrier{$callsign}{system},$id64,$x,$y,$z)]);
		$updated = 1;
	} 
	if (@check && $carrier{$callsign}{name} && ${$check[0]}{name} ne $carrier{$callsign}{name}) {
		db_mysql('elite',"update carriers set name=? where callsign=? and (isIGAU!=1 or isIGAU is null)",[($carrier{$callsign}{name},$callsign)]);
		$updated = 1;
	} 
	if (@check && $carrier{$callsign}{commander} && ${$check[0]}{commander} ne $carrier{$callsign}{commander}) {
		db_mysql('elite',"update carriers set commander=? where callsign=? and (isIGAU!=1 or isIGAU is null)",[($carrier{$callsign}{commander},$callsign)]);
		$updated = 1;
	} 
	if (@check && !${$check[0]}{lastEvent} && ${$check[0]}{systemName} ne $carrier{$callsign}{system}) {
		db_mysql('elite',"update carriers set systemName=?,systemId64=?,coord_x=?,coord_y=?,coord_z=? where callsign=?",
			[($carrier{$callsign}{system},$id64,$x,$y,$z,$callsign)]);
		$updated = 1;
	}
	if (!$updated) {
		db_mysql('elite',"update carriers set updated=NOW() where callsign=?",[($callsign)]);
	}
}

#db_mysql('elite',"delete from carriers where marketID is null and updated<?",[($delete_date)]) if (keys(%carrier)>5000);


exit;

###########################################################################

sub get_coords {
	my $sys = shift;
	my $sector = shift;
	my $next = '';
	my @rows = ();

	while ($sys && !@rows) {
		$sys = $next if ($next);
		@rows = db_mysql('elite',"select name,coord_x,coord_y,coord_z,id64 from systems where deletionState=0 and name=?",[($sys)]);

		if (!@rows) {
			my @s = split /\s+/,$sys;
			last if (@s == 1);
			pop @s;
			$next = join(' ',@s);
		}
	}

	if (@rows) {
		return (${$rows[0]}{coord_x}, ${$rows[0]}{coord_y}, ${$rows[0]}{coord_z}, ${$rows[0]}{name}, ${$rows[0]}{id64});
	} else {
		if ($sector) {
			my ($ax, $ay, $az, $num);
			my $sec = $sector;
			$sec =~ s/[^\w\d\_\-\.]+//gs;

			my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where deletionState=0 and name like '$sec\%'");
			foreach my $r (@rows) {
				$num++;
				$ax += $$r{coord_x};
				$ay += $$r{coord_y};
				$az += $$r{coord_z};
			}

			if ($num && (sqrt($ax**2 + $az**2)>500)) {
				return (floor($ax/$num),floor($ay/$num),floor($az/$num),$sec,undef);
			}
		}

		return (undef,undef,undef,$sys,undef);
	}
}

###########################################################################

