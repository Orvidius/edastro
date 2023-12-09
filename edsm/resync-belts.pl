#!/usr/bin/perl
use strict; $|=1;

###########################################################################

use lib "/home/bones/perl";
use DB qw(columns_mysql db_mysql show_queries);

###########################################################################


#my @rows = db_mysql('elite',"select distinct systemId64 from belts,stars where innerRadius>100 and innerRadius<=15000 and isStar=1 and planet_id=starID");
my @rows = db_mysql('elite',"select distinct systemId64 from rings,stars where innerRadius>10 and innerRadius<=15000 and isStar=1 and planet_id=starID");

my @ids = ();

foreach my $r (@rows) {
	if ($$r{systemId64}) {
		push @ids, $$r{systemId64};
	}

	if (@ids >= 50) {
		system("./get-system-bodies.pl ".join(' ',@ids));
		@ids = ();
	}
}
if (@ids) {
	system("./get-system-bodies.pl ".join(' ',@ids));
}
