#!/usr/bin/perl
use strict;

# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

#####################################################################

use lib "/home/bones/perl";
use DB qw(rows_mysql db_mysql);
use ATOMS qw(epoch2date date2epoch);

printf("%15s\t[%19s]\t%s\t%s\t%s\t%s\t%s\r\n",'SystemID','Date','Coord_X','Coord_Y','Coord_Z','SolDist','System Name');
print '-' x 100;
print "\n";

my @rows = db_mysql('elite',"select * from logs,systems where cmdrID=1 and systemId=edsm_id order by logs.date");
foreach my $r (@rows) {
	my $dist = sqrt( $$r{coord_x}**2 + $$r{coord_y}**2 + $$r{coord_z}**2 );
	printf("%15s\t[%19s]\t%.02f\t%.02f\t%.02f\t%.02f\t%s\r\n",$$r{systemId},$$r{date},$$r{coord_x},$$r{coord_y},$$r{coord_z},$dist,$$r{name});
}

