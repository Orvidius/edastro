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

my @rows = db_mysql('elite',"select count(*) as count, systemId64 from stars where subType like 'Wolf-Rayet\%' and deletionState=0 group by systemId64");

my $nonAAA = 0;
my $primary = 0;
my $secondary = 0;
my %class = ();
my %date = ();
my %finds = ();
foreach my $r (sort {$$a{systemId64} cmp $$b{systemId64}} @rows) {

	my @rows2 = db_mysql('elite',"select stars.name starname,systems.name systemname,subType,stars.updateTime from stars,systems where systemId64='$$r{systemId64}' and systemId64=id64 and stars.deletionState=0 and systems.deletionState=0");

	next if (!@rows);

	my %hash = ();
	my $systemName = ${$rows2[0]}{systemname};	# OK to grab one since they're all the same

	foreach my $r2 (@rows2) {
		$hash{$$r2{starname}} = $$r2{subType};
		$date{$$r2{starname}} = $$r2{updateTime};
	}

	foreach my $n (keys %hash) {

		if ($hash{$n} =~ /Rayet/i) {
			if ($n =~ /^(.*)\s+(\S+)\s*$/) {
				my ($sname, $desig) = ($1,$2);

				if ($sname eq $systemName) {
					if ($desig ne 'A') {
						#print "$n ($hash{$n})\n";
						$secondary++;

					} else {
						#print "Primary: $n ($hash{$n})\n";
						$primary++;
					}
				}

				if ($date{$n} =~ /(\d{4})\-?(\d{2})/) {
					$finds{"$1/$2"}++;
				}
			}
			if ($n =~ /^(\S+\s+){1,3}(\w\w\-\w\s+\S)/i) {
				if (uc($2) ne 'AA-A H') {
					print "$n ($hash{$n}): $2\n";
					$nonAAA++;
				} else {
					#print "AA-A H: $n ($hash{$n})\n";
				}
			}
		} elsif ($n =~ /^(.*)\s+(\S+)\s*$/) {
			my ($sname, $desig) = ($1,$2);

			if ($sname eq $systemName) {
				if ($desig eq 'A') {
					print "Primary: $n ($hash{$n})\n";
					$class{$hash{$n}}++;
				}
			}
		}
	}
}
print "$nonAAA Wolf Rayet stars found outside 'AA-A H' sectors\n";
print "$primary Wolf Rayet stars found as primaries\n";
print "$secondary Wolf Rayet stars found as secondaries\n";
print "\n";

foreach my $c (sort keys %class) {
	print "$c: $class{$c}\n";
}
print "\n";

foreach my $f (sort keys %finds) {
	print "$f: $finds{$f}\n";
}
print "\n";




