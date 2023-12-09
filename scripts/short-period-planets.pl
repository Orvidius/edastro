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

my @rows = db_mysql('elite',"select * from planets where orbitalPeriod<0.042 and orbitalPeriod>0 and orbitalPeriod is not null ".
			" and name rlike ' [0-9]\$' and deletionState=0 order by orbitalPeriod");

print "System,Planet,Mass Code,Type,Rings,Arrival Distance,Terraforming State,Radius,Earth Masses,Surface Gravity,Surface Temperature,".
	"Volcanism,Atmosphere,Axial Tilt,Rotational Period,Tidally Locked,Orbital Period,".
	"Semi-major Axis,Orbital Eccentricity,Orbital Inclination,Arg. of Periapsis,".
	"Coord X,Coord Y,Coord Z,Timestamp,EDSM Discoverer,EDSM Discovery Date\r\n";

my $count = 0;
foreach my $r (@rows) {

	next if (isBinary($r));

	$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{planetID} = 0 if (!defined($$r{planetID}));

	my @rows2 = db_mysql('elite',"select id from rings where planet_id='$$r{planetID}' and isStar=0");
	my $num = int(@rows2);

	my $r2 = undef;
	@rows2 = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where id64='$$r{systemId64}' and deletionState=0");
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

	print "$$r2{name},$$r{name},$masscode,$$r{subType},$num,".
		"$$r{distanceToArrivalLS},$$r{terraformingState},$$r{radius},$$r{earthMasses},$$r{gravity},$$r{surfaceTemperature},".
		"$$r{volcanismType},$$r{atmosphereType},$$r{axialTilt},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},$$r{semiMajorAxis},$$r{orbitalEccentricity},".
		"$$r{orbitalInclination},$$r{argOfPeriapsis},$$r2{coord_x},$$r2{coord_y},$$r2{coord_z},$$r{updateTime},$$r{commanderName},$$r{discoveryDate}\r\n";
	$count++;
}
warn "$count found\n";


sub isBinary {
	my $r = shift;
	my $basename = '';
	my $num = '';
	my $isBin = 0;

	if ($$r{name} =~ /^(.*\S)\s+([\d])\s*$/) {
		($basename,$num) = ($1,$2);
	}
	$basename =~ s/'/\\'/gs;

	my @checklist = ();
	if ($num == 1) {
		@checklist = (2);
	} else {
		@checklist = ($num-1,$num+1);
	}

	foreach my $n (@checklist) {
		my @check = db_mysql('elite',"select * from planets where name='$basename $n'");
		if (@check) {
			my $p = shift @check;
			next if ( abs($$r{orbitalPeriod}-$$p{orbitalPeriod})>$$r{orbitalPeriod}*0.001 );
			my $arg1 = $$r{argOfPeriapsis};
			my $arg2 = $$p{argOfPeriapsis};
			$arg1 += 360 if ($arg1 < $arg2 && $arg2-$arg1>180);
			$arg2 += 360 if ($arg2 < $arg1 && $arg1-$arg2>180);
			my $degrees = abs($arg1-$arg2);
			$isBin = 1 if ($degrees > 179.9);
		}
	}

	return $isBin;
}
