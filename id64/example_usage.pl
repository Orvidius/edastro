#!/usr/bin/perl

use lib '.';
use EliteTools::ID64;

my $id = "10477373803";
my @ids = (
	"10477373803",  #sol
	"164098653", #Achenar
	"3932277478106", #Shinrarta Dezhra
	"3238296097059", #Colonia
	"20578934",  #Sagittarius A*
	"82376148378", #VonRictofen's Rescue
	"1796439222828", #Systimbao SJ-R e4-418
	"252421771436682", #Ogairy XX-X c15-918
	"1900447582075",  #Jellyfish Sector EL-Y d55
);

print "id64: (sector) -> [boxel} {masscode} Est:(Estimated coords) +/-error margin {expected boxel name}\n";
foreach my $id(@ids)
	{
	my $id64 = EliteTools::ID64->new($id);
	my $est_coord = $id64->get_coordinates(1);
	printf("%s: (%s,%s,%s) -> [%s,%s,%s] {%s} Est:(%s,%s,%s) +/- %sLY {%s}\n",
		$id64->id64, $id64->sector->x, ,$id64->sector->y, $id64->sector->z, 
		$id64->boxel->x, $id64->boxel->y, $id64->boxel->z,$id64->masscode_letter,
		$est_coord->x, $est_coord->y, $est_coord->z,$id64->boxel_size / 2,
		$id64->suggest_boxel_name);
	}



