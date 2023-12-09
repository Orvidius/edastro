#!/usr/bin/perl
use strict; $|=1;

use lib "/home/bones/perl";
use DB qw(db_mysql);
use ATOMS qw(make_csv);

my $refsys = $ARGV[0];
my $maxdist = $ARGV[1];

die "Usage: $0 <system> <maxdistance>\n" if (!$refsys || !$maxdist);

my @rows = db_mysql('elite',"select * from systems where name=?",[($refsys)]);

die "System not found: $refsys\n" if (!@rows);

my $ID = ${$rows[0]}{ID};
my $x = ${$rows[0]}{coord_x};
my $y = ${$rows[0]}{coord_y};
my $z = ${$rows[0]}{coord_z};

my $and = '';
#$and = " and name like '$sector\%' ";

my @rows = db_mysql('elite',"select * from systems where coord_x>=? and coord_x<=? and coord_y>=? and coord_y<=? and coord_z>=? and coord_z<=? and ".
			"sqrt(pow(coord_x-?,2) + pow(coord_y-?,2) + pow(coord_z-?,2))<? and deletionState=0 order by name",
			[($x-$maxdist,$x+$maxdist,$y-$maxdist,$y+$maxdist,$z-$maxdist,$z+$maxdist,$x,$y,$z,$maxdist)]);

print make_csv("EDAstro ID","EDSM ID","ID64","Name","X","Y","Z","Sol Distance","Mass Code","Main Star Type","Date Added",'RegionID')."\r\n";

foreach my $r (@rows) {
	print make_csv($$r{ID},$$r{edsm_id},$$r{id64},$$r{name},$$r{coord_x},$$r{coord_y},$$r{coord_z},
		$$r{sol_dist},$$r{masscode},$$r{mainStarType},$$r{date_added},$$r{region})."\r\n";
}

