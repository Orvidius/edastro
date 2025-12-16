#!/usr/bin/perl
use strict;

use JSON;

use utf8;
use feature qw( unicode_strings );

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);
use ATOMS qw(date2epoch epoch2date btrim parse_csv);

my $year = '2025';

$year = $ARGV[0] if (@ARGV);

#foreach my $path ('archive','.') {
foreach my $path ('archive','.') {
	opendir DIR, $path;
	while (my $fn = readdir DIR) {
		if ($fn =~ /$year.+\.jsonl/) {
			process_file("$path/$fn");
		}
	}
	closedir DIR;
}

sub process_file {
	my $fn = shift;

	my $cat = $fn =~ /.gz$/ ? 'zcat' : 'cat';

	warn "$cat $fn\n";

	open(my $fh,"-|","$cat $fn") or die "Can't pipe from $cat: $!";
	while (my $line = <$fh>) {
		#eval {
			# "timestamp" : "2025-04-01T03:59:39Z",
			# "MarketID" : 3223810560,
			# "SystemAddress" : 13865899009465,

			my ($timestamp,$id64) = (undef,undef);
			my ($gov,$econ,$station,$type) = (undef,undef,undef,undef);
			my $inhabited = 0;

			if ($line =~ /"timestamp"\s*:\s*"(\d{4}\-\d{2}\-\d{2})T(\d{2}:\d{2}:\d{2})Z"/) {
				$timestamp = "$1 $2";
			}

			if ($line =~ /"(Station|System)Economy"\s*:\s*"([^"]+)"/) {
				$type = $1;
				$econ = $2;
			}
			if ($line =~ /"(Station|System)Government"\s*:\s*"([^"]+)"/) {
				$type = $1;
				$gov = $2;
			}
			if ($line =~ /"StationType"\s*:\s*"([^"]+)"/) {
				$station = $1;
			}

			if ($type eq 'System' || $station !~ /(Carrier|Mega)/i) {
				$inhabited = 1 if ($econ ne '' && $econ !~ /^\$?economy_None;?/i);
				$inhabited = 1 if ($gov ne '' && $gov !~ /^\$?government_None;?/i);
			}

			if ($line =~ /"SystemAddress"\s*:\s*(\d+)/) {
				$id64 = $1;
			}

			if ($id64 && $timestamp && $inhabited) {
				print "$id64 = $econ / $gov\n";

				db_mysql('elite',"update systems set inhabited=?,updated=updated where id64=? and (inhabited is null or inhabited>?)",[($timestamp,$id64,$timestamp)]);
			}
		#};
	}
	close $fh;
}



