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

my $planet_types = "'Earth-like world'";

if (@ARGV) {
	$planet_types = "";

	foreach my $arg (@ARGV) {
		$arg =~ s/[^\w\d\s\-\(\)\.]+//gs;
		$planet_types .= ",'$arg'";
	}

	$planet_types =~ s/^,//;
}

my @rows = db_mysql('elite',"select * from planets where subType in ($planet_types) and deletionState=0 order by name");

print "System,Planet,Total Moons,Ringed Moons,Mass Code,Type,Rings,Arrival Distance,Terraforming State,Radius,Earth Masses,Surface Gravity,Surface Temperature,Surface Pressure,".
	"Volcanism,Atmosphere,Axial Tilt,Rotational Period,Tidally Locked,Orbital Period,".
	"Semi-major Axis,Orbital Eccentricity,Orbital Inclination,Arg. of Periapsis,".
	"Coord X,Coord Y,Coord Z,Timestamp,EDSM Discoverer,EDSM Discovery Date\r\n";

my $count = 0;
foreach my $r (@rows) {

	#warn "$$r{name}\n";

	$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{planetID} = 0 if (!defined($$r{planetID}));

	my @rows2 = db_mysql('elite',"select id from rings where planet_id='$$r{planetID}' and isStar=0");
	my $num = int(@rows2);

	my $r2 = undef;
	@rows2 = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where id64='$$r{systemId64}'");
	if (@rows2) {
		$r2 = shift @rows2;
	} else {
		%$r2 = ();
	}

	my $locked = 'no';
	$locked = 'yes' if ($$r{rotationalPeriodTidallyLocked});

	my $masscode = '';

	if ($$r{name} =~ /\S+\s+\w\w\-\w\s+([a-zA-Z])(\d+\-)?\d+/) {
		$masscode = uc($1);
	}

	my @rows3 = db_mysql('elite',"select id,name,subType,planetID from planets where systemId64='$$r{systemId64}'");
	my ($moons, $ringed_moons) = (0,0);

	foreach my $r3 (@rows3) {
		#warn "$$r3{name} ($$r3{subType})\n";
		if ($$r3{name} =~ /^(.+)\s+\S+\s*$/) {
			my $parent_name = $1;
			$parent_name =~ s/\s*$//;
			next if (uc($parent_name) ne uc($$r{name}));
		} else {
			next;
		}

		$moons++;

		$$r3{planetID} = 0 if (!defined($$r3{planetID}));

		my @rings = db_mysql('elite',"select id from rings where isStar!=1 and planet_id=?",[($$r3{planetID})]);
		$ringed_moons++ if (@rings>0);
	}

	next if (!$ringed_moons);

	print "$$r2{name},$$r{name},$moons,$ringed_moons,$masscode,$$r{subType},$num,".
		"$$r{distanceToArrivalLS},$$r{terraformingState},$$r{radius},$$r{earthMasses},$$r{gravity},$$r{surfaceTemperature},$$r{surfacePressure},".
		"$$r{volcanismType},$$r{atmosphereType},$$r{axialTilt},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},$$r{semiMajorAxis},$$r{orbitalEccentricity},".
		"$$r{orbitalInclination},$$r{argOfPeriapsis},$$r2{coord_x},$$r2{coord_y},$$r2{coord_z},$$r{updateTime},$$r{commanderName},$$r{discoveryDate}\r\n";
	$count++;
last if ($count>3);
}
warn "$count found\n";


