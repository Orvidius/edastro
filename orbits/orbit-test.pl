#!/usr/bin/perl
use strict; $|=1;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

use POSIX qw(floor);

############################################################################

# Settings and constants

my $verbose	= 0;

my $pi		= 3.1415926535;
my $epoch	= time;


############################################################################
# INFO:

#	https://www.narom.no/undervisningsressurser/sarepta/rocket-theory/satellite-orbits/introduction-of-the-six-basic-parameters-describing-satellite-orbits/

#	https://theskylive.com/3dsolarsystem
#	view-source:https://theskylive.com/libjs/_lib_orbits.js?v=1624047523

############################################################################

my $id64 = 10477373803; # Sol

$id64 = $ARGV[0] if (@ARGV);

my %bodies = ();

if ($id64 !~ /^\d+$/) {
	# It's actually a name

	my @rows = db_mysql('elite',"select id64 from systems where name=? and deletionState=0",[($id64)]);

	if (@rows) {
		$id64 = ${$rows[0]}{id64};
	} else {
		die "System named '$id64' not found\n";
	}
}

foreach my $table (qw(stars planets barycenters)) {
	my @rows = db_mysql('elite',"select * from $table where systemId64=? and deletionState=0",[($id64)]);
	foreach my $r (@rows) {
		$bodies{$$r{bodyId}} = $r if (defined($$r{bodyId}));
		$bodies{$$r{bodyId}}{table} = $table;
	}
}

print "Epoch: $epoch (".epoch2date($epoch).")\n";

$bodies{0}{name} = 'barycenter' if (!exists($bodies{0}));
print "[0] $bodies{0}{name}: 0,0,0\n";
$bodies{0}{local_x} = 0;
$bodies{0}{local_y} = 0;
$bodies{0}{local_z} = 0;
$bodies{0}{system_x} = 0;
$bodies{0}{system_y} = 0;
$bodies{0}{system_z} = 0;

