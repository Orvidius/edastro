#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch);

use Image::Magick;

############################################################################

show_queries(0);

my @rows = db_mysql('elite',"select systems.name,systems.id64,stars.name starname,planets.name planetname from stars,planets,systems ".
		"where stars.subType like 'White Dwarf\%' and planets.subType='Ammonia world' and stars.systemId64=planets.systemId64 and stars.systemId64=systems.id64 ".
		"and stars.deletionState=0 and planets.deletionState=0 and systems.deletionState=0");

my $count = 0;
foreach my $r (sort {$$a{starname} cmp $$b{starname}} @rows) {
	if ($$r{planetname} =~ /^(.*\S)\s+(\d+)\s*$/) {
		my $parent = $1;

		if (uc($$r{starname}) eq uc($parent)) {
			my $primary = 'secondary';

			if ($$r{starname} eq $$r{name}) {
				$primary = 'primary';
			} elsif ($$r{starname} =~ /^(.*\S)\s+([a-zA-Z]+)\s*$/) {
				$primary = 'primary' if (uc($2) eq 'A');
			}

			#print "$$r{name}, $$r{id64}, $$r{starname}, $$r{planetname}, $primary\n";
			print "$$r{starname} / $$r{planetname}\n" ;# if ($primary eq 'primary');
			$count++;
		}
	}
}
print "$count found\n";



