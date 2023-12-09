#!/usr/bin/perl
use strict;
$|=1;

############################################################################
# Copyright (C) 2021, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

############################################################################

my $debug	= 0;
my $debug_limit	= 'limit 10';

my $sagA_x= 25.2188;
my $sagA_y= -20.9062;
my $sagA_z= 25900;

############################################################################

my %region = ();

my @rows = db_mysql('elite',"select * from regions");
foreach my $r (@rows) {
        $region{$$r{id}} = $$r{name};
}

my @rows = db_mysql('elite',"select systems.name system,planets.name,subType,region,surfaceTemperature,gravity,coord_x,coord_y,coord_z from systems,planets ".
		"where systemId64=id64 and volcanismType='Minor Carbon Dioxide Geysers' and isLandable=1 and subType='Rocky Ice world' and ".
		"systems.deletionState=0 and planets.deletionState=0");

print make_csv('System','Body','Region','Temperature','Gravity','Distance from Sgr-A*')."\r\n";

foreach my $r (@rows) {
	my $dist = sqrt(($$r{coord_x}-$sagA_x)**2 + ($$r{coord_y}-$sagA_y)**2 + ($$r{coord_z}-$sagA_z)**2);

	print make_csv($$r{system},$$r{name},$region{$$r{region}},$$r{surfaceTemperature},$$r{gravity},$dist)."\r\n";
}
