#!/usr/bin/perl
use strict; $|=1;

use lib "/home/bones/perl";
use ATOMS qw(parse_csv make_csv);

die "Usage: $0 <filename.CSV> [filename.CSV...]\n" if (!@ARGV);


foreach my $fn (@ARGV) {
	open CSV, "<$fn";
	my @lines = <CSV>;
	close CSV;


	my @out = ();
	my $changes = 0;

	foreach my $s (@lines) {
		$s =~ s/[\r\n]+$$//;
		my @v = parse_csv($s);

		for (my $i=0; $i<@v; $i++) {
			if ($v[$i] =~ /^\s*[\+\-\d]\.(\d+)+e\-?(\d+)\s*$/i) {
				my $digits = length($1) + $2;
				$v[$i] = sprintf("%.".$digits."f",$v[$i]);
				$changes++;
			} elsif ($v[$i] =~ /^\s*[\+\-\d]\.(\d+)+e\+?(\d+)\s*$/i) {
				$v[$i] = sprintf("%f",$v[$i]);
				$changes++;
			}
			$v[$i] =~ s/\.0+$//;
			$v[$i] =~ s/(\.\d*?)0+$/$1/;
		}

		push @out, make_csv(@v)."\r\n";
	}

	if ($changes) {
		print "$fn : $changes changes\n";
		open CSV, ">$fn";
		print CSV @out;
		close CSV;
	}
}
