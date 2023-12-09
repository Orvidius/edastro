#!/usr/bin/perl

use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my $dotcount = 0;

foreach my $fn (@ARGV) {
	
	print "\n$fn\n";
	
	open DATA, "zcat $fn |";
	
	while (my $line = <DATA>) {
		if ($line =~ /"type":"(Planet|Star)"/) {
	
			my $table = 'planets';
			$table = 'stars' if ($1 eq 'Star');
	
			my $radius = 0;
			my $edsmID = 0;
			my $body64 = 0;
	
			if ($line =~ /"radius":([\d\.\-\+]+)[,\}]/) {
				$radius = $1;
			}
	
			if ($line =~ /"id64":([\d\.\-\+]+)[,\}]/) {
				$body64 = $1;
			}
	
			if ($line =~ /"id":([\d\.\-\+]+)[,\}]/) {
				$edsmID = $1;
			}
	
			if ($radius && $radius>0 && ($body64 || $edsmID)) {
				my $where = '';
				my $id = 0;

				if ($body64) {
					$where = 'bodyId64=?';
					$id = $body64;
				} else {
					$where = 'edsmID=?';
					$id = $edsmID;
				}

				db_mysql('elite',"update $table set radius=? where $where",[($radius,$id)]);
			}

			$dotcount++;
			print '.' if ($dotcount % 10000 == 0);
			print "\n" if ($dotcount % 1000000 == 0);
		}
	}
	
	close DATA;
}



