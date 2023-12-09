#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(commify make_csv);

############################################################################

show_queries(0);

my $debug_limit	= '';# 'limit 1000';

############################################################################

my %out = ();

my @lookup = db_mysql('elite',"select max(planetID) as maxID from planets");
my $maxID = ${$lookup[0]}{maxID};
my $chunkID = 0;
my $chunkSize = 100000;
my $count = 0;
my $dotcount = 0;
my %helium = ();
my %heliumrich_gg = ();
my %out = ();

my $progname = $0;

while ($chunkID < $maxID) {

	$0 = "$progname (".commify($chunkID)." / ".commify($maxID).")";

	my @rows = db_mysql('elite',"select systemId64,subType,helium from planets,atmospheres where planetID>=? and planetID<? and deletionState=0 and planetID=planet_id and subType like '\%gas giant\%'",
			[($chunkID,$chunkID+$chunkSize)]);

	$chunkID += $chunkSize;

	$dotcount++;
	print '.';
	print "\n" if ($dotcount % 100 == 0);

	foreach my $r (@rows) {
		$helium{$$r{systemId64}} = $$r{helium} if ((!$helium{$$r{systemId64}} || $$r{helium} > $helium{$$r{systemId64}}) && $$r{helium} >= 32);

		if ($$r{subType} =~ /helium/i) {
			$heliumrich_gg{$$r{systemId64}}++;
		}
	}
}


$0 = "$progname (system lookups)";
my @list = keys %helium;

while (@list) {
	$dotcount++;
	print ':';
	print "\n" if ($dotcount % 100 == 0);

	my @lookup = splice @list, 0, 500;
	my @rows = db_mysql('elite',"select id64,name,coord_x,coord_y,coord_z,region regionID from systems where id64 in (".join(',',@lookup).") and deletionState=0");
	foreach my $r (@rows) {
		if ($helium{$$r{id64}} && $$r{name} =~ /[A-Z][A-Z]\-[A-Z]\s+[a-z]\d+/) {
			$out{$$r{name}} = make_csv($$r{id64},$$r{name},$heliumrich_gg{$$r{id64}},$helium{$$r{id64}},$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{regionID});
			delete($helium{$$r{id64}});
			$count++;
		} elsif ($helium{$$r{id64}}) {
			delete($helium{$$r{id64}});
		}
	}
}


print "\n";

$0 = "$progname (writing)";

open CSV, ">helium-rich-systems.csv";
print CSV "SystemAddress ID64,System Name,Helium Rich Giants,Helium Percent,X,Y,Z,RegionID\r\n";

foreach my $n (sort {$a cmp $b} keys %out) {
	print CSV "$out{$n}\r\n";
}
close CSV;

warn "$count found\n";



