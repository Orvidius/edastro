#!/usr/bin/env perl
use strict; $|=1;

##########################################################################

use Time::Local;
use File::Basename;
use POSIX;

use lib "/home/bones/perl";
use ATOMS qw(btrim epoch2date count_instances my_syslog $progname);
use lib "/home/bones/elite";
use EDDN qw(process_event_file process_event_json);
use EDSM qw($edsm_verbose);

##########################################################################

my $debug       = 0;

$edsm_verbose	= 1;

##########################################################################

if (!@ARGV) {
	my $txt = '';
        foreach my $line (<STDIN>) {
                $txt .= $line;
        }

        $txt =~ s/,\s*$//gs;
        $txt =~ s/^[^\{\[]+//s;

	my $event = '';

	if ($txt =~ /"event"\s*:\s*"([^"]+)"/) {
		$event = $1;
	}

	#warn "$txt\n\n";

	process_event_json($event,$txt);
	exit;
} else {

	foreach my $fn (@ARGV) {

		process_event_file($fn);
	}
}

exit;

##########################################################################


