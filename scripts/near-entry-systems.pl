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

my %sys = ();

my $ls		= 150;
my $min_bodies	= 10;

foreach my $bodytype (qw(planets stars)) {

	warn "Scanning $bodytype\n";

	my @rows = db_mysql('elite',"select edsm_id,id64,systems.name,coord_x,coord_y,coord_z,region,count(*) as count from systems,$bodytype where ".
			"systems.deletionState=0 and $bodytype.deletionState=0 and " .
			"systems.id64=$bodytype.systemId64 and distanceToArrivalLS is not null and distanceToArrivalLS<$ls and ".
			"$bodytype.name rlike concat('^',systems.name) ".
			"group by systemId64");

	while (@rows) {
		my $r = shift @rows;
	
		if ($bodytype eq 'planets' || ($sys{$$r{id64}}{p} + $sys{$$r{id64}}{s} + $$r{count} >= $min_bodies)) {
			$sys{$$r{id64}}{n} = $$r{name};
			$sys{$$r{id64}}{e} = $$r{edsm_id};
			$sys{$$r{id64}}{x} = $$r{coord_x};
			$sys{$$r{id64}}{y} = $$r{coord_y};
			$sys{$$r{id64}}{z} = $$r{coord_z};
			$sys{$$r{id64}}{r} = $$r{region};
			$sys{$$r{id64}}{p} += $$r{count} if ($bodytype eq 'planets');
			$sys{$$r{id64}}{s} += $$r{count} if ($bodytype eq 'stars');
		} else {
			delete($sys{$$r{id64}});
		}
	}
}

warn "Looping...\n";

print make_csv('ID64','EDSM ID','System',"Total Bodies <= $ls Ls","Stars <= $ls Ls","Planets <= $ls Ls",'Coord_x','Coord_y','Coord_z','RegionID')."\r\n";

my $count = 0;
foreach my $id (sort {$sys{$a}{n} cmp $sys{$b}{n}} keys %sys) {

	my %cmdrs = ();
	next if ($sys{$id}{n} eq 'Delphi');
	next if ($sys{$id}{n} eq 'Delkar');
	next if ($sys{$id}{n} !~ /\s+[A-Z][A-Z]\-[A-Z]\s+/);	# Skip if not proc-gen

	next if ($sys{$id}{p}+$sys{$id}{s} < $min_bodies);

	print make_csv($id,$sys{$id}{e},$sys{$id}{n},$sys{$id}{p}+$sys{$id}{s},$sys{$id}{s},$sys{$id}{p},$sys{$id}{x},$sys{$id}{y},$sys{$id}{z},$sys{$id}{r})."\r\n";

	delete($sys{$id});

	$count++;
}
warn "$count found\n";



