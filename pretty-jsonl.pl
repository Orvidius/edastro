#!/usr/bin/perl
use strict; $|=1;

foreach my $fn (@ARGV) {

	open TXT, "<$fn" if ($fn !~ /\.gz$/);
	open TXT, "/usr/bin/zcat $fn |" if ($fn =~ /\.gz$/);

	while (<TXT>) {
		if (/^\s*(\{.+\}),?\s*$/) {
			open OUT, "|/home/bones/elite/json-pretty.pl";
			print OUT $1;
			close OUT;
		}
	}

	close TXT;
}
