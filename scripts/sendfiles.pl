#!/usr/bin/perl
use strict; $|=1;

die "Need filenames\n" if (!@ARGV);

foreach my $fn (@ARGV) {
	if ($fn =~ /[\$\@\!\@\%\^\&\*\(\)\[\]\{\}\\\/\?\|\;\:\~\`\'\"]/) {
		warn "Can't send illegal filename: $fn\n";
		next;
	}
	my $send = "scp $fn www\@services:/www/edastro.com/mapcharts/files/";
	print "# $send\n";
	system($send);
}
