#!/usr/bin/perl
use strict;
$|=1;

my $path = '/home/bones/elite/sectors/sectordata';

my @dirs = ();

opendir DIR, $path;
while (my $dir = readdir DIR) {
	if ($dir !~ /^\./ && -d "$path/$dir") {
		push @dirs, "$path/$dir";
	}
}
closedir DIR;

foreach my $dir (sort @dirs) {

	opendir DIR, $dir;
	while (my $fn = readdir DIR) {
		if ($fn =~ /^(\d+)\.png/) {
			#next if ($1 < 600 || $1 >= 700);
			next if ($1 >= 1400);

			my $new = ($1*2).".png";

			print "mv $dir/$fn $dir/$new\n";
			system("/usr/bin/mv $dir/$fn $dir/$new");
		}
	}
	closedir DIR;
}




