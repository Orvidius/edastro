#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

use Image::Magick;

############################################################################

show_queries(0);

my @rows = db_mysql('elite',"select systems.name,systems.id64,stars.name starname,planets.name planetname, stars.subType starclass, planets.subtype planettype, ".
		"planets.gravity, planets.surfaceTemperature,planets.surfacePressure,planets.earthMasses,planets.radius from stars,planets,systems ".
		"where stars.subType='G (White-Yellow) Star' and planets.subType='Water world' and stars.systemId64=planets.systemId64 and stars.systemId64=systems.id64 ".
		"and stars.deletionState=0 and planets.deletionState=0 and systems.deletionState=0");

print make_csv('System','Star','StarClass','StarType','Planet','PlanetType','Gravity','Temperature','Pressure','EarthMasses','Radius')."\r\n";

my $count = 0;
foreach my $r (sort {$$a{starname} cmp $$b{starname}} @rows) {
	my $primary = 'secondary';

	if ($$r{starname} eq $$r{name}) {
		$primary = 'single';

		my @count = db_mysql('elite',"select starID from stars where systemId64='$$r{id64}'");
		$primary = 'primary' if (@count > 1);

	} elsif ($$r{starname} =~ /^(.*\S)\s+([a-zA-Z]+)\s*$/) {
		$primary = 'primary' if (uc($2) eq 'A');
	}

	#print "$$r{name}, $$r{id64}, $$r{starname}, $$r{planetname}, $primary\n";

	if ($primary eq 'primary' || $primary eq 'single') {
		print make_csv($$r{name},$$r{starname},$$r{starclass},$primary,$$r{planetname},$$r{planettype},$$r{gravity},
			$$r{surfaceTemperature},$$r{surfacePressure},$$r{earthMasses},$$r{radius})."\r\n";
		$count++;
	}
}
print "$count found\n";



