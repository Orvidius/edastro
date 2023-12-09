#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch);

############################################################################

show_queries(0);

my @rows = db_mysql('elite',"select distinct systemId64 from planets where isLandable>0 and orbitalInclination is not null and name REGEXP '\\d [a-z]\$' and deletionState=0");
#print int(@rows)."\n";
#exit;

print "System,Planet,Mass Code,Type,Parent Body,Parent Body Type,Parent Rings,Rings,Orbital Radius (LS),".
	"Arrival Distance,Terraforming State,Radius,Earth Masses,Surface Gravity,Surface Temperature,Surface Pressure,".
	"Volcanism,Atmosphere,Axial Tilt,Rotational Period,Tidally Locked,Orbital Period,".
	"Semi-major Axis,Orbital Eccentricity,Orbital Inclination,Arg. of Periapsis,".
	"Coord X,Coord Y,Coord Z,Timestamp,EDSM Discoverer,EDSM Discovery Date\r\n";

warn int(@rows)." systems to consider.\n";

my %out = ();
my $count = 0;
foreach my $r (@rows) {
	next if (!$$r{systemId64});

	my @planetlist = db_mysql('elite',"select *,abs(90-abs(90-(abs(orbitalInclination) mod 180))) as inclination,semiMajorAxis*149597871 as orbitalRadius ".
				"from planets where systemId64=$$r{systemId64} and deletionState=0");
	my %planets = ();
	foreach my $p (@planetlist) {
		$planets{$$p{name}} = $p;
	}
	next if (!@planetlist);

	my @starlist = ();
	my %stars = ();

	my $system = undef;

	foreach my $name (keys %planets) {
		my $r = $planets{$name};
		#%$r = %{$planets{$name}};
		my $parentname = $name;
		$parentname =~ s/(\s+[a-z])+\s*$//s;
		next if ($name eq $parentname);

		next if (!$$r{isLandable});
		next if ($$r{inclination}<10);
		next if ($$r{name} !~ /\s+\d+\s+[a-z]\s*$/);	# Must be a moon.
		next if ($$r{parents} =~ /^Null/);	# Skip obvious binary mooons

		if (!keys %$system) {
			my @systemlist = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where id64='$$r{systemId64}' and deletionState=0");
			if (@systemlist) {
				$system = shift @systemlist;
			} else {
				%$system = ();
			}
		}

		if (!@starlist) {
			@starlist = db_mysql('elite',"select starID,name,subType from stars where systemId64=$$r{systemId64} and deletionState=0");
			foreach my $s (@starlist) {
				$stars{$$s{name}} = $s;
			}
			next if (!@starlist);
		}

		next if (!exists($stars{$parentname}) && !exists($planets{$parentname}));

		my @rings = ();
		my %parentdata = ();
		my $outerradius = 0;

		if (exists($stars{$parentname})) {
			$stars{$parentname}{edsmID} = 0 if (!defined($stars{$parentname}{edsmID})); $stars{$parentname}{starID} = 0 if (!defined($stars{$parentname}{starID}));

			@rings = db_mysql('elite',"select outerRadius from rings where isStar=1 and planet_id=? order by outerRadius desc",[($stars{$parentname}{starID})]);
			%parentdata = %{$stars{$parentname}};
			if (@rings) {
				$outerradius = ${$rings[0]}{outerRadius};
			}
		} elsif (exists($planets{$parentname})) {
			$planets{$parentname}{edsmID} = 0 if (!defined($planets{$parentname}{edsmID})); $planets{$parentname}{starID} = 0 if (!defined($planets{$parentname}{starID}));

			@rings = db_mysql('elite',"select outerRadius from rings where isStar=0 and planet_id=? order by outerRadius desc",[($planets{$parentname}{planetID})]);
			%parentdata = %{$planets{$parentname}};
			if (@rings) {
				$outerradius = ${$rings[0]}{outerRadius};
			}
		}
		my $parentrings = int(@rings);

		next if (!$parentrings || !$outerradius);
		next if ($$r{orbitalRadius} > 2*$outerradius);

		$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{planetID} = 0 if (!defined($$r{planetID}));

		my @rows2 = db_mysql('elite',"select id from rings where isStar=0 and planet_id=?",[($$r{planetID})]);
		my $numrings = int(@rows2);
	
		my $locked = 'no';
		$locked = 'yes' if ($$r{rotationalPeriodTidallyLocked});
	
		my $masscode = '';
	
		if ($$r{name} =~ /\S+\s+\w\w\-\w\s+([a-zA-Z])(\d+\-)?\d+/) {
			$masscode = uc($1);
		}
	
		#warn "$$system{name},$$r{name},$masscode,$$r{subType},$lightseconds,$parentname,$stars{$parentname}{subType},$stars{$parentname}{solarRadius}\n";

		$out{$$r{name}} = "$$system{name},$$r{name},$masscode,$$r{subType},$parentname,$parentdata{subType},$parentrings,$numrings,$$r{orbitalRadius},".
			"$$r{distanceToArrivalLS},$$r{terraformingState},$$r{radius},$$r{earthMasses},$$r{gravity},$$r{surfaceTemperature},$$r{surfacePressure},".
			"$$r{volcanismType},$$r{atmosphereType},$$r{axialTilt},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},$$r{semiMajorAxis},$$r{orbitalEccentricity},".
			"$$r{orbitalInclination},$$r{argOfPeriapsis},$$system{coord_x},$$system{coord_y},$$system{coord_z},$$r{updateTime},$$r{commanderName},$$r{discoveryDate}\r\n";

		$count++;
	}
}
warn "$count found\n";

foreach my $name (sort keys %out) {
	print $out{$name};
}



