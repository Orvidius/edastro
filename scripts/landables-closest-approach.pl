#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

use POSIX qw(floor);

############################################################################
	

show_queries(0);

my @rows =  db_mysql('elite',"select sys.name systemName,p.systemId64,sol_dist,coord_x,coord_y,coord_z,p.planetID,p.name,p.semiMajorAxis,p.orbitalEccentricity,p.orbitalPeriod,".
			"p.semiMajorAxis*(1-p.orbitalEccentricity)*149598000 perihelionKM,s.subType starType,s.solarRadius,s.solarRadius*696340 radiusKM,".
			"(p.semiMajorAxis*(1-p.orbitalEccentricity)*149598000)/(s.solarRadius*696340) perihelionRadiusRatio from planets p,stars s,systems sys ".
			"where p.systemId64=id64 and isLandable=1 and p.orbitalEccentricity>0.8 and p.semiMajorAxis>0 and p.orbitalEccentricity<1 and p.parentStarID=s.starID ".
			"and p.deletionState=0 and s.deletionState=0 and sys.deletionState=0 and (p.semiMajorAxis*(1-p.orbitalEccentricity)*149598000)/(s.solarRadius*696340)<10 ".
			"order by p.semiMajorAxis*(1-p.orbitalEccentricity)/s.solarRadius");


print make_csv('Name','Semimajor Axis','Period','Eccentricity','Perihelion KM','Star Type','Solar Radius','Radius KM','Perihelion/Radius Ratio',
		'System','Sol Distance','Coord-X','Coord-Y','Coord-Z','Region')."\r\n";

foreach my $r (@rows) {
	my $region = '';

	my @regs = db_mysql('elite',"select name from regions,regionmap where id=region and coord_x=? and coord_z=?",[(floor($$r{coord_x}/10),floor($$r{coord_z}/10))]);
	if (@regs) {
		$region = ${$regs[0]}{name};
	}

	print make_csv($$r{name},$$r{semiMajorAxis},$$r{orbitalPeriod},$$r{orbitalEccentricity},$$r{perihelionKM},$$r{starType},$$r{solarRadius},$$r{radiusKM},$$r{perihelionRadiusRatio},
		$$r{systemName},$$r{sol_dist},$$r{coord_x},$$r{coord_y},$$r{coord_z},$region)."\r\n";
}

