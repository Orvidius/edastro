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

my %value = ();
$value{'Earth-like world'}	= 2;
$value{'Water world'}		= 1;
$value{'Ammonia world'}		= 1.75;

my $count = 0;
my $done = 0;

while (!$done) {
#	my $rows = rows_mysql('elite',"select id64,name,IFNULL(elw_num,0) ELWs,IFNULL(ww_num,0) WWs,".
#	"IFNULL(aw_num,0) AWs,IFNULL(elw_num,0)*2+IFNULL(aw_num,0)*1.75+IFNULL(ww_num,0) as score,coord_x,coord_y,coord_z from systems ".
#	"left join (select systemId64,count(*) as elw_num from planets where subType='Earth-like world' and deletionState=0 group by systemId64) as elw on elw.systemId64=systems.id64 ".
#	"left join (select systemId64,count(*) as ww_num from planets where subType='Water world' and deletionState=0 group by systemId64) as ww on ww.systemId64=systems.id64 ".
#	"left join (select systemId64,count(*) as aw_num from planets where subType='Ammonia world' and deletionState=0 group by systemId64) as aw on aw.systemId64=systems.id64 ".
#	"where planetscore is null limit 1000");

	my $cols = columns_mysql('elite',"select id64 from systems where planetscore is null and id64>0 and deletionState=0 limit 500");

	if (ref($cols) ne 'HASH' || ref($$cols{id64}) ne 'ARRAY' || !@{$$cols{id64}}) {
		$done = 1;
		last;
	}

	print ".";

	my $list = join(',',@{$$cols{id64}});
	my %points = ();
	my %score = ();

	if (!$list) {
		$done = 1;
		last;
	}

	foreach my $type (keys %value) {
		my $rows = rows_mysql('elite',"select systemId64 as id64,count(*) as num from planets where subType=? and deletionState=0 and systemId64 in ($list) ".
				"group by systemId64",[($type)]);

		foreach my $r (@$rows) {
			next if (!$$r{id64});

			$points{$$r{id64}} += $value{$type} * $$r{num};
		}
	}

	foreach my $id64 (@{$$cols{id64}}) {
		my $num = $points{$id64}+0;
		$score{$num}{$id64} = 1;
	}

	foreach my $points (keys %score) {
		my @list = keys %{$score{$points}};
		$count += int(@list);
		my $ids = join(',',@list);
	
		eval {
			db_mysql('elite',"update systems set planetscore=?,updated=updated where id64 in ($ids) and planetscore is null",[($points)]);
		};
	}
}
print "\n$count updated\n";



