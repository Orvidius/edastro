#!/usr/bin/perl
use strict;

# Copyright (C) 2019, Ed Toton (CMDR Orvidius), All Rights Reserved.

#####################################################################

use lib "/home/bones/perl";
use DB qw(rows_mysql db_mysql);

#####################################################################

my $do_all = 0;
my @rows = ();

my $chunk_size	= 1000;
my $limit	= 'limit 500000';

print "Pulling.\n";

@rows = db_mysql('elite',"select systems.name sysname,starID,stars.name starname ".
		"from systems,stars where systems.id64=stars.systemId64 and isPrimary is null and systems.deletionState=0 and stars.deletionState=0 $limit") if (!$do_all);

@rows = db_mysql('elite',"select systems.name sysname,starID,stars.name starname ".
		"from systems,stars where systems.id64=stars.systemId64 and systems.deletionState=0 and stars.deletionState=0 $limit") if ($do_all);;

print int(@rows)." stars to process.\n";

my $n = 0;

my @one_list = ();
my @zero_list = ();

while (@rows) {
	my $r = shift @rows;
	$n++;
	print '.' if ($n % 10000 == 0);
	print "\n" if ($n % 1000000 == 0);


	my $sysname = uc($$r{sysname});
	my $starname = uc($$r{starname});

	if (!$$r{starID}) {
		next;
	} elsif ($starname eq $sysname || $starname eq "$sysname A") {
		push @one_list, $$r{starID};
	} else {
		push @zero_list, $$r{starID};
	}

	if (@one_list >= $chunk_size) {
		db_mysql('elite',"update stars set isPrimary=1,updated=updated where starID in (".join(',',@one_list).")");
		@one_list = ();
	}
	if (@zero_list >= $chunk_size) {
		db_mysql('elite',"update stars set isPrimary=0,updated=updated where starID in (".join(',',@zero_list).")");
		@zero_list = ();
	}
}

if (@one_list) {
	db_mysql('elite',"update stars set isPrimary=1,updated=updated where starID in (".join(',',@one_list).")");
}
if (@zero_list) {
	db_mysql('elite',"update stars set isPrimary=0,updated=updated where starID in (".join(',',@zero_list).")");
}

print "\n";

#####################################################################




