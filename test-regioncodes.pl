#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use EDSM qw(findRegion);

############################################################################

my $db  = 'elite';

############################################################################

my $debug               = 0;
my $verbose             = 0;
my $fixing		= 1;

############################################################################

my @max = db_mysql($db,"select max(ID) maxID from systems");
my $maxID = ${$max[0]}{maxID};

my $id = 0;

my $chunk_size = 5000;

while ($id < $maxID) {

	my $rows = rows_mysql($db,"select ID,name,id64,coord_x,coord_y,coord_z,region from systems where ID>=? and ID<? and deletionState=0 and ".
				"coord_x is not null and coord_z is not null",[($id,$id+$chunk_size)]);

	foreach my $r (@$rows) {

		my $regionID = findRegion($$r{coord_x},$$r{coord_y},$$r{coord_z});

		next if (!$regionID);


		if ($$r{region} != $regionID) {
			print "DIFFERENT: $$r{name} $$r{id64} [$$r{ID}] ($$r{coord_x}, $$r{coord_y}, $$r{coord_z}) $$r{region} != $regionID\n";
			db_mysql($db,"update systems set updated=updated,region=? where ID=?",[($regionID,$$r{ID})]) if ($fixing);
		}
	}

	$id += $chunk_size;
}
