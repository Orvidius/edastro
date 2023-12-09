#!/usr/bin/perl
use strict;
$|=1;

#############################################################################

use lib "/home/bones/perl";
use ATOMS qw(epoch2date date2epoch);
use DB qw(rows_mysql db_mysql disconnect_all);

use POSIX qw(floor);
use POSIX ":sys_wait_h";
use Time::HiRes qw(sleep);

#############################################################################

my $chunk_size		= 10000;
my $max_children        = 4;
my $use_forking         = 1;
my $fork_verbose        = 0;

my $amChild   = 0;
my %child     = ();
$SIG{CHLD} = \&REAPER;


#############################################################################

foreach my $table (qw(planets stars)) {
	my $IDfield = 'planetID';
	$IDfield = 'starID' if ($table eq 'stars');

	my $maxID = 0;
	my @rows = db_mysql('elite',"select max($IDfield) as max from $table");
	if (@rows) {
		$maxID = ${$rows[0]}{max};
	} else {
		next;
	}

	print "TABLE $table ($maxID)\n";

	my $chunk = 0;
	my $dotcount = 0;

	my $pid = 0;
        my $do_anyway = 0;
        $SIG{CHLD} = \&REAPER;

	while ($chunk < $maxID) {

		while (int(keys %child) >= $max_children) {
                        #sleep 1;
                        sleep 0.05;
                }

		$dotcount++;
		print '.';
		print "\n" if ($dotcount % 100 == 0);

		my @rows = db_mysql('elite',"select $IDfield,updateTime,updated,eddn_date,discoveryDate from $table where $IDfield>=? and $IDfield<? and date_added is null",
			[($chunk,$chunk+$chunk_size)]);
		$chunk += $chunk_size;

		next if (!@rows);

                if ($use_forking) {
                        FORK: {
                                if ($pid = fork) {
                                        # Parent here
                                        $child{$pid}{start} = time;
                                        warn("FORK: Child spawned on PID $pid\n") if ($fork_verbose);
                                        next;
                                } elsif (defined $pid) {
                                        # Child here
                                        $amChild = 1;   # I AM A CHILD!!!
                                        warn("FORK: $$ ready.\n") if ($fork_verbose);
                                } elsif ($! =~ /No more process/) {
                                        warn("FORK: Could not fork a child, retrying in 3 seconds\n");
                                        sleep 3;
                                        redo FORK;
                                } else {
                                        warn("FORK: Could not fork a child. $! $@\n");
                                        $do_anyway = 1;
                                }
                        }
                } else {
                        $do_anyway = 1;
                }

		next if (!$amChild && !$do_anyway);

		disconnect_all() if ($amChild); # Important to make our own DB connections as a child process.

		if ($amChild || $do_anyway) {
	
			while (@rows) {
				my $r = shift @rows;
				my $date = '';
		
				foreach my $d (qw(updateTime updated eddn_date discoveryDate)) {
					$date = $$r{$d} if ($$r{$d} =~ /^\d{4}-\d{2}-\d{2}/ && (!$date || $$r{$d} lt $date)); # Use oldest date
				}
	
				if ($date) {
					db_mysql('elite',"update $table set date_added=?,updated=updated where $IDfield=?",[($date,$$r{$IDfield})]);
				}
			}
		}

		exit if ($amChild);
	}
	print "\n";

	print "\nWaiting on child processes.\n";
        while (int(keys %child) > 0) {
                #sleep 1;
                sleep 0.1;
        }
}

sub REAPER {
        while ((my $pid = waitpid(-1, &WNOHANG)) > 0) {
                warn("FORK: Child on PID $pid terminated.\n") if ($fork_verbose);
                delete($child{$pid});
        }
        $SIG{CHLD} = \&REAPER;
}
