#!/usr/bin/perl
use strict;
$|=1;

use POSIX qw(floor);

use lib "/home/bones/perl";
use DB qw(db_mysql);
use ATOMS qw(make_csv parse_csv btrim);

my $sol_mapsector_x     = -65;
my $sol_mapsector_y     = -25;
my $sol_mapsector_z     = -1065;
my $sol_sector_x        = 39;
my $sol_sector_y        = 32;
my $sol_sector_z        = 18;

#Sector,Systems,"Avg X","Avg Y","Avg Z"

open CSV, "</home/bones/elite/scripts/sector-list.csv";
foreach my $line (<CSV>) {
	chomp $line;
	my @v = parse_csv($line);

	my $name = btrim($v[0]);
	my $ax = $v[2];
	my $ay = $v[3];
	my $az = $v[4];

	next if ($ax =~ /[^\d\.\-]/ || $ay =~ /[^\d\.\-]/ || $az =~ /[^\d\.\-]/);
	next if ($name !~ /region|sector/i && $name !~ /^[A-Z]+$/);

	my $x = floor(($ax - $sol_mapsector_x)/1280) + $sol_sector_x;
	my $y = floor(($ay - $sol_mapsector_y)/1280) + $sol_sector_y;
	my $z = floor(($az - $sol_mapsector_z)/1280) + $sol_sector_z;

	my $sectorID = undef;
	my $sectorName = '';

	my @rows = db_mysql('elite',"select ID,name from sectors where sector_x=? and sector_y=? and sector_z=?",[($x,$y,$z)]);
	if (@rows) {
		$sectorID = ${$rows[0]}{ID};
		$sectorName = ${$rows[0]}{name};
	}

	next if (!$sectorID);

	my @rows = db_mysql('elite',"select ID,avgX,avgY,avgZ,ID,sectorID from fakesectors where name=?",[($name)]);

	if (@rows) {
		my $r = shift @rows;
		if ($$r{avgX} != $ax || $$r{avgY} != $ay || $$r{avgZ} != $az) {
			print "UPDATE: $name ($$r{ID}) $ax, $ay, $az / $x, $y, $z [$sectorName, $sectorID]\n";
			db_mysql('elite',"update fakesectors set avgX=?,avgY=?,avgZ=? where ID=?",[($ax,$ay,$az,$$r{ID})]);
		}
	} elsif ($sectorID) {
		print "INSERT $name : $ax, $ay, $az / $x, $y, $z [$sectorName, $sectorID]\n";
		db_mysql('elite',"insert into fakesectors (name,avgX,avgY,avgZ,sectorID,created) values (?,?,?,?,?,NOW())",[($name,$ax,$ay,$az,$sectorID)]);
	}
}
close CSV;

