#!/usr/bin/perl
use strict;$|=1;

use Cwd qw(getcwd);

my $bin		= "/usr/bin";
my $zcat	= "$bin/zcat";
my $cat		= "$bin/cat";
my $path	= "/home/bones/elite/api/completed";

my %days = ();
my %months = ();

chdir $path;

my @t = gmtime;

my $thisday = sprintf("%04u%02u%02u",$t[5]+1900,$t[4]+1,$t[3]);
my $thismonth = sprintf("%04u%02u",$t[5]+1900,$t[4]+1);

opendir DIR, $path;
while (my $fn = readdir DIR) {
	if ($fn =~ /journaldata-(\d{8})-(\d{2}).json.gz/) {
		$days{$1}{$fn} = $2;
	}
	if ($fn =~ /journaldata-(\d{6})(\d{2})-day.json.gz/) {
		$months{$1}{$fn} = $2;
	}
}
closedir DIR;

foreach my $day (sort keys %days) {
	if ($day lt $thisday && $day =~ /(\d{6})(\d{2})/) {
		my ($month,$dayofmonth) = ($1,$2);
		my $files = join(' ',keys(%{$days{$day}}));
		my $dayfile = "journaldata-$day-day.json.gz";
		my_system("$cat $files > $dayfile");
		print "#> unlink $files\n";
		unlink keys(%{$days{$day}});
		$months{$month}{$dayfile} = $dayofmonth;
	}
}

foreach my $month (sort keys %months) {
	if ($month lt $thismonth) {
		my $files = join(' ',keys(%{$months{$month}}));
		my $monthfile = "journaldata-$month-month.json.gz";
		my_system("$cat $files > $monthfile");
		print "-- unlink $files\n";
		unlink keys(%{$months{$month}});
	}
}

sub my_system {
	print "#> ".join(' ',@_)."\n";
	system(@_);
}
