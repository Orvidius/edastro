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
use ATOMS qw(btrim epoch2date $progname count_instances my_syslog);
use lib "/home/bones/elite";
use EDDN qw(eddn_json game_OK);


##########################################################################

my $debug	= 0;
my $daemonizing	= 1;
my $verbose	= 1;
my $log_only	= 0;
my $down_sleep	= 300;

my $restart_seconds		= 28800;	# 8 hours
my $loop_restart_seconds	= 60;		# 1 minute

my $schemafile	= '/home/bones/elite/eddn-schemas.dat';

my $progname	= basename($0);
my $startname	= $0; $startname =~ s/$progname\s+.*$/$progname/s;
my $endpoint	= "tcp://eddn.edcd.io:9500";

print "startname=$startname\nParam: $ARGV[0]\n";

##########################################################################

if ($debug && $ARGV[0] eq 'cron') {
	$debug = 0;
}

if (!$debug && $ARGV[0] eq 'debug') {
	#print "Debug mode, not executing from cron.\n";
	#exit;
	$debug = 1;
	$verbose = 1;

	$restart_seconds = 10;
	$loop_restart_seconds = 5;
}

if ($ARGV[0] eq 'logonly') {
	$log_only = 1;
	$debug = 1;
	$verbose = 1;
}

$verbose = 0 if ($ARGV[0] eq 'cron');

if ($ARGV[0] ne 'cron' && -f $ARGV[0]) {
	do_file($ARGV[0]);
	exit;
}

if (!$debug && count_instances() >= 1) {
	die "$progname is already running.\n";
}

daemonize() if (!$debug && $daemonizing);

my %schemas = ();

my $schemadata = '';

open TXT, "<$schemafile";
while (<TXT>) {
	$schemadata .= $_;
	chomp;
	if ($_) {
		my @v = split("\t",$_);
		my $s = shift @v;
		$schemas{$s} = {};
		foreach my $e (@v) {
			$schemas{$s}{$e} = 1;
		}
	}
}
close TXT;

my $ctx = ZMQ::FFI->new();
my $s = $ctx->socket(ZMQ_SUB);

$s->die_on_error(1);
$s->set_linger(1);
$s->connect($endpoint);
$s->subscribe('');

open LOG, ">>/home/bones/elite/eddn-log.jsonl";

my $startepoch = time;
my $alarm_status=0;
my $timeout = 20;

$SIG{ALRM} = sub { $alarm_status=1; die "timeout"; };

while(1) {
	if (time - $startepoch >= $restart_seconds) {
		do_restart();
	} else {
		$0 = "$progname ".time;
	}

	$alarm_status=1;
	eval {
		alarm($timeout);
		#usleep 100_000 until ($s->has_pollin || time - $startepoch >= $restart_seconds);

		my $loop_start = time;

		while (!$s->has_pollin) {
			usleep 100_000;
			my $time = time;
			$0 = "$progname ".$time;

			if ($time - $startepoch >= $restart_seconds || $time - $loop_start >= $loop_restart_seconds) {
				do_restart();
			}
		}
		alarm(0);

		if (!$s->has_pollin && time - $startepoch >= $restart_seconds) {
			do_restart();
		}
	
		my $data = $s->recv();
	
		if ($s->last_errno == EAGAIN) {
			sleep 1;
		} elsif ($s->last_errno) {
			warn $s->last_strerror."\n";

			if (game_OK()) {
				printlog('Error: '.$s->last_strerror);
				sleep 1;
				do_restart();
			} else {
				printlog('Error[down]: '.$s->last_strerror);
				sleep $down_sleep;
				do_restart('down');
			}
		} else {
			my $json = uncompress($data);
	
			if ($log_only) {
				printJSON($json);
			} else {
				do_json($json,1);
			}
			$alarm_status=0;
		}
		alarm(0);
	};
	alarm(0);

	if ($alarm_status || $@) {
		if (game_OK()) {
			printlog("Timed out!") if (!$@);
			printlog("Error: $@") if ($@);
			do_restart();
		} else {
			printlog("Timed out! [down]") if (!$@);
			printlog("ERROR[down]: $@") if ($@);
			sleep $down_sleep;
			do_restart('down');
		}
	}
}

