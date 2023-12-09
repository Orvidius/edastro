#!/usr/bin/perl
use strict;

my $numnames	= 10;

my %banned	= (ManNaut=>1);


srand(time()^($$+($$ << 15)));

my %words = ();

open TXT, "names.txt";
while (<TXT>) {
	chomp;
	$_ =~ s/\s+$//s;

	if (/(\w+)\s+(\d+)/) {
		push @{$words{$2}}, $1;
	} else {
		push @{$words{0}}, $_;
		push @{$words{1}}, $_;
	}
}
close TXT;

print "\n";

for(my $i=0; $i<=$numnames; $i++) {

	my $name = ucfirst($words{0}[int(rand(@{$words{0}}))]);
	my $s = ucfirst($words{1}[int(rand(@{$words{1}}))]);

	if ($s eq $name || $banned{"$name$s"} || !$name || !$s) {
		$i--;
		next;
	}

	$name .= $s;

	print "$name\n";
}

print "\n";

