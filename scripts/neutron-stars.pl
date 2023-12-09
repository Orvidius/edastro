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

print make_csv('ID64 SystemAddress','EDSM System ID','Name')."\r\n";

my @rows = db_mysql('elite',"select systemId64,systemId,name from stars where subType='Neutron star' and deletionState=0 order by name");
while (@rows) {
	my $r = shift @rows;
	print make_csv($$r{systemId64},$$r{systemId},$$r{name})."\r\n";
}

exit;

############################################################################



