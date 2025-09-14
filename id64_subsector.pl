#!/usr/bin/perl
use strict;
use lib "/home/bones/elite";
use EDSM qw(id64_subsector);


foreach my $id64 (@ARGV) {
	print "id64: $id64\n";
	my ($masscode,$subsector,$num) = id64_subsector($id64);
	print "id64_subsector = $masscode, $subsector, $num\n\n";
}
