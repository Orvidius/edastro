#!/usr/bin/perl
use strict; $|=1;

############################################################################

use POSIX qw/floor/;

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(btrim epoch2date date2epoch);

############################################################################
# Start

#############################################
# settings:

my $show_dots		= 1;
my $numAntThreads	= 10;
my $numAntsPerThread	= 10;
my $iterations		= 10;
my $decayRate		= 0.9;
my $pheromoneFloor	= 0.1;
my $pheromone_deposit	= 3;

$iterations		= $ARGV[0] if ($ARGV[0] =~ /^\d+$/);
$numAntThreads		= $ARGV[1] if ($ARGV[1] =~ /^\d+$/);
$numAntsPerThread	= $ARGV[2] if ($ARGV[2] =~ /^\d+$/);

#############################################
# initialization:

my %systems		= ();
my %pheromones		= ();
my @bestPath		= ();
my $bestDistance	= 999999999999;
my $start		= 0;
my $killCount		= 0;
my $dotCount		= 0;
my @nodeName		= ();
my %nameIndex		= ();

srand(time()^($$+($$ << 15)));

#############################################
# Retrieve list, copy-pasted from EDSM:

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

		push @bestPath, $myIndex;
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
			$bestDistance = $defaultDistance;
		}

		$index++ if ($index == $myIndex);
	} else {
		print "\nSkipped line:\n$line\n\n" if ($line =~ /\S/);
	}
}
close TXT;

print "Default Distance: ".prettyNum($defaultDistance)."\n";

#############################################
# Look up coordinates in database for any that are missing:

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

#############################################
# Calculate node-node distances for all possible connections:

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

#############################################
# Iterate and find best case:

foreach my $n (keys %systems) {
	foreach my $t (keys %systems) {
		$pheromones{$n}{$t} = 1 if ($n != $t);
	}
}

update_pheromones(\@bestPath);
update_pheromones(\@bestPath);

if ($iterations) {
	for (my $group=0; $group<$iterations; $group++) {
		do_ants($group);
	} 
} else {
	my $group = 0;
	while (1) {
		do_ants($group);
		$group++;
	}
}


#############################################
# Now output the results, and exit:

print_path(0);

exit;
	
############################################################################
# FUNCTIONS
	
sub print_path {
	my $to_file = shift;
	my $fh = *STDOUT;

	if ($to_file) {
		open $fh, ">gargantuan-path.txt";
	}

	print $fh "\n\n".int(@bestPath)." total waypoints, (".prettyNum($bestDistance)." lightyears total):\n\n";
	
	my $totalDistance = 0;
	my %found = ();
	
	for(my $i=0; $i<@bestPath; $i++) {
		my $index = $bestPath[$i];
	
		$found{$index} = 1;
	
		my $d = 0;
	
		if ($i) {
			$d = $systems{$index}{distance}{$bestPath[$i-1]};
		}
		$d = 0 if (!$d);
	
		$totalDistance += $d;
	
		print $fh sprintf("%s%03u",'#',$i+1)." ($index) $nodeName[$index] == ".prettyNum($d)." lightyears, ".prettyNum($totalDistance)." total\n";
	}
	
	print $fh "\n";
	
	foreach my $index (keys %systems) {
		my $name = $nodeName[$index];
		print $fh "MISSING: $name\n" if (!$found{$index});
	}
	if ($to_file) {
		close $fh;
	}
}

sub do_ants {
	my $group = shift;
	my @bestAntPath = ();
	my $bestAntDistance = 99999999999999;
	my %targets = ();
	$killCount = 0;
	$dotCount = 0;

	print "Doing ".int($numAntsPerThread*$numAntThreads)." ants for group $group.\n";

	foreach my $t (keys %systems) {
		$targets{$t} = 1 if ($t != $start);
	}

	my @kids = ();
	foreach my $ant (0..$numAntThreads-1) {

		showDot($numAntsPerThread);

		my $pid = open $kids[$ant] => "-|";
		die "Failed to fork: $!" unless defined $pid;

		unless ($pid) {
			# Child.

			foreach my $localAnt (0..$numAntsPerThread-1) {
				my $pos = $start;
				my %choices = %targets;
				my $distance = 0;
				my @path = ($start);
				
				while (keys %choices) {
					my $nextNode = chooseNode($pos,\%choices);
		
					#print "Ant#$ant $pos -> $nextNode ($systems{$pos}{distance}{$nextNode})\n";
		
					if ($nextNode) {
						$distance += $systems{$pos}{distance}{$nextNode};
						push @path, $nextNode;
						$pos = $nextNode;
		
						delete($choices{$nextNode});
					} else {
						last;
					}
				}
				$distance += $systems{$pos}{distance}{$start};
				push @path, $start;
				my $hops = int(@path);
	
				print "$$|$distance|$hops|".join(',',@path)."\n";
			}
			exit;

		}
	}

	foreach my $fh (@kids) {
		my @lines = <$fh>;

		foreach my $line (@lines) {
			chomp $line;
			my ($hops,$distance,@path,$pid);

			if ($line =~ /^\d+/) {
				($pid,$distance,$hops,my $list) = split /\|/,$line;
				@path = split /,/, $list;
			} else {
				next;
			}

			showDot();
	
			# Global: 
	
			if ($distance < $bestDistance) {
				$bestDistance = $distance;
				@bestPath = @path;
				print "\nGLOBAL BEST: ".prettyNum($distance)." ($hops hops) : ".join(',',@path)."\n\n";
	
				print_path(1);
			}
	
			# Local:
	
			if ($distance < $bestAntDistance) {
				$bestAntDistance = $distance;
				@bestAntPath = @path;
				#print "\nLOCAL BEST: ".prettyNum($distance)." ($hops hops) : ".join(',',@path)."\n\n";
			}
		}
	}
	1 while -1 != wait;

	my $hops = int(@bestAntPath);
	update_pheromones(\@bestAntPath);
	print "\nGROUP BEST: ".prettyNum($bestAntDistance)." ($hops hops) : ".join(',',@bestAntPath)."\n\n";
}

