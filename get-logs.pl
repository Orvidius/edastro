#!/usr/bin/perl
use strict;
#####################################################################

use LWP 5.64;
use IO::Socket::SSL;
use JSON;

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);
use ATOMS qw(date2epoch epoch2date);

use lib "/home/bones/elite";
use EDSM qw(object_exists);

#####################################################################

my $debug	= 0;
my $verbose	= 0;

my $db		= 'elite';

my $apiDomain	= 'https://www.edsm.net';
#   $apiDomain	= 'https://beta.edsm.net' if ($debug);

my $logURL	= "$apiDomain/api-logs-v1/get-logs";
my $systemsURL	= "$apiDomain/api-v1/systems";

my %cmdr = ();

show_queries($debug);

$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

$ENV{HTTPS_DEBUG} = 1;

IO::Socket::SSL::set_ctx_defaults(
     SSL_verifycn_scheme => 'www',
     SSL_verify_mode => 0,
);

#####################################################################


my $time = time;
my $epoch = time;
my %systems_needed = ();
my %cmdr_seen = ();
my %cmdr_updated = ();

#TEST:
if (0) {
$systems_needed{'Clookuia KF-A d6'} = 1;
$systems_needed{'Clookuia NL-Y d10'} = 1;
get_systems();
exit;
}
#/TEST

get_commanders();
get_logs();
get_systems();

if ($cmdr_seen{1} || $ARGV[0]) {
	sleep 3;
	system("cd /home/bones/elite ; ./logs-to-TSV.pl > orvidius-logs.tsv");
}

my @list = sort keys %cmdr_updated;
@list = sort keys %cmdr_seen if ($ARGV[0]);

foreach my $c (@list) {
	system("/home/bones/elite/commander-map.pl $c $ARGV[0] $ARGV[1]");
}

exit;

#####################################################################

