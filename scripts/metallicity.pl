#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2020, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

############################################################################

show_queries(0);

my $debug_limit = ''; # " limit 1000";

my @rows = db_mysql('elite',"select systems.name as sysname,stars.name as starname,stars.subType as startype, planets.name as planetname, planets.subType as planettype, stars.age, ".
		"hydrogen, helium from systems,stars,planets,atmospheres where systems.id64=planets.systemId64 and systems.id64=stars.systemId64 ".
		"and atmospheres.planet_id=planets.planetID and ".
		"planets.subType like '%gas giant%' and (stars.name=systems.name or stars.name=concat(systems.name,' A')) ".
		"and stars.deletionState=0 and planets.deletionState=0 and systems.deletionState=0 ".
		"order by systems.name,planets.name $debug_limit");


print "Mass Code,System,Main Star,Star Type,Star Age,Planet,Planet Type,Hydrogen,Helium,Metals\r\n";

warn "Looping...\n";

my $count = 0;
while (@rows) {
	my $r = shift @rows;

	my $masscode = '';

	if ($$r{sysname} =~ /\S+\s+\w\w\-\w\s+([a-zA-Z])(\d+\-)?\d+/) {
		$masscode = uc($1);
	}

	my $metals = sprintf("%.05f",100 - ($$r{hydrogen}+$$r{helium}));
	my $helium = sprintf("%.05f",$$r{helium});
	my $hydrogen = sprintf("%.05f",$$r{hydrogen});

	$metals =~ s/0+$//;
	$metals =~ s/\.$//;
	$helium =~ s/0+$//;
	$helium =~ s/\.$//;
	$hydrogen =~ s/0+$//;
	$hydrogen =~ s/\.$//;

	$metals = '0' if ($metals < 0);

	print make_csv($masscode,$$r{sysname},$$r{starname},$$r{startype},$$r{age},$$r{planetname},$$r{planettype},$hydrogen,$helium,$metals)."\r\n";
	$count++;
}
warn "$count found\n";


