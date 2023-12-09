#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);

############################################################################

print "Pulling systems missing boxel IDs\n";

my $done = 0;
my $chunk_size = 1000;

my $where = "where boxelID is null and coord_x is not null and coord_y is not null and coord_z is not null";

$where = '' if (@ARGV);

print "WHERE: $where\n" if ($where);

my $cols = columns_mysql('elite',"select ID from systems $where");

if (ref($$cols{ID}) eq 'ARRAY') {
	print int(@{$$cols{ID}})." found.\n";
} else {
	die "Nothing to do.\n";
}

print "Updating boxels\n";

my $count = 0;

while (!$done) {

	my @ids = splice @{$$cols{ID}},0,$chunk_size;
	last if (!@ids);
	my $where = "where ID in (".join(',',@ids).")";

	if (@ids) {

		#db_mysql('elite',"update systems set boxelID=((floor(coord_x/50)+900)*1800+(floor(coord_z/50)+900))*1800+floor(coord_y/50)+100 $where;");
		#db_mysql('elite',"update systems set boxelID=((floor(coord_x/10)+4500)*9000+(floor(coord_z/10)+4500))*9000+floor(coord_y/10)+500 $where;");
		db_mysql('elite',"update systems set boxelID=((floor(coord_x/10)+4500)*90000000+(floor(coord_z/10)+2500))*1000+floor(coord_y/10)+500 $where;");
		$count += $chunk_size;
		if ($count % 10000 == 0) {
			print '.';
		}
		if ($count % 1000000 == 0) {
			print "\n";
		}

	} else {
		$done = 1;
	}
}

print "\n";

