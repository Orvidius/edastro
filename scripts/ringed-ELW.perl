#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);

############################################################################

show_queries(0);

my @rows = db_mysql('elite',"select distinct planets.id,planets.name,systemId,distanceToArrival,gravity,surfaceTemperature,earthMasses,radius,".
			"rotationalPeriod,rotationalPeriodTidallyLocked,orbitalPeriod ".
			"from planets,rings where subType='Earth-like world' and planet_id=planets.id and isStar=0 order by planets.name");

open TXT, ">ringed-earthlikes.csv";

print TXT "ELW,Rings,Arrival Distance,Earth Masses,Surface Gravity,Surface Temperature,Rotational Period,Tidally Locked,Orbital Period,Coord X,Coord Y,Coord Z\r\n";

my $count = 0;
foreach my $r (@rows) {

	my @rows2 = db_mysql('elite',"select id from rings where planet_id='$$r{id}' and isStar=0");
	my $num = int(@rows2);

	my $r2 = undef;
	@rows2 = db_mysql('elite',"select * from systems where edsm_id='$$r{systemId}'");
	if (@rows2) {
		$r2 = shift @rows2;
	} else {
		%$r2 = ();
	}

	my $locked = 'no';
	$locked = 'yes' if ($$r{rotationalPeriodTidallyLocked});

	print TXT "$$r{name},$num,$$r{distanceToArrival},$$r{earthMasses},$$r{gravity},$$r{surfaceTemperature},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},".
		"$$r2{coord_x},$$r2{coord_y},$$r2{coord_z}\r\n";
	$count++;
}
warn "$count found\n";

close TXT;


