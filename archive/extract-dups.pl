#!/usr/bin/perl

use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my $dotcount = 0;


my %dups = ();

if (1) {
	print "Pull dups\n";
	my @rows = db_mysql('elite',"select distinct name from planets group by name having count(*)>1");
	push @rows, db_mysql('elite',"select distinct name from stars group by name having count(*)>1");
	foreach my $r (@rows) {
		$dups{$$r{name}}=1;
	}
	print "Proceeding...\n";
}

foreach my $fn (@ARGV) {
	
	print "\n$fn\n";
	
	open DATA, "zcat $fn |";
	$dotcount = 0;
	
	while (my $line = <DATA>) {
		if ($line =~ /"type":"(Planet|Star)"/) {
	
			my $table = 'planets';
			$table = 'stars' if ($1 eq 'Star');
	
			my $name = '';
			my $edsmID = 0;
			my $body64 = 0;
	
			if ($line =~ /"id64"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$body64 = $1;
			}
	
			if ($line =~ /"id"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$edsmID = $1;
			}
	
			if ($line =~ /"name"\s*:\s*"([^"]+)"[,\}]/) {
				$name = $1;
			}
	
			if (($body64 || $edsmID) && $name && $dups{$name}) {
				warn $line;
			}

			$dotcount++;
			print '.' if ($dotcount % 10000 == 0);
			print "\n" if ($dotcount % 1000000 == 0);
		}
	}
	
	close DATA;
}



