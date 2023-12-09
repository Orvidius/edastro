#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

use Image::Magick;
use POSIX qw(floor);

############################################################################

my $chunk_size		= 10000;
my $maxChildren		= 5;

my $galcenter_x         = 0;
my $galcenter_y         = -25;
my $galcenter_z         = 25000;

my $sector_radius       = 35;
my $sector_height       = 4;

my $sectorcenter_x      = -65;
my $sectorcenter_y      = -25;
my $sectorcenter_z      = 25815;

############################################################################

show_queries(0);

my %system_name = ();
my %sector_date = ();

my $maxID = 0;

my @list = ();
my @rows = db_mysql('elite',"select max(ID) as maxID from systems");

exit if (!@rows);

$maxID = ${$rows[0]}{maxID};

warn int($maxID)." system IDs to consider.\n";

my %sector64 = ();
my $sec = rows_mysql('elite',"select name,sector_x,sector_y,sector_z from sectors");
foreach my $s (@$sec) {
	$sector64{lc($$s{name})}{x} = $$s{sector_x};
	$sector64{lc($$s{name})}{y} = $$s{sector_y};
	$sector64{lc($$s{name})}{z} = $$s{sector_z};
}



my %sector  = ();
my $chunk = 0;

while ($chunk<$maxID) {
	my $next_chunk = $chunk + $chunk_size;

	my $select = "select name,date_added,coord_x,coord_y,coord_z from systems where ID>=$chunk and ID<$next_chunk and deletionState=0";
	$chunk = $next_chunk;
	my @rows = db_mysql('elite',$select);

	print '.';

	while (@rows) {
		my $r = shift @rows;

		if ($$r{name} =~ /^(.+\S)\s+[A-Z][A-Z]\-[A-Z]\s+([a-z](\d+\-)?\d+)?\s*$/) {
			my $s = $1;
			$sector{$s}{c}++;

			if (defined($$r{coord_x}) && defined($$r{coord_y}) && defined($$r{coord_z})) {
				$sector{$s}{n}++;
				$sector{$s}{x} += $$r{coord_x};
				$sector{$s}{y} += $$r{coord_y};
				$sector{$s}{z} += $$r{coord_z};

				$sector{$s}{x1} = $$r{coord_x} if ($$r{coord_x} < $sector{$s}{x1} || !$sector{$s}{x1});
				$sector{$s}{y1} = $$r{coord_y} if ($$r{coord_y} < $sector{$s}{y1} || !$sector{$s}{y1});
				$sector{$s}{z1} = $$r{coord_z} if ($$r{coord_z} < $sector{$s}{z1} || !$sector{$s}{z1});
	
				$sector{$s}{x2} = $$r{coord_x} if ($$r{coord_x} > $sector{$s}{x2} || !$sector{$s}{x2});
				$sector{$s}{y2} = $$r{coord_y} if ($$r{coord_y} > $sector{$s}{y2} || !$sector{$s}{y2});
				$sector{$s}{z2} = $$r{coord_z} if ($$r{coord_z} > $sector{$s}{z2} || !$sector{$s}{z2});

				if (defined($$r{date_added}) && $$r{date_added} ne '0000-00-00 00:00:00' && $$r{date_added} gt '2010-01-01 00:00:00') {
					$sector_date{$s} = $$r{date_added} if (!$sector_date{$s} || $$r{date_added} lt $sector_date{$s});
				}
			}
		}
	}

}
print "\n";

open CSV, ">sector-list.csv";

print CSV make_csv('Sector','Systems','Avg X','Avg Y','Avg Z','Min X','Min Y','Min Z','Max X','Max Y','Max Z','MapSector X','MapSector Y',
			'First Encountered','id64 X','id64 Y','id64 Z')."\r\n";
foreach my $s (sort keys %sector) {
	next if (!$sector{$s}{n});
	next if (!$sector{$s}{c});

	my $x  = sprintf("%.02f",$sector{$s}{x} / $sector{$s}{n});
	my $y  = sprintf("%.02f",$sector{$s}{y} / $sector{$s}{n});
	my $z  = sprintf("%.02f",$sector{$s}{z} / $sector{$s}{n});

	my $x1 = sprintf("%.02f",$sector{$s}{x1});
	my $y1 = sprintf("%.02f",$sector{$s}{y1});
	my $z1 = sprintf("%.02f",$sector{$s}{z1});

	my $x2 = sprintf("%.02f",$sector{$s}{x2});
	my $y2 = sprintf("%.02f",$sector{$s}{y2});
	my $z2 = sprintf("%.02f",$sector{$s}{z2});

	my $bx = floor(($x-$sectorcenter_x)/1280)+$sector_radius;
	my $bz = floor(($z-$sectorcenter_z)/1280)+$sector_radius;
 
	print CSV make_csv($s,$sector{$s}{c},$x,$y,$z,$x1,$y1,$z1,$x2,$y2,$z2,$bx,$bz,$sector_date{$s},$sector64{lc($s)}{x},$sector64{lc($s)}{y},$sector64{lc($s)}{z})."\r\n";
}

close CSV;


open CSV, ">sector-discovery.csv";

print CSV make_csv('Sector','Systems','First Encountered','id64 X','id64 Y','id64 Z')."\r\n";
foreach my $s (sort { $sector_date{$b} cmp $sector_date{$a} } keys %sector) {
        next if (!$sector{$s}{n});
        next if (!$sector{$s}{c});

        print CSV make_csv($s,$sector{$s}{c},$sector_date{$s},$sector64{lc($s)}{x},$sector64{lc($s)}{y},$sector64{lc($s)}{z})."\r\n";
}

close CSV;

