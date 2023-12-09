#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

use POSIX qw(floor);
use POSIX ":sys_wait_h";
use Time::HiRes qw(sleep);

############################################################################

show_queries(0);

my $debug		= 0;
my $skip_all		= 0;
my $verbose		= 0;

my $max_children	= 8;
my $use_forking		= 1;
my $fork_verbose	= 0;

my $id_add		= 10**12;

my $scale		= 10;

my @viewlist		= qw(top front side);
my @skipFields		= qw(ID updated view coord_x coord_y);

my %axes = ();
@{$axes{top}}	= qw(x y);
@{$axes{front}}	= qw(x z);
@{$axes{side}}	= qw(y z);

my $amChild   = 0;
my %child     = ();
$SIG{CHLD} = \&REAPER;

my %skip_field	= ();
my %fields	= ();

############################################################################

print "\nSTART: ".epoch2date(time)."\n";

init_fields();

update_projections();

print "\nFINISH: ".epoch2date(time)."\n";

exit;

############################################################################

sub init_fields {
	foreach my $f (@skipFields) {
		$skip_field{$f} = 1;
	}

	my @rows = db_mysql('elite',"describe projections");
	foreach my $r (@rows) {
		$fields{$$r{Field}}=$$r{Type} if (!$skip_field{$$r{Field}});
	}
}

sub update_projections {

	print "Initializing...\n";

	my %min = ();
	my %max = ();

	my @rows = db_mysql('elite',"select min(coord_x) minX,max(coord_x) maxX,min(coord_y) minY,max(coord_y) maxY,min(coord_z) minZ,max(coord_z) maxZ from systems ".
				"where coord_x is not null and coord_y is not null and coord_z is not null");
	if (@rows) {
		$min{x} = floor(${$rows[0]}{minX}/$scale);
		$max{x} = floor(${$rows[0]}{maxX}/$scale);
		$min{y} = floor(${$rows[0]}{minY}/$scale);
		$max{y} = floor(${$rows[0]}{maxY}/$scale);
		$min{z} = floor(${$rows[0]}{minZ}/$scale);
		$max{z} = floor(${$rows[0]}{maxZ}/$scale);
	}

	$min{x} = 0-(45000/$scale) if ($min{x} < 0-(45000/$scale));
	$max{x} = 45000/$scale if ($max{x} > 45000/$scale);
	$min{y} = 0-(4000/$scale) if ($min{y} < 0-(4000/$scale));
	$max{y} = 4000/$scale if ($max{y} > 4000/$scale);
	$min{z} = 0-(25000/$scale) if ($min{z} < 0-(25000/$scale));
	$max{z} = 70000/$scale if ($max{z} > 70000/$scale);

	print "Ranges: X:($min{x} -> $max{x}), Y:($min{y} -> $max{y}), Z:($min{z} -> $max{z})\n-----\n";


	print "Zeroing side view...\n";
	my $zero = '';
	foreach my $f (keys %fields) {
		$zero .= ",$f=0";
	}
	$zero =~ s/^,//;
	db_mysql('elite',"update projections set $zero where view='side'");
	

	print "Looping...\n";

	my $count = 0;
	my $pid = 0;
	my $do_anyway = 0;
	$SIG{CHLD} = \&REAPER;


	for (my $x=$min{x}; $x<=$max{x}; $x++) {

		while (int(keys %child) >= $max_children) {
			#sleep 1;
			sleep 0.05;
		}

		if ($use_forking) {
			FORK: {
				if ($pid = fork) {
					# Parent here
					$child{$pid}{start} = time;
					warn("FORK: Child spawned on PID $pid\n") if ($fork_verbose);
					next;
				} elsif (defined $pid) {
					# Child here
					$amChild = 1;   # I AM A CHILD!!!
					warn("FORK: $$ ready.\n") if ($fork_verbose);
					$0 =~ s/^.*\s+(\S+\.pl)\s+.*$/$1/;
					$0 .= " -- X=$x";
				} elsif ($! =~ /No more process/) {
					warn("FORK: Could not fork a child, retrying in 3 seconds\n");
					sleep 3;
					redo FORK;
				} else {
					warn("FORK: Could not fork a child. $! $@\n");
					$do_anyway = 1;
				}
			}
		} else {
			$do_anyway = 1;
		}

		$count++;
		print '.' if (!$amChild && $count % 10 == 0);
		print "\n" if (!$amChild && $count % 1000 == 0);

		if (!$amChild && !$do_anyway) {
			next;
		}

		disconnect_all() if ($amChild);	# Important to make our own DB connections as a child process.

		my %hash = ();
		my @side = ();

		my $minX = $x*$scale;
		my $maxX = ($x+1)*$scale;

		my @rows = sort { $$a{coord_y} <=> $$b{coord_y} || $$a{coord_z} <=> $$b{coord_z} } 
				db_mysql('elite',"select id64,edsm_id,name,coord_y,coord_z from systems where coord_x>=$minX and coord_x<$maxX and deletionState=0");

		my ($ly,$lz) = (undef,undef);

		while (@rows) {
			my $r = shift @rows;
			my $y = floor($$r{coord_y}/$scale);
			my $z = floor($$r{coord_z}/$scale);
			
			if ($y != $ly || $z != $lz) {
				do_pixel(1,'side',$ly,$lz,@side) if (@side);
				@side = ();
				$ly = $y;
				$lz = $z;
			}
			push @side, $r;

			if (ref($hash{y}{$y}) ne 'ARRAY') {
				@{$hash{y}{$y}} = ($r);
			} else {
				push @{$hash{y}{$y}}, $r;
			}

			if (ref($hash{z}{$z}) ne 'ARRAY') {
				@{$hash{z}{$z}} = ($r);
			} else {
				push @{$hash{y}{$y}}, $r;
			}
		}
		do_pixel(1,'side',$ly,$lz,@side) if (@side);

		foreach my $y (sort keys %{$hash{y}}) {
			do_pixel(0,'front',$x,$y,@{$hash{y}{$y}});
		}

		foreach my $z (sort keys %{$hash{z}}) {
			do_pixel(0,'top',$x,$z,@{$hash{z}{$z}});
		}

		exit if ($amChild);
	}

	#print "\nWaiting on child processes.\n";
	while (int(keys %child) > 0) {
		#sleep 1;
		sleep 0.1;
	}

	print "\nCleaning up...\n";

	db_mysql('elite',"delete from projections where date_add(updated, interval 2 day)<NOW()");
}


