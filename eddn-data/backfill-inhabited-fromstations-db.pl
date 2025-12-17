#!/usr/bin/perl
use strict;

use JSON;

use utf8;
use feature qw( unicode_strings );

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);
use ATOMS qw(date2epoch epoch2date btrim parse_csv);

my @rows = db_mysql('elite',"select id64,y.name,s.name,s.date_added,inhabited from systems y,stations s where y.inhabited is not null  and y.id64=s.systemId64 and type not in ('Fleet Carrier','Mega Ship') and s.date_added<y.inhabited and s.name not like '$%' and s.name not like '%Construction Site%' order by y.name");

foreach my $r (@rows) {
	my $date = "$$r{date_added} 23:59:59";

	next if ($date ge $$r{inhabited});

	print "$$r{id64} = $date ($$r{inhabited})\n";
	db_mysql('elite',"update systems set inhabited=?,updated=updated where id64=? and (inhabited is null or inhabited>?)",[($date,$$r{id64},$date)]);
}



