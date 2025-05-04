#!/usr/bin/perl
use strict;

############################################################################

use Math::Trig;
use Data::Dumper;
use POSIX qw(floor);
use POSIX ":sys_wait_h";
use Time::HiRes qw(sleep);

use lib "/home/bones/elite";
use EDSM qw(log10 update_systemcounts);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

#############################################################################

show_queries(0);

#exit;

$0 =~ s/^.*\///s;
my $progname = $0;

my $debug               = 0;
my $minutes		= 35;
my $db			= 'elite';
my $chunk_size		= 10000;

my $max_children        = 24;
my $use_forking         = 1;
my $fork_verbose        = 0;

my $amChild   = 0;
my %child     = ();
$SIG{CHLD} = \&REAPER;


#############################################################################

my %sys = ();

if ($ARGV[0] =~ /^\d+$/) {
	if ($ARGV[0] <= 10) {
		my $rows = rows_mysql($db,"select distinct systemId64 from logs where cmdrID=?",[($ARGV[0])]);
		if (ref($rows) eq 'ARRAY') {
			foreach my $r (@$rows) {
				$sys{$$r{systemId64}} = 1;
			}
		}
	} else {
		foreach my $id (@ARGV) {
			$sys{$id} = 1;
		}
	}
} elsif ($ARGV[0] eq 'poi') {
	my $rows = rows_mysql($db,"select distinct systemId64 from POI");
	if (ref($rows) eq 'ARRAY') {
		foreach my $r (@$rows) {
			$sys{$$r{systemId64}} = 1;
		}
	}
} elsif ($ARGV[0] eq 'missing') {
	my $limit = '';

	if ($ARGV[1] =~ /^\d+$/) {
		$limit = "limit $ARGV[1]";
	}

	my $rows = rows_mysql($db,"select distinct id64 from systems where (numStars is null or numPlanets is null or numTerra is null or numLandables is null or numELW is null or numAW is null or numWW is null) and deletionState=0 $limit");
	if (ref($rows) eq 'ARRAY') {
		foreach my $r (@$rows) {
			$sys{$$r{id64}} = 1;
		}
	}
} elsif ($ARGV[0] eq 'all') {

	my $done = 0;
	my $n = 0;

	my @rows = db_mysql($db,"select max(ID) as maxID from systems");
	my $maxID = ${$rows[0]}{maxID};

	my $id = 00000000;

	while ($id < $maxID) {

		my %sys = ();
		my @rows = db_mysql($db,"select id64 from systems where ID>=? and ID<? and deletionState=0",[($id,$id+$chunk_size)]);
		while (@rows) {
			my $r = shift @rows;
			$sys{$$r{id64}}++;
		}
		
		print "$$> do_update : $id - ".($id+$chunk_size-1)."\n" if ($fork_verbose);
		do_update(\%sys,0,1,"$id - ".($id+$chunk_size-1)) if (keys %sys);

		$id += $chunk_size;
		$n++;
		print '.';
		print " [".int($id)."]\n" if ($n % 100 == 0);
	}

	while (int(keys %child) > 0) {
            #sleep 1;
            sleep 1;
        }
	exit;

} else {

	foreach my $table (qw(stars planets)) {
		my $rows = rows_mysql($db,"select distinct systemId64 from $table where date_added>=date_sub(NOW(),interval $minutes minute)");

		if (ref($rows) eq 'ARRAY') {
			foreach my $r (@$rows) {
				$sys{$$r{systemId64}} = 1;
			}
		}
	}
}

do_update(\%sys,1,0) if (keys %sys);

exit;

#############################################################################

sub do_update {
	my $href    = shift;
	my $verbose = shift;
	my $do_fork = shift;
	my $label   = shift;

	if (!$use_forking || !$do_fork) {
		foreach my $id64 (keys %$href) {
	
			update_systemcounts($id64,$verbose);
	
			delete($sys{$id64});
		}
	} else {
		my $pid = 0;
		my $do_anyway = 0;
		$SIG{CHLD} = \&REAPER;
		
		while (int(keys %child) >= $max_children) {
			#sleep 1;
			sleep 0.05;
		}

		if ($pid = fork) {
			# Parent here
			$child{$pid}{start} = time;
			warn("$$> FORK: Child spawned on PID $pid ($label)\n") if ($fork_verbose);
			return; # NOT EXIT, since we're in a function instead of a loop
		} elsif (defined $pid) {
			# Child here
			$amChild = 1;   # I AM A CHILD!!!
			warn("$$> FORK: $$ ready. ($label)\n") if ($fork_verbose);
			$0 = $progname . " - $label";
		} elsif ($! =~ /No more process/) {
			warn("$$> FORK: Could not fork a child, retrying in 3 seconds\n");
			sleep 3;
			redo FORK;
		} else {
			warn("$$> FORK: Could not fork a child. $! $@\n");
			$do_anyway = 1;
		}

		
		return if (!$amChild && !$do_anyway);

		disconnect_all() if ($amChild); # Important to make our own DB connections as a child process.

		if ($amChild || $do_anyway) {

			foreach my $id64 (keys %$href) {
		
				update_systemcounts($id64,$verbose);
		
				delete($sys{$id64});
			}
		}

		exit if ($amChild);

	}

	#print "." if (!$verbose);

}

sub REAPER {
	while ((my $pid = waitpid(-1, &WNOHANG)) > 0) {
		warn("$$> FORK: Child on PID $pid terminated.\n") if ($fork_verbose);
		delete($child{$pid});
	}
	$SIG{CHLD} = \&REAPER;
}

#############################################################################




