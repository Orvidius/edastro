#!/usr/bin/perl
use strict; $|=1;

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql);
use ATOMS qw(epoch2date date2epoch);

open TXT, "<systems.txt";
my @list = <TXT>;
close TXT;

my $e = time;
my $n = 0;

foreach my $s (@list) {
	chomp $s;
	my $event = $n ? 'FSDJump' : 'Location';

	my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z,id64 from systems where name=? and deletionState=0",[($s)]);

	if (@rows) {
		my $r = shift @rows;
		$n++;
		$e++;

		my $ts = epoch2date($e);
		$ts =~ s/ /T/;
		$ts .= 'Z';

		print "{\"SystemAddress\":$$r{id64},\"StarSystem\":\"$s\",\"StarPos\":[$$r{coord_x},$$r{coord_y},$$r{coord_z}],\"event\":\"$event\",\"timestamp\":\"$ts\"}\n";
	}
}
