#!/usr/bin/perl
use strict; $|=1;

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql);
use ATOMS qw(btrim make_csv);

my $systems = rows_mysql('elite',"select distinct id64,systems.name sys,regions.name,coord_x,coord_y,coord_z from regions,systems,stars,planets where ".
		"regions.id=systems.region and id64=planets.systemId64 and id64=stars.systemId64 and (atmosphereType like 'Thin %' or atmosphereType like 'Hot Thin %') ".
		"and stars.subType='Herbig Ae/Be Star' and surfacePressureDec<=0.1 and planets.deletionState=0 and stars.deletionState=0 and systems.deletionState=0 ".
		"and CAST(stars.name as binary) not rlike ' [0-9]+( [a-z]+)*\$' ".
		"group by id64 order by regions.name,systems.name");

print make_csv('Region','ID64','System','Star','Planet','Type','Atmosphere','Surface Pressure','Surface Gravity','Surface Temperature','X','Y','Z')."\r\n";

while (@$systems) {
	my $s = shift @$systems;
	my $id64 = $$s{id64};
	my $region = $$s{name};
	my $system = $$s{sys};

	warn "$region: $system ($id64)\n";

	my @rows = db_mysql('elite',"select starID,name from stars where systemId64=? and subType='Herbig Ae/Be Star' and deletionState=0 order by name",[($id64)]);

	foreach my $r (@rows) {
		my $starname = $$r{name};
		$starname =~ s/[^a-zA-Z0-9\s\-\']//gs;
		$starname =~ s/'/\\'/gs;

		my @rows2 = db_mysql('elite',"select planetID,name,surfacePressureDec,surfaceTemperature,gravityDec,subType,atmosphereType from planets where systemId64=? and ".
				"(atmosphereType like 'Thin \%' or atmosphereType like 'Hot Thin \%') and name like '$starname \%' and surfacePressureDec<=0.1 and ".
				"deletionState=0 order by name",[($id64)]);

		foreach my $p (@rows2) {
			$$p{surfacePressureDec}+=0 if (defined($$p{surfacePressureDec}));
			$$p{surfaceTemperature}+=0 if (defined($$p{surfaceTemperature}));
			$$p{gravityDec}+=0 if (defined($$p{gravityDec}));

			print make_csv($region,$id64,$system,$$r{name},$$p{name},$$p{subType},$$p{atmosphereType},
					$$p{surfacePressureDec},$$p{gravityDec},$$p{surfaceTemperature},$$s{coord_x},$$s{coord_y},$$s{coord_z})."\r\n";
		}
	}
	
}
