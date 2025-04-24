#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/elite";
use EDSM qw(log10 id64_sectorcoords);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

############################################################################

show_queries(0);


my $rows = rows_mysql('elite',"select 
	p1.planetID,
	p1.name,
	p1.subType,
	p1.radiusDec,
	p1.semiMajorAxisDec*149597870.7 as sma,
	(p1.semiMajorAxisDec*149597870.7)-(outerRadius+p1.radiusDec) as gap,

	p2.planetID as parentID,
	p2.name as parentName,
	p2.subType as parentType,
	p2.radiusDec as parentRadius,

	rings.type as ringType,
	rings.outerRadius,

	systems.name as systemName,
	coord_x,
	coord_y,
	coord_z,
	region,
	sol_dist

	from planets p1 
	left join planets p2 on p1.parentPlanetID=p2.planetID and p2.deletionState=0 
	left join rings on rings.isStar=0 and rings.planet_id=p2.planetID 
	left join systems on p1.systemId64=id64 and systems.deletionState=0
	where p1.name rlike ' [a-z]\$' and p1.parents like 'Planet\%' and p1.deletionState=0 and p1.radiusDec>0 and p1.parentPlanetID is not null 
		and rings.outerRadius<p1.semiMajorAxisDec*149597870.7 and (p1.semiMajorAxisDec*149597870.7)-(outerRadius+p1.radiusDec)>0 
	order by gap limit 1000");

print make_csv(
	'Ring Gap km','Ring Gap (% of radius)',
	'Moon ID','Moon Name','Moon Type','Moon Radius','Moon SMA',
	'Parent ID','Parent Name','Parent Type','Parent Radius',
	'Ring Type','Ring Outer Radius',
	'System Name','X','Y','Z','Sol Distance','regionID'
	)."\r\n";

foreach my $r (@$rows) {
	print make_csv(
		sprintf("%.02f",$$r{gap}),sprintf("%.03f",($$r{gap}/$$r{radiusDec})*100),
		$$r{planetID},$$r{name},$$r{subType},$$r{radiusDec}+0,$$r{sma}+0,
		$$r{parentID},$$r{parentName},$$r{parentType},$$r{parentRadius}+0,
		$$r{ringType},$$r{outerRadius}+0,
		$$r{systemName},$$r{coord_x}+0,$$r{coord_y}+0,$$r{coord_z}+0,$$r{sol_dist}+0,$$r{region}
	)."\r\n";
}

