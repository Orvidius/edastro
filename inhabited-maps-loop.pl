#!/usr/bin/perl
use strict;
$|=1;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch parse_csv make_csv);

use POSIX ":sys_wait_h";

############################################################################

my $use_forking         = 0;	# Forking seems to clobber the system with lots of imagemagick threads
my $fork_verbose        = 0;
my $max_children        = 2;

my $amChild   = 0;
my %child     = ();
$SIG{CHLD} = \&REAPER;

############################################################################

my $time = time;
$time = date2epoch($ARGV[0]." 12:00:00") if (@ARGV);
my @t = localtime($time);
my $today = sprintf("%04u-%02u-%02u",$t[5]+1900,$t[4]+1,$t[3]);


my $start = '2025-02-14';
my $date = $start;

my $pid = 0;
my $do_anyway = 0;

while ($date le $today) {

	if ($use_forking) {
		if ($pid = fork) { 
			# parent
			$child{$pid}{start} = time;
		} elsif (defined $pid) {
			# child
			$0 .= ' '.$date;
			$amChild = 1;
			system('/home/bones/elite/inhabited-maps.pl',$date);
			exit;
		} elsif ($! =~ /No more process/) {
		} else {
		}
	
		while (int(keys %child) >= $max_children) {
			sleep 0.1;
		}
	} else {
		system('/home/bones/elite/inhabited-maps.pl',$date);
	}

	$date = epoch2date(date2epoch($date." 12:00:00")+86400);
	$date =~ s/\s+.*//s;
}


sub REAPER {
        while ((my $pid = waitpid(-1, &WNOHANG)) > 0) {
                info("FORK: Child on PID $pid terminated.\n") if ($fork_verbose);
                delete($child{$pid});
        }
        $SIG{CHLD} = \&REAPER;
}
