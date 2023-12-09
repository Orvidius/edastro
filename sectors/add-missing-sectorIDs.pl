#!/usr/bin/perl
use strict; $|=1;

use lib '/home/bones/perl';
use ATOMS qw(btrim);
use DB qw(db_mysql);

use lib '/home/bones/elite';
use EDSM qw(id64_sectorcoords);

my $db	= 'elite';

my $chunk_size = 10000;
my $maxID = 0;


my @rows = db_mysql('elite',"select max(ID) maxID from systems");
foreach my $r (@rows) {
	$maxID = $$r{maxID};
}

my $id = 0;
my $dotcount = 0;

my %sector = ();

while ($id<$maxID) {

	my @rows = db_mysql('elite',"select ID,name,id64,deletionState as del from systems where ID>=? and ID<=? and id64 is not null and sectorID is null",[($id,$id+$chunk_size)]);
	$id += $chunk_size;

	foreach my $r (@rows) {
		my $sectorID = 0;

		if ($$r{id64} && !$$r{sectorID} && !$$r{del}) {
			my ($x,$y,$z) = id64_sectorcoords($$r{id64});
	
			if (!$sectorID) {
				my @sec = db_mysql($db,"select ID from sectors where sector_x=? and sector_y=? and sector_z=? order by name limit 1",[($x,$y,$z)]);
				foreach my $s (@sec) {
					$sectorID = $$s{ID};
				}
			}
			if (!$sectorID && $$r{name} =~ /^([\w\s]+)\s+([A-Z][A-Z]\-[A-Z])\s+[a-z]/) {
				my $sector_name = btrim($1);
				my $code = $2;
	
				if ($sector{$sector_name}) {
					$sectorID = $sector{$sector_name};

				} elsif ($sector_name !~ /\s(Region|Sector)\s*$/i && $sector_name !~ /^[A-Z ]+$/ && $sector_name !~ /^[A-Z][a-z]+\d+/) {
					my @sec = db_mysql($db,"select ID from sectors where name=? and sector_x=? and sector_y=? and sector_z=?",[($sector_name,$x,$y,$z)]);
					if (@sec) {
						$sectorID = ${$sec[0]}{ID};
					} elsif ($code ne 'AA-A') {
						$sectorID = db_mysql($db,"insert into sectors (name,sector_x,sector_y,sector_z,created) values (?,?,?,?,NOW())",
									[($sector_name,$x,$y,$z)]);
					}
				}

				$sector{$sector_name} = $sectorID if ($sectorID && !$sector{$sector_name});
			}
		}

		if ($sectorID) {
			db_mysql($db,"update systems set sectorID=?,updated=updated where ID=?",[($sectorID,$$r{ID})]);
		}
	}

	$dotcount++;
	print '.';
	print "\n" if ($dotcount % 100 == 0);
}
print "\n";

