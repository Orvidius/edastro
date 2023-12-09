#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

use Image::Magick;
use POSIX qw(floor);

############################################################################

my $infinity		= 0xFFFFFFFFFF;

my $start 		= 'Sol';	# 'Myeadai MI-Q d6-1';
my $dest  		= 'Diaguandri';	# 'BD+46 1067';
my $jump  		= 42;
my $allow_ns		= 1;
my $allow_jumponium	= 1;
my $use_goaldistance	= 0;	# 1 = goal distance alone, 2 = hybrid, 0 = distance from start

############################################################################

my $totalEpoch = time;

$jump  = $ARGV[0] if ($ARGV[0]);
$start = $ARGV[1] if ($ARGV[1]);
$dest  = $ARGV[2] if ($ARGV[2]);
$allow_ns = $ARGV[3] if (defined($ARGV[3]));
$allow_jumponium = $ARGV[4] if (defined($ARGV[4]));

my %sys = ();		# Unchanging system data
my %name2num = ();	# Get ID number from name
my %unvisited = ();	# Unvisited systems and their tentative distance
my %available = ();	# Unvisited systems, short list of those with tentative distances
my %visited = ();	# Visited systems and their best distance
my %from = ();		# Node associated with shortest distances at each node
my %neutron = ();	# Node system contains neutron stars, boolean
my %coords = ();	# Coordinates for start and destination systems
my %dist2goal = ();	# Distance to goal, from each system

my $startID = undef;
my $destID  = undef;

my @rows = db_mysql('elite',"select edsm_id,name,coord_x,coord_y,coord_z from systems where name in ('$start','$dest') and coord_x is not null and coord_y is not null and coord_z is not null");
foreach my $r (@rows) {
	foreach my $axis (qw(x y z)) {
		$coords{$$r{edsm_id}}{$axis} = $$r{"coord_$axis"};
		$coords{$$r{edsm_id}}{"diff_$axis"} = 0 - $coords{$$r{edsm_id}}{$axis};	# flip sign
		$coords{$$r{edsm_id}}{"diff_$axis"} = '+'.$coords{$$r{edsm_id}}{"diff_$axis"} if ($coords{$$r{edsm_id}}{"diff_$axis"} > 0);
	}

	$startID = $$r{edsm_id} if (uc($$r{name}) eq uc($start));
	$destID  = $$r{edsm_id} if (uc($$r{name}) eq uc($dest));
}

die "Start system \"$start\" not found.\n" if (!$startID);
die "Destination system \"$dest\" not found.\n" if (!$destID);

my $range_x = abs($coords{$startID}{x}-$coords{$destID}{x});
my $range_y = abs($coords{$startID}{y}-$coords{$destID}{y});
my $range_z = abs($coords{$startID}{z}-$coords{$destID}{z});

my $long_axis = 'x';
$long_axis = 'z' if ($range_z >= $range_x && $range_z >= $range_y);
$long_axis = 'y' if ($range_y >= $range_x && $range_y >= $range_z);

my $min = undef;
my $max = undef;

if ($coords{$startID}{$long_axis} < $coords{$destID}{$long_axis}) {
	$min = $coords{$startID}{$long_axis};
	$max = $coords{$destID}{$long_axis};
} else {
	$max = $coords{$startID}{$long_axis};
	$min = $coords{$destID}{$long_axis};
}

my %minCoord = ();
my %maxCoord = ();

foreach my $c (qw(x y z)) {
	if ($coords{$startID}{$c} < $coords{$destID}{$c}) {
		$minCoord{$c} = $coords{$startID}{$c};
		$maxCoord{$c} = $coords{$destID}{$c};
	} else {
		$maxCoord{$c} = $coords{$startID}{$c};
		$minCoord{$c} = $coords{$destID}{$c};
	}
}

#my @rows = db_mysql('elite',"select edsm_id,name,coord_x,coord_y,coord_z,(select count(*) from stars where systemId=systems.edsm_id and subType='Neutron star') as NS from systems where abs(coord_x)<150 and abs(coord_y)<150 and abs(coord_z)<150");

my $sqldist = "abs(sqrt(pow(coord_x $coords{$startID}{diff_x},2)+pow(coord_y $coords{$startID}{diff_y},2)+pow(coord_z $coords{$startID}{diff_z},2)) * sqrt(pow(coord_x $coords{$destID}{diff_x},2)+pow(coord_y $coords{$destID}{diff_y},2)+pow(coord_z $coords{$destID}{diff_z},2))) / abs(sqrt(pow($coords{$destID}{x} $coords{$startID}{diff_x},2)+pow($coords{$destID}{y} $coords{$startID}{diff_y},2)+pow($coords{$destID}{z} $coords{$startID}{diff_z},2)))<500 and coord_$long_axis>=$min-500 and coord_$long_axis<$max+500";

$sqldist = "coord_x>$minCoord{x}-300 and coord_x<$maxCoord{x}+300 and coord_y>$minCoord{y}-300 and coord_y<$maxCoord{y}+300 and coord_z>$minCoord{z}-300 and coord_z<$maxCoord{z}+300";

my @rows = db_mysql('elite',"select edsm_id,name,coord_x,coord_y,coord_z,(select count(*) from stars where systemId=systems.edsm_id and subType='Neutron star') as NS from systems where coord_x is not null and coord_y is not null and coord_z is not null and $sqldist");

