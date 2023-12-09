#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

############################################################################

my $path	= '/home/bones/elite/scripts';
my $test_prepend= ''; $test_prepend = 'test-' if ($0 =~ /\.pl\.new/);
my $monthfile	= "$path/${test_prepend}discovery-months.csv";
my $datefile	= "$path/${test_prepend}discovery-dates.csv";

show_queries(0);

my %yearmonthday = ();
my %yearmonth = ();
my %table = ();

my @rows = db_mysql('elite',"select * from submissions");
foreach my $r (@rows) {
	$table{$$r{subDate}} = $r;
}

foreach my $type (qw(adjsystems systems planets stars)) {
	my @rows = ();

	warn "Checking $type: \n";
	@rows = db_mysql('elite',"select date(adj_date) date,count(*) count from systems group by date(adj_date)") if ($type eq 'adjsystems');
	@rows = db_mysql('elite',"select date(date_added) date,count(*) count from systems group by date(date_added)") if ($type eq 'systems');

# We can go back to these when the dates are filled in:
	@rows = db_mysql('elite',"select date(date_added) date,count(*) count from planets group by date(date_added)") if ($type eq 'planets');
	@rows = db_mysql('elite',"select date(date_added) date,count(*) count from stars group by date(date_added)") if ($type eq 'stars');

#	@rows = db_mysql('elite',"select date(date_added) date,count(*) count from planets where date_added is not null and date_added>='2020-04-01 00:00:00' group by date(date_added)") if ($type eq 'planets');
#	push @rows,db_mysql('elite',"select date(updateTime) date,count(*) count from planets where date_added is null or date_added<'2020-04-01 00:00:00' group by date(updateTime)") if ($type eq 'planets');
#
#	@rows = db_mysql('elite',"select date(date_added) date,count(*) count from stars where date_added is not null and date_added>='2020-04-01 00:00:00' group by date(date_added)") if ($type eq 'stars');
#	push @rows, db_mysql('elite',"select date(updateTime) date,count(*) count from stars where date_added is null or date_added<'2020-04-01 00:00:00' group by date(updateTime)") if ($type eq 'stars');

	warn int(@rows)." $type dates found.\n\n";

	foreach my $r (@rows) {
		my $date = $$r{date};
		my $month = '';
		my $year = '';

		if ($date =~ /^((\d{4})\-\d{2})/) {
			$month = $1;
			$year = $2;
		}

		next if ($year < 2015);

		$yearmonthday{$date}{$type} += $$r{count} if ($date);

		$yearmonth{$month}{$type} += $$r{count} if ($month);
	}
}

open CSV, ">$datefile";
print CSV make_csv('Date','Systems','Stars','Planets','Average bodies per system','Average stars per system','Average planets per system',
			'Adjusted Systems','Adjusted Average Bodies','Adjusted Average Stars','Adjusted Average Planets')."\r\n";
