#!/usr/bin/perl
use strict;

my $numnames	= 20;

my %banned	= (ManNaut=>1);


srand(time()^($$+($$ << 15)));

my @words = ();
my @prefix = ();
my @suffix = ();

open TXT, "names.txt";
while (<TXT>) {
	chomp;
	$_ =~ s/\s+$//s;

	if (/(\w+)\s+(\d+)/) {
		push @prefix, $1 if (!$2);
		push @suffix, $1 if ($2);
	} else {
		push @words, $_;
	}
}
close TXT;

@words = sort @words;

@prefix = sort (@prefix,@words);
@suffix = sort (@suffix,@words);

for (my $n=0; $n<@prefix; $n++) {
	for (my $i=0; $i<@suffix; $i++) {

		if ($prefix[$n] && $suffix[$i] && $prefix[$n] ne $suffix[$i]) {
			my $name = ucfirst($prefix[$n]) . ucfirst($suffix[$i]);

			print "$name\n";
		}
	}
}


