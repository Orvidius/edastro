#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch);

############################################################################

my $debug	= 0;

show_queries(0);

############################################################################

my %letter = ();
my $i = 0;
foreach my $l ('A'..'Z') {
	$i++;
	$letter{$l} = $i;
}
foreach my $l ('a'..'z') {
	$i++;
	$letter{$l} = $i;
}

my @systems = ();

my $limit = '';
$limit = ' limit 1000' if ($debug);

############################################################################

my %systemID = ();

my @rows = db_mysql('elite',"select distinct systemId64 from planets where argOfPeriapsis is not null and orbitalPeriod is not null and semiMajorAxis is not null and deletionState=0 $limit");
while (@rows) {
	my $r = shift @rows;
	$systemID{$$r{systemId64}}=1 if ($$r{systemId64});
}

my @rows = db_mysql('elite',"select distinct systemId64 from stars where argOfPeriapsis is not null and orbitalPeriod is not null and semiMajorAxis is not null and deletionState=0 $limit");
while (@rows) {
	my $r = shift @rows;
	$systemID{$$r{systemId64}}=1 if ($$r{systemId64});
}

@systems  = keys %systemID;
%systemID = ();

if ($debug) {
	push @systems, 21223268;
	push @systems, 31720064;
	push @systems, 21268147;
}

warn int(@systems)." systems to consider.\n";

my $count = 0;
my %out = ();
my %syscount = ();
my %found = ();

print "System Body Candidates,Distance to Sol,System,Mass Code,System Stars,Primary Star Type,Parent Star,Parent Star Type,Parent Body,Parent Body Type,Companion Name,".
	"Body Name,Type,Landable,Orbit Type,Rings,Arrival Distance,".
	"Terraforming State,Radius,Earth Masses,Solar Radius,Solar Masses,Absolute Magnitude,Surface Gravity,Surface Temperature,Surface Pressure,".
	"Volcanism,Atmosphere,Axial Tilt,Rotational Period,Tidally Locked,Orbital Period,".
	"Semi-major Axis,Orbital Eccentricity,Orbital Inclination,Arg. of Periapsis,".
	"Coord X,Coord Y,Coord Z,Timestamp,EDSM Discoverer,EDSM Discovery Date\r\n";


