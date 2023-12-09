#!/usr/bin/perl
use strict;
use lib "/home/bones/perl";
use DB qw(db_mysql);

my @rows = db_mysql('elite',"select * from codexname_local");
my @list = ();

foreach my $r (@rows) {
	if ($$r{name} =~ /[^[:print:]]/) {
		print "Not printable: $$r{name}\n";
		push @list, $$r{id};
	} else {
		print "Printable: $$r{name}\n";
	}
}

print "Non printable ID list: ".join(',',@list)."\n";