sub get_logs {
	print "Getting logs...\n";

	while (my $c = next_commander()) {

		my $end = epoch2date($cmdr{$c}{date} + (86400 * 7));
		my $start = epoch2date($cmdr{$c}{date}+1);

		$epoch = time;

		print "Looking up CMDR $c from '$start' -> '$end'\n";

		my $url = "$logURL?commanderName=$c\&apiKey=$cmdr{$c}{key}\&startDateTime=$start\&endDateTime=$end\&showId=1";
		print "GET $url\n";

		my $browser = LWP::UserAgent->new;
		my $response = $browser->get($url);
		
		if (!$response->is_success) {
			warn "Could not retrieve logs for $c from $start -> $end\n\t".$response->status_line;
			return;
		} else {
			my $json = JSON->new->allow_nonref;
			my $ref = $json->decode( $response->content );
			#print $json->pretty->encode( $ref )."\n\n" if ($verbose && $debug);

			do_logs($c,$ref,$end);
		}


		my $delay = get_delay($epoch,$response->header('X-Rate-Limit-Remaining'),$response->header('X-Rate-Limit-Limit'),);

		if ($delay > 0 && (next_commander() || keys %systems_needed)) {
			print "Sleeping: $delay\n";
			sleep $delay;
		}
	}
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

sub do_logs {
	my ($name, $ref, $enddate) = @_;

	my %input = %$ref;

	if ($input{msgnum} != 100) {
		print "Warning, pull request returned: $input{msgnum} \"$input{msg}\"\n";
		return;
	}

	if (ref($input{logs}) eq 'ARRAY') {
		my $count = 0;

		foreach my $l (sort { $$a{date} cmp $$b{date} } @{$input{logs}}) {

			if ($$l{firstDiscover}) {
				$$l{firstDiscover} = 1;
			} else {
				$$l{firstDiscover} = 0;
			}

			print "CMDR $name [$$l{date}] $$l{system} ($$l{systemId}/$$l{systemId64}) $$l{firstDiscover}\n";

			my $sql = "insert into logs (systemId,systemId64,system,cmdrID,shipId,firstDiscover,date) values (?,?,?,?,?,?,?)";
			my @params = ($$l{systemId},$$l{systemId64},$$l{system},$cmdr{$name}{ID},$$l{shipId},$$l{firstDiscover},$$l{date});
		
			if (check_exists($$l{systemId64},$$l{systemId},$cmdr{$name}{ID},$$l{date})) {
				print "Skipping entry for $$l{systemId},$$l{system},$cmdr{$name}{ID},$$l{date}\n";
			} else {
				print "SQL($db): $sql -- ".join(',',@params)."\n" if ($verbose || $debug);
				db_mysql($db,$sql,\@params) if (!$debug);
				$cmdr_updated{$cmdr{$name}{ID}} = 1;
			}

			$systems_needed{$$l{system}} = 1 if (!object_exists('system',$$l{systemId}));
			$cmdr_seen{$cmdr{$name}{ID}} = 1;

			set_commander_date($name,$$l{date});

			$count++;
		}

		if (!$count) {
			if (date2epoch($enddate) <= $time) {
				print "No logs. Updating CMDR $name to: $enddate\n";

				set_commander_date($name,$enddate);
			} else {
				print "No logs. Ignoring CMDR $name for now.\n";

				$cmdr{$name}{done} = 1;
			}
		} 
	}
}

sub set_commander_date {
	my ($name, $date) = @_;

	$cmdr{$name}{date} = date2epoch($date);

	my $sql = "update commanders set edsm_pull=? where ID=?";
	my @params = ($date,$cmdr{$name}{ID});

	print "SQL($db): $sql -- ".join(',',@params)."\n" if ($verbose || $debug);
	db_mysql($db,$sql,\@params) if (!$debug);
}

sub next_commander {
	my @tmplist = sort { $cmdr{$a}{date} <=> $cmdr{$b}{date} } keys %cmdr;
	my @list    = ();

	foreach my $c (@tmplist) {
		push @list, $c if (!$cmdr{$c}{done});
	}

	return undef if (!@list);

	my $c = $list[0];

	if ($cmdr{$c}{date} < $time) {
		return $c;
	} else {
		return undef;
	}

}

sub get_commanders {
	my @rows = db_mysql($db,"select * from commanders where active=1");

	foreach my $r (@rows) {
		next if (!$$r{name} || !$$r{edsm_key});

		$cmdr{$$r{name}}{key}  = $$r{edsm_key};
		$cmdr{$$r{name}}{ID}   = $$r{ID};
		$cmdr{$$r{name}}{date} = date2epoch($$r{edsm_pull});


		print "Verifying systems for $$r{name}\n";

		my %sys = ();

		my @logs = db_mysql($db,"select systemId,systemId64,system from logs where cmdrID='$$r{ID}'");
		while(@logs) {
			my $l = shift @logs;
			$sys{$$l{systemId}} = $$l{system};
		}

		print "Checking for non-existing systems for $$r{name}\n";
		foreach my $s (keys %sys) {
			my @check = db_mysql($db,"select ID from systems where edsm_id='$s'");
			$systems_needed{$sys{$s}} = 1 if (!@check);
		}

		print "Checking for missing coordinate systems for $$r{name}\n";
		#my @logs = db_mysql($db,"select systems.name sysname from logs,systems where (systemId=edsm_id or systemId64=id64) and coord_x is null and cmdrID='$$r{ID}'");
		my @logs = db_mysql($db,"select systems.name sysname from logs,systems where systemId=edsm_id and systemId>0 and coord_x is null and cmdrID='$$r{ID}'");
		push @logs, db_mysql($db,"select systems.name sysname from logs,systems where systemId64=id64 and systemId64>0 and coord_x is null and cmdrID='$$r{ID}'");
		foreach my $l (@logs) {
			$systems_needed{$$l{sysname}} = 1;
		}

		print "Backfilling missing systemId64 for $$r{name}\n";
		my @rows = db_mysql($db,"select logs.ID,systemId,id64 from logs,systems where cmdrID=? and systemId64 is null and systemId=edsm_id",[($$r{ID})]);
		foreach my $r (@rows) {
			db_mysql($db,"update logs set systemId64=? where ID=?",[($$r{id64},$$r{ID})]);
		}

	}
}

sub check_exists {
	my ($id64,$systemId,$cmdrID,$date) = @_;
	my @rows = db_mysql($db,"select ID from logs where (systemId64=? or systemId=?) and cmdrID=? and date=?",[($id64,$systemId,$cmdrID,$date)]);
	return int(@rows);
}

sub get_systems {
	my $depth = shift;
	$depth++;
	my $namelist = '';

	my $max_names = 80;

	my $c=0;
	foreach my $n (sort keys %systems_needed) {
		next if (!$systems_needed{$n});
	
		$namelist .= "\&systemName[]=$n";

		delete $systems_needed{$n};
		$c++;
		last if ($c>=$max_names);
	}

	my $ratelimit = undef;
	my $ratelimitmax = undef;

	if ($namelist) {
		my $url = "$systemsURL?showId=1\&showCoordinates=1$namelist";
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

			open TXT, ">systems-received.json";
			print TXT $response->content;
			print TXT "\n";
			close TXT;

			open TXT, ">systems-import.json";
			print TXT "[\n";

			my $json = JSON->new->allow_nonref;
			my $ref = $json->decode( $response->content );

			foreach my $r (@$ref) {
				#$$r{date} = $systems_needed{$$r{name}};
				$$r{date} = '2001-01-01 00:00:00' if (!$$r{date});
				print TXT "\t".$json->encode( $r )."\n";
			}

			print $json->pretty->encode( $ref )."\n\n" if ($verbose && $debug);

			print TXT "[\n";
			close TXT;

			system("/home/bones/elite/parse-data.pl -u systems-import.json");
		}
	}

	if (keys %systems_needed && $depth<20) {
		my $delay = get_delay($epoch,$ratelimit,$ratelimitmax);

		if ($delay > 0) {
			print "Sleeping: $delay\n";
			sleep $delay;
		}
		$epoch = time;
		get_systems($depth);
	}
}

#####################################################################