sub update_pheromones {
	my $path = shift;

	# Modify pheromones:

	my $weakest = 999999999999999;

	foreach my $i (keys %pheromones) {
		foreach my $k (keys %{$pheromones{$i}}) {
			next if (!defined($pheromones{$i}{$k}));

			$pheromones{$i}{$k} *= $decayRate;
			$pheromones{$i}{$k} = $pheromoneFloor if ($pheromones{$i}{$k} < $pheromoneFloor);
			$weakest = $pheromones{$i}{$k} if ($pheromones{$i}{$k} < $weakest);
		}
	}

	my $highest = 0;
	my $lowest = 999999999999999;

	for (my $i=0; $i<@$path-1; $i++) {
		my $node = $$path[$i];
		my $next = $$path[$i+1];

		$pheromones{$node}{$next} += $pheromone_deposit;
		#print "Pheromone: $node-$next = $pheromones{$node}{$next}\n";

		$highest = $pheromones{$node}{$next} if ($pheromones{$node}{$next} > $highest);
		$lowest  = $pheromones{$node}{$next} if ($pheromones{$node}{$next} < $lowest );
	}

	print "\n";
	print "Pheromone HIGHEST: $highest\n";
	print "Pheromone LOWEST:  $lowest\n";
	print "Pheromone WEAKEST: $weakest\n";

}

sub chooseNode {
	my $node = shift;
	my $choices = shift;
	my $probabilitySpace = 0;
	my $maxDistance = 0;
	my $found = undef;
	#my @choice_list = sort {$a <=> $b} keys %$choices;
	my @choice_list = keys %$choices;
	my %probability = ();

	my $debug_ant = 0;

	my $mult = 1.1;

	my $out = '';

	sub nodeProbability {
		my ($node,$n,$maxDistance,$mult) = @_;
		return (($maxDistance*$mult)-$systems{$node}{distance}{$n}) * $pheromones{$node}{$n};
	}


	if (int(keys %$choices) == 1) {
		my @list = keys %$choices;
		return $list[0];
	}
	$out .= "\nChoosing from: " if ($debug_ant);
	foreach my $n (@choice_list) {
		next if ($n == $node);
		$maxDistance = $systems{$node}{distance}{$n} if ($systems{$node}{distance}{$n} > $maxDistance);
	}
	$out .= "[max distance = $maxDistance] " if ($debug_ant);
	foreach my $n (@choice_list) {
		next if ($n == $node);
		$probabilitySpace += $probability{$n} = nodeProbability($node,$n,$maxDistance,$mult);
	}
	my $random = rand()*$probabilitySpace;
	#$out .= "Max:$maxDistance, Prob:$probabilitySpace, Rand:$random\n";

	my $runningTotal = 0;

	foreach my $n (sort {$probability{$b} <=> $probability{$a}} @choice_list) {
		next if ($n == $node);
		$out .= "$n(d=".prettyNum($systems{$node}{distance}{$n})."|p=".prettyNum($probability{$n})."), " if ($debug_ant);

		if ($runningTotal <= $random && $runningTotal+$probability{$n} > $random) {
			$found = $n;
			last;
		} else {
			$runningTotal += $probability{$n};
		}
	}
	$out .= " -- CHOSE: $found (".prettyNum($random)."|".prettyNum($probabilitySpace).")\n\n" if ($debug_ant);

	warn $out if ($out);
	return $found;
}

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
	my $n = shift;
	$n = 1 if (!$n);

	$killCount+=$n;
	if ($killCount>=10) {
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


