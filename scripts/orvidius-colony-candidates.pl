#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

use POSIX qw(floor);
use POSIX ":sys_wait_h";

############################################################################

my $debug		= 0;
my $allow_scp		= 1;

############################################################################

my @rows = db_mysql('elite',"select * from systems,logs where cmdrID=1 and firstDiscover>0 and systemId64=id64 and colonyCandidate>0 order by coord_z");

warn int(@rows)." stations pulled.\n";

print make_csv('id64','Name','Main Star Type','Sol Distance','FSS Percent','Planet Score','Stars','Planets','Landables','Terraformables',
			'Earth-like Worlds','Ammonia Worlds','Water Worlds','regionID','X','Y','Z')."\r\n";

foreach my $r (@rows) {
	print make_csv($$r{id64},$$r{name},$$r{mainStarType},$$r{sol_dist},100*($$r{FSSprogress}+0),$$r{planetscore},$$r{numStars},$$r{numPlanets},
		$$r{numLandables},$$r{numTerra},$$r{numELW},$$r{numAW},$$r{numWW},$$r{region},$$r{coord_x},$$r{coord_y},$$r{coord_z})."\r\n";
}
