#!/usr/bin/perl
use strict;

use JSON;

use utf8;
#use utf8::all;
use feature qw( unicode_strings );

my $fn = shift @ARGV;

die "Usage: $0 <filename>\n" if (!$fn);

my $json = '';
open TXT, "<$fn";
while (<TXT>) {
	$json .= $_;
}
close TXT;

my $href = JSON->new->decode($json);

foreach my $jref (@{$href}) {
	print JSON->new->encode($jref)."\n";
}

