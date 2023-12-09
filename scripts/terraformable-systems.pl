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

my @rows = db_mysql('elite',"select id64,edsm_id,systems.name,coord_x,coord_y,coord_z,region,count(*) as TFCs from systems,planets where ".
		"systems.id64=planets.systemId64 and terraformingState='Candidate for terraforming' and systems.deletionState=0 and ".
		"planets.deletionState=0 group by id64 having TFCs>=5 order by TFCs desc,systems.name");

print make_csv('ID64 SystemAddress','EDSM ID','System','Terraforming Candidates','Coord_x','Coord_y','Coord_z','RegionID')."\r\n";

my $count = 0;
foreach my $r (@rows) {

	my %cmdrs = ();

	#next if ($$r{name} !~ /(\S+\s+)+\w\w\-\w\s+\w\d*-\d+\s*$/);
	next if ($$r{name} eq 'Delphi');

	print make_csv($$r{id64},$$r{edsm_id},$$r{name},$$r{TFCs},$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{region})."\r\n";

	$count++;
}
warn "$count found\n";



