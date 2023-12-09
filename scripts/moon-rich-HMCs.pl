#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch);

############################################################################

show_queries(0);

my $min_moons	= 5;
my $debug_limit	= '';# 'limit 1000';

my %planet_types = ();
$planet_types{'High metal content world'} = 1;

my $planet_type_list = "'".join("','",keys %planet_types)."'";

############################################################################

my %counts = ();
my %out = ();

my @sysrows = db_mysql('elite',"select distinct systemId64 from planets where subType in ($planet_type_list) and deletionState=0 order by systemId64 $debug_limit");

warn int(@sysrows)." systems to look at.\n";

print "System,Planet,Mass Code,Type,Moons,Rings,Arrival Distance,Terraforming State,Radius,Earth Masses,Surface Gravity,Surface Temperature,Surface Pressure,".
	"Volcanism,Atmosphere,Axial Tilt,Rotational Period,Tidally Locked,Orbital Period,".
	"Semi-major Axis,Orbital Eccentricity,Orbital Inclination,Arg. of Periapsis,".
	"Coord X,Coord Y,Coord Z,Timestamp,EDSM Discoverer,EDSM Discovery Date\r\n";

my $count = 0;
foreach my $s (@sysrows) {
	my $sysID = $$s{systemId64};
	next if (!$sysID);

	my $sys = undef;

	my @rows = db_mysql('elite',"select * from planets where systemId64=? and deletionState=0",[($sysID)]);
	
	my %planet = ();
	my %mooncount = ();

	foreach my $r (@rows) {
		$planet{$$r{name}} = $r;
	}

	foreach my $r (@rows) {
		if ($$r{name} =~ /^(.+\S)\s+([\w\d]+)\s*$/) {
			my ($parent,$num) = ($1,$2);
			
			if ($planet{$parent}{name}) {
				$mooncount{$parent}++;
			}
		}
	}
	
	foreach my $name (keys %planet) {
		my $r = $planet{$name};
		next if (!$planet_types{$$r{subType}});

		$mooncount{$name} = 0 if (!$mooncount{$name});
		$counts{$mooncount{$name}}++;
		next if ($mooncount{$name}<$min_moons);

		if (!keys %$sys) {
			my @rows2 = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where id64='$$s{systemId64}' and deletionState=0");
			if (@rows2) {
				$sys = shift @rows2;
			} else {
				%$sys = ();
			}
		}

		$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{planetID} = 0 if (!defined($$r{planetID}));

		my @rows2 = db_mysql('elite',"select id from rings where planet_id='$$r{planetID}' and isStar=0");
		my $num = int(@rows2);
	
		my $locked = 'no';
		$locked = 'yes' if ($$r{rotationalPeriodTidallyLocked});
	
		my $masscode = '';
	
		if ($$r{name} =~ /\S+\s+\w\w\-\w\s+([a-zA-Z])(\d+\-)?\d+/) {
			$masscode = uc($1);
		}

		warn "$$sys{name},$$r{name},$mooncount{$name}\n" if ($mooncount{$name} >=12);
	
		$out{$mooncount{$name}}{$$r{name}} = "$$sys{name},$$r{name},$masscode,$$r{subType},$mooncount{$name},$num,".
			"$$r{distanceToArrivalLS},$$r{terraformingState},$$r{radius},$$r{earthMasses},$$r{gravity},$$r{surfaceTemperature},$$r{surfacePressure},".
			"$$r{volcanismType},$$r{atmosphereType},$$r{axialTilt},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},$$r{semiMajorAxis},$$r{orbitalEccentricity},".
			"$$r{orbitalInclination},$$r{argOfPeriapsis},$$sys{coord_x},$$sys{coord_y},$$sys{coord_z},$$r{updateTime},$$r{commanderName},$$r{discoveryDate}\r\n";
		$count++;
	}
}

foreach my $n (sort {$a <=> $b} keys %out) {
	foreach my $name (sort {$a cmp $b} keys %{$out{$n}}) {
		print $out{$n}{$name};
	}
}

warn "$count found\n";

print "\r\n";
print "Number of moons,Planets\r\n";

foreach my $n (sort {$a <=> $b} keys %counts) {
	print "$n,$counts{$n}\r\n";
	warn "$n,$counts{$n}\n";
}



