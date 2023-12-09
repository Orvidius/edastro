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

my @rows = db_mysql('elite',"select id64,edsm_id,name,IFNULL(elw_num,0) ELWs,IFNULL(ww_num,0) WWs,".
	"IFNULL(aw_num,0) AWs,IFNULL(elw_num,0)*2+IFNULL(aw_num,0)*1.75+IFNULL(ww_num,0) as score,coord_x,coord_y,coord_z,region from systems ".
	"left join (select systemId64,count(*) as elw_num from planets where subType='Earth-like world' and deletionState=0 group by systemId64) as elw on elw.systemId64=systems.id64 ".
	"left join (select systemId64,count(*) as ww_num from planets where subType='Water world' and deletionState=0 group by systemId64) as ww on ww.systemId64=systems.id64 ".
	"left join (select systemId64,count(*) as aw_num from planets where subType='Ammonia world' and deletionState=0 group by systemId64) as aw on aw.systemId64=systems.id64 ".
	"where IFNULL(elw_num,0)*2+IFNULL(aw_num,0)*1.75+IFNULL(ww_num,0)>=6 order by score desc,name");

print make_csv('ID64 SystemAddress','EDSM ID','System','Earth-like worlds','Water worlds','Ammonia worlds','Score',
			'Coord_x','Coord_y','Coord_z','EDSM Discoverers','RegionID')."\r\n";

my $count = 0;
foreach my $r (@rows) {

	my %cmdrs = ();

	#next if ($$r{name} !~ /(\S+\s+)+\w\w\-\w\s+\w\d*-\d+\s*$/);
	next if ($$r{name} eq 'Delphi');

	my @rows2 = db_mysql('elite',"select commanderName from planets where systemId64='$$r{id64}' and subType in ('Earth-like world','Water world','Ammonia world')");
	foreach my $r2 (@rows2) {
		$cmdrs{$$r2{commanderName}} = 1 if ($$r2{commanderName} =~ /\S/);
	}

	my $commanders = join(';',sort { uc($a) cmp uc($b) } keys %cmdrs);
	$commanders =~ s/^\s*;//;

	print make_csv($$r{id64},$$r{edsm_id},$$r{name},$$r{ELWs},$$r{WWs},$$r{AWs},$$r{score},$$r{coord_x},$$r{coord_y},$$r{coord_z},$commanders,$$r{region})."\r\n";

	eval {
		db_mysql('elite',"update systems set planetscore=? where id64=? and planetscore!=?",[($$r{score},$$r{id64},$$r{score})]);
	};

	$count++;
}
warn "$count found\n";



