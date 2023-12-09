#!/usr/bin/perl
use strict; $|=1;

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);

###########################################################################

my $debug	= 0;
my $verbose	= 0;
my $chunk_size	= 1000;

show_queries(0);

###########################################################################

if (!@ARGV) {
	foreach my $table (qw(rings belts materials atmospheres)) {
		system("$0 $table \&");
	}

	exit;
}

my $table = $ARGV[0];

die "Need table name!\n" if (!$table);

my $done = 0;
my $count = 0;

while (!$done) {
	my $star_column = '';
	$star_column = ',isStar' if ($table eq 'rings');

	my @rows = db_mysql('elite',"select id,planet_id$star_column from $table where useNewID=0 limit $chunk_size");

	if (!@rows) {
		$done = 1;
		last;
	}

	my %data = ();

	foreach my $r (@rows) {
		my $owner_table = 'planets';
		$owner_table = 'stars' if ($$r{isStar} || $table eq 'belts');

		$data{$owner_table}{$$r{planet_id}}{$$r{id}}=1;
	}

	foreach my $t (keys %data) {
		my @list = ();

		foreach my $id (keys %{$data{$t}}) {
			push @list, $id if ($id);
		}

		my $IDfield = 'planetID';
		$IDfield = 'starID' if ($t eq 'stars');

		my @rows2 = db_mysql('elite',"select $IDfield,id as edsmID from $t where id in (".join(',',@list).")") if (@list);

		foreach my $r2 (@rows2) {
			my @updateIDs = keys %{$data{$t}{$$r2{edsmID}}};

			next if (!@updateIDs);

			my $sql = "update $table set planet_id=?,useNewID=1 where id in (".join(',',@updateIDs).")";

			print "SQL: $sql [$$r2{$IDfield}] (orig planet_id: $$r2{edsmID})\n" if ($debug || $verbose);
			db_mysql('elite',$sql,[($$r2{$IDfield})]);

			$count++;
			print '.' if (!$verbose && $count % 1000 == 0);

			last if ($count && $debug);
		}

		last if ($count && $debug);
	}
	last if ($count && $debug);
}
print "\n";


###########################################################################



