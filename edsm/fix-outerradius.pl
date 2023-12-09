#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);


foreach my $type ('rings','belts') {
	foreach my $table ('planets','stars') {
		next if ($type eq 'belts' && $table eq 'planets');

		print "$table.$type\n";
	
		my $idf = $table eq 'planets' ? 'planetID' : 'starID';
		my $isS = $table eq 'planets' ? 0 : 1;
	
		my @rows = db_mysql('elite',"select distinct planet_id from $type,$table where char_length(innerRadius) - char_length(trim(trailing '0' from innerRadius))>=4 and char_length(outerRadius) - char_length(trim(trailing '0' from outerRadius))>=4 and outerRadius>10000 and planet_id=$idf and isStar=$isS and edsmID is null");
	
		foreach my $r (@rows) {
			my $id = $$r{planet_id};
	
			my @rings = db_mysql('elite',"select * from $type where planet_id=? and isStar=? and char_length(innerRadius) - char_length(trim(trailing '0' from innerRadius))>=4 and char_length(outerRadius) - char_length(trim(trailing '0' from outerRadius))>=4",[($id,$isS)]);

			foreach my $ring (@rings) {
				print "$type.$$ring{id}: $$ring{name} = $$ring{innerRadius}, $$ring{outerRadius}\n";
				my $sql = "update $type set innerRadius=innerRadius/1000,outerRadius=outerRadius/1000 where id=?";
				print "\tSQL> $sql [$$ring{id}]\n\n";
				#db_mysql('elite',$sql,[($$ring{id})]);
			}
#last;
		}
#last;
	}
#last;
}
