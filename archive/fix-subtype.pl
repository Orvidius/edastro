#!/usr/bin/perl

use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my $fix_dups = 0;
my $fix_type = ''; #'Herbig Ae/Be Star';
my $max_date = '2021-02-25 00:00:00';
my $dotcount = 0;


my %dups = ();

if ($fix_dups) {
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
	
			my $subType = undef;
			my $name = '';
			my $edsmID = 0;
			my $body64 = 0;
	
			if ($line =~ /"subType"\s*:\s*"([^"]*)"[,\}]/) {
				$subType = $1;
			}
	
			if ($line =~ /"id64"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$body64 = $1;
			}
	
			if ($line =~ /"id"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$edsmID = $1;
			}
	
#			if ($line =~ /"name"\s*:\s*"([^"]+)"[,\}]/) {
#				$name = $1;
#			}
	
			if (($body64 || $edsmID) && (!$fix_dups || ($name && $dups{$name})) && (!$fix_type || uc($subType) eq uc($fix_type))) {
				my $where = '';
				my @params = ();

				if ($body64) {
					$where .= ' or bodyId64=?';
					push @params, $body64;
				}

				if ($edsmID && !$body64) {
					$where .= ' or edsmID=?';
					push @params, $edsmID;
				} 

#				if ($name && !$fix_dups) {
#					$where .= ' or name=?';
#					push @params, $name;
#				}

				if (@params) {
					$where =~ s/\s*or\s+//;
					$where = "($where)" if (@params>1);

					@params = ($subType,@params,$subType);

					my $date_and = '';
					if ($max_date) {
						$date_and = "and updated<?";
						push @params, $max_date;
					}

					eval {
						db_mysql('elite',"update $table set subType=? where $where and subType!=? $date_and",\@params);
					};
				}
			}

			$dotcount++;
			print '.' if ($dotcount % 10000 == 0);
			print "\n" if ($dotcount % 1000000 == 0);
		}
	}
	
	close DATA;
}



