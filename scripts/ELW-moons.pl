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

my $planet_type = "Earth-like world";

my @rows = db_mysql('elite',"select * from planets where subType='$planet_type' and deletionState=0 order by name");

print "System,Planet,Mass Code,Type,Rings,Arrival Distance,Terraforming State,Radius,Earth Masses,Surface Gravity,Surface Temperature,Surface Pressure,".
	"Volcanism,Atmosphere,Axial Tilt,Rotational Period,Tidally Locked,Orbital Period,".
	"Semi-major Axis,Orbital Eccentricity,Orbital Inclination,Arg. of Periapsis,Moon of ELW,Parent Name,Parent Main Type,Parent SubType,".
	"Coord X,Coord Y,Coord Z,Timestamp,EDSM Discoverer,EDSM Discovery Date,RegionID\r\n";

my $count = 0;
foreach my $r (@rows) {

	my %parent = ();

	my $parent_name = uc($$r{name});
	$parent_name =~ s/\s+(\S+)\s*$//;
	next if ($1 !~ /^[a-zA-Z]$/ && $1 !~ /^\d+$/);
	next if ($parent_name eq uc($$r{name}));

	my @planets = db_mysql('elite',"select * from planets where systemId64=? and name=? and deletionState=0",[($$r{systemId64},$parent_name)]);
	foreach my $pp (@planets) {
		if (uc($$pp{name}) eq $parent_name) {
			%parent = %$pp;
			$parent{mainType} = 'Planet';
			last;
		}
	}

	if (!$parent{name}) {
		my @stars = db_mysql('elite',"select * from stars where systemId64=? and name=? and deletionState=0",[($$r{systemId64},$parent_name)]);
		foreach my $star (@stars) {
			next if ($$star{name} !~ /\s+\d+\s*$/ && $$star{name} !~ /\s+\d+\s+[a-zA-Z]\s*$/);

			if (uc($$star{name}) eq $parent_name) {
				%parent = %$star;
				$parent{mainType} = 'Star';
				last;
			}
		}
	}

	next if (!$parent{name});

	$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{planetID} = 0 if (!defined($$r{planetID}));

	my @rows2 = db_mysql('elite',"select id from rings where planet_id='$$r{planetID}' and isStar=0");
	my $num = int(@rows2);

	my $r2 = undef;
	@rows2 = db_mysql('elite',"select name,coord_x,coord_y,coord_z,region from systems where id64='$$r{systemId64}'");
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

	my $ELWmoon = 'NO';
	$ELWmoon = 'YES' if ($parent{subType} eq 'Earth-like world');

	print "$$r2{name},$$r{name},$masscode,$$r{subType},$num,".
		"$$r{distanceToArrivalLS},$$r{terraformingState},$$r{radius},$$r{earthMasses},$$r{gravity},$$r{surfaceTemperature},$$r{surfacePressure},".
		"$$r{volcanismType},$$r{atmosphereType},$$r{axialTilt},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},$$r{semiMajorAxis},$$r{orbitalEccentricity},".
		"$$r{orbitalInclination},$$r{argOfPeriapsis},$ELWmoon,$parent{name},$parent{mainType},$parent{subType},".
		"$$r2{coord_x},$$r2{coord_y},$$r2{coord_z},$$r{updateTime},$$r{commanderName},$$r{discoveryDate},$$r2{region}\r\n";
	$count++;
}
warn "$count found\n";


