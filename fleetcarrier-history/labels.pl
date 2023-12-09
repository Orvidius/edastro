#!/usr/bin/perl

use strict;

opendir DIR, ".";
while (my $fn = readdir DIR) {
	if ($fn =~ /(\d+).*\.png/) {
		if ($1 ge "20210212" && $1 le "20211001") {
			print "$fn\n";
			system("convert $fn systems.png -geometry +957+0 -composite temp.png");
			system("mv temp.png $fn");
		}
	}
}
closedir DIR;
