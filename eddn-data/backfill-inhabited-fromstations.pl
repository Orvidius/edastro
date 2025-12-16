#!/usr/bin/perl
use strict;

use JSON;

use utf8;
use feature qw( unicode_strings );

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);
use ATOMS qw(date2epoch epoch2date btrim parse_csv);

process_file("/home/bones/elite/stations.json.old");

# {"id":53599,"marketId":3229189888,"type":"Outpost","name":"Rukavishnikov Hangar","distanceToArrival":18187,"allegiance":"Federation","government":"Corporate","economy":"Refinery","secondEconomy":null,"haveMarket":false,"haveShipyard":false,"haveOutfitting":false,"otherServices":[],"updateTime":{"information":"2017-11-07 10:08:35","market":null,"shipyard":null,"outfitting":null},"systemId":8713,"systemId64":663329196387,"systemName":"4 Sextantis","commodities":null,"ships":null,"outfitting":null}

sub process_file {
	my $fn = shift;

	open(my $fh,"<",$fn) or die "Can't read from $fn $!";
	while (my $line = <$fh>) {
		#eval {

			my ($timestamp,$id64,$type) = (undef,undef,undef);
			my $inhabited = 0;

			if ($line =~ /"information"\s*:\s*"(\d{4}\-\d{2}\-\d{2}) (\d{2}:\d{2}:\d{2})"/) {
				$timestamp = "$1 $2";
			}

			if ($line =~ /"type"\s*:\s*"([^"]+)"/) {
				$type = $1;
			}

			if ($line =~ /"systemId64"\s*:\s*(\d+)/) {
				$id64 = $1;
			}

			if ($id64 && $timestamp && $type && $type !~ /carrier|fleet|mega/i) {
				print "$id64 = $type / $timestamp\n";

				db_mysql('elite',"update systems set inhabited=?,updated=updated where id64=? and (inhabited is null or inhabited>?)",[($timestamp,$id64,$timestamp)]);
			}
		#};
	}
	close $fh;
}



