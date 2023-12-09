#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

############################################################################

show_queries(0);

#my @rows = db_mysql('elite',"select distinct system from logs where cmdrID=1 and date>='2020-01-01 00:00:00'");
my @rows = db_mysql('elite',"select distinct(logs.system) from logs,systems where cmdrID=1 and logs.system=systems.name and sol_dist<500");
foreach my $r (@rows) {
	print "$$r{system}\r\n";
}