sub do_pixel {
	my ($use_addition,$view,$x,$y) = (shift,shift,shift,shift);
	my @rows = @_;
	my @id_list = ();
	my %hash = ();

	foreach my $r (@rows) {
		push @id_list, $$r{id64};
	}

	my %systemBodies = get_bodies(@id_list);

	while (@rows) {
		my $r = shift @rows;
		my $id = $$r{id64};

		$hash{systems}++;

		if ($$r{name} =~ /\w+\s+[a-zA-Z]{2}\-[a-zA-Z]\s+([a-hA-H])/) {
			my $masscode = uc($1);
			$hash{"mass$masscode"}++;

			my $primaryclass = '';
			foreach my $bodyID (keys %{$systemBodies{$id}}) {
				$primaryclass = $systemBodies{$id}{$bodyID}{subType} 
					if ($systemBodies{$id}{$bodyID}{isPrimary});
			}
			if ($primaryclass) {
				foreach my $subMap ('',$masscode) {
					my $classmass = "classmass$primaryclass$subMap";
					$hash{$classmass}++ if ($fields{$classmass});
				}
			}
		}

		foreach my $bodyID (keys %{$systemBodies{$id}}) {

			my $bodyhash = $systemBodies{$id}{$bodyID};

			if ($$bodyhash{subType}) {
				my @inc_list = ($$bodyhash{subType});

				if ($$bodyhash{starType}) {
					push @inc_list, 'giants' if ($$bodyhash{starType} eq 'G');
					push @inc_list, 'supergiants' if ($$bodyhash{starType} eq 'S');
					push @inc_list, 'dwarfs' if ($$bodyhash{starType} eq 'D');
				}

				if ($$bodyhash{terraformingState} =~ /candidate/i) {
					push @inc_list, 'TFC';
				}
				
				if ($$bodyhash{age} =~ /a(\d+)/) {
					push @inc_list, "age$1" if ($fields{"age$1"});
				}

				foreach my $d (@inc_list) {
					$hash{$d}++;
				}
			}
		}
	}

	# Store the projection pixel

	if (keys %hash) {

		if ($debug || $verbose) {
			my $string = "$view,$x,$y";
			foreach my $k (sort keys %hash) {
				$string .= ",$k=$hash{$k}";
			}
			print "$string\n";
		}

		# Store it here

		my @check = db_mysql('elite',"select ID from projections where view='$view' and coord_x=$x and coord_y=$y");
		if (@check) {

			my $id = ${$check[0]}{ID};

			my $update = '';
			foreach my $k (sort keys %fields) {
				$update .= ",$k='$hash{$k}'" if ($hash{$k} && (!$use_addition || $hash{$k} !~ /^\s*\d+\s*$/));
				$update .= ",$k=$k+$hash{$k}" if ($hash{$k} && ($use_addition && $hash{$k} =~ /^\s*\d+\s*$/));
				$update .= ",$k=0" if (!$hash{$k});
			}
			$update =~ s/^,//;

			my $ok = 0;
			my $tries = 0;
			while (!$ok && $tries<5) {
				$tries++;
				eval {
					db_mysql('elite',"update projections set $update where ID=$id");
					$ok = 1;
				};
				if (!$ok) {
					print "$$ ($view,$x,$y) : $! $@\n";
				}
			}
		} else {
			my ($vars,$vals) = ("view,coord_x,coord_y","'$view','$x','$y'");
			foreach my $k (sort keys %fields) {
				$vars .= ",$k";

				if ($hash{$k}) {
					$vals .= ",'$hash{$k}'";
				} else {
					$vals .= ",0";
				}
			}

			my $ok = 0;
			my $tries = 0;
			while (!$ok && $tries<5) {
				$tries++;
				eval {
					db_mysql('elite',"insert into projections ($vars) values ($vals)");
					$ok = 1;
				};
				if (!$ok) {
					print "$$ ($view,$x,$y) : $! $@\n";
				}
			}
		}
	}
}

