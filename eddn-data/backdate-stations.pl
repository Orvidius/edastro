#!/usr/bin/perl
use strict;

use JSON;

use utf8;
use feature qw( unicode_strings );

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);
use ATOMS qw(date2epoch epoch2date btrim parse_csv);

#foreach my $path ('archive','.') {
foreach my $path ('archive','.') {
	opendir DIR, $path;
	while (my $fn = readdir DIR) {
		if ($fn =~ /docked.jsonl/) {
			process_file("$path/$fn");
		}
	}
	closedir DIR;
}

sub process_file {
	my $fn = shift;

	warn "$fn\n";

	my $cat = $fn =~ /.gz$/ ? 'zcat' : 'cat';

	open DATA, "$cat $fn |";
	foreach my $line (<DATA>) {
		eval {
			# "timestamp" : "2025-04-01T03:59:39Z",
			# "MarketID" : 3223810560,
			# "SystemAddress" : 13865899009465,

			my ($timestamp,$id64,$marketID) = (undef,undef,undef);

			if ($line =~ /"timestamp"\s*:\s*"([\d\-:TZ]+)"/) {
				$timestamp = $1;
				$timestamp =~ s/T.*$//;
			}

			if ($line =~ /"MarketID"\s*:\s*(\d+)/) {
				$marketID = $1;
			}

			if ($line =~ /"SystemAddress"\s*:\s*(\d+)/) {
				$id64 = $1;
			}


			if ($id64 && $marketID && $timestamp) {
				print "$marketID/$id64 = $timestamp\n";
				db_mysql('elite',"update stations set date_added=?,updated=updated where date_added>? and marketID=? and systemId64=?",[($timestamp,$timestamp,$marketID,$id64)]);
			}
		};
	}
	close DATA;
}
