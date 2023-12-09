#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my $chunk_size = 10000;

foreach my $table (qw(stars planets)) {
	print "\n$table\n";

	my $idfield = 'starID';
	$idfield = 'planetID' if ($table eq 'planets');

	my @dat = db_mysql('elite',"select max(planetID) maxID from planets");
	my $maxID = ${$dat[0]}{maxID};

	my $id = 0;
	my $dotcount = 0;

	while ($id < $maxID) {
		db_mysql('elite',"update $table set distanceToArrivalLS=distanceToArrival where $idfield>=? and $idfield<? and ".
				"(distanceToArrivalLS is null or (distanceToArrivalLS=0 and distanceToArrival>0))",[($id,$id+$chunk_size)]);
		$id += $chunk_size;

		$dotcount++;
		print '.' if ($dotcount % 10 == 0);
		print "\n" if ($dotcount % 1000 == 0);
	}
}
print "\n";
