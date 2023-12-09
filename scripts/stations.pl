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

my $scripts_path        = "/home/bones/elite/scripts";

############################################################################

show_queries(0);

my @rows = db_mysql('elite',"select stations.id,stations.name,type,systemId64,systemId,systemName,bodyID,bodyName,coord_x,coord_y,coord_z,sol_dist,".
		"distanceToArrival,allegiance,government,economy,haveMarket,haveShipyard,haveOutfitting,stations.updateTime ".
		"from stations,systems where stations.systemId=systems.edsm_id order by stations.name");

print make_csv('EDSM ID','Station Name','Type', 'ID64','EDSM systemId','SystemName','BodyID','BodyName','Coord X','Coord Y','Coord Z','Sol Distance',
	'DistanceToArrival','Allegiance','Government','Economy','Market','Shipyard','Outfitting','Updated')."\r\n";

my $count = 0;
foreach my $r (@rows) {

	foreach my $k (qw(haveMarket haveShipyard haveOutfitting)) {
		my $yn = 'no';
		$yn = 'yes' if ($$r{$k});
		$$r{$k} = $yn;
	}

	print make_csv($$r{id},$$r{name},$$r{type}, $$r{systemId64},$$r{systemId},$$r{systemName},$$r{bodyID},$$r{bodyName},$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{sol_dist},
		$$r{distanceToArrival},$$r{allegiance},$$r{government},$$r{economy},$$r{haveMarket},$$r{haveShipyard},$$r{haveOutfitting},$$r{updateTime})."\r\n";

	$count++;
}
warn "$count found\n";

exit;

############################################################################




