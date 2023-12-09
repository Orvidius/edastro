#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

use IO::Handle;

############################################################################

show_queries(0);

my $debug               = 0;

############################################################################

my $min_date = '';
my $max_date = '';

my @rows = db_mysql('elite',"select min(updateTime) date from systems where updateTime is not null and updateTime>='2014-01-01 00:00:00'");
if (@rows) {
	$min_date = ${$rows[0]}{date};
} else {
	die "Couldn't get min date.\n";
}

my @rows = db_mysql('elite',"select max(updateTime) date from systems where updateTime is not null");
if (@rows) {
	$max_date = ${$rows[0]}{date};
} else {
	die "Couldn't get max date.\n";
}

$min_date =~ s/\s.*$//;
$max_date =~ s/\s.*$//;

my $min_epoch = date2epoch("$min_date 12:00:00"); # Whole days only, so using noon to convert back into dates
my $max_epoch = date2epoch("$max_date 12:00:00");

my $epoch = $min_epoch;
my $last_max_ID = 0;

warn "Scanning $min_date -> $max_date ($min_epoch - $max_epoch)\n";

#exit;

print make_csv('Date','Max EDSM ID',"Systems older than previous day's maximum","Total systems","Percent older","Purged and Re-Added Later")."\r\n";

my $n = 0;

while ($epoch < $max_epoch) {
	my $date = epoch2date($epoch);
	$date =~ s/\s+.*//;

	my $next = epoch2date($epoch+86400);
	$next =~ s/\s+.*//;

	my $new_max_ID = $last_max_ID;
	my $older = 0;
	my $new = 0;
	my $re_adds = 0;

	#warn "Pulling $date -> $next\n";

	my @rows = db_mysql('elite',"select edsm_id from systems where updateTime is not null and updateTime>='2014-01-01 00:00:00' and updateTime>=? and updateTime<? order by edsm_id",[("$date 00:00:00","$next 00:00:00")]);

	foreach my $r (sort { $$a{edsm_id} <=> $$b{edsm_id} } @rows) {
		$re_adds++ if ($$r{edsm_id} > $new_max_ID && $$r{edsm_id}-$new_max_ID >= 100000);
		$new_max_ID = $$r{edsm_id} if ($$r{edsm_id} > $new_max_ID && $$r{edsm_id}-$new_max_ID < 100000);
		$older++ if ($n && $$r{edsm_id} < $last_max_ID);
		$new++;
	}

	my $percent = 0;
	$percent = sprintf("%0.03f",100*$older/$new) if ($new);

	warn "$date: [$new_max_ID] $older ($new) $percent <$re_adds>\n";

	print "\"$date\",$new_max_ID,$older,$new,\"$percent\",$re_adds\r\n";

	$last_max_ID = $new_max_ID;
	$n++;
	$epoch += 86400;
}


############################################################################



