#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

use Image::Magick;

############################################################################

show_queries(0);

my @rows = db_mysql('elite',"select ID,id64,edsm_id,name,IFNULL(planet_num,0) num_planets,IFNULL(star_num,0) num_stars,".
	"IFNULL(planet_num,0)+IFNULL(star_num,0) as num_bodies,coord_x,coord_y,coord_z,region regionID from systems ".
	"left join (select systemId64,count(*) as planet_num from planets where deletionState=0 group by systemId64) as pl on pl.systemId64=systems.id64 ".
	"left join (select systemId64,count(*) as star_num from stars where deletionState=0 group by systemId64) as st on st.systemId64=systems.id64 ".
	"where IFNULL(planet_num,0)+IFNULL(star_num,0)>=100 and deletionState=0 order by num_bodies desc,name");

print make_csv('ID64 SystemAddress','EDSM ID','System','Total Bodies','Planets','Stars',,'Coord_x','Coord_y','Coord_z','RegionID')."\r\n";

my $count = 0;
foreach my $r (@rows) {

	my %cmdrs = ();

	#next if ($$r{name} !~ /(\S+\s+)+\w\w\-\w\s+\w\d*-\d+\s*$/);
	next if ($$r{name} eq 'Delphi');

	print make_csv($$r{id64},$$r{edsm_id},$$r{name},$$r{num_bodies},$$r{num_planets},$$r{num_stars},$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{regionID})."\r\n";

	$count++;
}
warn "$count found\n";



