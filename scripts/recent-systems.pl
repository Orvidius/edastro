#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

############################################################################

my $hours = $ARGV[0];
$hours = 12 if (!$hours);

die "Not a number: $hours\n" if (!$hours || $hours !~ /^\d+$/);

warn "Pulling systems added in last $hours hours\n";

my $rows = rows_mysql('elite',"select id64,name,region from systems where date_added>=date_sub(NOW(), interval $hours hour) and ".
			"deletionState=0 and id64 is not null and name is not null and id64>0");

foreach my $r (@$rows) {
	print make_csv($$r{id64},$$r{name},$$r{region})."\r\n";
}


