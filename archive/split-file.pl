#!/usr/bin/perl
use strict;
$|=1;

my $splits = 10;
my $filename = $ARGV[0];
my %fh = ();

die "'$filename' not found\n" if (!$filename || !-e $filename);

open TXT, "/usr/bin/zcat $filename |" if ($filename =~ /\.gz$/);
open TXT, "<$filename" if ($filename !~ /\.gz$/);

my $out = $filename;
$out =~ s/\..+$//;

for (my $i=0; $i<$splits; $i++) {
	open $fh{$i}, ">$out.$i.split";
}

my $i = 0;
while (<TXT>) {
	my $handle = $fh{$i};
	$i++; $i = 0 if ($i>=$splits);
	print $handle $_;
}

close TXT;

