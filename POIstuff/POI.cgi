#!/usr/bin/perl
use strict; $|=1;
###########################################################################

use lib "/www/EDtravelhistory/perl";
use ATOMS qw(parse_csv);

###########################################################################

my $type	= $ARGV[0];
my $color	= $ARGV[1];
my $path	= '/www/edastro.com/galmap';
my %list	= ();

print "Content-Type: text/plain\n\n";

if ($type ne 'ALL') {
	make_list($type);
} else {
	make_list('AB');	# Asteroid Bases
	make_list('AS');	# Abondoned Settlements
	make_list('N');		# Nebulae
	make_list('X');		# Permit locked regions
	make_list('P');		# Planetary Bases
	make_list('S');		# Starbases
	make_list('M');		# Meridians
	make_list();		# Misc
}

foreach my $s (sort { $list{$a} <=> $list{$b} } keys %list) {
	print $s;
}

exit;

###########################################################################

sub make_list {
	my $type = shift;
	my $fn   = 'POI-misc.csv';
	
	$fn = 'POI-nebulae.csv' if ($type eq 'N');
	$fn = 'POI-asteroidbases.csv' if ($type eq 'A' || $type eq 'AB');
	$fn = 'POI-abandoned.csv' if ($type eq 'AS');
	$fn = 'POI-permitlocks.csv' if ($type eq 'X');
	$fn = 'POI-planetarybases.csv' if ($type eq 'P');
	$fn = 'POI-starbases.csv' if ($type eq 'S');
	$fn = 'POI-meridians.csv' if ($type eq 'M');
	
	if ($fn && -e "$path/$fn") {
		open TXT, "<$path/$fn";
		while (<TXT>) {
			chomp;
	
			next if (/^\s*\// || /^\s*#/);
	
			my $string = $_;
			$string =~ s/ \/ /,/gs;
	
			my @v = parse_csv($string);
	
			my %edsm_id = ();
	
			if ($v[0] =~ /^\s*[\d\;]+\s*$/ && $v[3] =~ /^\s*[\-\d\.]+\s*$/) {
				my @ids = split /;/,shift(@v);
				foreach my $i (@ids) {
					$edsm_id{$i} = 1 if ($i);
				}
			}
	
			my $c = '';
			$c = ",'$color'" if ($color);
			$c = ",$v[4]" if ($v[4]);
	
			my $d = sqrt($v[0]**2 + $v[1]**2 + $v[2]**2);
	
			my $type_add = '';
			$type_add = ",'$type'" if ($type);
	
			$list{"\t\tcreateGalmapMarker3D(map,$v[0],$v[1],$v[2],\"$v[3]\"$type_add$c);\n"} = $d;
		}
		close TXT;
	}
}

###########################################################################



