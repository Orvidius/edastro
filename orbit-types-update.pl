#!/usr/bin/perl
use strict;

# Copyright (C) 2019, Ed Toton (CMDR Orvidius), All Rights Reserved.

#####################################################################

use lib "/home/bones/perl";
use DB qw(rows_mysql db_mysql);
use ATOMS qw(btrim);


#####################################################################

my $debug	= 0;

#####################################################################

my $debug_limit = 'limit 5000'; $debug_limit = '' if (!$debug);
my $limit = 'limit 2000000';

my $do_all = 0;
my @rows = ();

$do_all = 1 if (@ARGV);

my $chunk_size = 1000;

print "Pulling.\n";


foreach my $table (qw(stars planets)) {

	print uc($table)."\n";

	my $IDfield = 'planetID';
	$IDfield = 'starID' if ($table eq 'stars');

	@rows = db_mysql('elite',"select systems.name sysname,$table.$IDfield,$table.name bodyname ".
			"from systems,$table where systems.id64=$table.systemId64 and orbitType is null and $table.deletionState=0 and systems.deletionState=0 $limit") if (!$do_all);
	
	@rows = db_mysql('elite',"select systems.name sysname,$table.$IDfield,$table.name bodyname ".
			"from systems,$table where systems.id64=$table.systemId64 and $table.deletionState=0 and systems.deletionState=0 $debug_limit") if ($do_all);;
	
	print int(@rows)." $table to process.\n";
	
	my $n = 0;
	
	my %orbit = ();
	
	while (@rows) {
		my $r = shift @rows;
		$n++;
		print '.' if ($n % 10000 == 0);
		print "\n" if ($n % 1000000 == 0);
	
		my $sysname = btrim($$r{sysname});
		my $bodyname = btrim($$r{bodyname});

		my $type = 0; # unknown
	
		if (!$$r{$IDfield}) {
			next;
		} elsif (uc($bodyname) eq uc($sysname)) {
			$type = 1; # single star

		} elsif ($bodyname =~ /^\s*(\S.*?\S)\s+[A-Z]\s*$/) {
			if (uc(btrim($1)) eq uc($sysname)) {
				$type = 2; # stellar
			}

		} elsif ($bodyname =~ /^\s*(\S.*?\S)(\s+[A-Z]+)?\s+\d+\s*$/) {
			if (uc(btrim($1)) eq uc($sysname)) {
				$type = 3; # planetary
			}

		} elsif (0) {	# Not used currently
			$type = 4; # barycentric (binaries, etc)

		} elsif ($bodyname =~ /^\s*(\S.*?\S)(\s+[A-Z]+)?\s+\d+((\s+[a-z])+)\s*$/) {
			if (uc(btrim($1)) eq uc($sysname)) {
				my $moondepth = $3; $moondepth =~ s/\s+//gs;
				$type = 4 + length($moondepth); # moon
			}
		}

		#print "$bodyname = $type\n" if ($bodyname =~ /Ceos/ && $type == 0);

		$orbit{$type}{$$r{$IDfield}} = 1;
	
		if (int(keys %{$orbit{$type}}) >= $chunk_size) {
			#print "$table $type: ".int(keys(%{$orbit{$type}}))."\n";
			if ($type) {
				db_mysql('elite',"update $table set orbitType=? where $IDfield in (".join(',',keys(%{$orbit{$type}})).")",[($type)]);
			}
			delete($orbit{$type});
		}
	}
	
	foreach my $type (sort keys %orbit) {
		#print "$table $type: ".int(keys(%{$orbit{$type}}))."\n";
		if ($type) {
			db_mysql('elite',"update $table set orbitType=? where $IDfield in (".join(',',keys(%{$orbit{$type}})).")",[($type)]);
		}
		delete($orbit{$type});
	}
	print "\n";
}


#####################################################################




