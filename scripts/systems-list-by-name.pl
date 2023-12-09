#!/usr/bin/perl
use strict; $|=1;

use lib "/home/bones/perl";
use DB qw(db_mysql);
use ATOMS qw(make_csv);

my $sector = $ARGV[0];

die "Usage: $0 <sectorname>\n" if (!$sector);

my $and = " and name like '$sector\%' ";

my @rows = db_mysql('elite',"select * from systems where name like '$sector\%' and deletionState=0 order by name");

print make_csv("EDAstro ID","EDSM ID","ID64","Name","X","Y","Z","Sol Distance","Mass Code","Main Star Type","Date Added",'RegionID')."\r\n";

foreach my $r (@rows) {
	print make_csv($$r{ID},$$r{edsm_id},$$r{id64},$$r{name},$$r{coord_x},$$r{coord_y},$$r{coord_z},
		$$r{sol_dist},$$r{masscode},$$r{mainStarType},$$r{date_added},$$r{region})."\r\n";
}

