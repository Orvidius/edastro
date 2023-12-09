#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my %hash = ();

my $dec = 'Dec';

foreach my $table (qw(planets stars)) {
	my $maxID = 0;

	my $IDfield = 'planetID';
	$IDfield = 'starID' if ($table eq 'stars');

	my @rows = db_mysql('elite',"select max($IDfield) as maxID from $table");
	$maxID = ${$rows[0]}{maxID};

	print "$table($maxID)\n";

	my $chunk_size = 10000;
	my $chunk = 0;

	my @fieldlist = qw(surfacePressure gravity earthMasses radius axialTilt rotationalPeriod orbitalPeriod orbitalEccentricity orbitalInclination argOfPeriapsis semiMajorAxis);

	if ($table eq 'stars') {
		@fieldlist = qw(absoluteMagnitude solarMasses solarRadius axialTilt rotationalPeriod orbitalPeriod orbitalEccentricity orbitalInclination argOfPeriapsis semiMajorAxis);
	}

next if ($table eq 'stars');
@fieldlist = qw(surfacePressure);

	while ($chunk < $maxID) {
		my $next_chunk = $chunk + $chunk_size;

		foreach my $field (@fieldlist) {
			db_mysql('elite',"update $table set $field$dec=$field,updated=updated where $IDfield>=? and $IDfield<? and $field$dec is null and $field is not null",
				[($chunk,$next_chunk)]);
		}

		$chunk = $next_chunk;
		print '.';
	}
	print "\n";
}

print "\n";
