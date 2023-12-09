#!/usr/bin/perl
use strict; $|=1;

############################################################################

use POSIX qw/floor/;

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(btrim epoch2date date2epoch);

############################################################################

my $show_dots = 1;

my %systems = ();
my $start = 0;
my @finalList = ();
my $finalDistance = 999999999;
my $killCount = 0;
my $dotCount = 0;
my @nodeName = ();
my %nameIndex = ();


#1      Egnaix GW-V e2-0        6124.28125 / 2296.15625 / 22529.3125 
#2      Egnaix XJ-Z e30 (Heliotropeia Monoceratos)      6005.9375 / 2226.5625 / 22287.1875      278.34 Ly 


my $defaultDistance = 0;
my $index = 0;

open TXT, "<gargantuan.list";
while (my $line = <TXT>) {
	chomp;
	my @var = split /\t/, $line;

	if ($var[1]) {
		my $name = btrim($var[1]);

		my $myIndex = $index;

		if (defined($nameIndex{$name})) {
			$myIndex = $nameIndex{$name};
		}

		push @finalList, $myIndex;
		$nodeName[$myIndex] = $name;
		$nameIndex{$name} = $myIndex;

		if ($var[2] =~ /([\-\d\.]+)[\s\/]+([\-\d\.]+)[\s\/]+([\-\d\.]+)/) {
			$systems{$myIndex}{x} = $1;
			$systems{$myIndex}{y} = $2;
			$systems{$myIndex}{z} = $3;
		} else {
			print "\nCouldn't interpret line:\n$line\n\n";
		}

		if ($var[3] =~ /([\d\.\,]+)/) {
			my $ly = $1;
			$ly =~ s/,//g;
			$defaultDistance += $ly;
			$finalDistance = $defaultDistance;
		}

		$index++ if ($index == $myIndex);
	} else {
		print "\nSkipped line:\n$line\n\n" if ($line =~ /\S/);
	}
}
close TXT;

print "Default Distance: ".prettyNum($defaultDistance)."\n";

my @list = ();
my $qs   = '';

foreach my $index (keys %systems) {
	$qs .= ",?";
	if (!$systems{$index}{x} && !$systems{$index}{y} && !$systems{$index}{z}) {
		push @list, $nodeName[$index];
		delete($systems{$index});
	}
}
$qs =~ s/^,//;


my @rows = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where name in ($qs)",[(@list)]);
foreach my $r (@rows) {
	$systems{$nameIndex{$$r{name}}}{x} = $$r{coord_x};
	$systems{$nameIndex{$$r{name}}}{y} = $$r{coord_y};
	$systems{$nameIndex{$$r{name}}}{z} = $$r{coord_z};
}

foreach my $index (sort {$a <=> $b} keys %systems) {
	foreach my $target (sort {$a <=> $b} keys %systems) {
		next if ($target == $index);
		next if ($systems{$index}{distance}{$target});

		$systems{$index}{distance}{$target} = distance($systems{$index}{x},$systems{$index}{y},$systems{$index}{z},
			$systems{$target}{x},$systems{$target}{y},$systems{$target}{z});

		$systems{$target}{distance}{$index} = $systems{$index}{distance}{$target};

		$systems{$target}{weight}{$index} = floor($systems{$index}{distance}{$target}/10);
		$systems{$index}{weight}{$target} = floor($systems{$index}{distance}{$target}/10);

		print "Distance: $index \[$nodeName[$index]\] ($systems{$index}{x},$systems{$index}{y},$systems{$index}{z}) <-> ".
			"$target ($systems{$target}{x},$systems{$target}{y},$systems{$target}{z}) = $systems{$index}{distance}{$target} ".
			"(weight: $systems{$index}{weight}{$target})\n";
	}

	@{$systems{$index}{targetList}} = sort {$systems{$index}{distance}{$a} <=> $systems{$index}{distance}{$b}} keys %systems;
	#splice @{$systems{$index}{targetList}}, int(@{$systems{$index}{targetList}}/5);
}
print "\n";

my $swaps = 1;
my $loops = 0;
while ($swaps && $loops<10) {
	$swaps = 0;
	for (my $i=1; $i<@finalList-1; $i++) {
		for (my $k=1; $k<@finalList-1; $k++) {
			next if ($i == $k);
			my $swap = 0;
	
			my $current   = $systems{$finalList[$i]}{distance}{$finalList[$i-1]} + $systems{$finalList[$i]}{distance}{$finalList[$i+1]} +
					$systems{$finalList[$k]}{distance}{$finalList[$k-1]} + $systems{$finalList[$k]}{distance}{$finalList[$k+1]};
	
			my $potential = $systems{$finalList[$k]}{distance}{$finalList[$i-1]} + $systems{$finalList[$k]}{distance}{$finalList[$i+1]} +
					$systems{$finalList[$i]}{distance}{$finalList[$k-1]} + $systems{$finalList[$i]}{distance}{$finalList[$k+1]};
	
			$swap = 1 if ($potential < $current);
	
			if ($swap) {
				print "SWAP: ($finalList[$i]) $nodeName[$finalList[$i]] <-> ($finalList[$k]) $nodeName[$finalList[$k]]\n";
				($finalList[$i],$finalList[$k]) = ($finalList[$k],$finalList[$i]);
				$swaps++;
			}
		}
	}
	$loops++;
}

print "\n\n".int(@finalList)." total waypoints, (".prettyNum($finalDistance)." lightyears total):\n\n";

my $totalDistance = 0;

my %found = ();

for(my $i=0; $i<@finalList; $i++) {
	my $index = $finalList[$i];

	$found{$index} = 1;

	my $d = 0;

	if ($i) {
		$d = $systems{$index}{distance}{$finalList[$i-1]};
	}
	$d = 0 if (!$d);

	$totalDistance += $d;

	print sprintf("%s%03u",'#',$i+1)." ($index) $nodeName[$index] == ".prettyNum($d)." lightyears, ".prettyNum($totalDistance)." total\n";
}

print "\n";

foreach my $index (keys %systems) {
	my $name = $nodeName[$index];
	print "MISSING: $name\n" if (!$found{$index});
}


exit;
############################################################################


sub verifyPath {
	my $path = shift;
	my %found = ();
	my $ok = 1;

	foreach my $node (@$path) {
		$found{$node} = 1;
	}
	foreach my $node (keys %systems) {
		$ok = 0 if (!$found{$node}); 
	}

	return $ok;
	
}

sub showDot {
	$killCount++;
	if ($killCount>=10000) {
		print '.';
		$killCount = 0;
		$dotCount++;

		if ($dotCount>=100) {
			print "\n";
			$dotCount = 0;
		}
	}
	return;
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


