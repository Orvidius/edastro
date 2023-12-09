#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(make_csv parse_csv);

############################################################################

show_queries(0);

my %pattern = ();

open CSV, "<elw-eolprou-uniq.csv";
while (<CSV>) {
	chomp;
	my @v = parse_csv($_);
	$v[0] =~ s/\s+$//s;
	$pattern{$v[0]} = 0;
}
close CSV;

my @rows = db_mysql('elite',"select name from systems where deletionState=0 and name like 'Eol Prou %'");

die "None found.\n" if (!@rows);

while (@rows) {
	my $r = shift @rows;

	foreach my $p (keys %pattern) {
		my $pat = $p;
		$pat =~ s/([^\w\d])/\\$1/gs;
		#warn "# $p = $pat\n";
		if ($$r{name} =~ /$pat/) {
			$pattern{$p}++;
			last;
		}
	}
}

foreach my $p (sort keys %pattern) {
	print "$p,$pattern{$p}\r\n";
}
