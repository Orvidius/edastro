#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2019, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(make_csv epoch2date date2epoch);

############################################################################

show_queries(0);

print make_csv('ID64 SystemAddress','EDSM System ID','Name','Rotation Period Seconds','Region ID','X','Y','Z')."\r\n";

my @rows = db_mysql('elite',"select systemId64,systemId,stars.name,rotationalPeriod,region,coord_x,coord_y,coord_z from stars,systems where subType='Neutron star' and systemId64=id64 and stars.deletionState=0 and systems.deletionState=0 order by name");
while (@rows) {
	my $r = shift @rows;
	print make_csv($$r{systemId64},$$r{systemId},$$r{name},int($$r{rotationalPeriod}*86400000)/1000,$$r{region},$$r{coord_x},$$r{coord_y},$$r{coord_z})."\r\n";
}

exit;

############################################################################



