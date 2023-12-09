#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql);

my $rows = rows_mysql('elite',"select distinct navsystems.id64 from systems,navsystems where systems.id64=navsystems.id64");

my $count = 0;

foreach my $r (@$rows) {
	#print "$$r{id64}\n";
	$count++;
	print '.' if ($count % 10 == 0);
	db_mysql('elite',"delete from navsystems where id64=?",[($$r{id64})]);
}
print "\n";
