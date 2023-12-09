#!/usr/bin/perl
use strict;
use lib "/home/bones/perl";
use DB qw(db_mysql);

for (my $day=28; $day>0; $day--) {
	for (my $n=5; $n>=0; $n--) {
		my $n2 = $n+1;
		my $add = 0;
		if ($n2>=6) {
			$n2 = 0;
			$add = 1;
		}
		my $d1 = sprintf("2021-02-%02u %02u:00:00",$day,$n*4);
		my $d2 = sprintf("2021-02-%02u %02u:00:00",$day+$add,$n2*4);
		print "$d1 - $d2\n";
		db_mysql('elite',"update systems set eddn_updated=updated where date_added>=? and date_added<? and eddn_updated is null",[($d1,$d2)]);
	}
}
