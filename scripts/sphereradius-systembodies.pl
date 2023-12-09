#!/usr/bin/perl
use strict; $|=1;

############################################################################
# Copyright (C) 2023, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/elite";
use EDSM qw(log10 id64_sectorcoords compress_send);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

############################################################################

my @column_order = (
	'name', 'bodyId', 'bodyId64', 'bodyType', 'subType', 'spectralClass', 'distanceToArrivalLS', 'orbitType',
	'rotationalPeriodTidallyLocked', 'rotationalPeriodDec', 'axialTiltDec', 'orbitalPeriodDec', 'orbitalEccentricityDec',
	'orbitalInclinationDec', 'argOfPeriapsisDec', 'semiMajorAxisDec', 'meanAnomaly', 'meanAnomalyDate', 'ascendingNode',
	'surfaceTemperatureDec', 'surfacePressureDec', 'gravityDec', 'earthMassesDec', 'radiusDec', 'terraformingState',
	'volcanismType', 'atmosphereType', 'age', 'luminosity', 'absoluteMagnitudeDec', 'solarMassesDec', 'solarRadiusDec',
	'isLandable', 'isScoopable'
);
my %column_key = (
	'name'			=> 'Body Name',
	'bodyId'		=> 'Body ID',
	'bodyId64'		=> 'Body ID64',
	'bodyType'		=> 'Type',
	'subType'		=> 'SubType',
	'spectralClass'		=> 'Spectral Class',
	'distanceToArrivalLS'	=> 'Distance from Arrival',
	'orbitType'		=> 'Orbit Type',
	'rotationalPeriodTidallyLocked'	=> 'Tidally Locked',
	'rotationalPeriodDec'	=> 'Rotational Period',
	'axialTiltDec'		=> 'Axial Tilt',
	'orbitalPeriodDec'	=> 'Orbital Period',
	'orbitalEccentricityDec'=> 'Eccentricity',
	'orbitalInclinationDec'	=> 'Inclination',
	'argOfPeriapsisDec'	=> 'Argument of Periapsis',
	'semiMajorAxisDec'	=> 'SemiMajor Axis',
	'meanAnomaly'		=> 'Mean Anomaly',
	'meanAnomalyDate'	=> 'Anomaly Date',
	'ascendingNode'		=> 'Ascending Node',
	'surfaceTemperatureDec'	=> 'Surface Temperature',
	'surfacePressureDec'	=> 'Surface Pressure',
	'gravityDec'		=> 'Surface Gravity',
	'earthMassesDec'	=> 'Earth Masses',
	'radiusDec'		=> 'Radius',
	'terraformingState'	=> 'Terraforming State',
	'volcanismType'		=> 'Volcanism',
	'atmosphereType'	=> 'Atmosphere',
	'age'			=> 'Age',
	'luminosity'		=> 'Luminosity',
	'absoluteMagnitudeDec'	=> 'Absolute Magnitude',
	'solarMassesDec'	=> 'Solar Masses',
	'solarRadiusDec'	=> 'Solar Radius',
	'isLandable'		=> 'Landable',
	'isScoopable'		=> 'Scoopable'
);


my %column_index = ();
my $i=0;
foreach my $c (@column_order) {
	$column_index{$c} = $i;
	$i++;
}

show_queries(0);

my $filename	= 'sphereradius-systembodies.csv';
my $ref_system	= '';
my $radius	= 100;
my $center_x	= 0;
my $center_y	= 0;
my $center_z	= 0;

if (@ARGV) {
	$ref_system	= $ARGV[0];
	$radius		= $ARGV[1] if ($ARGV[1] &&  $ARGV[1] =~ /^\d+$/);
	$filename	= $ARGV[1] if ($ARGV[1] && !$ARGV[2] && $ARGV[1] !~ /^\d+$/);
	$filename	= $ARGV[2] if ($ARGV[2]);
}

die "Usage: $0 <RefSystem> [radius:100] [filename]\n" if (!$ref_system || !$radius);


warn "Ref system: $ref_system\n";

my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where name=? and deletionState=0 order by name,id64",[($ref_system)]);
die "Ref system not found.\n" if (!@rows);

foreach my $r (@rows) {
	$center_x = $$r{coord_x};
	$center_y = $$r{coord_y};
	$center_z = $$r{coord_z};
}

warn "Ref coordinates: $center_x, $center_y, $center_z (radius: $radius)\n";


open OUT, ">$filename";

my @header = ('System ID64','System','Coord-X','Coord-Y','Coord-Z','RegionID');

foreach my $c (@column_order) {
	push @header, $column_key{$c};
}

print OUT make_csv(@header)."\r\n";

my @systems = db_mysql('elite',"select id64,name,coord_x,coord_y,coord_z,region regionID from systems where ".
			"sqrt(pow(?-coord_x,2)+pow(?-coord_y,2)+pow(?-coord_z,2))<=$radius and deletionState=0",
			[($center_x,$center_y,$center_z)]);

warn int(@systems)." systems found.\n";

my $count = 1;

foreach my $sys (@systems) {
	my @rows = db_mysql('elite',"select *,planetID as itemID,'planet' as bodyType from planets where systemId64=? and deletionState=0",[($$sys{id64})]);
	push @rows, db_mysql('elite', "select *,starID as itemID,'star'   as bodyType from stars   where systemId64=? and deletionState=0",[($$sys{id64})]);

	warn "$$sys{id64} ($$sys{name}): ".int(@rows)." bodies\n";

	foreach my $r (sort { $$a{bodyId} <=> $$b{bodyId} || $$a{name} cmp $$b{name} } @rows) {
		my @line = ($$sys{id64},$$sys{name},$$sys{coord_x},$$sys{coord_y},$$sys{coord_z},$$sys{regionID});


		if (defined($$r{orbitType})) {
			$$r{orbitType} = ''		if ($$r{orbitType} == 0);
			$$r{orbitType} = 'single'	if ($$r{orbitType} == 1);
			$$r{orbitType} = 'stellar'	if ($$r{orbitType} == 2);
			$$r{orbitType} = 'planetary'	if ($$r{orbitType} == 3);
			$$r{orbitType} = 'barycentric'	if ($$r{orbitType} == 4);
			$$r{orbitType} = 'moon'		if ($$r{orbitType} >= 5);
		}

		foreach my $c (@column_order) {
			push @line, $$r{$c};
		}
		print OUT make_csv(@line)."\r\n";
		$count++;
	}
}

close OUT;

compress_send($filename,$count,{'debug'=>0, 'upload_only'=>0, 'allow_scp'=>1});




