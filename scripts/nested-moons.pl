#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

use Image::Magick;

############################################################################

show_queries(0);

print make_csv(qw(ParentName ParentClass ParentType MoonName subType isLandable distanceToArrival rotationalPeriod isTidallyLocked axialTilt gravity surfaceTemperature surfacePressure
	earthMasses radius orbitalInclination argOfPeriapsis semiMajorAxis orbitalEccentricity orbitalPeriod terraformingState 
	volcanismType atmosphereType commanderName discoveryDate))."\n";

my @rows = db_mysql('elite',"select * from planets where name RLIKE ' [a-z] [a-z] [a-z]\$' and deletionState=0");

my $count = 0;
foreach my $r (sort {$$a{name} cmp $$b{name}} @rows) {

	next if ($$r{name} !~ / [a-z] [a-z] [a-z]\s*$/);

	my $parent = $$r{name};
	$parent =~ s/(\s+[a-z]\s*)+$//gs;
	my $parenttype = '';
	my $parentclass = '';

	if ($parent && $parent ne $$r{name}) {	
		my @parents = db_mysql('elite',"select subType,'planet' as bodytype from planets where name=? and deletionState=0",[($parent)]);
		push @parents, db_mysql('elite',"select subType,'star' as bodytype from stars where name=? and deletionState=0",[($parent)]) if (!@parents);	

		if (@parents) {
			$parenttype = ${$parents[0]}{subType};
			$parentclass = ${$parents[0]}{bodytype};
		}
	} else {
		$parent = '';
	}

	my $landable ='No';
	$landable = 'Yes' if ($$r{isLandable});

	my $locked ='No';
	$locked = 'Yes' if ($$r{rotationalPeriodTidallyLocked});

	print make_csv($parent,$parentclass,$parenttype,$$r{name},$$r{subType},$landable,$$r{distanceToArrivalLS},$$r{rotationalPeriod},$locked,$$r{axialTilt},$$r{gravity},$$r{surfaceTemperature},$$r{surfacePressure},$$r{earthMasses},$$r{radius},$$r{orbitalInclination},$$r{argOfPeriapsis},$$r{semiMajorAxis},$$r{orbitalEccentricity},$$r{orbitalPeriod},$$r{terraformingState},$$r{volcanismType},$$r{atmosphereType},$$r{commanderName},$$r{discoveryDate})."\n";


	$count++;

}
warn "$count found\n";


