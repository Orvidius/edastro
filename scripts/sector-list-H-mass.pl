#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

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

my %sector_data = ();

open CSV, "</home/bones/elite/scripts/sector-list-backup.csv";
while (<CSV>) {
	chomp;
	my @v = parse_csv($_);
	my $sec = shift @v;
	$sector_data{uc($sec)} = \@v;
}
close CSV;


my %system_name = ();

my @list = ();
my @rows = db_mysql('elite',"select id64 from systems where name rlike ' AA-A h' and deletionState=0");

warn int(@rows)." systems to consider.\n";

while (@rows) {
	my $r = shift @rows;
	push @list, $$r{id64};
}

my %sector  = ();

while (@list) {
	my @ids = splice @list,0,$chunk_size;

	last if (!@ids);

	my $select = "select name,coord_x,coord_y,coord_z from systems where id64 in (".join(',',@ids).") and deletionState=0";
	my @rows = db_mysql('elite',$select);

	while (@rows) {
		my $r = shift @rows;

		if ($$r{name} =~ /^(.+\S)\s+[A-Z][A-Z]\-[A-Z]\s+([a-z](\d+\-)?(\d+))?\s*$/) {
			$sector{$1}{c}++;
			$sector{$1}{h} = $4 if (!$sector{$1}{h} || $4 > $sector{$1}{h});

			if (defined($$r{coord_x}) && defined($$r{coord_y}) && defined($$r{coord_z})) {
				$sector{$1}{n}++;
			}
		}
	}

}

print make_csv('Sector','AA-A_h systems','Highest Number','Sector Total Systems',"Avg X","Avg Y","Avg Z","Min X","Min Y","Min Z","Max X","Max Y","Max Z","MapSector X","MapSector Y")."\r\n";
foreach my $s (sort keys %sector) {
	next if (!$sector{$s}{n});
	next if (!$sector{$s}{c});
	my @list = ();
	@list = @{$sector_data{uc($s)}} if (exists($sector_data{uc($s)}) && ref($sector_data{uc($s)}) eq 'ARRAY');

	print make_csv($s,$sector{$s}{c},$sector{$s}{h},@list)."\r\n";
}

 