print int(@rows)." systems pulled.\n";
while (@rows) {
	my $r = shift @rows;
	$sys{$$r{edsm_id}}{x} = $$r{coord_x};
	$sys{$$r{edsm_id}}{y} = $$r{coord_y};
	$sys{$$r{edsm_id}}{z} = $$r{coord_z};
	$sys{$$r{edsm_id}}{n} = $$r{name};
	$neutron{$$r{edsm_id}} = 1 if ($$r{NS});
	$name2num{uc($$r{name})}  = $$r{edsm_id};
	$unvisited{$$r{edsm_id}} = $infinity; # infinite, effectively
	$dist2goal{$$r{edsm_id}} = sqrt(($$r{coord_x}-$coords{$destID}{x})**2 + ($$r{coord_y}-$coords{$destID}{y})**2 + ($$r{coord_z}-$coords{$destID}{z})**2);
}

die "Start system \"$start\" not in data set.\n" if (!$name2num{uc($start)});
die "Destination system \"$dest\" not in data set.\n" if (!$name2num{uc($dest)});

my $startEpoch = time;
my $travel_distance = node_dist($destID,$startID);

$unvisited{$startID} = 0;

my $done  = 0;
my $cur   = $startID;

while (!$done && keys %unvisited && $cur != $destID) {

	my $positional_distance = node_dist($cur,$startID)+node_dist($cur,$destID);

#	#if ($positional_distance > $travel_distance*1.5 || $positional_distance > $travel_distance+500) {
#	if ($positional_distance > $travel_distance+500) {
#		print "$sys{$cur}{n} is too far off the path. $positional_distance / $travel_distance\n";
#		delete($unvisited{$cur});
#	} else {

		my $neighbors = unvisited_neighbors($cur);

		print "$sys{$cur}{n} has ".int(keys %$neighbors)." neighbors.\n";

		foreach my $n (keys %$neighbors) {
			my $d = $unvisited{$cur} + $$neighbors{$n};
	
			if ($d < $unvisited{$n}) {
				$unvisited{$n} = $d;
				$available{$n} = $d;
				$from{$n} = $cur;
			}
		}
	
		$visited{$cur} = $unvisited{$cur};
		delete($unvisited{$cur});
		delete($available{$cur});
#	}

	$done = 1 if ($cur == $destID);
	$done = 1 if (!keys(%unvisited));

	if (!$done) {
		#$cur = (sort {$unvisited{$a} cmp $unvisited{$b}} keys %unvisited)[0];
		my $d = $infinity;
		my $next = undef;
		foreach my $n (keys %available) {
			next if ($unvisited{$n} == $infinity);

			if ($use_goaldistance == 2) {
				if ($dist2goal{$n}+$unvisited{$n} < $d) {
					$next = $n;
					$d = $dist2goal{$n}+$unvisited{$n};
				}
			} elsif ($use_goaldistance) {
				if ($dist2goal{$n} < $d) {
					$next = $n;
					$d = $dist2goal{$n};
				}
			} else {
				if ($unvisited{$n} < $d) {
					$next = $n;
					$d = $unvisited{$n};
				}
			}
		}
		$cur = $next if (defined($next));
		die "No route possible\n" if ($d == $infinity || !defined($next));
	}
}

if ($cur == $destID) {

	print "\nRoute found:\n\n";

	my @list = ();
	my $done = 0;
	my $n = $destID;

	while (!$done) {
		push @list, $n;
		if ($from{$n}) {
			$n = $from{$n};
		} else {
			$done = 1;
		}
	}

	my $prev = $startID;
	my $count = 0;
	my $total = 0;
	foreach my $n (reverse @list) {
		my $d = node_dist($n,$prev);
		$total += $d;
		$d = sprintf("%.02f",$d);

		my $how = '';

		if ($n == $startID) {
			$how = '[start]';
		} elsif ($allow_ns && $neutron{$prev} && $d > $jump) {
			$how = '[neutron supercharge jump]';
		} elsif ($allow_jumponium && $d > $jump) {
			$how = '[jumponium injection jump]';
		}

		if ($neutron{$n}) {
			$how .= " NS";
		}

		$how =~ s/\s+/ /gs;
		$how =~ s/^\s+//;

		print "$count. $sys{$n}{n} ($d ly) $how\n";
		$count++; 
		$prev = $n;
	}
	$count-- if ($count);

	$total = sprintf("%.02f",$total);
	my $travel = sprintf("%.02f",$travel_distance);
	print "\n$count jumps, $total lightyears ($travel ly direct distance).\n";
} else {
	die "Route not possible.\n";
}

print "Completed in ".(time-$startEpoch)." seconds, ".(time-$totalEpoch)." seconds total.\n";

exit;
############################################################################

sub unvisited_neighbors {
	my $id = shift;
	my %hash = ();

	foreach my $k (keys %unvisited) {
		my $d = node_dist($id,$k);
		next if ($d > $jump*4 || $k == $id);

		if ($allow_ns && $neutron{$id} && $d>$jump && $d/4<$jump) {
			$hash{$k} = $d/5;
		} elsif ($d <= $jump) { 
			$hash{$k} = $d;
		} elsif ($allow_jumponium && $d <= $jump*2) {
			$hash{$k} = $d*8;
		}
	}

	return \%hash;
}

sub node_dist {
	my ($id1, $id2) = @_;
	return sqrt(($sys{$id1}{x}-$sys{$id2}{x})**2 + ($sys{$id1}{y}-$sys{$id2}{y})**2 + ($sys{$id1}{z}-$sys{$id2}{z})**2);
}

sub dist {
	my ($x1,$y1,$z1, $x2,$y2,$z2) = @_;
	return sqrt(($x1-$x2)**2 + ($y1-$y2)**2 + ($z1-$z2)**2);
}

############################################################################

