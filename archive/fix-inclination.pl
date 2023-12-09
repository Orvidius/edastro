#!/usr/bin/perl

use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);

my $max_date = ''; #'2021-02-25 00:00:00';
my $dotcount = 0;

show_queries(0);


foreach my $fn (@ARGV) {
	
	print "\n$fn\n";

	my $filestring = "zcat $fn |";
	$filestring = "<$fn" if ($fn !~ /\.gz$/);
	
	open DATA, $filestring;
	$dotcount = 0;
	
	while (my $line = <DATA>) {
		#if ($line =~ /"type":"(Planet|Star)"/) {
		if ($line =~ /"type":"(Star|Planet)"/) {
	
			my $table = 'planets';
			$table = 'stars' if ($1 eq 'Star');
	
			my $inclination = undef;
			my $name = '';
			my $edsmID = 0;
			my $body64 = 0;
	
			if ($line =~ /"orbitalInclination"\s*:\s*"?([\d\.\-]+)"?[,\}]/) {
				$inclination = $1 if ($1 ne '');
			}
	
			if ($line =~ /"id64"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$body64 = $1;
			}
	
			if ($line =~ /"id"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$edsmID = $1;
			}

			if (defined($inclination) && ($body64 || $edsmID) && $inclination>=-180 && $inclination<=180) {
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


				if (@params && ($line =~ /Dryae Flyoae/ || $line =~ /Eock Groa/)) {
					$where =~ s/^\s*or\s+//;
					$where = "($where)" if (@params>1);

					my $date_and = '';
					if ($max_date) {
						$date_and = "and updated<?";
						push @params, $max_date;
					}

					eval {
						my @rows = db_mysql('elite',"select orbitalInclination from $table where $where $date_and",\@params);

						if (@rows) {
							my $old = ${$rows[0]}{orbitalInclination};
							@params = ($inclination,@params,$inclination);

							if ($line =~ /Dryae Flyoae NY-H d10-118 A 8/ || $line =~ /Eock Groa UW-L b40-1 BC 3/) {
								print "\n$line\nWHERE: $where [".join(',',@params)."] --- $inclination / $old ($fn) ".int(@rows)."\n";
							}

							if (!defined($old) || ($inclination!=$old && $inclination>$old-2 && $inclination<$old+2) || $old == -180) {
								show_queries(1) if ($line =~ /Dryae Flyoae NY-H d10-118 A 8/ || $line =~ /Eock Groa UW-L b40-1 BC 3/);

								db_mysql('elite',"update $table set orbitalInclination=?,updated=updated where $where and ((orbitalInclination is not null and orbitalInclination!=?) or orbitalInclination is null) and deletionState=0 $date_and",\@params);
								show_queries(0);
							}
						}
					};
				}
			}

			$dotcount++;
			print '.' if ($dotcount % 10000 == 0);
			#print "\n" if ($dotcount % 1000000 == 0);
		}
	}
	
	close DATA;
}



