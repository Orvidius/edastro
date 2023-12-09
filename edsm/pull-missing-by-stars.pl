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

my $ref = columns_mysql($db,"select distinct systemId64 from stars where edsmID is null and deletionState=0 order by starID");

while (@{$$ref{systemId64}}) {
	my @list = splice @{$$ref{systemId64}}, 0, 80;
	system('/home/bones/elite/edsm/get-system-bodies.pl',@list);
	sleep 1;
}

