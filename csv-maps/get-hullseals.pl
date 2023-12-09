#!/usr/bin/perl
use strict;

my @t = localtime;
my $date = sprintf("%04u-%02u-01",$t[5]+1900,$t[4]+1);

system("/usr/bin/wget -O hullseals-systems-new.csv https://hullseals.space/assets/mapdumps/SealExport_$date.csv");
system("/usr/bin/cat hullseals-systems.header hullseals-systems-new.csv > hullseals-systems.csv");


