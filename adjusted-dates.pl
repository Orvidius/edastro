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

my $debug		= 0;
my $verbose		= 1;
my $do_all		= 0;

my $update_days		= 4;
my $push_count		= 500;

my %table_ID = ();
$table_ID{systems} = 'edsm_id';
$table_ID{stars}   = 'edsmID';
$table_ID{planets} = 'edsmID';

############################################################################

my %fixes = ();

my @table_list = qw(systems);

@table_list = @ARGV if (@ARGV);

foreach my $table (@table_list) {
	print uc($table)."\n";

	if (!$table_ID{$table}) {
		print "Unknown table '$table'\n";
		next;
	}

	my %dateID = ();


	my @rows = db_mysql('elite',"select * from dates_$table");

	foreach my $r (@rows) {
		$dateID{$$r{subDate}} = $$r{maxID};
	}

	my $datefield = 'updateTime';
	$datefield = 'edsm_date' if ($table eq 'systems');

	my $IDfield = $table_ID{$table};
	
	my $min_date = '';
	my $max_date = '';
	my $upd_date = '';
	
	my @rows = db_mysql('elite',"select min($datefield) date from $table where $datefield is not null and $datefield>='2014-01-01 00:00:00'");
	if (@rows) {
		$min_date = ${$rows[0]}{date};
	} else {
		print "Couldn't get min date.\n";
		next;
	}
	
	my @rows = db_mysql('elite',"select max($datefield) date from $table where $datefield is not null");
	if (@rows) {
		$max_date = ${$rows[0]}{date};
	} else {
		print "Couldn't get max date.\n";
		next;
	}

	$upd_date = epoch2date(date2epoch($max_date)-(86400*$update_days));
	
	$min_date =~ s/\s.*$//;
	$max_date =~ s/\s.*$//;
	$upd_date =~ s/\s.*$//;
	
	my $min_epoch = date2epoch("$min_date 12:00:00"); # Whole days only, so using noon to convert back into dates
	my $max_epoch = date2epoch("$max_date 12:00:00");
	
	my $epoch = $min_epoch;
	my $last_max_ID = 0;
	
	print "Scanning '$table', $min_date -> $max_date ($min_epoch - $max_epoch) UPD = $upd_date\n";
	
	my $n = 0;
	
	while ($epoch < $max_epoch) {
		my $date = epoch2date($epoch);
		$date =~ s/\s+.*//;
	
		my $next = epoch2date($epoch+86400);
		$next =~ s/\s+.*//;
	
		my $new_max_ID = $last_max_ID;

		if ($do_all || !$dateID{$date} || $date ge $upd_date) {
			my @rows = db_mysql('elite',"select distinct $IDfield as ID from $table where $datefield>=? and $datefield<?",[("$date 00:00:00","$next 00:00:00")]);
	
			foreach my $r (sort { $$a{ID} <=> $$b{ID} } @rows) {
				$new_max_ID = $$r{ID} if ($$r{ID} && (!$new_max_ID || $$r{ID}-$new_max_ID < 100000)); # Ignore IDs that skip too far into the future
			}
		} else {
			$new_max_ID = $dateID{$date};
		}

		$dateID{$date} = $new_max_ID if ($do_all || !$dateID{$date} || $date ge $upd_date);

		$new_max_ID = $dateID{$date}; # stay in sync

		print uc($table)." $date [$dateID{$date}]\n" if ($verbose);
	
		my @rows = db_mysql('elite',"select $IDfield from $table where adj_date is null and $datefield>=? and $datefield<?",[("$date 00:00:00","$next 00:00:00")]);
		#my @rows = db_mysql('elite',"select $IDfield from $table where $datefield>=? and $datefield<?",[("$date 00:00:00","$next 00:00:00")]);
		my @needs_date = ();
	
		foreach my $r (@rows) {
			next if (!$$r{$IDfield});
			push @needs_date, $$r{$IDfield};
		}


		print "$date MAX = $dateID{$date}\n" if ($verbose);

		db_mysql('elite',"insert into dates_$table (subDate,maxID) values (?,?) on duplicate key update maxID=?",
				[($date,$new_max_ID,$new_max_ID)]) if (!$debug && ($do_all || $date ge $upd_date));

		db_mysql('elite',"insert ignore into dates_$table (subDate,maxID) values (?,?)",[($date,$new_max_ID)]) if (!$debug && !$do_all && $date lt $upd_date);

		foreach my $id (sort @needs_date) {
			my $new_date = '';

			foreach my $d (sort keys %dateID) {
				next if (!$d);
				if ($dateID{$d} < $id) {
					$new_date = $d;
				} else {
					last;
				}
			}

			$fixes{$table}{$new_date}{$id} = 1 if ($new_date && $id);

			if (int(keys %{$fixes{$table}{$new_date}})>=$push_count*2) {
				push_fixes($table,0);
			}
		}
	
		$dateID{$date} = $new_max_ID;
		$last_max_ID = $new_max_ID;
		$n++;
		$epoch += 86400;

		push_fixes($table,0);
	}
	push_fixes($table,1);
}


exit;

############################################################################

sub push_fixes {
	my $table  = shift;
	my $do_all = shift;

	foreach my $date (sort keys %{$fixes{$table}}) {
		if ($do_all || int(keys %{$fixes{$table}{$date}})>=$push_count) { 

			my @list = sort keys %{$fixes{$table}{$date}};

			print "$table [$date]: ".int(@list)."\n" if ($verbose);

			db_mysql('elite',"update $table set adj_date=? where $table_ID{$table} in (".join(',',@list).")",[("$date 12:00:00")]) if (!$debug && @list);

			delete($fixes{$table}{$date});
		}
	}
}

############################################################################

