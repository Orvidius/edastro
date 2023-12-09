#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);
use ATOMS qw(make_csv);

my $debug_limit	= ''; #'limit 100000'; 
my $pi		= 3.1415926535;
my $table	= 'rings';
my %total	= ();
my @stats	= qw(outerRadius innerRadius width mass density);
my $chunk_size	= 10000;
my $use_vector	= 0;
my $one		= 1;
my %idlist	= ();



foreach my $pass (0,1) {
	my $c = 0;

	print "First pass.\n" if (!$pass);
	print "Second pass.\n" if ($pass);

	foreach my $table (qw(planets stars)) {

		print "Get $table.\n";
		my @rows = ();
	
		my $idfield = $table eq 'planets' ? 'planetID' : 'starID';
	
		my @check = db_mysql('elite',"select max($idfield) as num from $table");
		next if (!@check);
		my $maxID = ${$check[0]}{num};
	
		my $chunk = 0;
	
		while ($chunk < $maxID) {
	
			my $next = $chunk + $chunk_size;

			%idlist = ();
	
			@rows = db_mysql('elite',"select id,planet_id,isStar,subType body,type,mass,innerRadius,outerRadius from rings,$table ".
					"where planetID>=$chunk and planetID<$next and planet_id=planetID and type is not null and subType is not null ".
					"and isStar=0 and deletionState=0 $debug_limit")
					if ($table eq 'planets');
		
			@rows = db_mysql('elite',"select id,planet_id,isStar,subType body,type,mass,innerRadius,outerRadius from rings,$table ".
					"where starID>=$chunk and starID<$next and planet_id=starID and type is not null and subType is not null ".
					"and isStar=1 and deletionState=0 $debug_limit")
					if ($table eq 'stars');
		
			while (@rows) {
				my $r = shift @rows;
				my $id = $$r{id};
				my $body = $$r{body};
				my $type = $$r{type};
			
				next if (!$$r{innerRadius} || !$$r{outerRadius} || !$$r{mass});
			
				$$r{width} = abs($$r{outerRadius} - $$r{innerRadius});
				$$r{width} = 0 if ($$r{$id}{width} < 0);

				my $area = abs(($pi * $$r{outerRadius}**2) - ($pi * $$r{innerRadius}**2));
				$$r{density} = $$r{mass} / $area;

				$idlist{$$r{$idfield}} = \$one;

				if (!$pass) {
					add_ring($body,$id,$r);
					add_ring($type,$id,$r);
					add_ring('planets',$id,$r) if (!$$r{isStar});
					add_ring('stars',$id,$r) if ($$r{isStar});
					add_ring('total',$id,$r);
				} else {
					deviation($body,$r);
					deviation($type,$r);
					deviation('planets',$r) if (!$$r{isStar});
					deviation('stars',$r) if ($$r{isStar});
					deviation('total',$r);
				}
				
				$c++;
				print '.' if ($c % 10000 == 0);
				print "\n" if ($c % 1000000 == 0);
			}
	
			if (!$pass && !$use_vector) {
				foreach my $type (keys %idlist) {
					if (ref($idlist{$type}) eq 'HASH') {
						$total{$type}{star_count} += int(keys(%{$idlist{$type}{star}})) if (ref($idlist{$type}{star}) eq 'HASH');
						$total{$type}{planet_count} += int(keys(%{$idlist{$type}{planet}})) if (ref($idlist{$type}{planet}) eq 'HASH');
					}
				}
			}

			$chunk = $next;
		}

		if (!$pass) {
			foreach my $type (keys %total) {
				next if (!$total{$type}{num});
			
				if ($use_vector) {
					$total{$type}{star_count} = unpack("%32b*", $total{$type}{id}{star});
					$total{$type}{planet_count} = unpack("%32b*", $total{$type}{id}{planet});
				}
			
				$total{$type}{body_count} = $total{$type}{star_count} + $total{$type}{planet_count};
			
				foreach my $thing (@stats) {
					$total{$type}{$thing}{avg} = $total{$type}{$thing}{total} / $total{$type}{num};
				}
			}
		}

		print "\n";
	}
}

