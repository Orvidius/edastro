#!/usr/bin/perl

use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);

my $debug	= 0;

my $max_date	= ''; #'2021-02-25 00:00:00';
my $dotcount	= 0;

my $progname	= $0;

show_queries(0);

my %fix = ();

my $attempts = 0;

foreach my $f (qw(gravity earthMasses radius absoluteMagnitude solarMasses solarRadius axialTilt rotationalPeriod orbitalPeriod orbitalEccentricity orbitalInclination argOfPeriapsis semiMajorAxis)) {
	$fix{$f} = $f.'Dec';
	print "FIXING: $f = $fix{$f}\n";
}

foreach my $fn (@ARGV) {
	
	print "\n$fn\n";
	$0 = "$progname $fn [0]\n";

	my $filestring = "zcat $fn |";
	$filestring = "<$fn" if ($fn !~ /\.gz$/);
	
	open DATA, $filestring;
	$dotcount = 0;
	
	while (my $line = <DATA>) {
		if ($line =~ /"type":"(Star|Planet)"/) {

			print "$line\n" if ($debug);
	
			my $table = 'planets';
			$table = 'stars' if ($1 eq 'Star');

			my $IDfield = 'planetID';
			$IDfield = 'starID' if ($table eq 'stars');
	
			my %hash = ();
			my $name = '';
			my $edsmID = 0;
			my $body64 = 0;
	
			foreach my $f (keys %fix) {
				if ($line =~ /"$f"\s*:\s*"?([\d\.\-]+)"?[,\}]/) {
					if ($f && $fix{$f}) {
						$hash{$f} = $1;
					}
				}
			}
	
			if ($line =~ /"id64"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$body64 = $1;
			}
	
			if ($line =~ /"id"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$edsmID = $1;
			}

			if (keys(%hash) && ($body64 || $edsmID)) {
				my $where = '';
				my @params = ();

				if ($body64) {
					$where .= ' or bodyId64=?';
					push @params, $body64;
				}

				if ($edsmID) { # && !$body64) {
					$where .= ' or edsmID=?';
					push @params, $edsmID;
				} 

				if (@params) {
					$where =~ s/^\s*or\s+//;
					$where = "($where)" if (@params>1);

					my $date_and = '';
					if ($max_date) {
						$date_and = "and updated<?";
						push @params, $max_date;
					}

					eval {

						my $columns = join ',', values %hash;

						my @rows = db_mysql('elite',"select $IDfield,$columns from $table where $where $date_and",\@params);

						foreach my $r (@rows) {
							my @vals = ();
							my @vars = ();

							foreach my $f (keys %hash) {
								if ($hash{$f} && (!$$r{$fix{$f}} || 
								   ($hash{$f} != $$r{$fix{$f}} && $hash{$f} >= $$r{$fix{$f}}-1 && $hash{$f} <= $$r{$fix{$f}}+1))) {
									push @vars, "$f=?";
									push @vals, $hash{$f};
									push @vars, "$fix{$f}=?";
									push @vals, $hash{$f};
								}
							}

							if (@vars && @vals) {
								@params = (@vals,$$r{$IDfield});
								my $cols = join ',',@vars;

								my $sql = "update $table set updated=updated,$cols where $IDfield=? and deletionState=0";

								print "MYSQL: $sql [".join(', ', @params)."]\n" if ($debug);

								db_mysql('elite',$sql,\@params) if (!$debug);
							}
						}
					};
					$attempts++;
				}
			}

			$dotcount++;
			print '.' if ($dotcount % 10000 == 0);
			$0 = "$progname $fn [$dotcount]\n" if ($dotcount % 10000 == 0);
			#print "\n" if ($dotcount % 1000000 == 0);
		}

		last if ($debug && $attempts);
	}
	
	close DATA;
}



