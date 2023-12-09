#!/usr/bin/perl
use strict;
$|=1;

use JSON;
use Data::Dumper;
use Time::HiRes qw( gettimeofday );
use File::Path qw(make_path);
use POSIX qw/floor/;

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch btrim);

use lib "/home/bones/elite";
use EDSM qw( load_mappings %atmo_map %volc_map %planet_map %star_map %terr_map );

my $debug	= 0;

load_mappings();

foreach my $raw (sort keys %star_map) {
	next if (!$raw || !$star_map{$raw});
	
	my @rows = db_mysql('elite',"select starID,name from stars where subType=? order by name",[($raw)]);
	while (@rows) {
		my $r = shift @rows;
		print "$raw -> $star_map{$raw} : $$r{name} ($$r{starID})\n";

		my $sql = "update stars set subType=?,updated=updated where starID=?";
		my @params = ($star_map{$raw},$$r{starID});

		if ($debug) {
			print "\t$sql (".join(', ',@params).")\n";
		} else {
			db_mysql('elite',$sql,\@params);
		}
	}
}

foreach my $raw (sort keys %planet_map) {
	next if (!$raw || !$planet_map{$raw});
	next if ($raw eq $planet_map{$raw});
	
	my @rows = db_mysql('elite',"select planetID,name from planets where subType=? order by name",[($raw)]);
	while (@rows) {
		my $r = shift @rows;
		print "$raw -> $planet_map{$raw} : $$r{name} ($$r{planetID})\n";

		my $sql = "update planets set subType=?,updated=updated where planetID=?";
		my @params = ($planet_map{$raw},$$r{planetID});

		if ($debug) {
			print "\t$sql (".join(', ',@params).")\n";
		} else {
			db_mysql('elite',$sql,\@params);
		}
	}
}

