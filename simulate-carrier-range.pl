#!/usr/bin/perl
use strict; $|=1;

my @services		= qw(refuel repair armoury redemption shipyard outfitting cartographics);
my $total_capacity	= 25000;
my $dry_mass		= 25000;
my $tank_size		= 1000;
my $jump_range		= 500;
my $min_fuel		= 5;

my %servicespace = ( 'refuel'=>500, 'repair'=>180, 'armoury'=>250, 'redemption'=>100, 'shipyard'=>3000, 'outfitting'=>1750, 'warehouse'=>250, 'cartographics'=>120);

@services = @ARGV if (@ARGV);

my $space_reserved = 0;
foreach my $s (@services) {
	$space_reserved += $servicespace{$s};
}


my $fuel = $tank_size + $total_capacity - $space_reserved;

print "\n";
print "Installed Services: ".join(', ',@services)."\n";
print "Space Reserved:     $space_reserved/$total_capacity\n";
print "Starting fuel:      $fuel (including depot tank, $tank_size)\n";
print "\n";

my $i = 0;
my $next_cost = next_cost();
my $distance = 0;
my $consumed = 0;

while ( $next_cost < $fuel ) {
	$i++;
	$fuel -= $next_cost;
	$distance += $jump_range;
	$consumed += $next_cost;
	printf("%3u: Fuel used (%u), Total consumed (%u), Fuel remaining (%u), Total distance (%u)\n",$i,$next_cost,$consumed,$fuel,$distance);
	$next_cost = next_cost();
}

sub next_cost {
	return int($min_fuel + (($fuel + $space_reserved + $total_capacity) * $jump_range / 200000) + 0.5); # Poor-man's rounding
}
