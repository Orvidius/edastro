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

my $planet_types = "'Earth-like world'";
my $and = '';

if (@ARGV) {
	$planet_types = "";

	foreach my $arg (@ARGV) {
		my $arg1 = $arg;
		$arg1 =~ s/[^\w\d\s\-\(\)\.\=\:\<\>\!\']+//gs;

		if ($arg1 =~ /^and:(\w+[\<\>\=\!]+)'([\w\d\.\s\-]+)'/) {
			$and .= " and $1'$2'";
		} elsif ($arg1 =~ /^and:(\w+[\<\>\=\!]+)([\w\d\.\-]+)/) {
			$and .= " and $1'$2'";
		} elsif ($arg =~ /^rlike:(\w+)=([\w\<\>\=\!\s\'\%\:\+\*\?\[\]\(\)\-\^\$]+)/i) {
			$and .= " and $1 rlike $2";
		} elsif ($arg =~ /^binlike:(\w+)=([\w\<\>\=\!\s\'\%\:\+\*\?\[\]\(\)\-\^\$]+)/i) {
			$and .= " and cast($1 as binary) rlike $2";
		} elsif ($arg1 =~ /^(and|rlike|binlike):/) {
			warn "Malformed \"$1\": $arg\n";
		} else {
			$planet_types .= ",'$arg'";
		}
	}

	$planet_types =~ s/^,//;
}
#warn "AND: $and\n" if ($and);
#exit;

die "Need parameters!\n" if (!$and && !$planet_types);

my $where = "subType in ($planet_types) and deletionState=0 $and";

if ($planet_types && !$and) {
	$where = "subType in ($planet_types)";
} elsif (!$planet_types && $and) {
	$where = $and;
	$where =~ s/^\s*and\s+//;
}

warn "WHERE: $where\n";
#exit;

my @parents = ();
@parents = db_mysql('elite',"select name,subType,systemId64,planetID from planets where $where limit 1000") if ($debug);
@parents = db_mysql('elite',"select name,subType,systemId64,planetID from planets where $where order by name") if (!$debug);

die "No planets found.\n" if (!@parents);
warn int(@parents)." planets to consider for moons.\n";

print "System,Mass Code,System Stars,Primary Star Type,Parent Star,Parent Star Type,Parent Body,Parent Body Type,Parent Total Moons,".
	"Moon Name,Landable,Orbit Type,Type,Rings,Arrival Distance,".
	"Terraforming State,Radius,Earth Masses,Surface Gravity,Surface Temperature,Surface Pressure,".
	"Volcanism,Atmosphere,Axial Tilt,Rotational Period,Tidally Locked,Orbital Period,".
	"Semi-major Axis,Orbital Eccentricity,Orbital Inclination,Arg. of Periapsis,".
	"Coord X,Coord Y,Coord Z,Timestamp\r\n";

my $count = 0;
foreach my $pp (@parents) {
	my $safe_name = $$pp{name};
	$safe_name =~ s/(['\[\]\*\+\^\$])/\\\\$1/gs;
	$safe_name =~ s/(['"])/\\$1/gs;
	my @rows = db_mysql('elite',"select * from planets where systemId64='$$pp{systemId64}' and name rlike '^$safe_name [a-z]' and deletionState=0 order by name");
	my $moon_count = int(@rows);

	next if (!@rows);

	my $star_name = '';
	my $star_type = '';
	my $parent_name = $$pp{name};
	my $parent_type = $$pp{subType};
	my $primary_type = '';

	my $r2 = undef;
	my @rows2 = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where id64='$$pp{systemId64}'");
	if (@rows2) {
		$r2 = shift @rows2;
	} else {
		%$r2 = ();
	}
	my $system_name = $$r2{name};
	my $system_type = '';
	
	if ($$pp{name} ne $system_name) {
		$parent_name = $$pp{name};
		$parent_type = $$pp{subType};

		if ($system_name) {
			my @primary = db_mysql('elite',"select name,subType from stars where systemId64=? and name in (?,?) and deletionState=0",[($$pp{systemId64},$system_name,"$system_name A")]);
			if (@primary) {
				$primary_type = ${$primary[0]}{subType};
				$system_type = 'multiple' if (${$primary[0]}{name} =~ /\s+A\s*$/);
				$system_type = 'single'   if (${$primary[0]}{name} !~ /\s+A\s*$/);
			}
		}


		my $n = 5;
		while ($n>0 && !$star_type) {
			$star_name = $parent_name if (!$star_name);
			$star_name =~ s/\s+[\w\d]+\s*$//;
			
			my @stars = db_mysql('elite',"select subType from stars where systemId64=? and name=? and deletionState=0",[($$pp{systemId64},$star_name)]);

			if (@stars) {
				$star_type = ${$stars[0]}{subType};
				last;
			}

			$n--;
		}
		$star_name = '' if (!$star_type);
	}

	foreach my $r (@rows) {

		$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{planetID} = 0 if (!defined($$r{planetID}));
	
		my @rows2 = db_mysql('elite',"select id from rings where planet_id='$$r{planetID}' and isStar=0");
		my $num = int(@rows2);
	
		my $orbit_type = '';
		$orbit_type = 'planetary' if ($$r{name} =~ /\s+\d\s*$/);
		$orbit_type = 'moon' if ($$r{name} =~ /\s+\d\s+[a-z]\s*$/i);
		$orbit_type = 'moon of moon' if ($$r{name} =~ /\s+\d\s+[a-z]\s+[a-z]\s*$/i);
		$orbit_type = 'moon of moon of moon' if ($$r{name} =~ /\s+\d\s+[a-z]\s+[a-z]\s+[a-z]\s*$/i);
	
		my $locked = 'no';
		$locked = 'yes' if ($$r{rotationalPeriodTidallyLocked});
	
		my $isLandable = 'no';
		$isLandable = 'yes' if ($$r{isLandable});
	
		my $masscode = '';
	
		if ($$r{name} =~ /\S+\s+\w\w\-\w\s+([a-zA-Z])(\d+\-)?\d+/) {
			$masscode = uc($1);
		}
	
		print "$system_name,$masscode,$system_type,$primary_type,$star_name,$star_type,$parent_name,$parent_type,$moon_count,$$r{name},$isLandable,$orbit_type,$$r{subType},$num,".
			"$$r{distanceToArrivalLS},$$r{terraformingState},$$r{radius},$$r{earthMasses},$$r{gravity},$$r{surfaceTemperature},$$r{surfacePressure},".
			"$$r{volcanismType},$$r{atmosphereType},$$r{axialTilt},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},$$r{semiMajorAxis},$$r{orbitalEccentricity},".
			"$$r{orbitalInclination},$$r{argOfPeriapsis},$$r2{coord_x},$$r2{coord_y},$$r2{coord_z},$$r{updateTime},$$r{commanderName},$$r{discoveryDate}\r\n";
		$count++;
	}
}
warn "$count found\n";


