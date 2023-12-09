#!/usr/bin/perl
use strict;

use JSON;

my $fn = shift @ARGV;

die "Usage: $0 <filename>\n" if (!$fn);

my $json = '';
open TXT, "<$fn";
while (<TXT>) {
	$json .= $_;
}
close TXT;

my $href = JSON->new->utf8->decode($json);
print JSON->new->pretty->encode($href)."\n";

