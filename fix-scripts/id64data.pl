#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql);

use lib "/home/bones/elite";
use EDSM qw(id64_subsector id64_sectorcoords id64_sectorID);

my %hash	= ();
my $table	= 'systems';
my $IDfield	= 'ID';
my $maxID	= 0;

my @rows = db_mysql('elite',"select max($IDfield) as maxID from $table");
$maxID = ${$rows[0]}{maxID};

my $start = 0;
my $end = 0;

if (0) {
	if (!@ARGV) {
		print "$table($maxID)\n";

		my $chunk_size = 2000000;
		my $chunk = 0;
		while ($chunk < $maxID) {
			my $next_chunk = $chunk + $chunk_size;
			my $exec = "$0 $chunk $next_chunk \&";
	
			#print "> $exec\n";
			system($exec);
	
			$chunk = $next_chunk;
		}
		exit;
	} else {
		($start,$end) = @ARGV;
		#print "< RANGE: $start - $end\n";
	}
} else {
	$end = $maxID;
}

my $chunk_size = 10000;
my $chunk = $start;


while ($chunk < $maxID && $chunk < $end) {
	my $next_chunk = $chunk + $chunk_size;

	my $rows = rows_mysql('elite',"select ID,id64 from systems where $IDfield>=? and $IDfield<? and deletionState=0 and (id64sectorID is null or id64boxelID is null) and id64 is not null",[($chunk,$next_chunk)]);
	next if (!$rows || ref($rows) ne 'ARRAY');

	foreach my $r (@$rows) {
		my $sectorID = id64_sectorID($$r{id64});
		my ($massID,$boxID,$boxnum) = id64_subsector($$r{id64},1);
		db_mysql('elite',"update $table set id64sectorID=?,id64mass=?,id64boxelID=?,id64boxelnum=?,updated=updated where ID=?",[($sectorID,$massID,$boxID,$boxnum,$$r{ID})]);
	}

	$chunk = $next_chunk;
	print '.';
}
print "\n";

