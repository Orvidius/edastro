#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use List::Util qw( min max );

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch btrim make_csv);

############################################################################

my $debug       = 0;
my $chunk_size	= 1000;
my $top_count	= 1000;
my $by_surface	= 0;

$top_count = 10 if ($debug);

$by_surface = 1 if (@ARGV);

show_queries(0);

############################################################################

my %letter = ();
my $i = 0;
foreach my $l ('A'..'Z') {
	$i++;
	$letter{$l} = $i;
}
foreach my $l ('a'..'z') {
	$i++;
	$letter{$l} = $i;
}


my $maxID = 0;

my @rows = db_mysql('elite',"select max(ID) maxID from systems");
die "Can't read table\n" if (!@rows);

$maxID = ${$rows[0]}{maxID};

my $chunk = 0;
my $count = 0;

my $lowest_val = 99999999999;
my $highest_val = 99999999999;
my $lowest_id = undef;
my $highest_id = undef;
my %best = ();

print "MaxID = $maxID\n";

while ($chunk < $maxID) {
	my $rows = rows_mysql('elite',"select id64,name from systems where ID>=? and ID<?",[($chunk,$chunk+$chunk_size)]);
	$chunk += $chunk_size;

	my %sys = ();
	
	my @list = ();
	foreach my $r (@$rows) {
		push @list, $$r{id64} if ($$r{id64});
		$sys{$$r{id64}} = $$r{name};
	}

	$rows = rows_mysql('elite',"select systemId64,starID,bodyId64,name,subType,solarMasses,solarRadius,argOfPeriapsis,semiMajorAxis,orbitalPeriod from stars ".
			"where systemId64 in (".join(',',@list).") and semiMajorAxis is not null and semiMajorAxis>0 and orbitalPeriod is not null and orbitalPeriod>0");

	my %stars = ();

	while (@$rows) {
		my $r = shift @$rows;

		if ($$r{name} =~ / ([A-Z])$/) {
			my $n = $letter{$1};
			$stars{$$r{systemId64}}{$n} = $r;
		}

	}

	foreach my $id64 (@list) {
		my $max = max keys %{$stars{$id64}};

		for (my $i=1; $i<$max; $i++) {
			my $k = $i+1;

			if (exists($stars{$id64}{$i}) && exists($stars{$id64}{$k})) {

				next if (abs($stars{$id64}{$i}{orbitalPeriod}-$stars{$id64}{$k}{orbitalPeriod}) > 0.0001);
				my $arg1 = $stars{$id64}{$i}{argOfPeriapsis};
				my $arg2 = $stars{$id64}{$k}{argOfPeriapsis};

				$arg1 += 360 if ($arg1 < $arg2 && $arg2-$arg1>180);
				$arg2 += 360 if ($arg2 < $arg1 && $arg1-$arg2>180);
				my $degrees = abs($arg1-$arg2);
				next if ($degrees <= 179.9);

				my $distance = ($stars{$id64}{$i}{semiMajorAxis} + $stars{$id64}{$k}{semiMajorAxis}) * 499.005;	# Store light seconds

				$distance -= ($stars{$id64}{$i}{solarRadius}+$stars{$id64}{$k}{solarRadius})*2.32276375 if ($by_surface);

				my $id = $id64.'-'.$i;

				if (int(keys %best)<$top_count || $distance<$highest_val) {
					$best{$id}{0} = $stars{$id64}{$i};
					$best{$id}{1} = $stars{$id64}{$k};
					$best{$id}{name} = $sys{$id64};
					$best{$id}{dist} = $distance;

					if ($distance < $lowest_val || !$lowest_id) {
						$lowest_val = $distance;
						$lowest_id = $id;
					}

					if ($distance > $highest_val || !$highest_id) {
						$highest_val = $distance;
						$highest_id = $id;
					}
				}

				if (int(keys %best)>$top_count) {
					# remove one

					delete($best{$highest_id});

					# Find new highest

					$highest_id = (sort { $best{$b}{dist} <=> $best{$a}{dist} } keys %best)[0];
					$highest_val = $best{$highest_id}{dist};
				}
			}
		}
	}

	$count++;
	print '.' if ($count % 10 == 0);
	print "\n" if ($count % 1000 == 0);

	last if ($debug && $count>=50);
}
print "\n";


my $fn_add = '';
$fn_add = '-surface' if ($by_surface);

my $type = 'centers';
$type = 'surfaces' if ($by_surface);

open CSV, ">tightest-binary-stars$fn_add.csv";

print CSV make_csv('SystemAddress ID64','System Name',"Average Binary Distance (LS) [$type]",'Orbital Period',
		'Star 1','Star 1 Type','Star 1 SemiMajor Axis','Star 1 Solar Mass','Star 1 Solar Radius',
		'Star 2','Star 2 Type','Star 2 SemiMajor Axis','Star 2 Solar Mass','Star 2 Solar Radius')."\r\n";


foreach my $id (sort { $best{$a}{dist} <=> $best{$b}{dist} } keys %best) {
	$id =~ /(\d+)\-/;
	my $id64 = $1;

	print CSV make_csv($id64,$best{$id}{name},$best{$id}{dist},$best{$id}{0}{orbitalPeriod},
		$best{$id}{0}{name},$best{$id}{0}{subType},$best{$id}{0}{semiMajorAxis},$best{$id}{0}{solarMasses},$best{$id}{0}{solarRadius},
		$best{$id}{1}{name},$best{$id}{1}{subType},$best{$id}{1}{semiMajorAxis},$best{$id}{1}{solarMasses},$best{$id}{1}{solarRadius})."\r\n";
}

close CSV;



