#!/usr/bin/perl
use strict;
##########################################################################

use POSIX;
use File::Basename;
use Sys::Syslog;
use Sys::Syslog qw(:DEFAULT setlogsock);

my $debug	= 0;
my $daemonizing = 1;
my $progname    = basename($0);

##########################################################################

if (!$debug && count_instances() >= 1) {
	die "$progname is already running.\n";
}

daemonize() if (!$debug && $daemonizing);

while (1) {
	system("source /etc/profile ; /home/bones/elite/discord-bot.py");
	sleep 1;
}

exit;

##########################################################################

sub daemonize {
	my $pid = fork;
	exit if ($pid);
	die "Couldn't fork: $!" unless defined($pid);
	POSIX::setsid() or die "Can't start new session: $!";
}

sub count_instances {
	my $count = 0;
	my $kill = shift;

	open PS, "/bin/ps awx |";
	while (<PS>) {
		if (/^\s*(\d+)\s+.+perl.+$progname/) {
			if ($1 != $$) {
				$count++;
				if ($kill) {
					my_syslog("$progname: killing old instance [$1]");
					kill 'KILL', $1;
				}
			}
		}
		if (/^\s*(\d+)\s+.+\d+\s+$progname\s+\d+/) {
			if ($1 != $$) {
				$count++;
				if ($kill) {
					my_syslog("$progname: killing old instance [$1]");
					kill 'KILL', $1;
				}
			}
		}
	}
	close PS;
	return $count;
}


sub my_syslog {
	while (@_) {
		my $message = shift;
		chomp $message;
		next if (!$message);
		$message =~ s/(\^M)?\s*$//;
		setlogsock('unix');
		openlog($progname,"pid","user");
		syslog("info","$message");
		closelog();
	}
}

##########################################################################