sub add_ring {
	my $type = shift;
	my $id = shift;
	my $r = shift;

	my $bodytype = 'planet';
	$bodytype = 'star' if ($$r{isStar});

	foreach my $thing (@stats) {
		if ($$r{$thing}) {
			$total{$type}{$thing}{min} = $$r{$thing} if (!$total{$type}{$thing}{min} || $$r{$thing} < $total{$type}{$thing}{min});
			$total{$type}{$thing}{max} = $$r{$thing} if (!$total{$type}{$thing}{max} || $$r{$thing} > $total{$type}{$thing}{max});
		}
		$total{$type}{$thing}{total} += $$r{$thing};
	}
	$total{$type}{num}++;
	
	if ($use_vector) {
		vec($total{$type}{id}{$bodytype},$$r{planet_id},1) = 1;
	} else {
		$idlist{$type}{$bodytype}{$$r{planet_id}} = \$one;
	}
}

sub deviation {
	my $type = shift;
	my $r = shift;

	foreach my $thing (@stats) {
		my $dev = ($$r{$thing} - $total{$type}{$thing}{avg}) ** 2;
		$total{$type}{$thing}{devtotal} += $dev;
	}
}

print "\n\nOutput:\n\n";

open CSV, ">rings-statistics.csv";
my $header = "Ring/Body Type,Ring Count,Star Count,Planet Count,Average Total Rings per Ringed Body,".
	"Inner Radius(km) Min,Inner Radius(km) Max,Inner Radius(km) Average,Inner Radius Standard Deviation,".
	"Outer Radius(km) Min,Outer Radius(km) Max,Outer Radius(km) Average,Outer Radius Standard Deviation,".
	"Width(km) Min,Width(km) Max,Width(km) Average,Width Standard Deviation,".
	"Mass(Mt) Min,Mass(Mt) Max,Mass(Mt) Average,Mass Standard Deviation,".
	"Density(Mt/km^2) Min,Density(Mt/km^2) Max,Density(Mt/km^2) Average,Density Standard Deviation";

print "$header\n";
print CSV "$header\r\n" if (!$debug_limit);

print_blank();
print_row('total');
print_row('planets');
print_row('stars');
print_blank();
print_row('Icy');
print_row('Metal Rich');
print_row('Metallic');
print_row('Rocky');
print_blank();

foreach my $type (sort keys %total) {
	print_row($type);
}

sub print_row {
	my $type = shift;

	foreach my $thing (@stats) {
		next if (!$total{$type}{num});
		$total{$type}{$thing}{devavg} = $total{$type}{$thing}{devtotal} / $total{$type}{num};
		$total{$type}{$thing}{stddev} = sqrt($total{$type}{$thing}{devavg}) if ($total{$type}{$thing}{devavg});
		$total{$type}{$thing}{stddev} = 0 if (!$total{$type}{$thing}{stddev});
	}

	my $average_rings = $total{$type}{num}/($total{$type}{star_count}+$total{$type}{planet_count});
	#my $average_rings = sprintf("%0.03f",$total{$type}{num}/($total{$type}{star_count}+$total{$type}{planet_count}));
	#$average_rings =~ s/\.0+$//;

	my $out = make_csv($type,$total{$type}{num},$total{$type}{star_count},$total{$type}{planet_count},$average_rings,
		$total{$type}{innerRadius}{min},$total{$type}{innerRadius}{max},$total{$type}{innerRadius}{avg},$total{$type}{innerRadius}{stddev},
		$total{$type}{outerRadius}{min},$total{$type}{outerRadius}{max},$total{$type}{outerRadius}{avg},$total{$type}{outerRadius}{stddev},
		$total{$type}{width}{min},$total{$type}{width}{max},$total{$type}{width}{avg},$total{$type}{width}{stddev},
		$total{$type}{mass}{min},$total{$type}{mass}{max},$total{$type}{mass}{avg},$total{$type}{mass}{stddev},
		$total{$type}{density}{min},$total{$type}{density}{max},$total{$type}{density}{avg},$total{$type}{density}{stddev},
		);

	print "$out\n";
	print CSV "$out\r\n" if (!$debug_limit);

	delete($total{$type});
}

sub print_blank {
	print "\n";
	print CSV "\r\n";
}

close CSV if (!$debug_limit);

exit;




