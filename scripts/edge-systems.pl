#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch);

use Image::Magick;

############################################################################

show_queries(0);

#my $star_types = "'Earth-like world'";
#
#if (@ARGV) {
#	$star_types = "";
#
#	foreach my $arg (@ARGV) {
#		$arg =~ s/[^\w\d\s\-\(\)\.]+//gs;
#		$star_types .= ",'$arg'";
#	}
#
#	$star_types =~ s/^,//;
#}

print "\"ID\",\"Edge\",\"Name\",\"Coord_x\",\"Coord_y\",\"Coord_z\",\"date\",\"RegionID\"\r\n";

my $limit = 500;

get_systems("where coord_x is not null and deletionState=0 order by coord_x limit $limit",'west');
get_systems("where coord_x is not null and deletionState=0 order by coord_x desc limit $limit",'east');
get_systems("where coord_y is not null and deletionState=0 order by coord_y limit $limit",'bottom');
get_systems("where coord_y is not null and deletionState=0 order by coord_y desc limit $limit",'top');
get_systems("where coord_z is not null and deletionState=0 order by coord_z limit $limit",'south');
get_systems("where coord_z is not null and deletionState=0 order by coord_z desc limit $limit",'north');

sub get_systems {
	my $where = shift;
	my $note = shift;

	my @rows = db_mysql('elite',"select * from systems $where");

	foreach my $r (@rows) {
		print "\"$$r{edsm_id}\",\"$note\",\"$$r{name}\",\"$$r{coord_x}\",\"$$r{coord_y}\",\"$$r{coord_z}\",\"$$r{updateTime}\",\"$$r{region}\"\r\n";
	}
}


