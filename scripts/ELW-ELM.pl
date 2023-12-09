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

my @rows = db_mysql('elite',"select count(*) as count, systemId64 from planets where subType='Earth-like world' and terraformingState!='Terraformed' group by systemId64 and deletionState=0 having count(*)>1");

my $count = 0;
foreach my $r (sort {$$a{systemId} cmp $$b{systemId}} @rows) {

	my @rows2 = db_mysql('elite',"select name from planets where systemId64='$$r{systemId64}' and subType='Earth-like world' and terraformingState!='Terraformed' and deletionState=0");
	my %hash = ();

	foreach my $r2 (@rows2) {
		$hash{$$r2{name}} = 1;
	}

	foreach my $n (keys %hash) {
		if ($n =~ /^(.*)\s+\S+\s*$/) {
			if ($hash{$1}) {
				# ELW appears to orbit another ELW

				print "$1 / $n\n";
				$count++;
			}
		}
	}
}
print "$count found\n";


