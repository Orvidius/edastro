#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my @rows = db_mysql('elite',"select * from regions order by name");

open CSV, ">regionID.csv";
print CSV "ID,Name\r\n";

foreach my $r (@rows) {
	print CSV "$$r{id},$$r{name}\r\n";
}

close CSV;

my @rows = db_mysql('elite',"select * from regionmap order by coord_x,coord_z");

open CSV, ">regionMAP.csv";
print CSV "X,Z,ID\r\n";

foreach my $r (@rows) {
	my ($x,$z) = ($$r{coord_x}*10, $$r{coord_z}*10);
        print CSV "$x,$z,$$r{region}\r\n";
}

close CSV;



