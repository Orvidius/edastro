#!/usr/bin/perl
use strict; $|=1;

###########################################################################

use LWP 5.64;
use JSON;

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);
use ATOMS qw(date2epoch epoch2date make_csv parse_csv);

use lib "/home/bones/elite";
use EDSM qw(object_exists);

###########################################################################

my $debug       = 0;
my $verbose     = 0;

my $db		= 'elite';
my $fn		= "sync-bodies-import.json";

my $apiDomain   = 'https://www.edsm.net';

my $systemsURL	= "$apiDomain/api-v1/systems";
my $bodiesURL	= "$apiDomain/api-system-v1/bodies";

###########################################################################

show_queries($debug);

my $time = time;
my $epoch = time;
my %systems_needed = ();

#TEST:
if (0) {
	$systems_needed{'Clookuia KF-A d6'} = 1;
	get_systems();
	exit;
}
#/TEST


die "Usage: $0 <filename.csv> [name/ID column] [skip header: 0|1]\n" if (!@ARGV);

die "$ARGV[0] not found\n" if (!-e $ARGV[0]);

my $column = 0;
$column = $ARGV[1] if ($ARGV[1] =~ /^\d+$/);

open CSV, "<$ARGV[0]";
my $header = <CSV> if ($ARGV[2]);
while (my $line = <CSV>) {
	chomp $line;
	my @v = parse_csv($line);

	$systems_needed{$v[$column]} = 1;
}
close CSV;

get_systems();
exit;

###########################################################################

sub get_systems {

	open TXT, ">$fn";
	print TXT "[\n";

	my $count = 0;
	my $ratelimit = 0;
	my $ratelimitmax = 0;

	foreach my $sys (sort keys %systems_needed) {

		if ($count) {
			my $delay = get_delay($epoch,$ratelimit);
			if ($delay > 0) {
				print "Sleeping: $delay ($ratelimit/$ratelimitmax)\n";
				sleep $delay;
			}
		}
		$epoch = time;

		my $param = 'systemName';
		$param = 'systemId' if ($sys =~ /^\d+$/);

		my $systemId = undef;
		my $systemId64 = undef;
		$systemId = $sys if ($sys =~ /^\d+$/);

		my $url = "$bodiesURL?$param=$sys";

		print "GET $url\n";
		my $browser = LWP::UserAgent->new;
		my $response = $browser->get($url);

		$ratelimit = $response->header('X-Rate-Limit-Remaining');
		$ratelimitmax = $response->header('X-Rate-Limit-Limit');
		
		if (!$response->is_success) {
			warn "Could not retrieve systems.\n";
			print $response->status_line()."\n";
			return;
		} else {
			my $json = JSON->new->allow_nonref;
			my $ref = $json->decode( $response->content );

			$systemId = $$ref{id} if (!$systemId);

			my @rows = db_mysql('elite',"select id64 from systems where edsm_id=?",[($systemId)]);
			if (@rows) {
				$systemId64 = ${$rows[0]}{id64};
			}

			my %bodies = ();

			my @rows = db_mysql('elite',"select edsmID from planets where systemId=?",[($systemId)]);
			push @rows, db_mysql('elite',"select edsmID from stars where systemId=?",[($systemId)]);

			foreach my $r (@rows) {
				$bodies{$$r{edsmID}} = 1;
			}

			foreach my $r (@{$$ref{bodies}}) {
				$$r{systemId} = $systemId;
				$$r{systemId64} = $systemId64;

				delete($bodies{$$r{id}});

				delete($$r{discovery});
			
				print TXT "\t".$json->encode( $r )."\n";
			}

			print $json->pretty->encode( $ref )."\n\n" if ($verbose && $debug);

			if (keys %bodies) {
				my $list = join(',',keys %bodies);
				db_mysql('elite',"update stars set deletionState=1 where id in ($list)");
				db_mysql('elite',"update planets set deletionState=1 where id in ($list)");
			}
		}

		$count++;

		last if ($debug);
	}

	print TXT "]\n";
	close TXT;

	system("/home/bones/elite/parse-data.pl -u $fn") if (!$debug);
}

sub get_delay {
	my $epoch = shift;
	my $ratelimit = shift;
	my $ratelimitmax = shift;

	my $delay = 12 - (time - $epoch);       # default

	if ($ratelimit =~ /^\d+$/) {
		if ($ratelimit/$ratelimitmax < 0.1) {
			$delay = 25;
		} elsif ($ratelimit/$ratelimitmax < 0.3) {
			$delay = 10;
		} elsif ($ratelimit/$ratelimitmax < 0.5) {
			$delay = 5;
		} elsif ($ratelimit/$ratelimitmax < 0.7) {
			$delay = 3;
		} elsif ($ratelimit/$ratelimitmax < 0.8) {
			$delay = 2;
		} elsif ($ratelimit/$ratelimitmax < 0.9) {
			$delay = 1;
		} else {
			$delay = 0;
		}
	}
	return $delay;
}

###########################################################################

