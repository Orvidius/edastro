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

my @table = ();

my @sys = db_mysql('elite',"select distinct systemId64 sID,coord_x x,coord_y y,coord_z z,systems.name as sysname,region regionID ".
		"from stars,systems where stars.systemId64=systems.id64 and stars.systemId64>0 and solarMasses>0 and stars.deletionState=0 and systems.deletionState=0 ".
		"group by systemId64 having count(*)>1");

warn "Found ".int(@sys)." systems with multiple stars.\n";

my @list;

foreach my $s (@sys) {
	my $sysID = $$s{sID};

	next if (!$sysID);

	my @planets = db_mysql('elite',"select planetID from planets where systemId64=$sysID");

	next if (@planets);

	my @rows = db_mysql('elite',"select name,subType,solarMasses mass from stars where systemId64=$sysID and deletionState=0");
	my $stars = int(@rows);

	my %star = ();
	
	foreach my $r (@rows) {
		if ($$r{mass}) { 
			$star{$$r{name}} = $r;
		}
	}

	foreach my $name (keys %star) {
		if ($name =~ /^([\w\d\s\-\.\']+\S)\s+([\w\d])$/) {
			my $parent = $1;
			my $child = $2;

			if (exists($star{$parent}) && $star{$name}{mass}*25<$star{$parent}{mass}) {
				my %hash = (%{$star{$name}}, %$s);
				$hash{parent} = $parent;
				$hash{pSM} = $star{$parent}{mass};
				$hash{pST} = $star{$parent}{subType};
				$hash{planets} = int(@planets);
				$hash{stars} = $stars;

				push @list, \%hash;
			}
		}
	}
}

print make_csv('Star','Type','Solar Masses','Parent','Parent Type','Parent Solar Masses',
	'System Name','System Stellar Bodies','System Planetary Bodies','Coord X','Coord Y','Coord Z','RegionID')."\r\n";

my $count = 0;
foreach my $r (sort { $$a{name} cmp $$b{name} } @list) {

	print make_csv($$r{name},$$r{subType},$$r{mass},$$r{parent},$$r{pST},$$r{pSM},$$r{sysname},$$r{stars},$$r{planets},$$r{x},$$r{y},$$r{z},$$r{regionID})."\r\n";

	$count++;
}
warn "$count found\n";



