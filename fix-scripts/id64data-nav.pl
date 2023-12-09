#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql);

use lib "/home/bones/elite";
use EDSM qw(id64_subsector id64_sectorcoords id64_sectorID);

my %hash	= ();

my @rows = db_mysql('elite',"select id64 from navsystems where id64sectorID is null");
my $count = 0;


while (@rows) {
	my $r = shift @rows;

	my $sectorID = id64_sectorID($$r{id64});
	my ($massID,$boxID,$boxnum) = id64_subsector($$r{id64},1);
	db_mysql('elite',"update navsystems set id64sectorID=?,id64mass=?,id64boxelID=?,id64boxelnum=?,updated=updated where id64=?",[($sectorID,$massID,$boxID,$boxnum,$$r{id64})]);

	$count++;
	print '.' if ($count % 10000 == 0);
}
print "\n";

