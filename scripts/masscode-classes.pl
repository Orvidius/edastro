#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

#############################################################################

show_queries(0);

my @rows = db_mysql('elite',"select masscode,mainStarType,count(*) as num from systems where deletionState=0 group by masscode,mainStarType order by masscode,mainStarType");

print "Mass Code,Main Star Type,Count\r\n";

foreach my $r (@rows) {
	next if (!$$r{masscode} || !$$r{mainStarType});

	print make_csv($$r{masscode},$$r{mainStarType},$$r{num})."\r\n";
}
