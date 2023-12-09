#!/usr/bin/perl
use strict;
$|=1;

use File::Copy;

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(btrim epoch2date date2epoch parse_csv);

use lib "/home/bones/elite";
use EDSM qw(update_object key_findcreate_local codex_entry);
use EDDN qw(track_carrier track_exploration $eddn_verbose);

my $verbose		= 1;

my $ssh			= '/usr/bin/ssh';
my $scp			= '/usr/bin/scp';
my $zcat		= '/usr/bin/zcat';
my $local_incoming	= '/home/bones/elite/api/incoming';
my $completed		= '/home/bones/elite/api/completed';
my $remote_outgoing	= '/www/edastro.com/api/outgoing';
my $remote_server	= 'www@services';
my $no_post_processing	= 0;

show_queries($verbose);
$eddn_verbose = $verbose;


my @files = ();

if (@ARGV) {
	@files = @ARGV;
	$no_post_processing = 1;
} else {
	system("$scp $remote_server:$remote_outgoing/journaldata*.gz $local_incoming/");

	opendir DIR, $local_incoming;
	while (my $fn = readdir DIR) {
		if ($fn =~ /^\w+.+\.gz$/) {
			push @files, "$local_incoming/$fn";
		}
	}
	closedir DIR;
}

foreach my $fn (sort {$a cmp $b} @files) {
	warn "FILE: $fn\n";

	open TXT, "$zcat $fn |" if ($fn =~ /\.gz$/);
	open TXT, "<$fn" if ($fn !~ /\.gz$/);
	while (<TXT>) {
		chomp;
		print "PROCESSING: $_\n" if ($verbose);
		process_line($_);
	}
	close TXT;

	if (!$no_post_processing) {
		move($fn,"$completed/".strippath($fn));
		system($ssh,$remote_server,"rm -f $remote_outgoing/".strippath($fn));
	}
}

sub process_line {
	my $line = btrim(shift);

	if ($line =~ /^\s*(\{.+\})\s*,?\s*$/) {
		$line = $1;
	} else {
		return;
	}

	# Do something here

	if ($line =~ /"event"\s*:\s*"([\d\w]+)"/) {
		my $eventType = $1;
		my $jref = undef;
		eval {
			$jref = JSON->new->utf8->decode($line);
		};

		if ($@) {
			print "JSON error: $@\n";
		} elsif (!$jref || ref($jref) ne 'HASH') {
			print "JSON invalid!\n";
		} else {
			my %jhash = ();
			%{$jhash{message}} = %$jref; # Make a copy, in "message" node, like an EDDN event.

			if ($eventType eq "CarrierStats" || $eventType eq "Docked" || $eventType eq 'FSSSignalDiscovered') {
				track_carrier('CarrierStats', \%jhash);
				track_exploration($eventType, \%jhash) if ($eventType eq 'FSSSignalDiscovered');
			} else {
				track_exploration($eventType, \%jhash);
			}
		}
	}
}

sub get_orgID {
	return key_findcreate_local(@_);
}

sub strippath {
	my $s = shift;
	$s =~ s/^.*\/+//s;
	return $s;
}

#sub get_orgID {
#	my $table = shift;
#	my $ugly_name = shift;
#	my $pretty_name = shift;
#	my $table2 = $table.'_local';
#	my $IDname = $table.'ID';
#
#	my $mainID = undef;
#	my $localID = undef;
#
#	my @rows = db_mysql('elite',"select id from $table where name=?",[($ugly_name)]);
#	foreach my $r (@rows) {
#		$mainID = $$r{id};
#	}
#
#	if (!$mainID) {
#		$mainID = db_mysql('elite',"insert into $table (name,date_added) values (?,NOW())",[($ugly_name)]);
#	}
#	
#	my @rows = db_mysql('elite',"select id from $table2 where name=?",[($pretty_name)]);
#	foreach my $r (@rows) {
#		$localID = $$r{id};
#	}
#
#	if (!$localID) {
#		$localID = db_mysql('elite',"insert into $table2 (name,$IDname,date_added) values (?,?,NOW())",[($pretty_name,$mainID)]);
#	}
#
#	return $mainID;
#}



