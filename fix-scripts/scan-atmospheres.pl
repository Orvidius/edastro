#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my %hash = ();

open TXT, "grep Atmosphere journals/Journal\.* |";
while (<TXT>) {
	my $name = undef;
	my $type = undef;
	my $atmo = undef;
	if (/"BodyName"\s*:\s*"([^"]+)"/) {
		$name = $1;
	}
	if (/"Atmosphere"\s*:\s*"([^"]*)"/) {
		$atmo = $1;
	}
	if (/"AtmosphereType"\s*:\s*"([^"]*)"/) {
		$type = $1;
	}

	if ($name && defined($atmo) && defined($type) && !$hash{$atmo}{$type}) {

		my @rows = db_mysql('elite',"select atmosphereType from planets where name=?",[($name)]);
		if (@rows) {
			my $result = ${$rows[0]}{atmosphereType};
			if ($result) {
				print "\"$atmo\", \"$type\" = $result ($name)\n";
				$hash{$atmo}{$type} = $result;
			}
		}
	}
}
close TXT;

print "\n\n";

foreach my $atmo (sort keys %hash) {
	foreach my $type (sort keys %{$hash{$atmo}}) {
		print "    \$atmo_map{\"$atmo\"}{\"$type\"} = \"$hash{$atmo}{$type}\";\n";
	}
}
