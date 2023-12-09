#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql columns_mysql show_queries);
use ATOMS qw(btrim);

my $dotcount = 0;

show_queries(0);

my $fn = $ARGV[0];

my $table = 'planets';
$table = 'stars' if ($fn =~ /star/);

open DATA, "<$fn";
#"distanceToArrival":1538.022286

while (my $line = <DATA>) {
	chomp $line;
	my @v = split /,/, $line;

	while ((@v>3 && $table eq 'planets') || (@v>2 && $table eq 'stars')) {
		my $s = shift @v;
		$v[0] = "$s,$v[0]";
	}

	my $name = $v[0];
	my $dist = $v[1];
	my $rad  = $v[2];

	my $set = '';
	my @params = ();
	
	if ($dist) {
		$set .= ',distanceToArrivalLS=?';
		push @params, $dist;
	}
	if ($rad && $table eq 'planets') {
		$set .= ',radius=?';
		push @params, $rad;
	}

	$set =~ s/^,//;
	push @params, $name;

	eval {
		db_mysql('elite',"update $table set $set where name=?",\@params) if ($set && @params);
	};
	
	$dotcount++;
	print '.' if ($dotcount % 100000 == 0);
	#print "\n" if ($dotcount % 1000000 == 0);
}

close DATA;
	