foreach my $id (sort {$a <=> $b} keys %bodies) {
	#next if ($id != 3);	# Earth only, for now

	next if (!$id);

	$bodies{$id}{name} = 'barycenter' if ($bodies{$id}{table} eq 'barycenters');
	$bodies{$id}{name} = 'unknown' if (!$bodies{$id}{name});
	print "[$id] $bodies{$id}{name}\n" if ($verbose);

	my @parents = split /;/, $bodies{$id}{parents};
	my $parentID = undef;

	if ($parents[0] =~ /\w+:(\d+)/) {
		$parentID = $1+0;
	}

	my ($N,$i,$w,$a,$e,$M,$P) = ($bodies{$id}{ascendingNode},$bodies{$id}{orbitalInclinationDec},$bodies{$id}{argOfPeriapsisDec},$bodies{$id}{semiMajorAxisDec},
					$bodies{$id}{orbitalEccentricityDec},$bodies{$id}{meanAnomaly},$bodies{$id}{orbitalPeriodDec});

	($N,$i,$w,$a,$e,$M,$P) = ($bodies{$id}{ascendingNode},$bodies{$id}{orbitalInclination},$bodies{$id}{argOfPeriapsis},$bodies{$id}{semiMajorAxis},
					$bodies{$id}{orbitalEccentricity},$bodies{$id}{meanAnomaly},$bodies{$id}{orbitalPeriod}) if ($bodies{$id}{table} eq 'barycenters');

	$bodies{$id}{degreesPerDay} = 360/$P if ($P && !$bodies{$id}{degreesPerDay});
	$bodies{$id}{anomaly_epoch} = date2epoch($bodies{$id}{meanAnomalyDate}) if (!$bodies{$id}{anomaly_epoch});

	$M += (($epoch-$bodies{$id}{anomaly_epoch})/86400)*$bodies{$id}{degreesPerDay};
	while ($M >= 360) {
		$M -= 360;
	}

	#$e = 0.99;
	#$i = 90;

	if ($verbose) {
		print "L.Ascending Node,  N: $N\n";	# Longitude of Ascending Node
		print "Inclination,       i: $i\n";	# Inclination
		print "Arg. of Periapsis, w: $w\n";	# Argument of Periapsis
		print "Semi-Major Axis,   a: $a\n";	# Semi-Major Axis
		print "Eccentricity,      e: $e\n";	# Eccentricity
		print "Mean Anomaly,      M: $M\n";	# Mean Anomaly
		print "Anomaly Epoch:        $bodies{$id}{anomaly_epoch}\n";
		print "Period,            P: $P\n";	# Period (days)
		print "Periapsis Epoch:      ".($bodies{$id}{anomaly_epoch}-$P*$M/360)."\n";
		print "Degrees per day:      $bodies{$id}{degreesPerDay}\n";
	}

	print "\n" if ($verbose);

	my $E = EccentricAnomaly($e,$M);
	print "M $M, E: $E, " if ($verbose);	# Eccentric Anomaly

	# Coordinates within its own orbital plane, relative to parent:
	my $xv = $a * (cos($E*$pi/180) - $e);
	my $yv = $a * (sqrt(1 - $e**2) * sin($E*$pi/180));

	my $v = atan2($xv,$yv)*180/$pi;	# True anomaly in radians
	my $r = sqrt($xv**2 + $yv**2);	# Current "radius" distance from body to parent.

	print "Radius: $r, Coords: $xv, $yv: " if ($verbose);	# Radius and coordinates within its own plane, relative to parent

	my $cosN  = cos($pi*$N/180);
	my $sinN  = sin($pi*$N/180);
	my $cosi  = cos($pi*$i/180);
	my $sini  = sin($pi*$i/180);
	my $cosvw = cos($pi*($v+$w)/180);
	my $sinvw = sin($pi*($v+$w)/180);

	# 3D coordinates relative to parent:
	my $x = $r * ($cosN*$cosvw - $sinN*$sinvw*$cosi);
	my $y = $r * ($sinN*$cosvw + $cosN*$sinvw*$cosi);
	my $z = $r * $sinvw * $sini;

	print "($x, $y, $z)\n" if ($verbose);	# 3D coordinates relative to parent

	$bodies{$id}{local_x} = $x;
	$bodies{$id}{local_y} = $y;
	$bodies{$id}{local_z} = $z;
	#print "[$id]($parentID) $bodies{$id}{name}: (local) $bodies{$id}{local_x}, $bodies{$id}{local_y}, $bodies{$id}{local_z}\n" if (!$verbose);

	if (defined($parentID) && defined($bodies{$parentID}{system_x})) {
		$bodies{$id}{system_x} = $bodies{$parentID}{system_x} + $x;
		$bodies{$id}{system_y} = $bodies{$parentID}{system_y} + $y;
		$bodies{$id}{system_z} = $bodies{$parentID}{system_z} + $z;

		printf("[$id]($parentID) $bodies{$id}{name} %.05f, %.05f, %.05f\n", $bodies{$id}{system_x}, $bodies{$id}{system_y}, $bodies{$id}{system_z}) if (!$verbose);
	} else {
		print "[$id]($parentID) $bodies{$id}{name} Missing parent!\n";
	}

	print "\n" if ($verbose);
}

sub EccentricAnomaly {
	my $e = shift;		# Orbital Eccentricity
	my $M = shift;		# Mean Anomaly (degrees)
	my $Mrad = $pi*$M/180;	# Mean Anomaly in Radians

	my $E = $M + ($e * sin($Mrad) * (1 + ($e * cos($Mrad))));
	my $error = 1;

	while ($error >= 0.00001) {
		my $F = $E - ($E - (sin($E*$pi/180) * $e * 180/$pi) - $M) / (1 - $e * cos($E*$pi/180));
		$error = abs($F-$E);
		$E = $F;
	}

# From javascript example: view-source:https://theskylive.com/libjs/_lib_orbits.js?v=1624047523
#
#var E = M + (e * Angle.SinDeg(M) * (1.0 + (e * Angle.CosDeg(M))));
#for(;;) {
#var F = E - (E - (Angle.DEG_FROM_RAD * e * Angle.SinDeg (E)) - M) / (1 - e * Angle.CosDeg (E));
#var error = Math.abs (F - E);
#E = F;
#if (error < 1.0e-5) {
#break;  // the angle is good enough now for our purposes
#}

	return $E;
}

