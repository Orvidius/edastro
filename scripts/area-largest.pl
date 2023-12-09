#!/usr/bin/perl
use strict; $|=1;

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql);
use ATOMS qw(make_csv);

print make_csv('Ring/Belt','Type','Name','Outer Radius','Inner Radius','Area','Mass','Parent Type','Parent Name',
		'SystemAddress ID64','System Name','Region','X','Y','Z')."\r\n";

foreach my $table (qw(rings belts)) {
	warn uc($table)."\n";

	my $rows = rows_mysql('elite',"select *,(pi()*pow(outerRadius,2))-(pi()*pow(innerRadius,2)) as area from $table order by area desc limit 150");

	my $n = 0;
	foreach my $r (@$rows) {
		my ($bodytype,$idtype) = ('planets','planetID');
		($bodytype,$idtype) = ('stars','starID') if ($$r{isStar});

		my @bod = db_mysql('elite',"select *,$bodytype.name as bodyname,systems.name as systemname,regions.name as regionname ".
				"from $bodytype,systems,regions where $idtype=? and systemId64=id64 and regions.id=region and ".
				"$bodytype.deletionState=0 and systems.deletionState=0",[($$r{planet_id})]);

		if (@bod) {
			my $b = shift @bod;

			print make_csv(uc($table),$$r{type},$$r{name},$$r{outerRadius},$$r{innerRadius},$$r{area},$$r{mass},
				$$b{subType},$$b{name},$$b{systemId64},$$b{systemname},$$b{regionname},$$b{coord_x},$$b{coord_y},$$b{coord_z})."\r\n";

			$n++;
			last if ($n>=100);
		}
	}
}
