#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my %hash = ();

open TXT, "grep Volcanism journals/Journal\.* |";
while (<TXT>) {
	my $name = undef;
	my $type = undef;
	if (/"BodyName"\s*:\s*"([^"]*)"/) {
		$name = $1;
	}
	if (/"Volcanism"\s*:\s*"([^"]*)"/) {
		$type = $1;
	}

	if ($name && defined($type) && !$hash{$type}) {

		my @rows = db_mysql('elite',"select volcanismType from planets where name=?",[($name)]);
		if (@rows) {
			my $result = ${$rows[0]}{volcanismType};
			if ($result) {
				print "\"$type\" = $result ($name)\n";
				$hash{$type} = $result;
			}
		}
	}
}
close TXT;

print "\n\n";

foreach my $type (sort keys %hash) {
	print "    \$volc_map{\"$type\"} = \"$hash{$type}\";\n";
}
