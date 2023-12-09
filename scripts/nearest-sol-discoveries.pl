#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch);

use Image::Magick;

############################################################################

show_queries(0);

my $verbose	= 1;
my $do_anyway	= 0;

############################################################################

my $today = epoch2date(time);
$today =~ s/\s+.+$//s;

warn "TODAY: $today\n";
#exit;


print "\"ID64\",\"EDAstro ID\",\"EDSM ID\",\"Name\",\"Sol Distance\",\"Coord_x\",\"Coord_y\",\"Coord_z\",\"date\"\r\n";

my @dates = db_mysql('elite',"select distinct day_added from systems where day_added is not null and day_added>='2010-01-01' ".
				"group by day_added order by day_added");


foreach my $d (@dates) {
	my @dist = ();
	my @rows = ();

	next if ($$d{day_added} eq $today);

	#warn "$$d{day_added}\n";

	my @check = ();
	@check = db_mysql('elite',"select nearestSolDist as SolDist,nearestSolId64 from submissions where subDate=?",[($$d{day_added})]) if (!$do_anyway);

	my $timediff = time - date2epoch($d);

	if ($do_anyway || !@check || (@check && !${$check[0]}{SolDist}) || $timediff < 86400*7) {	# Allow recalc for last few days, otherwise fill in blanks

		@dist = db_mysql('elite',"select min(sol_dist) SolDist from systems where day_added=? and deletionState=0 and sol_dist is not null ".
					"and sol_dist>0 and coord_x is not null and coord_y is not null and coord_z is not null",[($$d{day_added})]);

		my $soldist = undef;
		$soldist = ${$dist[0]}{SolDist} if (@dist);
	
		next if (!defined($soldist));
		#warn "$$d{day_added}: $soldist ly\n";
	
		@rows = db_mysql('elite',"select ID,id64,edsm_id,name,coord_x,coord_y,coord_z,sol_dist,day_added from systems ".
			"where day_added=? and sol_dist<=? and deletionState=0 order by sol_dist limit 1", [($$d{day_added},$soldist+0.001)]);

		db_mysql('elite',"update submissions set nearestSolId64=?,nearestSolDist=? where subDate=?",[(${$rows[0]}{id64},${$rows[0]}{sol_dist},$$d{day_added})]) if (@check);
		db_mysql('elite',"insert into submissions (subDate,nearestSolId64,nearestSolDist) values (?,?,?)",[($$d{day_added},${$rows[0]}{id64},${$rows[0]}{sol_dist})]) if (!@check);
	
	} elsif (@check) {
		my $id64 = ${$check[0]}{nearestSolId64};
		
		@rows = db_mysql('elite',"select ID,id64,edsm_id,name,coord_x,coord_y,coord_z,sol_dist,day_added from systems ".
			"where id64=? and deletionState=0", [($id64)]);
	}

	foreach my $r (@rows) {
		my $distance = sprintf("%.02f",$$r{sol_dist});
		warn "$$r{day_added}: ($$r{id64}) $$r{name} / $$r{sol_dist}\n" if ($verbose);
		print "\"$$r{id64}\",\"$$r{ID}\",\"$$r{edsm_id}\",\"$$r{name}\",\"$distance\",\"$$r{coord_x}\",\"$$r{coord_y}\",\"$$r{coord_z}\",\"$$r{day_added}\"\r\n";
	}
}


