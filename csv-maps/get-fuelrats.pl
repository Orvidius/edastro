#!/usr/bin/perl
use strict;
use JSON;

use lib "/home/bones/perl";
use ATOMS qw(make_csv);

my $fn = 'fuelrats.json';

system("/usr/bin/wget -O fuelrats.json https://system.api.fuelrats.com/heatmap");

my $json = '';
open TXT, "<$fn";
while (<TXT>) {
	$json .= $_;
}
close TXT;

my $href = JSON->new->decode($json);

print "System,Rescues,X,Y,Z\r\n";

foreach my $jref (@{$href}) {
	#print JSON->new->encode($jref)."\n";
	my @systems = keys(%$jref);

	foreach my $s (@systems) {
		print make_csv($s,$$jref{$s}{rescues},$$jref{$s}{coords}{x},$$jref{$s}{coords}{y},$$jref{$s}{coords}{z})."\r\n";
	}
}

