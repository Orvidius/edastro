#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch);

use Image::Magick;

############################################################################

show_queries(0);

my $planet_types = "'Earth-like world'";
my $min_count = 2;

if (@ARGV) {
	$planet_types = "";

	$min_count = shift @ARGV;

	foreach my $arg (@ARGV) {
		$arg =~ s/[^\w\d\s\-\(\)\.]+//gs;
		$planet_types .= ",'$arg'";
	}

	$planet_types =~ s/^,//;
}

my @idrows = db_mysql('elite',"select count(*),systemId64 from planets where subType='Earth-like world' group by systemId64 having count(*)>1 order by count(*),name");

print "System,Count,Planet,Mass Code,Type,Rings,Arrival Distance,Terraforming State,Radius,Earth Masses,Surface Gravity,Surface Temperature,Surface Pressure,".
	"Volcanism,Atmosphere,Axial Tilt,Rotational Period,Tidally Locked,Orbital Period,".
	"Semi-major Axis,Orbital Eccentricity,Orbital Inclination,Arg. of Periapsis,Coord X,Coord Y,Coord Z,Timestamp,EDSM Discoverer,EDSM Discovery Date\r\n";

my $count = 0;

foreach my $idr (@idrows) {
	my $planet_count = $$idr{'count(*)'};

	my @rows = db_mysql('elite',"select * from planets where systemId64='$$idr{systemId64}' and subType in ($planet_types) order by name");

	#warn "$$idr{systemId64} = $planet_count, ".int(@rows)."\n";

	foreach my $r (@rows) {
	
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
	
		print "$$r2{name},$planet_count,$$r{name},$masscode,$$r{subType},$num,$$r{distanceToArrivalLS},$$r{terraformingState},$$r{radius},$$r{earthMasses},".
			"$$r{gravity},$$r{surfaceTemperature},$$r{surfacePressure},".
			"$$r{volcanismType},$$r{atmosphereType},$$r{axialTilt},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},$$r{semiMajorAxis},$$r{orbitalEccentricity},".
			"$$r{orbitalInclination},$$r{argOfPeriapsis},$$r2{coord_x},$$r2{coord_y},$$r2{coord_z},$$r{updateTime},$$r{commanderName},$$r{discoveryDate}\r\n";
		$count++;
	}
}
warn "$count found\n";


