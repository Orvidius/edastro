#!/usr/bin/perl
use strict;
use lib "/home/bones/perl";
use DB qw(db_mysql);
use ATOMS qw(make_csv);

my %sector = ();
my %out = ();

my @rows = db_mysql('elite',"select sectors.name,count(*) as num from sectors,systems where systems.id=sectorID and deletionState=0 group by sectors.name");
foreach my $r (@rows) {
	$sector{$$r{name}} = $$r{num};
}

my @rows = db_mysql('elite',"select sectors.name,count(*) as num from sectors,systems where systems.id=sectorID and date_added<='2021-03-01 00:00:00' and deletionState=0 group by sectors.name");
foreach my $r (@rows) {
	next if (!$sector{$$r{name}});
	my $percent = $$r{num}/$sector{$$r{name}};

	$out{$$r{name}}{percent} = $percent;
	$out{$$r{name}}{line} = make_csv($$r{name},$sector{$$r{name}},$$r{num},sprintf("%.02f",$$r{num}/$sector{$$r{name}}))."\r\n";
}

print "Sector,Total,New,Percent New\r\n";
foreach my $name (sort {$out{$b}{percent} <=> $out{$a}{percent}} keys %out) {
	print $out{$name}{line};
}
