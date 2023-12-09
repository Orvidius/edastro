#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);

############################################################################

show_queries(0);

my @rows = db_mysql('elite',"select systems.name system,stars.name star,coord_x,coord_y,coord_z,region regionID from systems,stars ".
			"where systemId64=id64 and systems.deletionState=0 and stars.deletionState=0 and (subType is null or subType='') order by system");

print "System,Star,Coord X,Coord Y,Coord Z,RegionID\r\n";

my $count = 0;
foreach my $r (@rows) {

	print "$$r{system},$$r{star},$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{regionID}\r\n";
	$count++;
}
warn "$count found\n";


