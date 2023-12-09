#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

use POSIX qw(floor);

############################################################################

show_queries(0);

warn "Low pressure...\n";
my @rows = db_mysql('elite',"select *,p.id pid,s.name systemName,p.name planetName,r.name regionName,s.coord_x cX,s.coord_y cY,s.coord_z cZ from ".
			"planets p,systems s, regions r, regionmap rm where s.id64=p.systemId64 and rm.region=r.id and rm.coord_x=floor(s.coord_x/10) and rm.coord_z=floor(s.coord_z/10) ".
			"and atmosphereType like '\%thick\%' and surfacePressure is not null and surfacePressure>0 and s.deletionState=0 and p.deletionState=0 ".
			"order by surfacePressure limit 1000");

warn "High pressure...\n";

push @rows, db_mysql('elite',"select *,p.id pid,s.name systemName,p.name planetName,r.name regionName,s.coord_x cX,s.coord_y cY,s.coord_z cZ from ".
			"planets p,systems s, regions r, regionmap rm where s.id64=p.systemId64 and rm.region=r.id and rm.coord_x=floor(s.coord_x/10) and rm.coord_z=floor(s.coord_z/10) ".
			"and atmosphereType like '\%thick\%' and surfacePressure is not null and surfacePressure>0 and s.deletionState=0 and p.deletionState=0 ".
			"order by surfacePressure desc limit 1000");

warn "Saving...\n";
print make_csv('Estimated Region','X','Y','Z','id64','System','Planet','Type','Atmosphere','Surface Pressure','Surface Gravity','Atmosphere Composition')."\r\n";

foreach my $r (@rows) {
	my $comp = '';

	$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{planetID} = 0 if (!defined($$r{planetID}));

	my @atmos = db_mysql('elite',"select * from atmospheres where planet_id=?",[($$r{planetID})]);
	foreach my $a (@atmos) {
		foreach my $k (keys %$a) {
			next if ($k eq 'planet_id');
			$comp .= ",$k(".sprintf("%.02f",$$a{$k})."%)" if ($$a{$k});
		}
	}
	$comp =~ s/^,//;
	print make_csv($$r{regionName},$$r{cX},$$r{cY},$$r{cZ},$$r{id64},$$r{systemName},$$r{planetName},$$r{subType},$$r{atmosphereType},$$r{surfacePressure},$$r{gravity},$comp)."\r\n";
}

warn "Done.\n";

