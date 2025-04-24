#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);

############################################################################

show_queries(0);

my @rows = db_mysql('elite',"select distinct stars.starID,stars.name,subType,systemId64,distanceToArrivalLS,age,absoluteMagnitude,luminosity,surfaceTemperature,".
			"solarMasses,solarRadius,rotationalPeriod,rotationalPeriodTidallyLocked,orbitalPeriod,commanderName,discoveryDate,starID ".
			"from stars,rings where planet_id=stars.starID and isStar=1 and subType not in ".
			"('T (Brown dwarf) Star','Y (Brown dwarf) Star','L (Brown dwarf) Star','T Tauri Star') and deletionState=0 and ".
			"rings.name not like '%Belt' order by stars.name");

print "Name,Rings,Arrival Distance,Type,Age,Absolute Magnitude,Luminosity,Surface Temperature,Solar Masses,Solar Radius,Rotational Period,Tidally Locked,Orbital Period,Commander Name,Discovery Date,Coord X,Coord Y,Coord Z,regionID\r\n";

my $count = 0;
foreach my $r (@rows) {

	$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{starID} = 0 if (!defined($$r{starID}));

	my @rows2 = db_mysql('elite',"select id from rings where planet_id='$$r{starID}' and isStar=1");
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

	print "$$r{name},$num,$$r{distanceToArrivalLS},$$r{subType},$$r{age},$$r{absoluteMagnitude},$$r{luminosity},$$r{surfaceTemperature},".
		"$$r{solarMasses},$$r{solarRadius},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},\"$$r{commanderName}\",\"$$r{discoveryDate}\",".
		"$$r2{coord_x},$$r2{coord_y},$$r2{coord_z},$$r2{region}\r\n";
	$count++;
}
warn "$count found\n";


