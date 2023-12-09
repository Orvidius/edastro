#!/usr/bin/perl
use strict; $|=1;

###########################################################################

use lib "/home/bones/perl";
use DB qw(columns_mysql db_mysql show_queries);

###########################################################################

my $debug       = 0;
my $verbose     = 0;

my $db          = 'elite';

###########################################################################

my %systems = ();
my %bodies = ();

my $ref = columns_mysql($db,"select name from systems where edsm_id is null and deletionState=0");

while (@{$$ref{name}}) {
	my @list = splice @{$$ref{name}}, 0, 80;
	system('/home/bones/elite/edsm/get-system-bodies.pl',@list);
	sleep 1;
}

