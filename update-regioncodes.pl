#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);

use Image::Magick;
use POSIX qw(floor);

############################################################################

my $db	= 'elite';

############################################################################

my $debug		= 0;
my $verbose		= 0;

############################################################################


if ($ARGV[0]) {
	# Update/correct all
	db_mysql($db,"update systems sys inner join regionmap rm on rm.coord_x=floor(sys.coord_x/10) and rm.coord_z=floor(sys.coord_z/10) set sys.region=rm.region ".
			"where $ARGV[0] and rm.region is not null");
} else {
	# Fill in the missing data
	db_mysql($db,"update systems sys inner join regionmap rm on rm.coord_x=floor(sys.coord_x/10) and rm.coord_z=floor(sys.coord_z/10) set sys.region=rm.region ".
			"where sys.region is null and rm.region is not null");
}

############################################################################

