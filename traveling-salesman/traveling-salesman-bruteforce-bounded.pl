#!/usr/bin/perl
use strict; $|=1;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(btrim epoch2date date2epoch);

############################################################################

my $show_dots = 1;

my %systems = ();
my $start = "";
my @finalList = ();
my $finalDistance = 999999999;
my $killCount = 0;


#1      Egnaix GW-V e2-0        6124.28125 / 2296.15625 / 22529.3125 
#2      Egnaix XJ-Z e30 (Heliotropeia Monoceratos)      6005.9375 / 2226.5625 / 22287.1875      278.34 Ly 


my $defaultDistance = 0;

open TXT, "<gargantuan.txt";
while (<TXT>) {
	chomp;
	my @var = split /\t/, $_;

	if ($var[1]) {
		my $name = btrim($var[1]);
		$start = $name if (!$start);

		push @finalList, $name;

		if ($var[2] =~ /([\-\d\.]+)[\s\/]+([\-\d\.]+)[\s\/]+([\-\d\.]+)/) {
			$systems{$name}{x} = $1;
			$systems{$name}{y} = $2;
			$systems{$name}{z} = $3;
		}

		if ($var[3] =~ /([\d\.\,]+)/) {
			my $ly = $1;
			$ly =~ s/,//g;
			$defaultDistance += $ly;
			$finalDistance = $defaultDistance;
		}
	}
}
close TXT;

print "Default Distance: ".prettyNum($defaultDistance)."\n";

my @list = ();
my $qs   = '';

foreach my $name (keys %systems) {
	$qs .= ",?";
	if (!$systems{$name}{x} && !$systems{$name}{y} && !$systems{$name}{z}) {
		push @list, $name;
		delete($systems{$name});
	}
}
$qs =~ s/^,//;


my @rows = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where name in ($qs)",[(@list)]);
foreach my $r (@rows) {
	$systems{$$r{name}}{x} = $$r{coord_x};
	$systems{$$r{name}}{y} = $$r{coord_y};
	$systems{$$r{name}}{z} = $$r{coord_z};
}

foreach my $name (keys %systems) {
	foreach my $target (keys %systems) {
		next if ($target eq $name);
		next if ($systems{$name}{distance}{$target});

		$systems{$name}{distance}{$target} = distance($systems{$name}{x},$systems{$name}{y},$systems{$name}{z},
			$systems{$target}{x},$systems{$target}{y},$systems{$target}{z});

		$systems{$target}{distance}{$name} = $systems{$name}{distance}{$target};

		print "Distance: $name ($systems{$name}{x},$systems{$name}{y},$systems{$name}{z}) <-> ".
			"$target ($systems{$target}{x},$systems{$target}{y},$systems{$target}{z}) = $systems{$name}{distance}{$target}\n";
	}

	@{$systems{$name}{targetList}} = sort {$systems{$name}{distance}{$a} <=> $systems{$name}{distance}{$b}} keys %systems;
}
print "\n";


recurseAll(0,$start,0);

print "\n\n".int(@finalList)." total waypoints, (".prettyNum($finalDistance)." lightyears total):\n\n";

my $totalDistance = 0;

my %found = ();

for(my $i=0; $i<@finalList; $i++) {
	$found{$finalList[$i]} = 1;

	my $d = 0;

	if ($i) {
		$d = $systems{$finalList[$i]}{distance}{$finalList[$i-1]};
	}
	$d = 0 if (!$d);

	$totalDistance += $d;

	print sprintf("%s%03u",'#',$i+1)." $finalList[$i] == ".prettyNum($d)." lightyears, ".prettyNum($totalDistance)." total\n";
}

print "\n";

foreach my $name (keys %systems) {
	print "MISSING: $name\n" if (!$found{$name});
}


exit;
############################################################################

sub recurseAll {
	my $depth = shift;
	my $node = shift;
	my $totalDistance = shift;
	my @pathTaken = @_;
	my %visited = ();

	if ($show_dots && $totalDistance > $finalDistance) {
		# Kill this path.
		$killCount++;
		if ($killCount>=10000) {
			print '.';
			$killCount = 0;
		}
		return;
	}

	my @list = ();

	foreach my $prevNode (@pathTaken) {
		$visited{$prevNode} = 1;
	}

	# Recurse over all potential child nodes:

	my $count = 0;
	foreach my $child (@{$systems{$node}{targetList}}) {
		next if ($visited{$child});

		print "\n[".epoch2date(time)."] Trying: [$depth]: $node / $child\n" if ($depth<40);

		recurseAll($depth+1,$child,$totalDistance+$systems{$node}{distance}{$child},@pathTaken,$child);
		$count++;
	}

	if (!$count) {
		my $pathDistance = $totalDistance+$systems{$node}{distance}{$start};
		if ($pathDistance < $finalDistance) {
			$finalDistance = $pathDistance;
			@finalList = (@pathTaken,$start);
			print "\n[".epoch2date(time)."] NEW PATH: (".prettyNum($finalDistance).") ".join(', ',@finalList)."\n\n";

			open TXT, ">gargantuan-path.txt";
			print TXT "Distance: ".prettyNum($finalDistance)."\n".join("\n",@finalList)."\n";
			close TXT;
			
		}
	}
}

sub distance {
	my ($x1, $y1, $z1, $x2, $y2, $z2) = @_;
	return ( (($x1-$x2)**2) + (($y1-$y2)**2) + (($z1-$z2)**2) ) ** 0.5;
}

sub commify {
	my $text = reverse $_[0];
	$text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
	return scalar reverse $text
}

sub prettyNum {
	my $n = shift;

	if ($n != int($n)) {
		$n = sprintf("%0.02f",$n);
	}

	return commify($n);
}

############################################################################


