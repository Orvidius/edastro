#!/usr/bin/perl
use strict;

use lib "/home/bones/elite";
use EDSM qw(id64_to_name);

die "Usage: $0 <id64> [id64..]\n" if (!@ARGV);

foreach my $id64 (@ARGV) {

	my $name = id64_to_name($id64);

	print "$id64 = $name\n" if ($name);
	print "$id64 UNKNOWN\n" if (!$name);
}
