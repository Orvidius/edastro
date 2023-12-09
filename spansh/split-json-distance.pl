#!/usr/bin/perl

use strict;

my $numsplit = 4;
my $count = 0;
my %file = ();

open INFILE, "<bodies.jsonl";
print "Splitting...\n";

foreach my $table ('stars','planets') {
	for (my $i=0; $i<$numsplit; $i++) {
		open $file{$table}{$i}, ">distance-$table$i.csv";
	}
}

while (my $line = <INFILE>) {
	if ($line =~ /"type":"(Planet|Star)"/) {

		my $table = 'planets';
		$table = 'stars' if ($1 eq 'Star');

		my $distance = 0;
		my $radius = 0;

		if ($line =~ /"radius":([\d\.\-\+]+)[,\}]/) {
			$radius = $1;
		}

		if ($line =~ /"distanceToArrival":([\d\.\-\+]+)[,\}]/) {
			$distance = $1;
		}

		if ($line =~ /"name":"([^"]+)"/) {
			my $name = $1;

			my $n = $count % $numsplit;
			$count++;
			my $handle = $file{$table}{$n};
			print $handle "$name,$distance,$radius\n" if ($table eq 'planets');
			print $handle "$name,$distance\n" if ($table eq 'stars');
		}
	}
}



close INFILE;