$s->unsubscribe('');
close LOG;

exit;

##########################################################################

sub printJSON {
	my $json = shift;

	open JSONTXT, ">>/home/bones/elite/eddn-data/events.jsonl";
	print JSONTXT "$json\n";
	close JSONTXT;
}

sub printlog {
	foreach (@_) {
		print "### $_\n" if ($debug || $verbose);
		my_syslog($_);
	}
	#open LOGTXT, ">>/home/bones/elite/eddn-listener.log";
	#print '['.epoch2date(time).'] '.$_."\n";
	#close LOGTXT;
}

sub do_restart {
	my $msg = shift;
	$msg = "[$msg]" if ($msg);

	printlog("Restarting$msg: $startname $ARGV[0]");
	close LOG;
	#$s->unsubscribe('');
	#$s->close();
	#$ctx->destroy();
	#sleep 1;
	exec($startname,$ARGV[0]);
}


sub do_file {
	my $fn = shift;

	open JSONL, "<$fn";
	while (<JSONL>) {
		my $line = $_;
		$line =~ s/^[^\{]*//s;

		if ($line =~ /^\s*\{.*\}\s*$/s) {
			do_json($line,0);
		}
	}
	close JSONL;
}

sub do_json {
	my $json = shift;
	my $logging = shift;

	print LOG "$json\n" if (!$debug && $verbose);
	my $ref = decode_json($json);
	my $schema = $ref->{'$schemaRef'};
	chomp $json;
	$json =~ s/[\r\n]+//gs;

	printf "schema = %s\n", $schema if ($verbose);
	printf "\tsoftware = %s\n", $ref->{header}->{softwareName} if ($verbose);

	if ($schema eq "https://eddn.edcd.io/schemas/journal/1") {
		my $event = $ref->{message}->{event};
		printf "\tevent = %s\n", $event;

		if (!$schemas{$schema}{$event}) {
			add_schema($schema,$event);
		}

		if ($event eq "FSDJump" || $event eq 'Location') {
			printf "\tStarSystem = %s (%s) %s,%s,%s\n", $ref->{message}->{StarSystem}, $ref->{message}->{SystemAddress}, 
				$ref->{message}->{StarPos}->[0],$ref->{message}->{StarPos}->[1],$ref->{message}->{StarPos}->[2];
		}

		if ($event eq "CarrierJumpRequest") {
			printf "\tStarSystem = %s (%s) %s, CarrierID=%s\n", $ref->{message}->{SystemName}, $ref->{message}->{SystemAddress}, 
				$ref->{message}->{Body}, $ref->{message}->{CarrierID};
		}
	}
	eddn_json($json,$logging) if (!$debug);
	print "------\n" if ($verbose);

	if ($schema && !exists($schemas{$schema})) {
		add_schema($schema);
	}
}


sub add_schema {
	my $schema = shift;
	my $event = shift;
	my $out = '';

	$schemas{$schema}{$event} = 1 if ($event);
	%{$schemas{$schema}} = () if (!$event && !exists($schemas{$schema}));

	foreach my $s (sort keys %schemas) {
		my @list = ($s);
		push @list, sort keys %{$schemas{$s}} if (keys %{$schemas{$s}});
		
		$out .= join("\t",@list)."\n";
	}

	if ($out ne $schemadata) {
		open SCHEMA, ">$schemafile";
		print SCHEMA $out;
		close SCHEMA;
	}
}

sub daemonize {
	my $pid = fork;
	exit if ($pid);
	die "Couldn't fork: $!" unless defined($pid);
	POSIX::setsid() or die "Can't start new session: $!";
	my_syslog('Started');
}


##########################################################################

