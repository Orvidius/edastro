#!/usr/bin/perl
use strict;
$|=1;

use lib "/home/bones/perl";
use DB qw(rows_mysql db_mysql show_queries);
use ATOMS qw(make_csv);


my %region = ();
my %id64 = ();
        
my @rows = db_mysql('elite',"select * from regions");
foreach my $r (@rows) {
	$region{$$r{id}} = $$r{name};
}

print make_csv('Region',"System ID64","System EDSM ID","System Name","Body ID64","Body EDSM ID","Body Name","Body SubType",'Variable','Value',"Reason for Suspicion")."\r\n";

#show_queries(1);

find_bad_data('both','Invalid orbital eccentricity','orbitalEccentricity',"orbitalEccentricity>=1",[()]);
find_bad_data('planets','Icy Body with large radius','radius',"subType='Icy body' and radius>32000",[()]);
find_bad_data('planets','Landable with unusually high gravity','gravity',"isLandable=1 and gravity>12",[()]);
find_bad_data('planets','Landable with unusual body type','subType',"isLandable=1 and subType not in ('High metal content world','Icy body','Metal-rich body','Rocky body','Rocky Ice world')",[()]);

#find_bad_data('planets','Landable with too much surface pressure','surfacePressure',"isLandable=1 and surfacePressure>=0.001",[()]); # Horizons
find_bad_data('planets','Landable with too much surface pressure','surfacePressure',"isLandable=1 and surfacePressure>=0.1",[()]); # Odyssey

#find_bad_data('planets','Periapsis below 1 km','semiMajorAxisDec',"149597870700*semiMajorAxisDec*(1-orbitalEccentricityDec) < 1000 and semiMajorAxisDec is not null and orbitalEccentricityDec is not null and orbitalEccentricityDec<1",[()]);
	# parents is not null and (parents like 'Star:%' or parents like 'Planet:%')

if (@ARGV) {
        my @systems = keys(%id64);
        
        while (@systems) {
                my @list = splice @systems, 0, 80;
                system('/home/bones/elite/edsm/get-system-bodies.pl',@list);
                sleep 1;
        }
}

sub find_bad_data {
	my ($table_choice,$reason,$var,$whereClause,$paramref) = @_;

	my @tables = ($table_choice);
	@tables = ('stars','planets') if ($table_choice eq 'both');

	foreach my $table (@tables) {
		warn "$table: $reason ($whereClause)\n";

		my $ref = rows_mysql('elite',"select region,systemId64,systemId,systems.name systemName,bodyId64,edsmID,$table.name bodyName,".
				"subType,$var from $table,systems where $table.systemId64=systems.id64 and ($whereClause) ".
				"and systems.deletionState=0 and $table.deletionState=0 order by systemName,bodyName",$paramref);

		warn "\t^ ".int(@$ref)." found.\n";
	
		foreach my $r (@$ref) {
			print make_csv($region{$$r{region}},$$r{systemId64},$$r{systemId},$$r{systemName},$$r{bodyId64},$$r{edsmID},
						$$r{bodyName},$$r{subType},$var,$$r{$var},$reason)."\r\n";
			$id64{$$r{systemId64}}=1;
		}
	}
}



