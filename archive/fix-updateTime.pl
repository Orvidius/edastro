#!/usr/bin/perl

use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my $fix_new = 1;
my $max_date = ''; # '2021-02-25 00:00:00';
my $dotcount = 0;

my $one = 1;

my %list_id64 = ();
my %list_edsmID = ();

if ($fix_new) {
	print "Pull IDs\n";
	print "planets\n";
	my @rows = db_mysql('elite',"select bodyId64,edsmID from planets where updateTime>'2021-01-01 00:00:00'");
	print "stars\n";
	push @rows, db_mysql('elite',"select bodyId64,edsmID from stars where updateTime>'2021-01-01 00:00:00'");
	foreach my $r (@rows) {
		${$list_id64{$$r{bodyId64}}} = \$one if ($$r{bodyId64});
		${$list_edsmID{$$r{edsmID}}} = \$one if ($$r{edsmID});
	}
	print int(keys %list_id64)." bodies to consider.\n";
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
	
			my $updateTime = undef;
			my $name = '';
			my $edsmID = 0;
			my $body64 = 0;
	
			if ($line =~ /"updateTime"\s*:\s*"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"[,\}]/) {
				$updateTime = $1;
			}
	
			if ($line =~ /"id64"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$body64 = $1;
			}
	
			if ($line =~ /"id"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$edsmID = $1;
			}
	
			if ($line =~ /"name"\s*:\s*"([^"]+)"[,\}]/) {
				$name = $1;
			}
	
			if (($body64 || $edsmID) && (!$fix_new || ($body64 && $list_id64{$body64}) || ($edsmID && $list_edsmID{$edsmID}))) {
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

				if (@params) {
					$where =~ s/\s*or\s+//;
					$where = "($where)" if (@params>1);

					@params = ($updateTime,@params,$updateTime);

					my $date_and = '';
					if ($max_date) {
						$date_and = "and updated<?";
						push @params, $max_date;
					}

					eval {
						db_mysql('elite',"update $table set updateTime=?,updated=updated where $where and updateTime!=? $date_and",\@params);
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



