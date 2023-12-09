#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10 estimated_coords load_sectors);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

############################################################################

my $debug	= 0;

show_queries(0);
my $sector_ref = load_sectors();

############################################################################

my $and = '';
$and = "and name like 'Aaeyoea %'" if ($debug);

my @rows = db_mysql('elite',"select id64,edsm_id,name,region from systems where (coord_x is null or coord_y is null or coord_z is null) and id64 is not null ".
				"and deletionState=0 $and order by name");

print make_csv('ID64 SystemAddress','EDSM ID','System','Estimation error','Estimated X','Estimated Y','Estimated Z','Estimated Sol Distance','RegionID')."\r\n";

my $count = 0;
foreach my $r (@rows) {

	my $missing = '';

	foreach my $c (qw(x y z)) {
		$missing .= ','.uc($c) if (!defined($$r{'coord_'.$c}));
	}
	$missing =~ s/^,//;

	next if (!$missing);

	my ($x, $y, $z, $width, $size) = estimated_coords($$r{name},$sector_ref);
	my $dist = sprintf("%.02f",sqrt($x**2 + $y**2 + $z**2));
	$dist = '' if ($dist == 0);

	print make_csv($$r{id64},$$r{edsm_id},$$r{name},$size*10,$x,$y,$z,$dist,$$r{region})."\r\n";

	$count++;
}
warn "$count found\n";

exit;

############################################################################



