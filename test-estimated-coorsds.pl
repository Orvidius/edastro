#!/usr/bin/perl
use strict;
use lib "/home/bones/elite";
use EDSM qw(estimated_coordinates64 system_coordinates);

my $id64 = 10477373803;

$id64 = $ARGV[0] if (@ARGV);

#my ($x,$y,$z,$error,$bx,$by,$bz) = estimated_coordinates64($id64);
#print "[$id64] Estimated Coordinates: $x, $y, $z (+/- $error ly), within sector: $bx, $by, $bz (+/- $error ly).\n";


my ($x,$y,$z,$error) = system_coordinates($id64);
print "[$id64] Estimated Coordinates: $x, $y, $z (+/- $error ly)\n" if (defined($error));
print "[$id64] Found Coordinates: $x, $y, $z\n" if (!defined($error));
