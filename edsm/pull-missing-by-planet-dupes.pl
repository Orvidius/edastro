#!/usr/bin/perl
use strict; $|=1;

###########################################################################

use lib "/home/bones/perl";
use DB qw(columns_mysql db_mysql show_queries);

###########################################################################

my $debug       = 0;
my $verbose     = 0;

my $db          = 'elite';
my $one		= 1;

###########################################################################

my %systems = ();
my %bodies = ();

my @rows = db_mysql($db,"select distinct name,count(*) from planets group by name having count(*)>1");
foreach my $r (@rows) {
	my $n = $$r{name};
	$n =~ s/'/\\'/gs;
	${$bodies{$n}} = \$one if ($n);
}


exit if (!keys %bodies);

my @names = ();

foreach my $n (keys %bodies) {
	push @names, $n;
	delete($bodies{$n});
}

while (@names) {
	my @namechunk = splice @names, 0, 100;
	my $chunk = "'".join("','",@namechunk)."'";

	my $ref = columns_mysql($db,"select distinct distinct systemId64 from planets where name in ($chunk)");

	while (@{$$ref{systemId64}}) {
		${$systems{shift @{$$ref{systemId64}}}} = \$one;
	}
}

my @idlist = ();

foreach my $id64 (keys %systems) {
	push @idlist, $id64;
	delete($systems{$id64});
}


while (@idlist) {
	my @list = splice @idlist, 0, 80;
	system('/home/bones/elite/edsm/get-system-bodies.pl',@list);
	sleep 1;
}

