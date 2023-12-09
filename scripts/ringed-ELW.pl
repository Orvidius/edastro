#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);

############################################################################

show_queries(0);

my @rows = db_mysql('elite',"select distinct planets.id,planets.name,systemId64,distanceToArrivalLS,gravity,surfaceTemperature,surfacePressure,earthMasses,radius,".
			"rotationalPeriod,rotationalPeriodTidallyLocked,orbitalPeriod,planetID ".
			"from planets,rings where subType='Earth-like world' and planet_id=planets.planetID and isStar=0 and deletionState=0 order by planets.name");

print "ELW,Rings,Arrival Distance,Earth Masses,Surface Gravity,Surface Temperature,Surface Pressure,Rotational Period,Tidally Locked,Orbital Period,".
		"Coord X,Coord Y,Coord Z,RegionID\r\n";

my $count = 0;
foreach my $r (@rows) {

	$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{planetID} = 0 if (!defined($$r{planetID}));

	my @rows2 = db_mysql('elite',"select id from rings where planet_id='$$r{planetID}' and isStar=0");
	my $num = int(@rows2);

	my $r2 = undef;
	@rows2 = db_mysql('elite',"select * from systems where id64='$$r{systemId64}' and deletionState=0");
	if (@rows2) {
		$r2 = shift @rows2;
	} else {
		%$r2 = ();
	}

	my $locked = 'no';
	$locked = 'yes' if ($$r{rotationalPeriodTidallyLocked});

	print "$$r{name},$num,$$r{distanceToArrivalLS},$$r{earthMasses},$$r{gravity},$$r{surfaceTemperature},$$r{surfacePressure},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},".
		"$$r2{coord_x},$$r2{coord_y},$$r2{coord_z},$$r2{region}\r\n";
	$count++;
}
warn "$count found\n";


