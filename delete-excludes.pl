#!/usr/bin/perl
use strict;

opendir DIR, '.';
while (my $fn = readdir DIR) {
	if ($fn =~ /^\-\-exclude/) {
		print "$fn\n";
		unlink $fn;
	}
}
closedir DIR;
