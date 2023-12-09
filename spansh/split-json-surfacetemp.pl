#!/usr/bin/perl

use strict;

my $numsplit = 8;

my $start_count = 80000000;

my $count = 0;
my %file = ();


open INFILE, "<bodies.jsonl";
print "Splitting...\n";

foreach my $table ('stars','planets') {
	for (my $i=0; $i<$numsplit; $i++) {
		open $file{$table}{$i}, ">surfacetemp-$table$i.csv";
	}
}

while (my $line = <INFILE>) {
	if ($line =~ /"type":"(Planet|Star)"/) {

		my $table = 'planets';
		$table = 'stars' if ($1 eq 'Star');

		my $temp = 0;

		if ($line =~ /"surfaceTemperature":(\-?\d+\.\d+)[,\}]/s) {
			$temp = $1;
		}

		if ($line =~ /"name":"([^"]+)"/ && $temp) {
			my $name = $1;

			my $n = $count % $numsplit;
			$count++;
			my $handle = $file{$table}{$n};
			print $handle "$name,$temp\n" if (!$start_count || $count>=$start_count);
		}
	}
}



close INFILE;



