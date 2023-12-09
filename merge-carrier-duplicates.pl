#!/usr/bin/perl
use strict; $|=1;

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);

show_queries(0);

my @rows = db_mysql('elite',"select distinct marketID,count(*) as num from carriers group by marketID having count(*)>1 order by marketID");

foreach my $r (@rows) {
	#print "$$r{marketID}\n";

	my @lookup = db_mysql('elite',"select callsign from carriers where marketID=? order by ID",[($$r{marketID})]);

	print "./reassign-carrier.pl ${$lookup[0]}{callsign} ${$lookup[1]}{callsign} 1 #($$r{marketID})\n";
	system("./reassign-carrier.pl",${$lookup[0]}{callsign},${$lookup[1]}{callsign},1);
}

