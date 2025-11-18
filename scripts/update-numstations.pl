#!/usr/bin/perl
use strict;

############################################################################

use Math::Trig;
use Data::Dumper;
use POSIX qw(floor);
use POSIX ":sys_wait_h";
use Time::HiRes qw(sleep);

use lib "/home/bones/elite";
use EDSM qw(log10 update_systemcounts);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

#############################################################################

show_queries(0);

my @rows = db_mysql('elite',"select distinct(systemId64) id64, count(*) num from stations where type not in ('Fleet Carrier','Mega ship','GameplayPOI') and type is not null group by systemId64");
print int(@rows)." systems to check.\n";

my $count = 0;

foreach my $r (@rows) {
	db_mysql('elite',"update systems set numStations=?,updated=updated where id64=? and (numStations is null or numStations!=?)",[($$r{num},$$r{id64},$$r{num})]);
	$count++;
	print "." if ($count % 100 == 0);
	print "\n" if ($count % 10000 == 0);
}

print "\n";
