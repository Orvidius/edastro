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

my @rows = db_mysql('elite',"select systemId64,name from planets where subType='Earth-like world' and rotationalPeriodTidallyLocked>0 and deletionState=0");

my $stars = 0;
my $planets = 0;
my $singles = 0;
foreach my $r (sort {$$a{systemId64} cmp $$b{systemId64}} @rows) {
	my %hash = ();

	my @rows2 = db_mysql('elite',"select name from planets where systemId64='$$r{systemId64}' and deletionState=0");
	foreach my $r2 (@rows2) {
		$hash{$$r2{name}} = 'planet';
	}

	my @rows2 = db_mysql('elite',"select name from stars where systemId64='$$r{systemId64}' and deletionState=0");
	foreach my $r2 (@rows2) {
		$hash{$$r2{name}} = 'star';
	}

	my @rows2 = db_mysql('elite',"select name from systems where id64='$$r{systemId64}' and deletionState=0");
	foreach my $r2 (@rows2) {
		$hash{$$r2{name}} = 'singles';
	}

	my $name = $$r{name};
	$name =~ s/\s+\S+\s*$//;

	foreach my $n (keys %hash) {
		if ($n eq $name) {
			print "$n ($hash{$n}) / $name (ELW)\n";
			$stars++ if ($hash{$n} eq 'star');
			$planets++ if ($hash{$n} eq 'planet');
			$singles++ if ($hash{$n} eq 'singles');
		}
	}
}
print "$singles single stars found\n";
print "$stars any stars found\n";
print "$planets planets found\n";


