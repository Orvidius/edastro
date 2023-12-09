#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my %hash = ();

open TXT, "grep StarType journals/Journal\.* |";
while (<TXT>) {
	my $name = '';
	my $type = '';
	if (/"BodyName"\s*:\s*"([^"]+)"/) {
		$name = $1;
	}
	if (/"StarType"\s*:\s*"([^"]+)"/) {
		$type = $1;
	}

	if ($name && $type && !$hash{$type}) {

		my @rows = db_mysql('elite',"select subType from stars where name=?",[($name)]);
		if (@rows) {
			my $star = ${$rows[0]}{subType};
			$hash{$type} = $star;
			print "$type = $star ($name)\n";
		}
	}
}
close TXT;

foreach my $type (sort keys %hash) {
	print "$type = $hash{$type}\n";
}
