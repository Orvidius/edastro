#!/usr/bin/perl
use strict;
use lib "/home/bones/perl";
use DB qw(db_mysql);

my @rows = db_mysql('elite',"select name,atmosphereType,subType,surfacePressure from planets where surfacePressure is not null and surfacePressure<=0.03 and surfacePressure>=0.001 and deletionState=0 and atmosphereType not like '%thin%' order by name");

print "Name,Type,Atmosphere,Pressure\r\n";

foreach my $r (@rows) {
	print "$$r{name},$$r{subType},$$r{atmosphereType},$$r{surfacePressure}\r\n";
}
