#!/usr/bin/perl
use strict;
use lib "/home/bones/elite";
use EDSM qw(estimated_coordinates64 system_coordinates commify completion_report);
use DB qw(db_mysql);
use ATOMS qw(btrim);

###########################################################################

if (!@ARGV) {
	print "No command!\n";
	exit;
}

my $cmd = $ARGV[0];

#$cmd = "!$cmd" if ($cmd =~ /^(help|carrier|station|coord|dist|brain)/);

if ($cmd =~ /^\s*!help(\s*)$/) {
	print "EDAstro Bot usage:

!distance <system1> : <system2>
!coordinates <system>
!station <system>
!carrier <system>
!carrier <system> <service>
!braincheck <system>
!complete <system>
!help

In each case, you can use either a system's name, or its ID64 address, if known. If the system doesn't exist in the database, but the name/id64 is in a valid format for a procedurally generated system, it will estimate the coordinates.

The commands \"!station\" and \"!carrier\" find the closest of those to the system specified. The carrier search can optionally search for a specific service.

Valid carrier services: repair, rearm, refuel, armory/armoury, outfitting, shipyard, uc, redemption.

The distance/coordinates commands have short forms as well, such as \"!dist\" and \"!coords\".

The \"!complete\" command generates a completion report for the boxel that the system belongs to. Can also invoke as \"!completion\".
";
} elsif ($cmd =~ /^\s*!(complete|completion)\s+(\S+.*\S+)\s*$/i) {
	my $system = system_name($2);
	my %hash = completion_report($system);

	if ($hash{error}) {
		print "Error: $hash{error}\n";
	} else {

		#my $out = sprintf("%-24s MinSysCount: %u\n","$hash{sector} [$hash{boxel}]",$hash{highest});
		my $out = "$hash{sector} [$hash{boxel}]  MinSysCount: $hash{highest}\n";
		foreach my $type (qw(complete incomplete unknown missing)) {
	
			$out .= " -> ".sprintf("%12s","{".ucfirst($type)."}")." ";
			my $found = 0;
	
			if ($hash{$type} && ref($hash{$type}) eq 'ARRAY' && @{$hash{$type}}) {
				for (my $i=0; $i<@{$hash{$type}}; $i++) {
					if ($i == int(@{$hash{$type}})-1 || ${$hash{$type}}[$i+1] > ${$hash{$type}}[$i]+1) {
						# Single item, include it:
		
						$out .= "," if ($found);
						$out .= ${$hash{$type}}[$i];
						$found++;
					} else {
						# Found a range, let's do that:
		
						my $end = ${$hash{$type}}[$i];
		
						for (my $k=$i+1; $k<@{$hash{$type}}; $k++) {
							if ($k == int(@{$hash{$type}})-1 || ${$hash{$type}}[$k+1] > ${$hash{$type}}[$k]+1) {
								# Reached the end

								my $sep = ${$hash{$type}}[$k]==${$hash{$type}}[$i]+1 ? ',' : '-';
		
								$out .= "," if ($found);
								$out .= ${$hash{$type}}[$i].$sep.${$hash{$type}}[$k];
								$i=$k;
								$found++;
								last;
							}
						}
					}
				}
			}
			$out .= "\n";
		}
		print "```$out```\n";
	}

} elsif ($cmd =~ /^\s*!brain(check|tree|trees)?\s+(\S+.*\S+)\s*$/i) {
	my $system = system_name($2);

	if (!$system) {
		print "No system name or ID64 address given.\n";
		exit;
	}

	my ($x,$y,$z,$error) = system_coordinates($system);

	if (!valid_coords($x,$y,$z)) {
		print "[$system] System not found, and can't be estimated\n";
		exit;
	}

	my @rows = db_mysql('elite',"select systems.name,coord_x,coord_y,coord_z,sqrt(pow(coord_x-?,2)+pow(coord_y-?,2)+pow(coord_z-?,2)) as distance from codex_edsm,systems ".
				"where isBrainTree=1 and id64=systemId64 and coord_x is not null and coord_y is not null and coord_z is not null ".
				"and systems.deletionState=0 and (codex_edsm.deletionState=0 or codex_edsm.deletionState is null) order by distance limit 1",[($x,$y,$z)]);

	if (@rows) {
		my $r = shift @rows;
		$$r{distance} = sprintf("%.02f",$$r{distance}) if ($$r{distance} =~ /\.\d{3,}/);
		print "[$system] Nearest 'Brain Tree' codex location: $$r{distance} ly (estimated) : $$r{name} ($$r{coord_x}, $$r{coord_y}, $$r{coord_z})\n" if (defined($error));
		print "[$system] Nearest 'Brain Tree' codex location: $$r{distance} ly : $$r{name} ($$r{coord_x}, $$r{coord_y}, $$r{coord_z})\n" if (!defined($error));
	} else {
		print "[$system] No brain trees located in codex.\n";
	}

	foreach my $zonecheck ('Hen 2-333','Gamma Velorum') {
		my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z,sqrt(pow(coord_x-?,2)+pow(coord_y-?,2)+pow(coord_z-?,2)) as distance from systems ".
				"where name=? and deletionState=0",[($x,$y,$z,$zonecheck)]);
		if (@rows) {
			my $r = shift @rows;
			$$r{distance} = sprintf("%.02f",$$r{distance}) if ($$r{distance} =~ /\.\d{3,}/);
			if ($$r{distance}<=750) {
				print "[$system] Within 750 ly of '$zonecheck' ($$r{distance} ly)\n";
			}
		}
	}

	#print "[$system] Estimated Coordinates: $x, $y, $z (+/- $error ly)\n" if (defined($error));
	#print "[$system] Found Coordinates: $x, $y, $z\n" if (!defined($error));


} elsif ($cmd =~ /^\s*!coords?(inates?)?\s+(\S+.*\S+)\s*$/i) {
	my $system = system_name($2);

	if (!$system) {
		print "No system name or ID64 address given.\n";
		exit;
	}

	my ($x,$y,$z,$error) = system_coordinates($system);

	if (!valid_coords($x,$y,$z)) {
		print "[$system] System not found, and can't be estimated\n";
		exit;
	}

	print "[$system] Estimated Coordinates: $x, $y, $z (+/- $error ly)\n" if (defined($error));
	print "[$system] Found Coordinates: $x, $y, $z\n" if (!defined($error));

} elsif ($cmd =~ /^\s*!dist(ance?)?\s+(\S+.*\S+)\s*$/i) {
	my ($sys1,$sys2) = split /\s+:\s+/, uc($2);
	$sys1 = system_name($sys1);
	$sys2 = system_name($sys2);

	my ($x1,$y1,$z1,$e1) = system_coordinates($sys1);
	my ($x2,$y2,$z2,$e2) = system_coordinates($sys2);

	my $estimated = 0; $estimated = 1 if (defined($e1) || defined($e2));
	my $error = $e1 + $e2;

	if (!valid_coords($x1,$y1,$z1)) {
		print "[$sys1] System not found, and can't be estimated\n";
		exit;
	} 

	if (!valid_coords($x2,$y2,$z2)) {
		print "[$sys2] System not found, and can't be estimated\n";
		exit;
	} 

	my $distance = sprintf("%.02f",sqrt(($x1-$x2)**2 + ($y1-$y2)**2 + ($z1-$z2)**2));
	$distance =~ s/\.00$//;

	print "[$sys1, $sys2] Estimated distance: ".commify($distance).", +/- $error ly\n" if ($estimated);
	print "[$sys1, $sys2] Calculated distance: ".commify($distance)."ly \n" if (!$estimated);

} elsif ($cmd =~ /^\s*!stations?\s+(\S+.*\S+)\s*$/i) {
	my $system = system_name($1);

	my ($x,$y,$z,$error) = system_coordinates($system);

	if (valid_coords($x,$y,$z)) {
		my @rows = db_mysql('elite',"select stations.name stationName,type,systems.name systemName,coord_x,coord_y,coord_z from stations,systems ".
					"where stations.systemId64=systems.id64 and type!='Fleet Carrier' and ".
					"systems.coord_x is not null and systems.coord_y is not null and systems.coord_z is not null order by ".
					"sqrt(pow(coord_x-?,2)+pow(coord_y-?,2)+pow(coord_z-?,2)) limit 1",[($x,$y,$z)]);

		if (@rows) {
			my $r = shift @rows;
			my $distance = sprintf("%.02f",sqrt(($x-$$r{coord_x})**2 + ($y-$$r{coord_y})**2 + ($z-$$r{coord_z})**2));
			$distance =~ s/\.00$//;
			print "[$system] Nearest station: $$r{stationName} [$$r{type}], $$r{systemName} ($distance ly) $$r{coord_x}, $$r{coord_y}, $$r{coord_z}\n";
		} else {
			print "No stations found.\n";
		}
	} else {
		print "Unknown system: $system\n";
		exit;
	}

} elsif ($cmd =~ /^\s*!carrier?\s+(\S+.*\S+)\s*$/i) {
	my $system = system_name($1);
	my @w = split /\s+/, btrim($system);
	my $service = lc(pop(@w));

	if ($service =~ /^(uc|exploration|outfitting|outfit|redemption|rearm|armory|armoury|repair|refuel|shipyard|voucherredemption)$/) {
		$system = system_name(join(' ',@w));
	} else {
		$service = undef;
	}

	$service = 'exploration' if ($service eq 'uc');
	$service = 'outfitting' if ($service eq 'outfit');
	$service = 'voucherredemption' if ($service eq 'redemption');
	$service = 'rearm' if ($service eq 'armory' || $service eq 'armoury');

	my $service_and = '';
	$service_and = " and services like '\%$service\%' " if ($service);
	my $with = '';
	$with = " with $service" if ($service);

	my($x,$y,$z,$error) = system_coordinates($system);

	if (valid_coords($x,$y,$z)) {
		my @rows = db_mysql('elite',"select carriers.name carrierName,callsign,services,systems.name systemName,systems.coord_x,systems.coord_y,systems.coord_z,".
					"sqrt(pow(systems.coord_x-?,2)+pow(systems.coord_y-?,2)+pow(systems.coord_z-?,2)) distance ".
					"from carriers,systems where carriers.systemId64=systems.id64 and ".
					"systems.coord_x is not null and systems.coord_y is not null and systems.coord_z is not null ".
					"$service_and order by distance limit 1", [($x,$y,$z)]);

		if (@rows) {
			my $r = shift @rows;
			my $distance = sprintf("%.02f",sqrt(($x-$$r{coord_x})**2 + ($y-$$r{coord_y})**2 + ($z-$$r{coord_z})**2));
			$distance =~ s/\.00$//;
			print "[$system] Nearest fleet carrier$with: $$r{carrierName} [$$r{callsign}], $$r{systemName} ($distance ly) $$r{coord_x}, $$r{coord_y}, $$r{coord_z}\n";
			my $services = $$r{services};

			foreach my $s (qw(autodock carrierfuel carriermanagement commodities contacts crewlounge dock engineer flightcontroller stationMenu stationoperations)) {
				$services =~ s/$s//gs;
			}
			$services =~ s/^,+//;
			$services =~ s/,+$//;
			$services =~ s/,+/, /gs;

			print " ^ Services: $services\n" if ($services);
			print " ^ (Note that there is no guarantee that the carrier is still present, or allowing docking)\n";
		} else {
			print "No carriers found.\n";
		}
	} else {
		print "Unknown system: $system\n";
		exit;
	}

} else {
	#print "Unknown or incomplete command: $cmd\n";
	exit;
}

exit;

###########################################################################

sub valid_coords {
	my ($x,$y,$z) = @_;
	return 1 if (defined($x) && defined($y) && defined($z));
}

sub system_name {
	my $system = btrim(uc(shift));
	$system =~ s/\s+/ /gs;
	$system =~ s/[^\w\d\-\'\,\s\*\+].*$//s;
	return btrim($system);
}

###########################################################################




