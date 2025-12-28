#!/usr/bin/env perl
use strict; $|=1;

##########################################################################

use JSON::XS 'decode_json';
use ZMQ::FFI qw(ZMQ_SUB);
use Time::HiRes q(usleep);
use Time::Local;
use Compress::Zlib;
use File::Basename;
use POSIX;
use Sys::Syslog;
use Sys::Syslog qw(:DEFAULT setlogsock);

use lib "/home/bones/perl";
use ATOMS qw(btrim epoch2date count_instances my_syslog $progname);
use lib "/home/bones/elite";
use EDDN qw(process_queue);

##########################################################################

my $debug	= 0;
my $kill_old	= 1;
my $daemonizing = 1;

my $progname    = basename($0);
my $startname   = $0; $startname =~ s/$progname\s+.*$/$progname/s;
my $is_daemon	= 0;	# Must start as 0

##########################################################################

if ($daemonizing) {
	$kill_old = @ARGV ? 1 : 0;
}

if (!$debug && count_instances($kill_old) >= 1) {
	die "$progname is already running.\n" if (!$kill_old);
}

daemonize() if (!$debug && $daemonizing);

if (!$is_daemon) {
	process_queue(1,1);
	process_queue(1,1);	# Let's do it again to grab things that came in during the first pass.
} else {
	while (1) {
		$0 = "$progname ".time." [processing]";
		process_queue(1,1);

		for(my $i=10;$i>0;$i--) {
			$0 = "$progname ".time.sprintf(" [sleep=%02u]",$i);
			sleep 1;
		}
	}
}

exit;

##########################################################################

sub daemonize {
        my $pid = fork;
        exit if ($pid);
        die "Couldn't fork: $!" unless defined($pid);
        POSIX::setsid() or die "Can't start new session: $!";
        my_syslog('Started');
	$is_daemon = 1;
}



