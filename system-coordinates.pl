#!/usr/bin/perl
use strict;
use lib "/home/bones/elite";
use EDSM qw(estimated_coordinates64 system_coordinates);
use ATOMS qw(btrim);

my $system = 'Sol';
$system = btrim($ARGV[0]) if (@ARGV);
$system =~ s/^\s*\!coords?(inates?)?\s+//s;
$system =~ s/\s+/ /gs;
$system =~ s/[^\w\d\-\'\,\s].*$//s;
$system = btrim($system);

if (!$system) {
	print "Must supply a system name or id64 address.\n";
	exit;
}

my ($x,$y,$z,$error) = system_coordinates($system);

if (!defined($x) || !defined($y) || !defined($z)) {
	print "[$system] System not found, and can't be estimated\n";
	exit;
}

print "[$system] Estimated Coordinates: $x, $y, $z (+/- $error ly)\n" if (defined($error));
print "[$system] Found Coordinates: $x, $y, $z\n" if (!defined($error));
