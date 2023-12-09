#!/bin/perl
use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my $debug = 0;

my @rows = db_mysql('elite_old',"select * from carrierlog where logdate>'2020-07-20 00:00:00'");

foreach my $r (@rows) {

	my @check = db_mysql('elite',"select ID from carrierlog where callsign=? and systemId64=? and logdate=?",[($$r{callsign},$$r{systemId64},$$r{logdate})]);

	if (!@check) {
		#print "\n> carrierlog ($$r{callsign},$$r{logdate},$$r{systemId64},$$r{systemName},$$r{body},$$r{coord_x},$$r{coord_y},$$r{coord_z})\n";

		mysql_do('elite',"insert into carrierlog (callsign,logdate,systemId64,systemName,body,coord_x,coord_y,coord_z) values (?,?,?,?,?,?,?,?)",
				[($$r{callsign},$$r{logdate},$$r{systemId64},$$r{systemName},$$r{body},$$r{coord_x},$$r{coord_y},$$r{coord_z})]);
	}
}


my @rows = db_mysql('elite_old',"select * from carriers where updated>'2020-07-20 00:00:00'");

foreach my $r (@rows) {
	my @rows2 = db_mysql('elite',"select * from carriers where callsign=?",[($$r{callsign})]);

	if (@rows2) {
		my $r2 = shift @rows2;
		my $changed = 0;
		foreach my $k (qw(lastEvent lastMoved systemId64 systemName coord_x coord_y coord_z)) {
			$changed = 1 if ($$r{$k} ne $$r2{$k});
		}
		
		if ($changed && $$r{lastUpdate} gt $$r2{lastUpdate}) {	# Only update this row if the old DB's data is newer than in the new DB

			my $update = '';

			foreach my $k (qw(name callsign_old created lastEvent lastMoved systemId64 systemName distanceToArrival 
					services coord_x coord_y coord_z commander isDSSA isIGAU wasDSSA converted note)) {

				if (!defined($$r{$k})) {
					$update .= ",$k=NULL";
				} else {
					$update .= ",$k='$$r{$k}'";
				}
			}
			$update =~ s/^,+//s;

			mysql_do('elite',"update carriers set $update where callsign=?",[($$r{callsign})]);
		}

	} else {
		mysql_do('elite',"insert into carriers (name,marketID,callsign,callsign_old,created,lastEvent,lastMoved,systemId64,systemName,distanceToArrival,".
			"services,coord_x,coord_y,coord_z,commander,isDSSA,isIGAU,wasDSSA,converted,note) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
			[($$r{name},$$r{marketID},$$r{callsign},$$r{callsign_old},$$r{created},$$r{lastEvent},$$r{lastMoved},$$r{systemId64},$$r{systemName},$$r{distanceToArrival},
			$$r{services},$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{commander},$$r{isDSSA},$$r{isIGAU},$$r{wasDSSA},$$r{converted},$$r{note})]);
	}
}

my @rows = db_mysql('elite_old',"select * from carrierdockings where docked>'2020-07-20 00:00:00'");

foreach my $r (@rows) {
	my @check = db_mysql('elite',"select * from carrierdockings where callsign=? and docked=?",[($$r{callsign},$$r{docked})]);

	if (!@check) {
		#print "\n> carrierdockings ($$r{callsign},$$r{docked})\n";

		mysql_do('elite',"insert into carrierdockings (callsign,docked) values (?,?)", [($$r{callsign},$$r{docked})]);
	}
}


exit;

sub mysql_do {
	my $sql = 'SQL:';

	foreach my $s (@_) {
		if (ref($s) eq 'ARRAY') {
			$sql .= " [('".join("','",@$s)."')]" if (@$s);
			$sql .= " [()]" if (!@$s);
		} else {
			$sql .= ' '.$s;
		}
	}

	warn "$sql\n";
	return db_mysql(@_) if (!$debug);
}

