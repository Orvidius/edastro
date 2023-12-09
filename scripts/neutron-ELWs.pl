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
		"where stars.subType='Neutron Star' and planets.subType='Earth-like world' and stars.systemId64=planets.systemId64 and stars.systemId64=systems.id64 ".
		"and stars.deletionState=0 and planets.deletionState=0 and systems.deletionState=0");

my $count = 0;
foreach my $r (sort {$$a{starname} cmp $$b{starname}} @rows) {

	if ($$r{planetname} =~ /^(.*\S)\s+(\d+)\s*$/) {
		my $parent = $1;

		if (uc($$r{starname}) eq uc($parent)) {
			my $primary = 'secondary';

			my @count = db_mysql('elite',"select id from stars where systemId64='$$r{id64}' and deletionState=0");

			if ($$r{starname} eq $$r{name}) {
				$primary = 'single';
			} elsif ($$r{starname} =~ /^(.*\S)\s+([a-zA-Z]+)\s*$/) {
				$primary = 'primary' if (uc($2) eq 'A');
			}

			if (@count == 1 && $primary eq 'single') {
				print "$$r{starname} / $$r{planetname}\n";
				$count++;
			}
		}
	}
}
print "$count found\n";



