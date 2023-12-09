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

show_queries(0);

my $min_moons	= 10;
my $debug_limit	= '';# 'limit 1000';

############################################################################

my %counts = ();
my %out = ();

my $moonletter = chr(ord('a')+$min_moons-1);
warn "Looking for moons with letter '$moonletter'\n";

my @lookup = db_mysql('elite',"select max(planetID) as maxID from planets");
my $maxID = ${$lookup[0]}{maxID};
my $startID = 0;
my $chunkSize = 10000;
my $count = 0;
my $dotcount = 0;

while ($startID < $maxID) {

	my @sysrows = db_mysql('elite',"select systemId64 from planets where planetID>=? and planetID<? and deletionState=0 and CAST(name as binary) rlike ' [0-9]+ $moonletter\$'",
			[($startID,$startID+$chunkSize)]);

	$startID += $chunkSize;

	$dotcount++;
	print '.';
	print "\n" if ($dotcount % 100 == 0);

	foreach my $s (@sysrows) {
		my $sysID = $$s{systemId64};
		next if (!$sysID);
	
		my $sys = undef;
	
		my @rows = db_mysql('elite',"select *,1 as isStar from stars where systemId64=? and deletionState=0 and CAST(name as binary) rlike ' [0-9]{1,2}\$'",[($sysID)]);
		push @rows, db_mysql('elite',"select *,0 as isStar from planets where systemId64=? and deletionState=0",[($sysID)]);
		
		my %planet = ();
		my %mooncount = ();
	
		foreach my $r (@rows) {
			$planet{$$r{name}} = $r;
		}
	
		foreach my $r (@rows) {
			if ($$r{name} =~ /^(.+\S)\s+([\w\d]+)\s*$/) {
				my ($parent,$num) = ($1,$2);
				
				if ($planet{$parent}{name}) {
					$mooncount{$parent}++;
				}
			}
		}
		
		foreach my $name (keys %planet) {
			my $r = $planet{$name};
			next if (!$$r{isStar});
	
			$mooncount{$name} = 0 if (!$mooncount{$name});
			$counts{$mooncount{$name}}++;
			next if ($mooncount{$name}<$min_moons);
	
			if (!keys %$sys) {
				my @rows2 = db_mysql('elite',"select name,coord_x,coord_y,coord_z,region regionID from systems where id64='$$s{systemId64}' and deletionState=0");
				if (@rows2) {
					$sys = shift @rows2;
				} else {
					%$sys = ();
				}
			}
	
			$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{starID} = 0 if (!defined($$r{starID}));
	
			my @rows2 = db_mysql('elite',"select id from rings where planet_id='$$r{starID}' and isStar=1");
			my $num = int(@rows2);
		
			my $locked = 'no';
			$locked = 'yes' if ($$r{rotationalPeriodTidallyLocked});
		
			my $masscode = '';
		
			if ($$r{name} =~ /\S+\s+\w\w\-\w\s+([a-zA-Z])(\d+\-)?\d+/) {
				$masscode = uc($1);
			}
	
			#warn "$$sys{name},$$r{name},$mooncount{$name}\n" if ($mooncount{$name} >=12);
		
			$out{$mooncount{$name}}{$$r{name}} = "$$sys{name},$$r{name},$masscode,$$r{subType},$mooncount{$name},$num,".
				"$$r{distanceToArrivalLS},$$r{solarRadius},$$r{solarMasses},$$r{absoluteMagnitudeDec},$$r{luminosity},$$r{surfaceTemperature},".
				"$$r{age},$$r{axialTilt},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},$$r{semiMajorAxis},$$r{orbitalEccentricity},".
				"$$r{orbitalInclination},$$r{argOfPeriapsis},$$sys{coord_x},$$sys{coord_y},$$sys{coord_z},$$sys{regionID},
				$$r{updateTime},$$r{commanderName},$$r{discoveryDate}\r\n";
			$count++;
		}
	}
}

print "\n";

open CSV, ">moon-rich-stars.csv";
print CSV "System,Star,Mass Code,Type,Moons,Rings,Arrival Distance,Solar Radius,Solar Masses,Absolute Magnitude,Luminosity,Surface Temperature,".
	"Age,Axial Tilt,Rotational Period,Tidally Locked,Orbital Period,".
	"Semi-major Axis,Orbital Eccentricity,Orbital Inclination,Arg. of Periapsis,".
	"Coord X,Coord Y,Coord Z,RegionID,Timestamp,EDSM Discoverer,EDSM Discovery Date\r\n";

foreach my $n (sort {$a <=> $b} keys %out) {
	foreach my $name (sort {$a cmp $b} keys %{$out{$n}}) {
		print CSV $out{$n}{$name};
	}
}
close CSV;

warn "$count found\n";

print "\r\n";
print "Number of moons,Planets\r\n";

foreach my $n (sort {$a <=> $b} keys %counts) {
	print "$n,$counts{$n}\r\n";
	warn "$n,$counts{$n}\n";
}



