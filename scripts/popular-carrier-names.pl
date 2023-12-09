#!/usr/bin/perl
use strict;
$|=1;

use lib "/home/bones/perl";
use DB qw(db_mysql);
use ATOMS qw(make_csv);

my @rows = db_mysql('elite',"select name,count(*) num from carriers where name is not null and name!='' group by name having count(*)>=2 order by count(*) desc");

print "Name,count\r\n";

foreach my $r (@rows) {
	print make_csv($$r{name},$$r{num})."\r\n";
}
