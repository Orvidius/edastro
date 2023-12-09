#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

############################################################################

my @max = db_mysql('elite',"select max(ID) maxID from systems");

die "Couldn't retrieve systems.\n" if (!@max);

my $chunk = 0;
my $chunk_size = 10000;
my $maxID = ${$max[0]}{maxID};

while ($chunk <= $maxID) {

	my $rows = rows_mysql('elite',"select id64,name,region from systems where ID>=? and ID<? and deletionState=0 and id64 is not null and name is not null and id64>0",
				[($chunk,$chunk+$chunk_size)]);

	foreach my $r (@$rows) {
		print make_csv($$r{id64},$$r{name},$$r{region})."\r\n";
	}

	$chunk += $chunk_size;
}

