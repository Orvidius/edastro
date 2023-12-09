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

my @rows = db_mysql('elite',"select systems.name,systems.id64,stars.name starname,planets.name planetname,coord_x,coord_y,coord_z from stars,planets,systems ".
		"where stars.subType in ('A (Blue-White super giant) Star','A (Blue-White) Star') and planets.isLandable>0 and ".
		"planets.subType='Metal-rich body' and stars.systemId64=planets.systemId64 and stars.systemId64=systems.id64 and stars.deletionState=0 and planets.deletionState=0 ".
		"and systems.deletionState=0");

my %checked = ();

print "System,Planet,X,Y,Z\r\n";

my $count = 0;
foreach my $r (sort {$$a{name} cmp $$b{name}} @rows) {

	next if ($checked{$$r{planetname}});
	$checked{$$r{planetname}}++;

	my @check = db_mysql('elite',"select name from planets where systemId64='$$r{id64}' and subType in ('Gas giant with water-based life','Earth-like world','Water giant') and deletionState=0");

	if (@check) {
		print "$$r{name},$$r{planetname},$$r{coord_x},$$r{coord_y},$$r{coord_z}\r\n";
		$count++;
	}

}
warn "$count found\n";



