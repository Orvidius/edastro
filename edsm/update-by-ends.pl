#!/usr/bin/perl
use strict; $|=1;

###########################################################################

use lib "/home/bones/perl";
use DB qw(columns_mysql db_mysql show_queries);

###########################################################################

my $debug       = 0;
my $verbose     = 0;

my $db          = 'elite';
my $progname	= $0;

###########################################################################

foreach my $table (qw(planets stars)) {
	my @cols = ();

	@cols = qw(gravityDec earthMassesDec radiusDec axialTiltDec rotationalPeriodDec orbitalPeriodDec orbitalEccentricityDec orbitalInclinationDec argOfPeriapsisDec semiMajorAxisDec surfacePressureDec) if ($table eq 'planets');
	@cols = qw(solarRadiusDec solarMassesDec absoluteMagnitudeDec axialTiltDec rotationalPeriodDec orbitalPeriodDec orbitalEccentricityDec orbitalInclinationDec argOfPeriapsisDec semiMajorAxisDec) if ($table eq 'stars');

	my @rows = db_mysql('elite',"select distinct subType from $table order by subType");
	my %types = ();
	foreach my $r (@rows) {
		$types{$$r{subType}} = 1;
	}

	foreach my $type (sort keys %types) {
		foreach my $col (sort @cols) {

			next if ($type lt 'Class IV gas giant');
			next if ($type eq 'Class IV gas giant' && $col lt 'gravityDec');

			$0 = $progname.": $type [$col]";

			print "$type [$col]\n";

			my @list = ();

			my $sql  = "select distinct systemId64 from $table where subType=? and $col is not null order by $col limit 150";
			my $ref  = columns_mysql($db,$sql,[($type)]);
			
			my $sql2 = "select distinct systemId64 from $table where subType=? and $col is not null order by $col desc limit 150";
			my $ref2 = columns_mysql($db,$sql,[($type)]);

			if (ref($$ref{systemId64}) eq 'ARRAY') {
				push @list, @{$$ref{systemId64}};
			}

			if (ref($$ref2{systemId64}) eq 'ARRAY') {
				push @list, @{$$ref2{systemId64}};
			}

			print int(@list)." id64 systems to look at.\n";
	
			while (@list) {
				my @list = splice @list, 0, 80;
				system('/home/bones/elite/edsm/get-system-bodies.pl',@list);
				sleep 1;
			}
		}
	}
}


