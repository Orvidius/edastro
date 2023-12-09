#!/usr/bin/perl
use strict; $|=1;

################################################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql);
use ATOMS qw(date2epoch);
use lib "/home/bones/elite";
use EDDN qw(game_OK);

################################################################################################

my $debug = 0;
my $force = $ARGV[0];

################################################################################################

my @rows1 = db_mysql('elite',"select max(lastEvent) lastEvent from carriers");
die "Could not get max lastEvent\n" if (!@rows1);

my @rows2 = db_mysql('elite',"select max(eddn_date) lastEvent from planets");
die "Could not get max lastEvent\n" if (!@rows2);

my @rows3 = db_mysql('elite',"select max(eddn_date) lastEvent from stars");
die "Could not get max lastEvent\n" if (!@rows3);

my @rows4 = db_mysql('elite',"select max(eddn_date) lastEvent from systems");
die "Could not get max lastEvent\n" if (!@rows4);

my $lastepoch = 0;

foreach my $e (date2epoch(${$rows1[0]}{lastEvent}),date2epoch(${$rows2[0]}{lastEvent}),date2epoch(${$rows3[0]}{lastEvent}),date2epoch(${$rows4[0]}{lastEvent})) {
	print "epoch: $e\n";
	$lastepoch = $e if ($e and $e>$lastepoch);
}
my $time = time;

print "comparing $time <-> $lastepoch, difference = ".($time-$lastepoch)."\n";

my $restarting = 0;


open PS, "/usr/bin/ps awx | /usr/bin/grep listener |";
my @lines = <PS>;
close PS;

while (@lines) {
	my $line = shift @lines;
	#22945 ?        Ssl    0:01 perl /home/bones/elite/listener-eddn.pl cron
	my $pid = 0;
	my $epoch = 0;

	if ($line =~ /^\s*(\d+).+\sperl\s\S+\/listener-eddn.pl\s+cron/) {
		$pid = $1;
		print "Found: $pid\n" if ($debug);
	} elsif ($line =~ /^\s*(\d+).+\d+\s+listener-eddn.pl\s+(\d+)/) {
		$pid = $1;
		$epoch = $2;
		print "Found: $pid (epoch:$epoch)\n" if ($debug);
		print "comparing $time <-> $epoch, difference = ".($time-$epoch)."\n";
	}

	if ($pid && ($force || ($time-$lastepoch > 300) || ($epoch && $time - $epoch > 20))) {

		if ($force || game_OK()) {
			print "Killing $pid\n";
			system("/usr/bin/kill $pid >/dev/null 2>\&1") if (!$debug);
			sleep 1;
			system("/usr/bin/kill -9 $pid >/dev/null 2>\&1") if (!$debug);
			sleep 1;
			$restarting = 1;
		}
	}
}


#if ($restarting) {
#	print "Restarting 'listener-eddn.pl cron'\n";
	system("/home/bones/elite/listener-eddn.pl cron > /dev/null 2>\&1 \&") if (!$debug);
#}


################################################################################################


