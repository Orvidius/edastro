#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch);

############################################################################

show_queries(0);

my %letter = ();
my $i = 0;
foreach my $l ('a'..'z') {
        $i++;
        $letter{$l} = $i;
        $letter{$i} = $l;
}
$letter{0} = '?';
$letter{'?'} = 0;


my $maxSemiMajorAxis = 0.001002; #sprintf("%.05f",1.2/499.005);

my $debug_limit = '';
#$debug_limit = ' limit 10000';

my @parent_types = @ARGV;
@parent_types = ('Earth-like world') if (!@parent_types);

my %parent_type_OK = ();
foreach my $type (@parent_types) {
	$parent_type_OK{$type} = 1;
}

############################################################################

#my $conditions = "isLandable>0 and semiMajorAxis>0 and semiMajorAxis<=$maxSemiMajorAxis and cast(name as binary) rlike ' [0-9]+ [a-f]\$'";
my $conditions = "isLandable>0 and semiMajorAxis>0 and semiMajorAxis<=$maxSemiMajorAxis and cast(name as binary) rlike ' [a-f]\$'";

my @rows = db_mysql('elite',"select distinct systemId64 from planets where $conditions and deletionState=0 $debug_limit");

warn int(@rows)." systems to consider.\n";

print "System,Moon,Mass Code,Type,Semi-major Axis (LS),Parent Planet,Parent Type,Rings,".
	"Arrival Distance,Terraforming State,Radius,Earth Masses,Surface Gravity,Surface Temperature,Surface Pressure,".
	"Volcanism,Atmosphere,Axial Tilt,Rotational Period,Tidally Locked,Orbital Period,".
	"Semi-major Axis,Orbital Eccentricity,Orbital Inclination,Arg. of Periapsis,".
	"Coord X,Coord Y,Coord Z,Timestamp,EDSM Discoverer,EDSM Discovery Date\r\n";

my $count = 0;
foreach my $sys (@rows) {
	next if (!$$sys{systemId64});

	my @planetlist = db_mysql('elite',"select * from planets where systemId64=? and $conditions and deletionState=0",[($$sys{systemId64})]);
	my %planets = ();
	foreach my $p (@planetlist) {
		$planets{$$p{name}} = $p;
	}
	next if (!@planetlist);

	my %out = ();
	my @bodylist = ();
	my %bodies = ();

	my $system = undef;

	foreach my $name (keys %planets) {
		my $r = $planets{$name};
		#%$r = %{$planets{$name}};
		my $parentname = $name;
		$parentname =~ s/\s+[a-z]\s*$//s;
		next if ($name eq $parentname);

		next if (!$$r{isLandable} || !$$r{semiMajorAxis} || $$r{semiMajorAxis}>$maxSemiMajorAxis);
		next if ($$r{parents} && $$r{parents} =~ /^Star/i);

		my $lightseconds = $$r{semiMajorAxis}*499.005;
		$lightseconds = sprintf("%.03f",$lightseconds) if ($lightseconds>0);

		next if (!$lightseconds);

		if (!@bodylist) {
			@bodylist = db_mysql('elite',"select name,subType,orbitalPeriod,argOfPeriapsis,semiMajorAxis from planets where systemId64=$$r{systemId64} and deletionState=0");
			foreach my $s (@bodylist) {
				$bodies{$$s{name}} = $s;
			}
			next if (!@bodylist);
		}

		if ($$r{name} =~ /^(.+\S)\s+([a-z])$/) {

			# Attempt to filter out binaries

			my $moon1 = $1.' '.$letter{$letter{$2}-1};
			my $moon2 = $1.' '.$letter{$letter{$2}+1};

			my $angleOK = 1;

			foreach my $moon ($moon1,$moon2) {
				next if (!$bodies{$moon});

				my $arg1 = $$r{argOfPeriapsis};
				my $arg2 = $bodies{$moon}{argOfPeriapsis};

				$arg1 += 360 if ($arg1 < $arg2 && $arg2-$arg1>180);
				$arg2 += 360 if ($arg2 < $arg1 && $arg1-$arg2>180);

				my $degrees = abs($arg1-$arg2);
				$angleOK = 0 if ($degrees>= 179.8 && abs($$r{orbitalPeriod}-$bodies{$moon}{orbitalPeriod})<=$$r{orbitalPeriod}*0.001);
			}

			next if (!$angleOK);
		}

		next if (!exists($bodies{$parentname}) || !$parent_type_OK{$bodies{$parentname}{subType}});

		if (!keys %$system) {
			my @systemlist = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where id64='$$r{systemId64}' and deletionState=0");
			if (@systemlist) {
				$system = shift @systemlist;
			} else {
				%$system = ();
			}
		}

		next if ($name =~ /\s+I+\s*$/ && $parentname ne $$system{name});

		$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{planetID} = 0 if (!defined($$r{planetID}));

		my @rows2 = db_mysql('elite',"select id from rings where planet_id='$$r{planetID}' and isStar=0");
		my $numrings = int(@rows2);
	
		my $locked = 'no';
		$locked = 'yes' if ($$r{rotationalPeriodTidallyLocked});
	
		my $masscode = '';
	
		if ($$r{name} =~ /\S+\s+\w\w\-\w\s+([a-zA-Z])(\d+\-)?\d+/) {
			$masscode = uc($1);
		}

		#warn "$$system{name},$$r{name},$masscode,$$r{subType},$lightseconds,$parentname,$bodies{$parentname}{subType}\n";
	
		$out{$name} = "$$system{name},$$r{name},$masscode,$$r{subType},$lightseconds,$parentname,$bodies{$parentname}{subType},$numrings,".
			"$$r{distanceToArrivalLS},$$r{terraformingState},$$r{radius},$$r{earthMasses},$$r{gravity},$$r{surfaceTemperature},$$r{surfacePressure},".
			"$$r{volcanismType},$$r{atmosphereType},$$r{axialTilt},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},$$r{semiMajorAxis},$$r{orbitalEccentricity},".
			"$$r{orbitalInclination},$$r{argOfPeriapsis},$$system{coord_x},$$system{coord_y},$$system{coord_z},$$r{updateTime},$$r{commanderName},$$r{discoveryDate}\r\n";
	}

	foreach my $name (sort keys %out) {
		print $out{$name};
		$count++;
	}
}
warn "$count found\n";


