#!/usr/bin/perl
use strict; $|=1;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my $fixing = 0;
$fixing = 1 if (@ARGV);

my @rows = db_mysql('elite',"select id,name from codexname order by name");

foreach my $r (@rows) {
	my @rows2 = db_mysql('elite',"select id,name,preferred from codexname_local where codexnameID=? order by preferred desc,name",[($$r{id})]);

	my $pref = 0;

	foreach my $r2 (@rows2) {
		$pref++ if ($$r2{preferred});
	}

	if ($fixing && @rows2 == 1 && !$pref) {
		foreach my $r2 (@rows2) {
			db_mysql('elite',"update codexname_local set preferred=1 where id=?",[($$r2{id})]);
		}
	}

	next if (@rows2 == 1 || $pref == 1);	# OK if either is set to 1

	print "$$r{name} [$$r{id}]: ".int(@rows2)."\n";

	foreach my $r2 (@rows2) {
		print "\t* " if ($$r2{preferred});
		print "\t  " if (!$$r2{preferred});

		print "$$r2{name} [$$r2{id}]\n";
	}
}
