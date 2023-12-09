#!/usr/bin/perl
use strict;

my @list = (q(rlike:name=\'\ \[\0-9\]+\(\ \[a-z\]\)+$\'),'Class I gas giant','Class II gas giant','Class III gas giant','Class IV gas giant','Class V gas giant'
,'Gas giant with ammonia-based life','Gas giant with water-based life','Helium gas giant','Helium-rich gas giant','Water giant');

foreach (@list) {
	print "$_\n";
}