while (@systems) {
	my @list = splice @systems, 0, 1000;
	last if (!@list);
	my $list = join(',',@list);

	my @rows =  db_mysql('elite',"select *,0 as isStar,planetID as localID from planets where systemId64 in ($list) and deletionState=0 and ".
					"argOfPeriapsis is not null and orbitalPeriod is not null and semiMajorAxis is not null");

	push @rows, db_mysql('elite',"select *,1 as isStar,starID as localID from stars where systemId64 in ($list) and deletionState=0 and ".
					"argOfPeriapsis is not null and orbitalPeriod is not null and semiMajorAxis is not null");
	my %sys  = ();

	foreach my $r (@rows) {
		$sys{$$r{systemId64}}{$$r{name}} = $r;
	}

	foreach my $s (sort {$a <=> $b} keys %sys) {

		foreach my $p (sort {$a cmp $b} keys %{$sys{$s}}) {
			
			my $r = $sys{$s}{$p};
			my $partner = '';

			my $parentName = '';
			my $num1 = '';

			if ($p =~ /^(.*\S)\s+([0-9a-zA-Z]+)\s*$/) {
				$parentName = $1;
				$num1 = $2;
			} else {
				next;
			}

			foreach my $p2 (keys %{$sys{$s}}) {
				next if ($p2 eq $p);
				my $r2 = $sys{$s}{$p2};

				if ($p2 =~ /^(.*\S)\s+([0-9a-zA-Z]+)\s*$/) {
					my ($parent2, $num2) = ($1,$2);

					next if ($parent2 ne $parentName);
					next if ($num1 =~ /^\d+$/ && $num2 !~ /^\d+$/);
					next if ($num2 =~ /^\d+$/ && $num1 !~ /^\d+$/);

					next if ( abs($$r{orbitalPeriod}-$$r2{orbitalPeriod})>$$r{orbitalPeriod}*0.001 ||
							abs($$r{semiMajorAxis}-$$r2{semiMajorAxis})>$$r{semiMajorAxis}*0.001 );

					next if ( defined($$r{orbitalEccentricity}) && defined($$r2{orbitalEccentricity}) &&  (
							abs($$r{orbitalEccentricity}-$$r2{orbitalEccentricity})>$$r{orbitalEccentricity}*0.1 ||
							abs($$r{orbitalEccentricity}-$$r2{orbitalEccentricity})>0.1
							) 
						);

					my $adjacent = 0;
					$adjacent = 1 if ($num1 =~ /^\d+$/ && $num2 =~ /^\d+$/ && ($num2==$num1-1 || $num2==$num1+1));
					$adjacent = 1 if ($num1 !~ /^\d+$/ && $num2 !~ /^\d+$/ && ($letter{$num2}==$letter{$num1}-1 || $letter{$num2}==$letter{$num1}+1));
					next if (!$adjacent);

					my $angleOK = 0;
					my $arg1 = $$r{argOfPeriapsis};
					my $arg2 = $$r2{argOfPeriapsis};
					$arg1 += 360 if ($arg1 < $arg2 && $arg2-$arg1>180);
					$arg2 += 360 if ($arg2 < $arg1 && $arg1-$arg2>180);
					my $degrees = abs($arg1-$arg2);
					next if ($degrees > 179.8);

					$partner = $p2;	# We're all good, if we got this far.
				}
				last if ($partner);
			}

			next if (!$partner);

			$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{localID} = 0 if (!defined($$r{localID}));
	
			my @rows2 = db_mysql('elite',"select id from rings where planet_id='$$r{localID}' and isStar=$$r{isStar}");
			my $num = int(@rows2);
		
			my $r2 = undef;
			@rows2 = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where id64='$$r{systemId64}' and deletionState=0");
			if (@rows2) {
				$r2 = shift @rows2;
			} else {
				%$r2 = ();
			}
		
			my $system_name = $$r2{name};
		
			my $system_type = '';
			my $orbit_type = '';
			my $primary_type = '';
			my $star_name = '';
			my $star_type = '';
			my $parent_name = '';
			my $parent_type = '';
			my $parent_body = '';
		
			$orbit_type = 'main stars' if ($$r{name} =~ /\s+[A-Z]\s*$/);
			$orbit_type = 'planetary' if ($$r{name} =~ /\s+\d\s*$/);
			$orbit_type = 'moon' if ($$r{name} =~ /\s+\d\s+[a-z]\s*$/);
			$orbit_type = 'moon of moon' if ($$r{name} =~ /\s+\d\s+[a-z]\s+[a-z]\s*$/);
			$orbit_type = 'moon of moon of moon' if ($$r{name} =~ /\s+\d\s+[a-z]\s+[a-z]\s+[a-z]\s*$/);
		
			if ($$r{name} ne $system_name) {
				$parent_name = $$r{name};
				$parent_name =~ s/\s+[\w\d]+\s*$//;
				my @pbody = ();
		
				if ($parent_name) {
					@pbody = db_mysql('elite',"select subType from stars where systemId64=? and name=? and deletionState=0",[($$r{systemId64},$parent_name)]);
		
					if (@pbody) {
						$parent_body = 'star';
						$orbit_type = 'planetary' if (!$orbit_type);
						$orbit_type = 'moon of star' if ($orbit_type =~ /moon/);
					} else {
						@pbody = db_mysql('elite',"select subType from planets where systemId64=? and name=? and deletionState=0",[($$r{systemId64},$parent_name)]);
						if (@pbody) {
							$parent_body = 'planet';
							$orbit_type = 'moon' if (!$orbit_type);
						}
					}
				}
		
				if (@pbody) {
					$parent_type = ${$pbody[0]}{subType};
				} else {
					$parent_name = '';
				}
		
				if ($system_name) {
					my @primary = db_mysql('elite',"select name,subType from stars where systemId64=? and name in (?,?) and deletionState=0",
								[($$r{systemId64},$system_name,"$system_name A")]);
					if (@primary) {
						$primary_type = ${$primary[0]}{subType};
						$system_type = 'multiple' if (${$primary[0]}{name} =~ /\s+A\s*$/);
						$system_type = 'single'   if (${$primary[0]}{name} !~ /\s+A\s*$/);
					}
				}
		
				if ($parent_body eq 'star') {
					$star_name = $parent_name;
					$star_type = $parent_type;
				}
		
				my $n = 5;
				while ($n>0 && !$star_type && $parent_body ne 'star') {
					$star_name = $parent_name if (!$star_name);
					$star_name =~ s/\s+[\w\d]+\s*$//;
					
					my @stars = db_mysql('elite',"select subType from stars where systemId64=? and name=? and deletionState=0",[($$r{systemId64},$star_name)]);
		
					if (@stars) {
						$star_type = ${$stars[0]}{subType};
					}
		
					$n--;
				}
				$star_name = '' if (!$star_type);
			}
		
			my $locked = 'no';
			$locked = 'yes' if ($$r{rotationalPeriodTidallyLocked});
		
			my $isLandable = 'no';
			$isLandable = 'yes' if ($$r{isLandable});
		
			my $masscode = '';
		
			if ($$r{name} =~ /\S+\s+\w\w\-\w\s+([a-zA-Z])(\d+\-)?\d+/) {
				$masscode = uc($1);
			}

			my $solDistance = 0;
			if ($$r2{coord_x} || $$r2{coord_y} || $$r2{coord_z}) {
				$solDistance = sprintf("%.02f",sqrt($$r2{coord_x}**2 + $$r2{coord_y}**2 + $$r2{coord_z}**2));
			}

			if ($$r{isStar} && !$$r{earthMasses} && $$r{solarMasses}) {
				$$r{earthMasses} = $$r{solarMasses}*332946;
			}
			if ($$r{isStar} && !$$r{radius} && $$r{solarRadius}) {
				$$r{radius} = $$r{solarRadius}*696342;
			}
		
			$out{$p}{$s} = "$solDistance,$system_name,$masscode,$system_type,$primary_type,$star_name,$star_type,$parent_name,$parent_type,$partner,$$r{name},".
				"$$r{subType},$isLandable,$orbit_type,$num,".
				"$$r{distanceToArrivalLS},$$r{terraformingState},$$r{radius},$$r{earthMasses},$$r{solarRadius},$$r{solarMasses},".
				"$$r{absoluteMagnitude},$$r{gravity},$$r{surfaceTemperature},$$r{surfacePressure},".
				"$$r{volcanismType},$$r{atmosphereType},$$r{axialTilt},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},$$r{semiMajorAxis},$$r{orbitalEccentricity},".
				"$$r{orbitalInclination},$$r{argOfPeriapsis},$$r2{coord_x},$$r2{coord_y},$$r2{coord_z},$$r{updateTime},$$r{commanderName},$$r{discoveryDate}\r\n";
			$syscount{$s}++;
			$count++;
		}
	}
}
warn "$count candidates found\n";
	
foreach my $p (sort {$a cmp $b} keys %out) {
	foreach my $s (sort {$a <=> $b} keys %{$out{$p}}) {
		$found{$s}{$p} = 1;
	}
}

foreach my $s (keys %found) {
	if (keys(%{$found{$s}})<2) {
		foreach my $p (keys(%{$found{$s}})) {
			warn "Deleting single: $s, $p\n";
			delete($out{$p}{$s});
			delete($out{$p}) if (!keys(%{$out{$p}}));
		}
	}
}

$count = 0;
foreach my $p (sort {$a cmp $b} keys %out) {
	foreach my $s (sort {$a <=> $b} keys %{$out{$p}}) {
		print "$syscount{$s},$out{$p}{$s}";
		$count++;
	}
}
warn "$count candidates listed\n";
	
exit;

############################################################################




