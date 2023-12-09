#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use ATOMS qw(parse_csv);

my %keys = ();

#Type,Variable,"Max EDAstro ID","Max Name","Max EDSM ID","Max EDSM System ID","Max System ID64","Max System Name","Min EDAstro ID","Min Name","Min EDSM ID","Min EDSM System ID","Min System ID64","Min System Name"

open CSV, "</home/bones/elite/scripts/galactic-records-keys.csv";
while (<CSV>) {
	chomp;
	my @v = parse_csv($_);

	$keys{$v[6]}=1 if (!$v[5]);
	$keys{$v[12]}=1 if (!$v[11]);
}
close CSV;

system('/home/bones/elite/edsm/get-system-bodies.pl',keys %keys);

