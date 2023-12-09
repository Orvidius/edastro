#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

use POSIX qw(floor);

############################################################################

show_queries(0);

my $and = '';

if (@ARGV) {
	$and = $ARGV[0];
}
$and = "$and and" if ($and);

print make_csv(qw(Callsign Name Owner LastUpdated LastMoved LastSystem SystemAddress Coord_X Coord_Y Coord_Z SolDistance EstimatedRegion LocationHistory DockingsEDDN Services))."\r\n";

my @rows = db_mysql('elite',"select *,(select count(*) from carrierlog cl where c.callsign=cl.callsign) as logcount,(select count(*) from carrierdockings cd ".
			"where c.callsign=cd.callsign) as dockings from carriers c where $and c.lastEvent is not null order by c.callsign");

foreach my $r (@rows) {
	my $services = $$r{services};
	$services =~ s/,/;/gs;

	my $region = '';

	if ($$r{coord_x} || $$r{coord_z}) {
		my @regs = db_mysql('elite',"select name from regions,regionmap where region=id and coord_x=? and coord_z=?",[(floor($$r{coord_x}/10),floor($$r{coord_z}/10))]);
		if (@regs) {
			$region = ${$regs[0]}{name};
		}
	}

	print make_csv($$r{callsign},$$r{name},$$r{commander},$$r{lastEvent},$$r{lastMoved},$$r{systemName},$$r{systemId64},$$r{coord_x},$$r{coord_y},$$r{coord_z},
		sprintf("%.02f",sqrt($$r{coord_x}**2 + $$r{coord_y}**2 + $$r{coord_z}**2)),$region,$$r{logcount},$$r{dockings},$services)."\r\n";
}

