#!/usr/bin/perl
use strict;

#############################################################################

use lib "/home/bones/perl";
use ATOMS qw(epoch2date date2epoch);
use DB qw(rows_mysql db_mysql);

#############################################################################


print "Sol Distance:\n";
db_mysql('elite',"update systems set sol_dist=sqrt(pow(systems.coord_x,2)+pow(systems.coord_y,2)+pow(systems.coord_z,2)) where sol_dist is null and coord_x is not null and coord_y is not null and coord_z is not null");

print "Added Dates\n";
#db_mysql('elite',"update systems set date_added=cast(edsm_date as date) where date_added is null and edsm_date is not null");
db_mysql('elite',"update systems set date_added=edsm_date where date_added is null and edsm_date is not null");
db_mysql('elite',"update systems set day_added=date_added where day_added is null or day_added!=cast(date_added as date)");

print "Mass Codes\n";
while (my @rows = db_mysql('elite',"select ID,id64 from systems where masscode is null and deletionState=0 and id64 is not null and id64>0 limit 500")) {
	my %hash = ();

	foreach my $r (@rows) {
		my $mc = chr(ord('a')+($$r{id64} & 7));

		$hash{$mc}{$$r{ID}} = 1;
	}

	foreach my $mc (keys %hash) {
		next if (!keys %{$hash{$mc}});

		my $list = join(',',keys %{$hash{$mc}});

		if ($list) {
			db_mysql('elite',"update systems set masscode=? where ID in ($list)",[($mc)]);
		}
	}
	print ".";
}
print "\n";
