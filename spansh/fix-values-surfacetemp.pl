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

	my $name = $v[0];
	my $temp = $v[1];

	#my $table = $line =~ /solarMasses/ ? 'stars' : 'planets';

	my $set = 'updated=updated';
	my @params = ();
	my $ok = 0;
	
	if ($temp && $temp =~ /\.\d+/) {
		$set .= ',surfaceTemperatureDec=?,surfaceTemperature=?';
		push @params, $temp;
		push @params, int($temp);
		$ok = 1;
	}

	$set =~ s/^,//;
	push @params, $name;

	if ($ok && $set && @params) {
		#eval {
			db_mysql('elite',"update $table set $set where name=? and (surfacetemperatureDec is null or surfacetemperatureDec=0 or floor(surfacetemperatureDec)=surfacetemperatureDec)",\@params);
		#};
	}
	
	$dotcount++;
	print '.' if ($dotcount % 10000 == 0);
}

close DATA;
	





