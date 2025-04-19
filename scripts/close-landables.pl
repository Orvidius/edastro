#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

############################################################################

show_queries(0);

my @rows = db_mysql('elite',"select distinct systemId64 from planets where isLandable>0 and semiMajorAxis>0 and semiMajorAxis<=5 and ".
		"(name like '% 1' or name like '% 2' or name like '% II') and deletionState=0 order by name");

print "System,Planet,Mass Code,Type,Semi-major Axis (LS),Parent Star,Star Type,Star Radius,Rings,".
	"Arrival Distance,Terraforming State,Radius,Earth Masses,Surface Gravity,Surface Temperature,Surface Pressure,".
	"Volcanism,Atmosphere,Axial Tilt,Rotational Period,Tidally Locked,Orbital Period,".
	"Semi-major Axis,Orbital Eccentricity,Orbital Inclination,Arg. of Periapsis,".
	"Coord X,Coord Y,Coord Z,Timestamp,EDSM Discoverer,EDSM Discovery Date,regionID\r\n";

my $count = 0;
foreach my $r (@rows) {
	next if (!$$r{systemId64});

	my @planetlist = db_mysql('elite',"select * from planets where systemId64=$$r{systemId64} and (name like '% 1' or name like '% 2' or name like '% I' or name like '% II') and deletionState=0");
	my %planets = ();
	foreach my $p (@planetlist) {
		$planets{$$p{name}} = $p;
	}
	next if (!@planetlist);

	my %out = ();
	my @starlist = ();
	my %stars = ();

	my $system = undef;

	foreach my $name (keys %planets) {
		my $r = $planets{$name};
		#%$r = %{$planets{$name}};
		my $parentname = $name;
		$parentname =~ s/\s+[I\d]+\s*$//s;
		next if ($name eq $parentname);

		next if ($name !~ /\s+([12]|I{1,2})\s*$/);	# Consider only the first two planets around any given body

		next if (!$$r{isLandable} || !$$r{semiMajorAxis} || $$r{semiMajorAxis}>5);
		next if ($$r{parents} && $$r{parents} !~ /^Star/i);

		my $lightseconds = $$r{semiMajorAxis}*499.005;
		$lightseconds = sprintf("%.03f",$lightseconds) if ($lightseconds>0);

		next if (!$lightseconds);

		if (!keys %$system) {
			my @systemlist = db_mysql('elite',"select name,coord_x,coord_y,coord_z,region from systems where id64='$$r{systemId64}' and deletionState=0");
			if (@systemlist) {
				$system = shift @systemlist;
			} else {
				%$system = ();
			}
		}

		next if ($name =~ /\s+I+\s*$/ && $parentname ne $$system{name});

		if (!@starlist) {
			@starlist = db_mysql('elite',"select name,subType,solarRadius from stars where systemId64=$$r{systemId64} and solarRadius>0 and deletionState=0");
			foreach my $s (@starlist) {
				$stars{$$s{name}} = $s;
			}
			next if (!@starlist);
		}

		next if (!exists($stars{$parentname}));
		next if ($lightseconds > $stars{$parentname}{solarRadius}*5 && $lightseconds > 2);
		next if (!$$r{parents} && $$r{distanceToArrivalLS} > $stars{$parentname}{solarRadius}*5);

		$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{planetID} = 0 if (!defined($$r{planetID}));

		my @rows2 = db_mysql('elite',"select id from rings where planet_id='$$r{planetID}' and isStar=0");
		my $numrings = int(@rows2);
	
		my $locked = 'no';
		$locked = 'yes' if ($$r{rotationalPeriodTidallyLocked});
	
		my $masscode = '';
	
		if ($$r{name} =~ /\S+\s+\w\w\-\w\s+([a-zA-Z])(\d+\-)?\d+/) {
			$masscode = uc($1);
		}
	
		#warn "$$system{name},$$r{name},$masscode,$$r{subType},$lightseconds,$parentname,$stars{$parentname}{subType},$stars{$parentname}{solarRadius}\n";

		$out{$name} = make_csv($$system{name},$$r{name},$masscode,$$r{subType},$lightseconds,$parentname,$stars{$parentname}{subType},$stars{$parentname}{solarRadius},$numrings,
			$$r{distanceToArrivalLS},$$r{terraformingState},$$r{radius},$$r{earthMasses},$$r{gravity},$$r{surfaceTemperature},$$r{surfacePressure},
			$$r{volcanismType},$$r{atmosphereType},$$r{axialTilt},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},$$r{semiMajorAxis},$$r{orbitalEccentricity},
			$$r{orbitalInclination},$$r{argOfPeriapsis},$$system{coord_x},$$system{coord_y},$$system{coord_z},$$r{updateTime},$$r{commanderName},$$r{discoveryDate},
			$$system{region})."\r\n";
	}

	foreach my $name (sort keys %out) {

		# Filter out binaries whose orbits are smaller than the innermost planet.

		if ($name =~ /^(.+\S)\s+(\d+)\s*$/) {
			my ($parent,$n) = ($1,$2);
			my $innermost = "$parent 1";
			my $second = "$parent 2";

			if ($n > 1) {
				next if (!$planets{$innermost}{semiMajorAxis});
				next if ($planets{$innermost}{semiMajorAxis} > 0 && $planets{$name}{semiMajorAxis} < $planets{$innermost}{semiMajorAxis});
			} else {
				next if ($planets{$second}{semiMajorAxis} > 0 && $planets{$second}{semiMajorAxis} < $planets{$name}{semiMajorAxis}*1.05);
			}
		} elsif ($name =~ /^(.+\S)\s+([IVX]+)\s*$/) {
			my ($parent,$n) = ($1,$2);
			my $innermost = "$parent I";
			my $second = "$parent II";

			if ($n ne 'I') {
				next if (!$planets{$innermost}{semiMajorAxis});
				next if ($planets{$innermost}{semiMajorAxis} > 0 && $planets{$name}{semiMajorAxis} < $planets{$innermost}{semiMajorAxis});
			} else {
				next if ($planets{$second}{semiMajorAxis} > 0 && $planets{$second}{semiMajorAxis} < $planets{$name}{semiMajorAxis}*1.05);
			}
		} elsif ($name =~ /^(.+\S)\s+(\d+)\s*$/) {
			
		} else {
			next;
		}

		# Still alive? Print it and move on.

		print $out{$name};
		$count++;
	}
}
warn "$count found\n";


