#!/usr/bin/perl
use strict; $|=1;

my $path	= '/home/bones/elite/eddn-data';

my @t = localtime();
my $date = sprintf("%04u%02u",$t[5]+1900,$t[4]+1);

print "Date limit: $date\n";

opendir DIR, $path;
while (my $fn = readdir DIR) {
	#print "# $fn\n";
	if ($fn =~ /^(\d{6})-.+\.jsonl$/) {
		compress_file($fn) if ($1 lt $date);
	}
}
closedir DIR;

sub compress_file {
	my $fn = shift;

	print "> gzip $path/$fn\n";
	system("/usr/bin/gzip $path/$fn");
}
