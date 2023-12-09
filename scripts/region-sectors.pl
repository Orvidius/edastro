#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

use POSIX qw(floor);

############################################################################

my $debug_limit = ''; #'limit 10';

my @what = ();

die "Usage: <regionID|regionName>\n" if (!$ARGV[0]);

my @rows = ();

@rows = db_mysql('elite',"select id from regions where id=?",[($ARGV[0])]) if ($ARGV[0] =~ /^\d+$/);
@rows = db_mysql('elite',"select id from regions where name=?",[($ARGV[0])]) if ($ARGV[0] !~ /^\d+$/);

die "Not found.\n" if (!@rows);

my $region = ${$rows[0]}{id};

my @rows =  db_mysql('elite',"select name,mainStarType from systems where region=? and deletionState=0 order by name",[($region)]);

my %sector = ();

open CSV1, ">region-$region-systems.csv";
open CSV2, ">region-$region-sectors.csv";

print CSV1 "System,Main star\r\n";

foreach my $r (@rows) {
	if ($$r{name} =~ /^(.*\S)\s+[A-Z][A-Z]\-[A-Z]\s+/) {
		$sector{$1}++;
	}

	print CSV1 "$$r{name},$$r{mainStarType}\r\n" if ($$r{mainStarType} !~ /dwarf/i);
	#print CSV1 "$$r{name}\r\n" if ($$r{mainStarType} !~ /dwarf/i);
}

print CSV2 "Sector,Count\r\n";

foreach my $s (sort keys %sector) {
	print CSV2 "$s,$sector{$s}\r\n";
}

close CSV1;
close CSV2;

