#!/usr/bin/perl
use strict;
use Data::Dumper;

use lib "/home/bones/perl";
use DB qw(db_mysql);

############################################################################

my $debug	= 0;
my $chunk_size	= 100000;
my $debug_count	= 100000;

my @variables	= qw(solarMasses solarRadius surfaceTemperature age absoluteMagnitude); # These must all match for inclusion in the output

############################################################################
my $varlist	= join(',',@variables);

my @max = db_mysql('elite',"select max(starID) as maxID from stars");
my $maxID = ${$max[0]}{maxID};

my $id = 0;
my %data = ();
my $count = 0;
my $found = 1;

while ($id < $maxID) {
	my @rows = db_mysql('elite',"select name,subType,$varlist from stars where starID>=? and starID<? and isMainStar=1 and deletionState=0",[($id,$id+$chunk_size)]);
	$id += $chunk_size;

	foreach my $r (@rows) {
		%{$data{$$r{subType}}} = () if (!defined($data{$$r{subType}}) || ref($data{$$r{subType}}) ne 'HASH'); # initialize if missing
		my $href = $data{$$r{subType}};

		foreach my $v (@variables) {

			last if (!$$r{$v});	# Use only non-zero values

			if ($v eq $variables[@variables-1]) {
				${$$href{$$r{$v}}{$$r{name}}} = \$found;	# Memory efficient, they all point to the same thing.
			} else { 
				$href = \%{$$href{$$r{$v}}};
			}
		}

	}

	$count++;
	print '.';
	if ($count*$chunk_size >= 10000000) {
		$count = 0;
		print "\n";
	}

	last if ($debug && $id>=$debug_count);
	#last if ($debug);
}
print "\n";

#print Dumper(\%data)."\n";

if (!$debug) {
	open CSV, ">/home/bones/elite/scripts/identical-main-stars.csv";
	print CSV "Type,$varlist,name,X,Y,Z\r\n";
} else {
	print "Type,$varlist,name,X,Y,Z\r\n";
}

foreach my $subType (sort {$a cmp $b} keys %data) {
	recursive_print($subType,\%{$data{$subType}},int(@variables))."\r\n";
}

close CSV if (!$debug);
exit;


############################################################################

sub recursive_print {
	my $sofar = shift;
	my $href  = shift;
	my $depth = shift;
	
	if (ref($href) eq 'HASH') {

		return if ($depth <= 0 && keys %$href <= 1);	# We only want cases of 2+ at the last variable

		foreach my $val (sort {$a <=> $b} keys %$href) {

			if (ref($$href{$val}) eq 'HASH') {
				recursive_print("$sofar,$val",\%{$$href{$val}},$depth-1);
			} else {
				my $coord_string = get_coords($val);
				print CSV "$sofar,$val,$coord_string\r\n" if (!$debug);
				print "$sofar,$val,$coord_string\n" if ($debug);
			}
		}
	}
}

sub get_coords {
	my $name = shift;
	my ($x,$y,$z);

	my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems,stars where stars.name=? and systems.id64=stars.systemId64",[($name)]);
	if (@rows) {
		$x = ${$rows[0]}{coord_x};
		$y = ${$rows[0]}{coord_y};
		$z = ${$rows[0]}{coord_z};
	}

	return "$x,$y,$z";
}

############################################################################



