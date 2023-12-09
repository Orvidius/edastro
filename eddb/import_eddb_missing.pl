#!/usr/bin/perl
use strict;

# Copyright (C) 2021, Ed Toton (CMDR Orvidius), All Rights Reserved.

#####################################################################

use lib "/home/bones/perl";
use DB qw(rows_mysql db_mysql show_queries);
use ATOMS qw(parse_csv make_csv epoch2date date2epoch);

my $debug = 0;

#id,edsm_id,name,x,y,z,population,is_populated,government_id,government,allegiance_id,allegiance,security_id,security,primary_economy_id,primary_economy,power,power_state,power_state_id,needs_permit,updated_at,simbad_ref,controlling_minor_faction_id,controlling_minor_faction,reserve_type_id,reserve_type,ed_system_address

my $fn = $ARGV[0];
die "Need filename!\n" if (!$fn);
die "File \"$fn\" does not exist!\n" if (!-e $fn);

show_queries($debug);
my $dotcount = 0;

	open CSV, "<$fn";

	my %header = ();
	my $h = <CSV>; chomp $h;
	my @v = parse_csv($h);
	my $n = 0;
	foreach my $s (@v) {
		$header{name} = $n if ($s eq 'name');
		$header{eddbID} = $n if ($s eq 'id');
		$header{edsmID} = $n if ($s eq 'edsm_id');
		$header{x} = $n if ($s eq 'x');
		$header{y} = $n if ($s eq 'y');
		$header{z} = $n if ($s eq 'z');
		$header{id64} = $n if ($s =~ /system_address/);
		$header{updated} = $n if ($s =~ /updated_at/);
		$n++;
	}
	foreach my $k (keys %header) {
		print "$k = $header{$k}\n";
	}
	while (my $line = <CSV>) {
		chomp $line;
		next if (!$line);
		my @v = parse_csv($line);
		next if (!@v);

		next if (!$v[$header{id64}]);

		my $updated = epoch2date($v[$header{updated}]);

		my @check = db_mysql('elite',"select ID,eddb_id,eddb_date from systems where id64=?",[($v[$header{id64}])]);

		if (@check) {
			my $r = shift @check;

			if (!$$r{eddb_id} || !$$r{eddb_date} || $$r{eddb_id}!=$v[$header{eddbID}] || $updated ne $$r{eddb_date}) {
				print "update($v[$header{id64}]): $v[$header{eddbID}] / $updated \"$v[$header{name}]\"\n" if ($debug);
				db_mysql('elite',"update systems set eddb_id=?,eddb_date=? where id64=?",[($v[$header{eddbID}],$updated,$v[$header{id64}])]) if (!$debug);
			}
		} else {
			my $sol_dist = undef;
			$sol_dist = sqrt($v[$header{x}]**2 + $v[$header{y}]**2 + $v[$header{z}]**2) if ($v[$header{x}] || $v[$header{y}] || $v[$header{z}]);

			print "insert($v[$header{id64}]): $v[$header{eddbID}] / $updated \"$v[$header{name}]\" ($v[$header{x}],$v[$header{y}],$v[$header{z}]) $sol_dist\n" if ($debug);

			db_mysql('elite',"insert into systems (eddb_id,edsm_id,id64,name,eddb_date,coord_x,coord_y,coord_z,sol_dist,date_added,day_added) ".
					"values (?,?,?,?,?,?,?,?,?,now(),now())",[($v[$header{eddbID}],$v[$header{edsmID}],$v[$header{id64}],$v[$header{name}],
					$updated,$v[$header{x}],$v[$header{y}],$v[$header{z}],$sol_dist)]) if (!$debug);
			print '!';
		}

		$dotcount++;
		print '.' if ($dotcount % 10000 == 0);
		print "\n" if ($dotcount % 1000000 == 0);
	}

