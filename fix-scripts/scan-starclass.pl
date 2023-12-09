#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my %hash = ();

my $journal_var = 'StarType';
my $db_var = 'subType';
my $table = 'stars';
my $hashname = 'star_map';

open TXT, "grep $journal_var journals/Journal\.* |";
while (<TXT>) {
	my $name = '';
	my $type = '';
	if (/"BodyName"\s*:\s*"([^"]+)"/) {
		$name = $1;
	}
	if (/"$journal_var"\s*:\s*"([^"]+)"/) {
		$type = $1;
	}

	if ($name && $type && !$hash{$type}) {

		my @rows = db_mysql('elite',"select $db_var from $table where name=?",[($name)]);
		if (@rows) {
			my $result = ${$rows[0]}{$db_var};
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
	print "    \$$hashname\{\"$type\"} = \"$hash{$type}\";\n";
}
