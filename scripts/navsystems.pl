#!/usr/bin/perl
use strict; $|=1;
use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql);
use ATOMS qw(make_csv);

my $rows = rows_mysql('elite',"select * from navsystems");

print make_csv('ID64','Name','Class','Coord-X','Coord-Y','Coord-Z')."\r\n";

while (@$rows) {
	my $r = shift @$rows;
	print make_csv($$r{id64},$$r{name},$$r{starclass},$$r{coord_x}+0,$$r{coord_y}+0,$$r{coord_z}+0)."\r\n";
}
