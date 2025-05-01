#!/usr/bin/perl
use strict;

use JSON;

use utf8;
use feature qw( unicode_strings );

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);
use ATOMS qw(date2epoch epoch2date btrim parse_csv);

#foreach my $path ('archive','.') {
foreach my $path ('archive','.') {
	opendir DIR, $path;
	while (my $fn = readdir DIR) {
		if ($fn =~ /docked.jsonl/) {
			process_file("$path/$fn");
		}
	}
	closedir DIR;
}

sub process_file {
	my $fn = shift;

	warn "$fn\n";

	my $cat = $fn =~ /.gz$/ ? 'zcat' : 'cat';

	open DATA, "$cat $fn |";
	foreach my $line (<DATA>) {
		eval {
			# "timestamp" : "2025-04-01T03:59:39Z",
			# "MarketID" : 3223810560,
			# "SystemAddress" : 13865899009465,


			next if ($line =~ /"StationType"\s*:\s*"FleetCarrier"/);

			my ($services,$id64,$marketID) = (undef,undef,undef);
			my %have = ();

			if ($line =~ /"StationServices"\s*:\s*\[([^\]]+)\]/) {
				my @list = split /,\s*/, $1;
				foreach my $s (sort @list) {
					if ($s =~ /"(\w+)"/) {
						$services .= ",$1";
					}
				}
				$services =~ s/^,+//s;
				
				$have{haveOutfitting} = $services =~ /outfitting/ ? 1 : 0;
				$have{haveShipyard} = $services =~ /shipyard/ ? 1 : 0;
				$have{haveMarket} = $services =~ /commodities/ ? 1 : 0;
				$have{haveColonization} = $services =~ /coloni[sz]ation/ ? 1 : 0;

			}

			if ($line =~ /"MarketID"\s*:\s*(\d+)/) {
				$marketID = $1;
			}

			if ($line =~ /"SystemAddress"\s*:\s*(\d+)/) {
				$id64 = $1;
			}


			if ($id64 && $marketID && $services) {
				print "$marketID/$id64 = $services\n";

				if ($have{haveColonization} == 1) {
					db_mysql('elite',"update stations set services=?,updated=updated,haveOutfitting=?,haveShipyard=?,haveMarket=?,haveColonization=? where (services is null or services not like \"\%colonisation\%\") and marketID=? and systemId64=?",[($services,$have{haveOutfitting},$have{haveShipyard},$have{haveMarket},$have{haveColonization},$marketID,$id64)]);
				} else {
					db_mysql('elite',"update stations set services=?,updated=updated,haveOutfitting=?,haveShipyard=?,haveMarket=?,haveColonization=? where services is null and marketID=? and systemId64=?",[($services,$have{haveOutfitting},$have{haveShipyard},$have{haveMarket},$have{haveColonization},$marketID,$id64)]);
				}
			}
		};
	}
	close DATA;
}



