#!/usr/bin/env perl

use JSON::XS 'decode_json';
use ZMQ::FFI qw(ZMQ_SUB);
use Time::HiRes q(usleep);
use Compress::Zlib;
use Data::Dumper;

sub msg {
	printf STDERR @_;
}

my $endpoint = "tcp://eddn.edcd.io:9500";
my $ctx			= ZMQ::FFI->new();

my $s = $ctx->socket(ZMQ_SUB);

$s->connect($endpoint);

$s->subscribe('');

open LOG, ">>/home/bones/elite/eddn-log.jsonl";

while(1)
{
	usleep 100_000 until ($s->has_pollin);
	my $data = $s->recv();
	my $udata = uncompress($data);

	# turn the json into a perl hash
	print LOG "$udata\n";
	my $pj = decode_json($udata);
	my $schema = $pj->{'$schemaRef'};
	#my $odyssey = $pj->{header}->{odyssey} ? 'true' : 'false';
	#$odyssey = 'null' if (!defined($pj->{header}->{odyssey}));
	msg "schema = %s\n", $schema;
	msg "	software = %s\n", $pj->{header}->{softwareName};
	msg "	odyssey = %s\n", $odyssey if ($odyssey);
	if ($schema eq "https://eddn.edcd.io/schemas/journal/1") {
		my $event = $pj->{message}->{event};
		msg "	event = %s\n", $event;
		if ($event eq "FSDJump" || $event eq 'Location' || $event =~ /^Scan/ || $event =~ /CarrierJump/i) {
			msg "	StarSystem = %s (%s) %s,%s,%s\n", $pj->{message}->{StarSystem}, $pj->{message}->{SystemAddress}, 
				$pj->{message}->{StarPos}->[0],$pj->{message}->{StarPos}->[1],$pj->{message}->{StarPos}->[2];
			msg Dumper($pj);
		}
	}
	msg "------\n";
}
$s->unsubscribe('');
close LOG;
