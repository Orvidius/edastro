#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql);

use lib "/home/bones/elite";
use EDSM qw(id64_subsector id64_sectorcoords id64_sectorID);



my @rows = db_mysql('elite',"select name,ID from sectors where id64sectorID is null");

foreach my $r (@rows) {
	my @sys = db_mysql('elite',"select id64 from systems where name like '$$r{name}\%' and sectorID=? and id64 is not null and deletionState=0 limit 1",[($$r{ID})]);

	if (@sys) {
		my $id64 = ${$sys[0]}{id64};
		my $sectorID = id64_sectorID($id64);

		print "$$r{name} = $sectorID\n";

		db_mysql('elite',"update sectors set id64sectorID=?,updated=updated where ID=?",[($sectorID,$$r{ID})]);
	}
}


print "\n";

