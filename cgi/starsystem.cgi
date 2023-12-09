#!/usr/bin/perl
use strict;

use JSON;
use CGI;

use lib "/home/bones/perl";
use DB qw(rows_mysql db_mysql);

my $q = CGI->new;
my $name = $q->param('s');

$name =~ s/_/\+/gs;

print "Content-Type: application/json\n\n";

if ($ENV{REMOTE_ADDR} ne '45.79.209.247' && $ENV{REMOTE_ADDR} ne '74.207.224.66' && $ENV{REMOTE_ADDR} !~ /^10\.99\.50\./) {
	print "{}\n";
	exit;
}

my @rows = db_mysql('elite',"select * from systems where name=? and deletionState=0",[($name)]);

if (@rows) {
	my $r = shift @rows;
	print JSON->new->encode($r)."\n";
	exit;
} else {

	@rows = db_mysql('elite',"select * from navsystems where name=?",[($name)]);

	if (@rows) {
		my $r = shift @rows;
		print JSON->new->encode($r)."\n";
		exit;
	}
}

print "{}\n";
