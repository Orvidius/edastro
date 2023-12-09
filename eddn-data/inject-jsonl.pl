#!/usr/bin/perl
use strict; $|=1;

my $debug = 0;

my $path = '/home/bones/elite/eddn-data/queue';
my $dir = '';


die "Usage: $0 <json_1> [json_2...]\n" if (!@ARGV);

opendir DIR, $path;
while (my $d = readdir DIR) {
	if ($d =~ /^2/ && -d "$path/$d") {
		$dir = "$path/$d";
		last;
	}
}
closedir DIR;

die "No path found\n" if (!$dir);

my $n = 0;

foreach my $fn (@ARGV) {
	if (-e $fn) {
		open DATA, "<$fn";
		while (my $json = <DATA>) {
			if ($json =~ /^\s*\{/) {
				my $date = time.'';
				my $event = '';

				if ($json =~ /"gatewayTimestamp"\s?:\s?"(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/) {
					$date = "$1$2$3-$4$5$6";
				}

				if ($json =~ /"event"\s?:\s?"([^"]+)"/) {
					$event = $1;
				} else {
					next;
				}

				$n++;
				my $nn = sprintf("%08u",$n);

				my $out = "$dir/$date-injection-$nn.$event";

				print "-> $out\n";

				if (!$debug) {
					open TXT, ">$out";
					print TXT $json;
					close TXT;
				}
			}
		}
		close DATA;
	} else {
		warn "$fn not found\n";
	}
}
