#!/usr/bin/perl
use strict;

print "\n";

foreach my $script (@ARGV) {
	#print "$script: ";
	system("perl -c $script");
	#print "\n";
}
print "\n";