############################################################################

sub get_bodies {
	return () if (!@_);
	my $id_list = '('.join(',',@_).')';
	my %hash  = ();
	my @rows  = ();
	my $retry = 0;
	my $ok = undef;

	while (!$ok && $retry < 3) {
		$ok = eval {
			@rows = db_mysql('elite',"select starID,isPrimary,systemId64,systemId,subType,absoluteMagnitude,luminosity,surfaceTemperature,age,updateTime,discoveryDate from stars where systemId64 in $id_list and deletionState=0");
			1;
		};

		unless($ok) {
			print "\n$@\n";
			$retry++;
		}
	}
	print "No stars returned\n" if (($debug || $verbose) && !@rows);
	

	foreach my $r (@rows) {	
		my $class = '';
		my $subType = $$r{subType};

		my $starType = '';
		$starType = 'D' if ($subType =~ /dwarf/i);
		$starType = 'G' if ($subType =~ /giant/i);
		$starType = 'S' if ($subType =~ /super/i);

		$$r{starType} = $starType;

		if ($subType =~ /^\s*(\S)\s+.*(star|dwarf)/i) {
			$class = uc($1);
		}
		$class = 'BD' if ($subType =~ /brown/i);
		$class = 'WD' if ($subType =~ /white.*dwarf/i);
		$class = 'NS' if ($subType =~ /neutron/i);
		$class = 'WR' if ($subType =~ /wolf|rayet/i);
		$class = 'TT' if ($subType =~ /tauri/i);
		$class = 'HE' if ($subType =~ /herbig/i);
		$class = 'BH' if ($subType =~ /black hole/i);
		$class = 'C' if ($subType =~ /carbon/i || $subType =~ /^(C|S|MS|CN|CJ)[\-\s](type|star)/i);
		$class = 'U' if (!$class);

		if ($$r{age}) {
			$$r{age} = 'a'.int(log10($$r{age}));
		} else {
			$$r{age} = undef;
		}

		print "! Unused star type: [".$$r{systemId64}."] $subType\n" if (!$class);

		$$r{subType} = $class;
		$$r{star} = 1;

		%{$hash{$$r{systemId64}}{$$r{starID}}} = %$r;
	}


	@rows  = ();
	$retry = 0;
	$ok = undef;

	while (!$ok && $retry < 3) {
		$ok = eval {
			@rows = db_mysql('elite',"select planetID,systemId64,systemId,subType,gravity,surfaceTemperature,earthMasses,updateTime,terraformingState,discoveryDate from planets where systemId64 in $id_list and deletionState=0");
			1;
		};

		unless($ok) {
			print "\n$@\n";
			$retry++;
		}
	}
	print "No planets returned\n" if (($debug || $verbose) && !@rows);

	foreach my $r (@rows) {
		my $class = '';
		my $subType = $$r{subType};

		$class = 'AW' if ($subType =~ /Ammonia world/i);
		$class = 'ELW' if ($subType =~ /Earth/i);
		$class = 'WW' if ($subType =~ /Water world/i);
		$class = 'WG' if ($subType =~ /Water Giant/i);
		$class = 'GG1' if ($subType =~ /Class I gas giant/i);
		$class = 'GG2' if ($subType =~ /Class II gas giant/i);
		$class = 'GG3' if ($subType =~ /Class III gas giant/i);
		$class = 'GG4' if ($subType =~ /Class IV gas giant/i);
		$class = 'GG5' if ($subType =~ /Class V gas giant/i);
		$class = 'GGAL' if ($subType =~ /ammonia-based/i);
		$class = 'GGWL' if ($subType =~ /water-based/i);
		$class = 'GGHE' if ($subType =~ /Helium/i);
		$class = 'GGHR' if ($subType =~ /Helium-rich/i);
		$class = 'HMC' if ($subType =~ /High metal/i);
		$class = 'MR' if ($subType =~ /Metal-rich/i);
		$class = 'ICY' if ($subType =~ /Icy body/i);
		$class = 'ROCKY' if ($subType =~ /Rocky body/i);
		$class = 'ROCKICE' if ($subType =~ /Rocky Ice/i);
		$class = 'potato' if (!$class);
		
		print "! Unused planet type: [".$$r{systemId64}."] $subType\n" if (!$class);

		$$r{subType} = $class;

		%{$hash{$$r{systemId64}}{$$r{planetID}+$id_add}} = %$r;
	}

	return %hash;
}

sub REAPER {
        while ((my $pid = waitpid(-1, &WNOHANG)) > 0) {
                warn("FORK: Child on PID $pid terminated.\n") if ($fork_verbose);
                delete($child{$pid});
        }
        $SIG{CHLD} = \&REAPER;
}

############################################################################




