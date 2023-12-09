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

my @rows =  db_mysql('elite',"select planets.name,subType,gravity,radius,coord_y from planets,systems where systems.deletionState=0 and planets.deletionState=0 and ".
			"id64=systemId64 and isLandable=1 order by coord_y desc limit 500");

push @rows, db_mysql('elite',"select planets.name,subType,gravity,radius,coord_y from planets,systems where systems.deletionState=0 and planets.deletionState=0 and ".
			"id64=systemId64 and isLandable=1 order by coord_y limit 500");

print make_csv('Name','Type','Y','Gravity','Radius')."\r\n";

foreach my $r (@rows) {
	print make_csv($$r{name},$$r{subType},$$r{coord_y},$$r{gravity},$$r{radius})."\r\n";
}