foreach my $d (sort keys %yearmonthday) {
	my $avg_bodies = 0;
	$avg_bodies = sprintf("%.02f",($yearmonthday{$d}{stars}+$yearmonthday{$d}{planets})/$yearmonthday{$d}{systems}) if ($yearmonthday{$d}{systems});
	my $avg_stars = 0;
	$avg_stars = sprintf("%.02f",$yearmonthday{$d}{stars}/$yearmonthday{$d}{systems}) if ($yearmonthday{$d}{systems});
	my $avg_planets = 0;
	$avg_planets = sprintf("%.02f",$yearmonthday{$d}{planets}/$yearmonthday{$d}{systems}) if ($yearmonthday{$d}{systems});

	my $a_avg_bodies = 0;
	$a_avg_bodies = sprintf("%.02f",($yearmonthday{$d}{stars}+$yearmonthday{$d}{planets})/$yearmonthday{$d}{adjsystems}) if ($yearmonthday{$d}{adjsystems});
	my $a_avg_stars = 0;
	$a_avg_stars = sprintf("%.02f",$yearmonthday{$d}{stars}/$yearmonthday{$d}{adjsystems}) if ($yearmonthday{$d}{adjsystems});
	my $a_avg_planets = 0;
	$a_avg_planets = sprintf("%.02f",$yearmonthday{$d}{planets}/$yearmonthday{$d}{adjsystems}) if ($yearmonthday{$d}{adjsystems});

	print CSV make_csv($d,$yearmonthday{$d}{systems},$yearmonthday{$d}{stars},$yearmonthday{$d}{planets},
			$avg_bodies,$avg_stars,$avg_planets,$yearmonthday{$d}{adjsystems},$a_avg_bodies,$a_avg_stars,$a_avg_planets)."\r\n";

	my $timediff = time - date2epoch($d);

	my $ok = 0;
	if (!exists($table{$d})) {
		eval {
			db_mysql('elite',"insert into submissions (subDate,systems,stars,planets,adjsystems) values (?,?,?,?,?)",
				[($d,$yearmonthday{$d}{systems},$yearmonthday{$d}{stars},$yearmonthday{$d}{planets},$yearmonthday{$d}{adjsystems})]);
			$ok = 1;
		};
	}
	if (exists($table{$d}) || !$ok || $timediff <= 86400*7) {
		my $update = '';
		my @params = ();

		# only update with positive values, where none is present already, unless it's within 7 days (recalc all)

		foreach my $key (qw(systems stars planets adjsystems)) {
			if (!defined($table{$d}{$key}) || (!$table{$d}{$key} && $yearmonthday{$d}{$key}) || $timediff <= 86400*7) {
				$update .= ",$key=?";
				push @params, $yearmonthday{$d}{$key};
			}
		}
		$update =~ s/^,+//;

		if ($update) {
			push @params, $d;
			eval {
				db_mysql('elite',"update submissions set $update where subDate=?",\@params);
			};
		}
	}
}
close CSV;

open CSV, ">$monthfile";
print CSV make_csv('Date','Systems','Stars','Planets','Average bodies per system','Average stars per system','Average planets per system',
			'Adjusted Systems','Adjusted Average Bodies','Adjusted Average Stars','Adjusted Average Planets')."\r\n";
foreach my $d (sort keys %yearmonth) {
	my $avg_bodies = 0;
	$avg_bodies = sprintf("%.02f",($yearmonth{$d}{stars}+$yearmonth{$d}{planets})/$yearmonth{$d}{systems}) if ($yearmonth{$d}{systems});
	my $avg_stars = 0;
	$avg_stars = sprintf("%.02f",$yearmonth{$d}{stars}/$yearmonth{$d}{systems}) if ($yearmonth{$d}{systems});
	my $avg_planets = 0;
	$avg_planets = sprintf("%.02f",$yearmonth{$d}{planets}/$yearmonth{$d}{systems}) if ($yearmonth{$d}{systems});

	my $a_avg_bodies = 0;
	$a_avg_bodies = sprintf("%.02f",($yearmonth{$d}{stars}+$yearmonth{$d}{planets})/$yearmonth{$d}{adjsystems}) if ($yearmonth{$d}{adjsystems});
	my $a_avg_stars = 0;
	$a_avg_stars = sprintf("%.02f",$yearmonth{$d}{stars}/$yearmonth{$d}{adjsystems}) if ($yearmonth{$d}{adjsystems});
	my $a_avg_planets = 0;
	$a_avg_planets = sprintf("%.02f",$yearmonth{$d}{planets}/$yearmonth{$d}{adjsystems}) if ($yearmonth{$d}{adjsystems});

	print CSV make_csv($d,$yearmonth{$d}{systems},$yearmonth{$d}{stars},$yearmonth{$d}{planets},
			$avg_bodies,$avg_stars,$avg_planets,$yearmonth{$d}{adjsystems},$a_avg_bodies,$a_avg_stars,$a_avg_planets)."\r\n"
}
close CSV;


