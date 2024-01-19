#!/usr/bin/perl
use strict;

############################################################################

use POSIX qw(floor);
use Math::Trig;
use Data::Dumper;

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

#############################################################################

show_queries(0);

#exit;

my $pi		= 3.14159265358979;
my $e		= 2.718281828459045;
my $GM		= 398600.4;

$0 =~ s/^.*\///s;
my $progname = $0;

my $debug		= 0;
my $debug_2mass 	= 0;
my $debug_KOI		= 0;
my $debug_Xothuia	= 0;
my $debug_HypioFlyao	= 0;
my $debug_Pleiades	= 0;
my $debug_Egnaimt	= 0;
my $debug_size		= 100000;
my $chunk_size		= 100000;
my $do_rings		= 1;
my $do_procgen		= 1;
my $allow_scp		= 1;
my $get_edsm		= 0;

my $max_peri_time	= 365.25*86400*5; # 5 years

my $runfile = '/home/bones/elite/pull-systems.pl.run';

my $maxtops	= 10; 

my $maxChildren	= 7;
my $lowChildren	= 5;
my $fork_verbose= 0;

my $filename	= 'galactic-records';
my $keyfile	= 'galactic-records-keys';
my $topsfile	= 'galactic-records-tops';

my $db_cpu = get_DB_CPU();

if ($debug) {
	$filename	= 'debug-galactic-records';
	$keyfile	= 'debug-galactic-records-keys';
	$topsfile	= 'debug-galactic-records-tops';
	$allow_scp	= 0;
	$do_procgen	= 0;
}

my $scp                 = '/usr/bin/scp -P222';
my $ssh                 = '/usr/bin/ssh -p222';
my $remote_server       = 'www@services:/www/edastro.com/mapcharts/files';


my %skipKey = ();
$skipKey{bodyId} = 1;
$skipKey{bodyId64} = 1;
$skipKey{systemId} = 1;
$skipKey{systemId64} = 1;
$skipKey{id64} = 1;
$skipKey{id} = 1;
$skipKey{ID} = 1;
$skipKey{planet_id} = 1;
$skipKey{planetID} = 1;
$skipKey{starID} = 1;
$skipKey{planet_id} = 1;
$skipKey{parentStar} = 1;
$skipKey{parentStarID} = 1;
$skipKey{parentPlanet} = 1;
$skipKey{parentPlanetID} = 1;
$skipKey{orbitType} = 1;
$skipKey{isLandable} = 1;
$skipKey{isStar} = 1;
$skipKey{edsmID} = 1;
$skipKey{edsm_id} = 1;
$skipKey{eddb_id} = 1;
$skipKey{deletionState} = 1;
$skipKey{suspicious} = 1;
$skipKey{isMainStar} = 1;
$skipKey{isPrimary} = 1;
$skipKey{isScoopable} = 1;
$skipKey{rotationalPeriodTidallyLocked} = 1;
$skipKey{argOfPeriapsis} = 1;
$skipKey{meanAnomaly} = 1;
$skipKey{ascendingNode} = 1;
$skipKey{offset} = 1;
$skipKey{orbitType} = 1;
$skipKey{distanceToArrival} = 1;
$skipKey{coord_x} = 1;
$skipKey{coord_y} = 1;
$skipKey{coord_z} = 1;
$skipKey{mainStarID} = 1;
$skipKey{sectorID} = 1;
$skipKey{boxelID} = 1;
$skipKey{region} = 1;
$skipKey{planetScore} = 1;
$skipKey{planetscore} = 1;
$skipKey{FSSprogress} = 1;
$skipKey{complete} = 1;
$skipKey{SystemGovernment} = 1;
$skipKey{SystemSecurity} = 1;
$skipKey{SystemEconomy} = 1;
$skipKey{SystemSecondEconomy} = 1;
$skipKey{SystemAllegiance} = 1;
$skipKey{nonbodyCount} = 1;

my %nonzero = ();
my %nonnegative = ();
foreach my $nz (qw(distanceToArrival distanceToArrivalLS gravity earthMasses radius orbitalPeriod rotationalPeriod semiMajorAxis solarMasses solarRadius 
		surfaceTemperature surfaceGravity sol_dist 
		width area mass density innerRadius outerRadius
		ring_max_mass ring_max_area ring_max_density ring_max_width ring_max_innerRadius ring_max_outerRadius
		ring_min_mass ring_min_area ring_min_density ring_min_width ring_min_innerRadius ring_min_outerRadius
		belt_max_mass belt_max_area belt_max_density belt_max_width belt_max_innerRadius belt_max_outerRadius
		belt_min_mass belt_min_area belt_min_density belt_min_width belt_min_innerRadius belt_min_outerRadius
		ring_mass ring_area ring_density ring_width ring_innerRadius ring_outerRadius
		belt_mass belt_area belt_density belt_width belt_innerRadius belt_outerRadius
		numStars bodyCount numBodies
		)) {
	$nonzero{$nz} = 1;
	$nonnegative{$nz} = 1;
}
#$nonnegative{distanceToArrival}=1;
$nonnegative{sagittariusA_dist}=1;
$nonnegative{numPlanets}=1;
$nonnegative{nonbodyCount}=1;
$nonnegative{numELW}=1;
$nonnegative{numWW}=1;
$nonnegative{numAW}=1;
$nonnegative{numTerra}=1;

my %skip_col = ();
my %col_rename = ();
my %colcast = ();

foreach my $f (qw(surfaceTemperature surfacePressure gravity earthMasses radius absoluteMagnitude solarMasses solarRadius axialTilt rotationalPeriod orbitalPeriod orbitalEccentricity orbitalInclination argOfPeriapsis semiMajorAxis)) {
	$skip_col{$f} = 1;
	$col_rename{$f."Dec"} = $f;
}
#$colcast{axialTilt} = 'decimal(65,12)';
#$colcast{orbitalInclination} = 'decimal(65,12)';
#$colcast{orbitalEccentricity} = 'decimal(65,12)';
#$colcast{orbitalPeriod} = 'decimal(65,12)';
#$colcast{rotationalPeriod} = 'decimal(65,12)';
#$colcast{earthMasses} = 'decimal(65,12)';
#$colcast{radius} = 'decimal(65,12)';
#$colcast{solarRadius} = 'decimal(65,12)';
#$colcast{solarMasses} = 'decimal(65,12)';
#$colcast{distanceToArrivalLS} = 'decimal(65,12)';
#$colcast{surfacePressure} = 'decimal(65,12)';
#$colcast{absoluteMagnitude} = 'decimal(65,12)';

#############################################################################

my %region_name = ();

my @rows = db_mysql('elite',"select * from regions");
foreach my $r (@rows) {
	$region_name{$$r{id}} = $$r{name};
}

my $force_passes = 0;
$force_passes = 1 if ($ARGV[0]);

print "DEBUG\n" if ($debug);

#############################################################################

my %data = ();
my %avg = ();

my $time = time;

foreach my $table (qw(planets stars systems)) {
	my $dotcount = 0;
	my %cols = ();

	my $idfield = 'planetID';
	$idfield = 'starID' if ($table eq 'stars');
	$idfield = 'ID' if ($table eq 'systems');

	my $isStar = 0;
	$isStar = 1 if ($table eq 'stars');

	my @check = db_mysql('elite',"select max($idfield) as num from $table");
	my $maxID = ${$check[0]}{num};

	my @struct = db_mysql('elite',"describe $table");
	foreach my $r (@struct) {
		next if ($skip_col{$$r{Field}});

		if ($colcast{$$r{Field}}) {
			$cols{"cast($$r{Field} as $colcast{$$r{Field}}) $$r{Field}"} = 1;

		} elsif ($col_rename{$$r{Field}}) {
			$cols{"$$r{Field} as $col_rename{$$r{Field}}"} = 1;

		} elsif ($$r{Type} =~ /int\(/ || $$r{Type} eq 'float' || $$r{Type} =~ /decimal/i) {
			$cols{$$r{Field}} = 1 if (!$skipKey{$$r{Field}});
		}
	}

	#$cols{"149597870700*semiMajorAxisDec*(1-orbitalEccentricityDec) as periapsisMeters"} = 1;

	my $columns = join(',',keys %cols);
	$columns .= ",$table.deletionState";
	$columns .= ",isLandable" if ($table eq 'planets');
	$columns .= ",meanAnomaly,meanAnomalyDate,parents,suspicious" if ($table =~ /^(stars|planets)$/);

	my $amChild = 0;

	foreach my $pass (0,1) {
		print "\nPROCESSING $table, pass $pass\n";

		my $id = 0;
		my $no_more_data = 0;

		while ($id < $maxID && !$no_more_data) {
			my @kids = ();
			my @childpid = ();

			my $numChildren = -e $runfile ? $lowChildren : $maxChildren;

			$db_cpu = get_DB_CPU();
			my $calc = int($maxChildren - ($db_cpu/100));
			$calc = 2 if ($calc < 2);

			$numChildren = $calc if ($calc < $numChildren && $db_cpu >= 90);


			foreach my $childNum (0..$numChildren-1) {

				last if ($id > $maxID || $no_more_data);

				my $pid = open $kids[$childNum] => "-|";
				die "Failed to fork: $!" unless defined $pid;


				if ($pid) {
					# Parent.
		
					$childpid[$childNum] = $pid;
					$0 = $progname.' [parent] '."$table/$pass ".commify($id);
			
					$dotcount++;
					print '.'; # if ($dotcount % 1 == 0);
					print "\n" if ($dotcount % 100 == 0);

					$id += $chunk_size;
					$no_more_data = 1 if ($debug && $id >= $debug_size);
					$no_more_data = 1 if ($id > $maxID);
					$no_more_data = 1 if ($debug && ($debug_2mass || $debug_KOI || $debug_Xothuia || $debug_HypioFlyao || $debug_Pleiades || $debug_Egnaimt));
				} else {
					# Child.
					%data = ();
					$amChild = 1;
	
					disconnect_all();       # Important to make our own DB connections as a child process.
					$0 = $progname.' [child] '."$table/$pass ".commify($id);


					my $table_range = "$table.$idfield>=? and $table.$idfield<?";
					my $sector = undef;

					if ($debug) {
						$sector='KOI' if ($debug_KOI);
						$sector='2MASS' if ($debug_2mass);
						$sector='Xothuia' if ($debug_Xothuia);
						$sector='Hypio Flyao' if ($debug_HypioFlyao);
						$sector='Pleiades' if ($debug_Pleiades);
						$sector='Egnaimt' if ($debug_Egnaimt);
						$table_range = "systems.name like '$sector \%'" if ($sector);
					}

					my %local = ();
					if ($do_rings && $table ne 'systems') {
						foreach my $ringtype (qw(rings belts)) {
							next if (!$isStar && $ringtype eq 'belts');
				
							my @rows2 = ();

							@rows2 = db_mysql('elite',"select *,outerRadius-innerRadius as width,'$ringtype' as source from $ringtype ".
										"where planet_id>=? and planet_id<? and isStar=?",
										[($id,$id+$chunk_size,$isStar)]) if (!$sector);

							@rows2 = db_mysql('elite',"select *,outerRadius-innerRadius as width,'$ringtype' as source from $ringtype ".
										"where name like '$sector \%' and isStar=?",
										[($isStar)]) if ($sector);
							while (@rows2) {
								my $r2 = shift @rows2;
								%{$local{$ringtype}{$$r2{planet_id}+0}{$$r2{id}+0}} = %$r2;
								#$local{$ringtype}{$$r2{planet_id}}{$$r2{id}} = $r2;
							}
#warn "RINGBELT: ".int(keys %{$local{$ringtype}})." $table found for $ringtype $isStar, $id - ".($id+$chunk_size)."\n";
						}
					}

					my @rows = ();
					my @params = $sector ? () : ($id,$id+$chunk_size);
				
					push @rows, db_mysql('elite',"select $idfield,$table.name,subType,edsmID,systemId,systems.name as sysname,
								coord_x,coord_y,coord_z,sol_dist,$columns from $table,systems ".
								"where $table_range and systemId64=id64 and ".
								"systems.deletionState=0 and $table.deletionState=0",\@params) if ($table ne 'systems');

					push @rows, db_mysql('elite',"select $idfield,name,name as sysname,edsm_id as edsmID,mainStarType,coord_x,coord_y,coord_z,sol_dist,$columns ".
								"from $table where $table_range and deletionState=0",\@params) if ($table eq 'systems');

					#my @rings = sort {$a <=> $b} keys %{$local{rings}};

					while (@rows) {
						my $r = shift @rows;
						next if ($$r{deletionState} || $$r{suspicious});

#print "PRINT: $$r{name} solarRadius = $$r{solarRadius}\n" if ($$r{subType} eq 'Black Hole' && $$r{solarRadius});
		
						#%{$$r{belts}} = %{$local{belts}{$$r{$idfield}}} if (keys(%{$local{belts}{$$r{$idfield}}}) && $isStar);
						#%{$$r{rings}} = %{$local{rings}{$$r{$idfield}}} if (keys(%{$local{rings}{$$r{$idfield}}}));

						my $periapsis = undef;
						$periapsis = 149597870.700*$$r{semiMajorAxis}*(1-$$r{orbitalEccentricity}) 
								if (defined($$r{semiMajorAxis}) && $$r{semiMajorAxis}>0 && defined($$r{orbitalEccentricity}) && 
									$$r{orbitalEccentricity}>=0 && $$r{orbitalEccentricity}<1);

						if (0) {
						if ($periapsis && $$r{semiMajorAxis} && defined($$r{orbitalEccentricity})) {
							my $SMA = 149597870.700*$$r{semiMajorAxis};
							my $fp = 0; # Undefined? Should be:  $fp = 1/tan(($e*sin(0))/(1+$e*cos(0))); 
							my $alt = $SMA * (1 - $e*cos($$r{orbitalEccentricity}));
							my $vel = sqrt($GM * (2/$alt - 1/$SMA));
							#$$r{periapsisVelocity} = 
						}
						}

						if (defined($$r{coord_x}) && defined($$r{coord_y}) && defined($$r{coord_z})) {
							$$r{sagittariusA_dist} = sqrt((abs($$r{coord_x}-25.2188)**2)+(abs($$r{coord_y}+20.9062)**2)+(abs($$r{coord_z}-25900)**2));
						}

						if ($table eq 'systems') {
							$$r{numBodies} = $$r{numStars} + $$r{numPlanets};
						}

						if ($periapsis) { 
							if ($$r{orbitalPeriod} && $$r{orbitalPeriod} * 86400 <= $max_peri_time) {
								$$r{periapsis5Y} = sprintf("%.02f",$periapsis);

							} elsif ($$r{parents} && $$r{orbitalPeriod} && defined($$r{meanAnomaly}) && $$r{meanAnomalyDate} && $$r{parents} =~ /^(Planet|Star):/) {
								my $period    = $$r{orbitalPeriod} * 86400;
								my $timesince = $period * (($$r{meanAnomaly} % 360)/360);
								my $timeuntil = $period - $timesince;
								my $next = date2epoch($$r{meanAnomalyDate}) + $timeuntil;
	
								if ($next < $time && $next > 0) { # Next periapsis is in the past, but sometimes after January 1 1970:
	
									$next += floor(($time-$max_peri_time)/$period)*$period;
								}
								$next += $period if ($next <= $time);
								$next += $period if ($next <= $time);
								$next += $period if ($next <= $time);
	
								$$r{periapsis5Y} = sprintf("%.02f",$periapsis) if ($periapsis>0 && $next>$time && ($next-$time)<=$max_peri_time); # 5 years
							}

							$$r{periapsis} = sprintf("%.02f",$periapsis) if ($$r{parents} && $$r{parents} =~ /^(Planet|Star):/);
						}


						foreach my $k (keys %$r) {
							$$r{$k} += 0 if ($$r{$k} =~ /^\-?\d+(\.\d+)?$/);
						}
						if ($do_rings && $table ne 'systems') {
							my %ringbelt = ();

							foreach my $ringtype (qw(rings belts)) {
								if (ref($local{$ringtype}{$$r{$idfield}}) eq 'HASH' && keys(%{$local{$ringtype}{$$r{$idfield}}})) {
#warn "RINGBELT: $table.$$r{$idfield}/$ringtype = ".int(keys(%{$local{$ringtype}{$$r{$idfield}}}))."\n";
									foreach my $ringID (keys(%{$local{$ringtype}{$$r{$idfield}}})) {
										my $ring = $local{$ringtype}{$$r{$idfield}}{$ringID};

#warn "RINGBELT: $table.$$r{$idfield}/$ringtype.$$ring{id} = $$ring{type}\n" if ($$ring{type} =~ /icy/i);
#warn "RINGBELT: $table.$$r{$idfield}/$ringtype.$$ring{id} = $$ring{type} ($$ring{name})\n" if ($sector && $$ring{name} !~ /$sector/i);

										my $realtype = $ringtype;
										if ($$ring{name} =~ /(Ring|Belt)\s*$/) {
											#$$ring{type} = $1;
											$realtype = ($$ring{name} =~ /Belt/i) ? 'belts' : 'rings';
										}
										if ($realtype =~ /^(ring|belt)$/i) {
											$realtype = lc($realtype).'s';
										}

										$$ring{width} = $$ring{outerRadius}-$$ring{innerRadius};
										$$ring{area} = ($pi*($$ring{outerRadius}**2)) - ($pi*($$ring{innerRadius}**2));
										$$ring{density} = $$ring{mass}/$$ring{area} if ($$ring{area});

										$$ring{area} = sprintf("%.06f",$$ring{area}) if ($$ring{area} >= 100);
										$$ring{area} = sprintf("%.02f",$$ring{area}) if ($$ring{area} >= 1000000);
										$$ring{density} = sprintf("%.06f",$$ring{density}) if ($$ring{density} >= 100);
										$$ring{density} = sprintf("%.02f",$$ring{density}) if ($$ring{density} >= 1000000);

										$$ring{area} =~ s/\.0+$//;
										$$ring{density} =~ s/\.0+$//;

										$$ring{area} =~ s/(\.\d*[1-9])0+\s*$/$1/s;
										$$ring{adensity} =~ s/(\.\d*[1-9])0+\s*$/$1/s;
#warn "RINGBELT $ringtype ($realtype) $ringID: $$ring{outerRadius}, $$ring{innerRadius}, $$ring{width}\n";

										foreach my $f (qw(width area mass density innerRadius outerRadius)) {
											
											if (!defined($ringbelt{$realtype}{$f}{max}) || $$ring{$f}+0 > $ringbelt{$realtype}{$f}{max}+0) {
												$ringbelt{$realtype}{$f}{max} = $$ring{$f};
											}
											if (!defined($ringbelt{$realtype}{$f}{min}) || $$ring{$f}+0 < $ringbelt{$realtype}{$f}{min}+0) {
												$ringbelt{$realtype}{$f}{min} = $$ring{$f};
											}
#print "RINGBELT: $realtype.$f.min=$ringbelt{$realtype}{$f}{min}, $realtype.$f.max=$ringbelt{$realtype}{$f}{max}\n";
										}

										$$ring{type} .= ' '.ucfirst($realtype);
										$$ring{type} =~ s/s$//;
										$$ring{type} =~ s/(Ring|Belt)\s(Ring|Belt)$/$2/s;

#warn "RINGBELT $ringtype ($realtype) $ringID: $$ring{name} / $$ring{type} SOURCE: $$ring{source}\n" if ($$ring{id}==15708450);
										add_data($realtype,$ring,$pass);
									}
								}
							}

							foreach my $ringtype (qw(rings belts)) {
							#foreach my $ringtype (keys %ringbelt) {
								foreach my $f (qw(width area mass density innerRadius outerRadius)) {
									if ($ringbelt{$ringtype}{$f}{max} && $ringbelt{$ringtype}{$f}{min}) {
#print "RINGBELT: $ringtype.$f.min=$ringbelt{$ringtype}{$f}{min}, $ringtype.$f.max=$ringbelt{$ringtype}{$f}{max}\n";
										$$r{$ringtype."_min_$f"} = $ringbelt{$ringtype}{$f}{min};
										$$r{$ringtype."_max_$f"} = $ringbelt{$ringtype}{$f}{max};
									}
								}
							}
						}

						$$r{isLandable} = 0 if ($table eq 'planets' && $$r{subType} =~ /giant/i);

						next if ($$r{subType} eq 'Supermassive Black Hole');
			
						add_data($table,$r,$pass);

#if ($$r{name} eq 'Hypio Flyao BW-N e6-87') {
#	print "PRINT: $$r{name} [$$r{starID}] ($$r{subType}) Current solarRadius min: $data{stars}{solarRadius}{min} $data{stars}{solarRadius}{minID}\n";
#}

						if ($table eq 'stars' && $$r{subType} =~ /Wolf-Rayet/i) {
							my %alt = %$r;
							$alt{subType} = 'Wolf-Rayet (any) Star';
							add_data($table,\%alt,$pass);
						}
						if ($table eq 'stars' && $$r{subType} =~ /White Dwarf/i) {
							my %alt = %$r;
							$alt{subType} = 'White Dwarf (any) Star';
							add_data($table,\%alt,$pass);
						}
						if ($table eq 'stars' && $$r{subType} =~ /Brown dwarf/i) {
							my %alt = %$r;
							$alt{subType} = 'Brown Dwarf (any) Star';
							add_data($table,\%alt,$pass);
						}
						if ($table eq 'stars' && ($$r{subType} =~ /^C\S? Star/i || $$r{subType} =~ /^M?S-type Star/i)) {
							my %alt = %$r;
							$alt{subType} = 'Carbon (any) Star';
							add_data($table,\%alt,$pass);
						}

					}
					foreach my $group (keys %data) {
						foreach my $type (keys %{$data{$group}}) {
							foreach my $key (keys %{$data{$group}{$type}}) {
								if (!$pass) {
									# First pass
									print "DATA|$group|$type|$key|$data{$group}{$type}{$key}{table}|".
										"$data{$group}{$type}{$key}{n}|$data{$group}{$type}{$key}{t}|".
										"$data{$group}{$type}{$key}{maxcount}|$data{$group}{$type}{$key}{mincount}|".
										"$data{$group}{$type}{$key}{max}|$data{$group}{$type}{$key}{maxID}|".
										"$data{$group}{$type}{$key}{min}|$data{$group}{$type}{$key}{minID}\n";
	
									if ($maxtops) {
										sort_tops(1,$group,$type,$key);
		
										foreach my $list (qw(tops bots)) {
											foreach my $line (@{$data{$group}{$type}{$key}{$list}}) {
												print uc($list)."|$group|$type|$key|$$line{ID}|$$line{val}|$$line{name}\n";
											}
										}
									}
								} else {
									# Second pass
									print "STDEV|$group|$type|$key|$data{$group}{$type}{$key}{devcount}|$data{$group}{$type}{$key}{devtotal}\n";
								}
							}
						}
					}
					#exit if defined $pid;
					exit;
				}
				exit if ($amChild);
			}
				
			my $cn = 0;
			foreach my $fh (@kids) {
				my @lines = <$fh>;

				foreach my $line (@lines) {
					chomp $line;

					if ($line =~ /^DATA\|/) {
						# First pass

						print "$line\n" if ($fork_verbose);
						my @v = split /\|/, $line;
						shift @v;

						$data{$v[0]}{$v[1]}{$v[2]}{table} = $v[3];
						$data{$v[0]}{$v[1]}{$v[2]}{n} += $v[4];
						$data{$v[0]}{$v[1]}{$v[2]}{t} += $v[5];

						my $maxcount = $v[6];
						my $mincount = $v[7];

						$avg{$v[0]}{$v[1]}{$v[2]} = $data{$v[0]}{$v[1]}{$v[2]}{t} / $data{$v[0]}{$v[1]}{$v[2]}{n} if ($data{$v[0]}{$v[1]}{$v[2]}{n});
						$data{$v[0]}{$v[1]}{$v[2]}{a} = $data{$v[0]}{$v[1]}{$v[2]}{t} / $data{$v[0]}{$v[1]}{$v[2]}{n} if ($data{$v[0]}{$v[1]}{$v[2]}{n});

						if (!defined($data{$v[0]}{$v[1]}{$v[2]}{max}) || $v[8]+0 > $data{$v[0]}{$v[1]}{$v[2]}{max}+0) {
							$data{$v[0]}{$v[1]}{$v[2]}{max} = $v[8];
							$data{$v[0]}{$v[1]}{$v[2]}{maxID} = $v[9];
							$data{$v[0]}{$v[1]}{$v[2]}{maxcount} = $maxcount;
						} elsif ($v[8] eq $data{$v[0]}{$v[1]}{$v[2]}{max} || $v[8]+0 == $data{$v[0]}{$v[1]}{$v[2]}{max}+0) {
							$data{$v[0]}{$v[1]}{$v[2]}{maxcount} += $maxcount;
						}

						if (!defined($data{$v[0]}{$v[1]}{$v[2]}{min}) || $v[10]+0 < $data{$v[0]}{$v[1]}{$v[2]}{min}+0) {
							$data{$v[0]}{$v[1]}{$v[2]}{min} = $v[10];
							$data{$v[0]}{$v[1]}{$v[2]}{minID} = $v[11];
							$data{$v[0]}{$v[1]}{$v[2]}{mincount} = $mincount;
						} elsif ($v[10] eq $data{$v[0]}{$v[1]}{$v[2]}{min} || $v[10]+0 == $data{$v[0]}{$v[1]}{$v[2]}{min}+0) {
							$data{$v[0]}{$v[1]}{$v[2]}{mincount} += $mincount;
						}
					} elsif ($line =~ /^(TOPS|BOTS)\|/) {	
						# Top/Bottom 10 lists
						my $list = lc($1);

						print "$line\n" if ($fork_verbose);
						my @v = split /\|/, $line;
						shift @v;

						push @{$data{$v[0]}{$v[1]}{$v[2]}{$list}}, {ID=>$v[3], val=>$v[4], name=>$v[5]};
						sort_tops(0,$v[0],$v[1],$v[2]);

					} elsif ($line =~ /^STDEV\|/) {
						# Second pass

						print "$line\n" if ($fork_verbose);
						my @v = split /\|/, $line;
						shift @v;

						$data{$v[0]}{$v[1]}{$v[2]}{devcount} += $v[3];
						$data{$v[0]}{$v[1]}{$v[2]}{devtotal} += $v[4];

						$data{$v[0]}{$v[1]}{$v[2]}{sd} = sqrt($data{$v[0]}{$v[1]}{$v[2]}{devtotal} / $data{$v[0]}{$v[1]}{$v[2]}{devcount}) if ($data{$v[0]}{$v[1]}{$v[2]}{devcount});
					} elsif ($line =~ /^PRINT:\s*(.+)$/i) {
						print "$1\n";
					} else {
						print "$line\n";
					}
				}

				waitpid $childpid[$cn], 0;
				$cn++;
			}
			#1 while -1 != wait;
		}
		$dotcount = 0;
	}
}
	
my %out = ();
my %out2 = ();
my %edsm_id64 = ();

$0 = $progname.' [parent] Processing';


foreach my $group (sort keys %data) {

	next if (!$do_procgen && $group eq 'procgen');

	my $fn = $group eq 'all' ? $topsfile : "$topsfile-$group";

	open CSV, ">$fn.csv";
	print CSV make_csv('Table','List','Type','Variable','Value','ID','Name')."\r\n";

	foreach my $type (sort keys %{$data{$group}}) {
		foreach my $key (sort keys %{$data{$group}{$type}}) {
			my $table = $data{$group}{$type}{$key}{table};
	
			sort_tops(1,$group,$type,$key);

			my $maxsource = $data{$group}{$type}{$key}{maxsource} ? $data{$group}{$type}{$key}{maxsource} : $table;
			my $minsource = $data{$group}{$type}{$key}{minsource} ? $data{$group}{$type}{$key}{minsource} : $table;
	
			my ($name_max,$edsmID_max,$edsmSysID_max,$id64_max,$sysname_max) = get_details($maxsource,$data{$group}{$type}{$key}{maxID});
			my ($name_min,$edsmID_min,$edsmSysID_min,$id64_min,$sysname_min) = get_details($minsource,$data{$group}{$type}{$key}{minID});
	
			my $line = make_csv($type,$key,$data{$group}{$type}{$key}{maxcount},showdecimal($data{$group}{$type}{$key}{max}),$name_max,
						$data{$group}{$type}{$key}{mincount},showdecimal($data{$group}{$type}{$key}{min}),$name_min,
						showdecimal($data{$group}{$type}{$key}{a}),showdecimal($data{$group}{$type}{$key}{sd}),$data{$group}{$type}{$key}{n},$table);
	
			push @{$out{$group}}, $line;
	
			my $line = make_csv($type,$key,$data{$group}{$type}{$key}{maxID},$name_max,$edsmID_max,$edsmSysID_max,$id64_max,$sysname_max,
						$data{$group}{$type}{$key}{minID},$name_min,$edsmID_min,$edsmSysID_min,$id64_min,$sysname_min,$table);
			push @{$out2{$group}}, $line;
	
			if ($maxtops) {
				foreach my $list (qw(tops bots)) {
					my $listname = ($list eq 'tops') ? 'Top'.$maxtops : 'Bottom'.$maxtops;
		
					foreach my $r (@{$data{$group}{$type}{$key}{$list}}) {
						print CSV make_csv($table,$listname,$type,$key,showdecimal($$r{val}),$$r{ID},$$r{name})."\r\n";
					}
				}
			}
		}
	}
	close CSV;
}

# Records output:

foreach my $group (keys %out) {
	next if (!$do_procgen && $group eq 'procgen');

	my $fn = $group eq 'all' ? $filename : "$filename-$group";

	open CSV, ">$fn.csv";
	print CSV make_csv('Type','Variable','Max Count','Max Value','Max Body',
			'Min Count','Min Value','Min Body',
			'Average','Standard Deviation','Count','Table')."\r\n";

	foreach my $s (@{$out{$group}}) {
		print CSV "$s\r\n";
		print "$s\n";
	}
	close CSV;
}

foreach my $group (keys %out2) {
	next if (!$do_procgen && $group eq 'procgen');

	my $fn = $group eq 'all' ? $keyfile : "$keyfile-$group";

	open CSV, ">$fn.csv";
	print CSV make_csv('Type','Variable','Max EDAstro ID','Max Name','Max EDSM ID','Max EDSM System ID','Max System ID64','Max System Name',
				'Min EDAstro ID','Min Name','Min EDSM ID','Min EDSM System ID','Min System ID64','Min System Name','Table')."\r\n";

	foreach my $s (@{$out2{$group}}) {
		print CSV "$s\r\n";
		print "$s\n";
	}

	close CSV;
}

if (!$debug && $allow_scp) {
	my_system("$scp $filename*csv $keyfile*csv $remote_server/");
	#my_system("$ssh www\@services 'cd /www/edastro.com/records ; /www/edastro.com/cgi/records 1 > records-include.html'");
	my_system("cd /home/bones/elite/scripts ; ./update-galrecords.pl");
}

if (!$debug && $get_edsm) {
	my @ids = sort keys %edsm_id64;
	%edsm_id64 = ();

	while (@ids) {
		my @list = splice @ids, 0, 80;

		system('/home/bones/elite/edsm/get-system-bodies.pl',@list);
		sleep 1;
	}
}

exit;


#############################################################################

sub my_system {
        my $string = shift;
        print "# $string\n";
        #print TXT "$string\n";
        system($string);
}

sub get_details {
	my ($table, $id) = @_;
	my $idfield = '';
	$idfield = 'planetID' if ($table eq 'planets');
	$idfield = 'starID' if ($table eq 'stars');
	$idfield = 'ID' if ($table eq 'systems');
	$idfield = 'id' if ($table eq 'belts' || $table eq 'rings');
	return '' if (!$idfield);

	if ($table eq 'belts' || $table eq 'rings') {
		my @rows = db_mysql('elite',"select name,isStar,planet_id from $table where $idfield=?",[($id)]);
		if (@rows) {
			my $table2 = ${$rows[0]}{isStar} ? 'stars' : 'planets';
			my $idfield2 = ${$rows[0]}{isStar} ? 'starID' : 'planetID';

			my @rows2 = db_mysql('elite',"select edsmID,systemId,systemId64 from $table2 where $idfield2=?",[(${$rows[0]}{planet_id})]);
			if (@rows2) {
				return (${$rows[0]}{name},${$rows2[0]}{edsmID},${$rows2[0]}{systemId},${$rows2[0]}{systemId64},
					get_systemname(${$rows2[0]}{systemId},${$rows2[0]}{systemId64}));
			} else {
				return (${$rows[0]}{name},undef,undef,undef,undef);
			}
		}
		return '';
	}

	my @rows = ();
	@rows = db_mysql('elite',"select name,edsmID,systemId,systemId64 from $table where $idfield=?",[($id)]) if ($table ne 'systems');
	@rows = db_mysql('elite',"select name,edsm_id as edsmID,edsm_id as systemId,id64 as systemId64 from $table where $idfield=?",[($id)]) if ($table eq 'systems');

	if (@rows && ((${$rows[0]}{edsmID} && ${$rows[0]}{systemId}) || !${$rows[0]}{systemId64})) {
		return (${$rows[0]}{name},${$rows[0]}{edsmID},${$rows[0]}{systemId},${$rows[0]}{systemId64},get_systemname(${$rows[0]}{systemId},${$rows[0]}{systemId64}));
	} else {

		if ($debug) {
			return (${$rows[0]}{name},${$rows[0]}{edsmID},${$rows[0]}{systemId},${$rows[0]}{systemId64},get_systemname(${$rows[0]}{systemId},${$rows[0]}{systemId64}));
		}

		$edsm_id64{${$rows[0]}{systemId64}} = 1 if ($get_edsm);

		my @rows = ();
		@rows = db_mysql('elite',"select name,edsmID,systemId,systemId64 from $table where $idfield=?",[($id)]) if ($table ne 'systems');
		@rows = db_mysql('elite',"select name,edsm_id as edsmID,edsm_id as systemId,id64 as systemId64 from $table where $idfield=?",[($id)]) if ($table eq 'systems');

		if (@rows) {
			return (${$rows[0]}{name},${$rows[0]}{edsmID},${$rows[0]}{systemId},${$rows[0]}{systemId64},get_systemname(${$rows[0]}{systemId},${$rows[0]}{systemId64}));
		}

	}
	return '';
}

sub get_systemname {
	my ($edsmID,$id64) = @_;

	my @rows = db_mysql('elite',"select name from systems where (edsm_id is not null and edsm_id=?) or (id64 is not null and id64=?)",[($edsmID,$id64)]);

	if (@rows) {
		return ${$rows[0]}{name};
	}

	return undef;
}

sub get_name {
	my ($table, $id) = @_;
	my $idfield = '';
	$idfield = 'planetID' if ($table eq 'planets');
	$idfield = 'starID' if ($table eq 'stars');
	$idfield = 'ID' if ($table eq 'systems');
	$idfield = 'id' if ($table eq 'belts' || $table eq 'rings');
	return '' if (!$idfield);

	my @rows = db_mysql('elite',"select name from $table where $idfield=?",[($id)]);
	if (@rows) {
		return ${$rows[0]}{name};
	}
	return '';
}

sub sort_tops {
	my ($force,$g,$t,$key) = @_;

	return if (!$maxtops);

	# We only want to do this occasionally, or with a force

	if ($force || ($data{$g}{$t}{$key}{tops} && @{$data{$g}{$t}{$key}{tops}}>$maxtops*3) || ($data{$g}{$t}{$key}{bots} && @{$data{$g}{$t}{$key}{bots}}>$maxtops*3)) {

		if ($data{$g}{$t}{$key}{tops} && @{$data{$g}{$t}{$key}{tops}}) {
			@{$data{$g}{$t}{$key}{tops}} = sort { $$b{val} <=> $$a{val} } @{$data{$g}{$t}{$key}{tops}};
			@{$data{$g}{$t}{$key}{tops}} = splice @{$data{$g}{$t}{$key}{tops}}, 0, $maxtops if (@{$data{$g}{$t}{$key}{tops}}>$maxtops);
		}

		if ($data{$g}{$t}{$key}{bots} && @{$data{$g}{$t}{$key}{bots}}) {
			@{$data{$g}{$t}{$key}{bots}} = sort { $$a{val} <=> $$b{val} } @{$data{$g}{$t}{$key}{bots}};
			@{$data{$g}{$t}{$key}{bots}} = splice @{$data{$g}{$t}{$key}{bots}}, 0, $maxtops if (@{$data{$g}{$t}{$key}{bots}}>$maxtops);
		}
	}
}

sub add_data {
	my ($table, $href, $pass) = @_;

	return if (($table ne 'systems' && !$$href{subType} && !$$href{type}) || $$href{suspicious} || $$href{deletionState});

	my $idfield = '';
	$idfield = 'planetID' if ($table eq 'planets');
	$idfield = 'starID' if ($table eq 'stars');
	$idfield = 'ID' if ($table eq 'systems');
	$idfield = 'id' if ($table =~ /belts?/i || $table =~ /rings?/i);
	my $typefield = '';
	$typefield = 'subType' if ($table eq 'planets' || $table eq 'stars');
	$typefield = 'type' if ($table =~ /belts?/i || $table =~ /rings?/i);

	return if (!$idfield);
	return if ($table ne 'systems' && !$typefield);

	my $isProcGen = $$href{name} =~ /\s+[A-Z][A-Z]\-[A-Z]\s+[a-z]\d+(\-\d+)?/ ? 1 : 0;

	my @groups = ('all');
	push @groups, 'procgen' if ($do_procgen && $isProcGen);


#warn "RINGBELT: $table $idfield=$$href{$idfield}, $typefield=$$href{$typefield}\n" if ($table =~ /belt|ring/i);

	my $sysname_safe = $$href{sysname};
	$sysname_safe =~ s/([\$\%\-\+\?\(\)])/\\$1/g;

	my $id = $$href{$idfield};
	my $type = $$href{$typefield};

#print "RING DUMP: ".Dumper($href)."\n" if ($id == 15708450);

	my @typelist = ();

	$type = 'Belts' if ($type =~ /^belts?$/i);
	$type = 'Rings' if ($type =~ /^rings?$/i);

	@typelist = ($table);
	push @typelist, $type if ($type !~ /^\s*(belt|ring)s?\s*$/i);	# Not a valid type. Only one or two of these.

	if ($table eq 'planets' && $$href{isLandable}>0) {
		push @typelist, 'landables';
		push @typelist, "$type (landable)";
	}
	#if ($table =~ /stars|planets/ && $$href{name} =~ /[A-Z][A-Z]\-[A-Z]\s+.+(\s+[a-z])+\s*$/) {
	if ($table =~ /stars|planets/ && $$href{name} =~ /(\s+[a-z])+\s*$/) {
		push @typelist, 'moons' if ($table eq 'planets');
		push @typelist, "$type (as moon)";
	}
	#if ($table =~ /stars|planets/ && $$href{name} =~ /[A-Z][A-Z]\-[A-Z]\s+.+\s+([A-Z]+\s+)?\d{1,3}\s*$/) {
	if ($table =~ /stars|planets/ && $$href{name} =~ /^$sysname_safe\s+([A-Z]+\s+)?\d{1,3}\s*$/) {
		push @typelist, "$type (as planet)";
	}
	if ($table eq 'stars' && (uc($$href{name}) eq uc($$href{sysname}) || uc($$href{name}) eq uc("$$href{sysname} A"))) {
		push @typelist, "$type (as main star)";
		push @typelist, "main stars";
	}
	if ($isProcGen && $$href{subType} eq 'Earth-like world') {
		push @typelist, "$type ProcGen";
		#push @typelist, "$type ProcGen (as moon)" if ($$href{name} =~ /[A-Z][A-Z]\-[A-Z]\s+.+(\s+[a-z])+\s*$/);
		#push @typelist, "$type ProcGen (as planet)" if ($$href{name} =~ /[A-Z][A-Z]\-[A-Z]\s+.+\s+([A-Z]+\s+)?\d{1,3}\s*$/);
		push @typelist, "$type ProcGen (as moon)" if ($$href{name} =~ /(\s+[a-z])+\s*$/);
		push @typelist, "$type ProcGen (as planet)" if ($$href{name} =~ /^$sysname_safe\s+([A-Z]+\s+)?\d{1,3}\s*$/);
	}

	push @typelist, "$$href{mainStarType} Systems" if ($table eq 'systems' && $$href{mainStarType});

#print "PRINT: solarRadius add_data proceeding = $$href{solarRadius}\n" if ($$href{name} eq 'Hypio Flyao BW-N e6-87');
#print "PRINT: surfacePressure add_data proceeding = $$href{surfacePressure} ($$href{name} / $$href{subType})\n" if (defined($$href{surfacePressure}) && $$href{subType} =~ /Giant/i);

	foreach my $key (keys %$href) {
		if (defined($$href{$key}) && !ref($$href{$key}) && ("$$href{$key}" =~ /^\s*[\d\.\-]+\s*$/ || "$$href{$key}" =~ /^\s*[\d\.\-]+e[\+\-]?\d+\s*$/) && !$skipKey{$key} && ok_sanity($key,$$href{$key},$href)) {
			# We have a scalar number here.

			foreach my $g (@groups) {
				foreach my $t (@typelist) {

					next if (!$t);
					next if ($g eq 'procgen' && ($t =~ /ProcGen|landable/i || $t =~ /\(as \w+(\s+\w+)?\)/ || $t eq 'main stars' || $t eq 'moons'));

					if (!$pass) {
						# First pass, store data
	
						$data{$g}{$t}{$key}{table} = $table;
						$data{$g}{$t}{$key}{n}++;			# num
						$data{$g}{$t}{$key}{t} += $$href{$key};	# total
	
#print "PRINT: $key add_data loop = $$href{$key} ($$href{name} / $$href{subType})\n" if ($key eq 'surfacePressure' && defined($$href{$key}) && $$href{subType} =~ /Giant/i);
	
						# Begin top/bottom lists:
	
						if ($maxtops) {
							if (!$data{$g}{$t}{$key}{tops}) { @{$data{$g}{$t}{$key}{tops}} = () }
							if (!$data{$g}{$t}{$key}{bots}) { @{$data{$g}{$t}{$key}{bots}} = () }
		
							my %hash = (ID=>$id, val=>$$href{$key}, name=>$$href{name});
	
							push @{$data{$g}{$t}{$key}{tops}}, \%hash;
							push @{$data{$g}{$t}{$key}{bots}}, \%hash;
		
							sort_tops(0,$g,$t,$key);
						}
	
						# End top/bottom lists
	
	
						# Min/Max tracking: 
	
						if ($$href{$key}+0 > $data{$g}{$t}{$key}{max}+0 || !defined($data{$g}{$t}{$key}{max})) {
							$data{$g}{$t}{$key}{maxsource} = $$href{source} if ($$href{source}); 
							delete($data{$g}{$t}{$key}{maxsource}) if (!$$href{source});
							$data{$g}{$t}{$key}{max} = $$href{$key};
							$data{$g}{$t}{$key}{maxID} = $id;
							$data{$g}{$t}{$key}{maxcount} = 1;
						} elsif ($$href{$key} eq $data{$g}{$t}{$key}{max} || $$href{$key}+0 == $data{$g}{$t}{$key}{max}+0) {
							$data{$g}{$t}{$key}{maxcount}++;
						}
						if ($$href{$key}+0 < $data{$g}{$t}{$key}{min}+0 || !defined($data{$g}{$t}{$key}{min})) {
							$data{$g}{$t}{$key}{minsource} = $$href{source} if ($$href{source}); 
							delete($data{$g}{$t}{$key}{minsource}) if (!$$href{source});
							$data{$g}{$t}{$key}{min} = $$href{$key};
							$data{$g}{$t}{$key}{minID} = $id;
							$data{$g}{$t}{$key}{mincount} = 1;
						} elsif ($$href{$key} eq $data{$g}{$t}{$key}{min} || $$href{$key}+0 == $data{$g}{$t}{$key}{min}+0) {
							$data{$g}{$t}{$key}{mincount}++;
						}
	
					} else {
						# Second pass, count toward standard deviations
	
						$data{$g}{$t}{$key}{devcount}++;
						$data{$g}{$t}{$key}{devtotal} += ($$href{$key}-$avg{$g}{$t}{$key}) ** 2;
					}
				}
			}
		}
	}
}

sub ok_sanity {
	my ($key, $value, $href) = @_;

	return 0 if ($key eq 'surfacePressure' && $value>0.1 && $$href{isLandable}>0 && $$href{subType} !~ /Giant/i);
	#return 0 if ($key eq 'gravity' && $value>=20 && $$href{isLandable}>0);
	return 0 if ($key eq 'orbitalEccentricity' && $value >= 1);

	# Values that should never be zero.
	return 0 if ($nonzero{$key} && $value == 0);
	return 0 if ($nonnegative{$key} && $value < 0);

	return 1;
}


sub showdecimal {
        my $text = shift;
        if ($text =~ /^\s*[\+\-\d]\.(\d+)+e[\+\-]?(\d+)\s*$/i) {
                my $digits = length($1) + $2;
                $text = sprintf("%.".$digits."f",$text);
        } elsif ($text =~ /^\s*[\+\-\d]\.(\d+)+e\+?(\d+)\s*$/i) {
                $text = sprintf("%f",$text);
        }
        $text =~ s/\.0+$//;
        $text =~ s/(\.\d*?)0+$/$1/;
        return $text;
}

sub commify {
    my $text = reverse showdecimal($_[0]);
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}

sub get_DB_CPU {
	open TOPEXEC, "/usr/bin/top -b -n 1 | /usr/bin/grep mariadbd |";
#   1829 mysql     20   0  248.7g 242.7g   6516 S 100.0  96.5 128020:29 mariadbd

	my $cpu = 0;

	while (<TOPEXEC>) {
		if (/\s*\d+\s+mysql\s+\d+\s+\S+(\s+\S+)+\s+(\S+)\s+\S+\s+\S+\s+mariadbd/) {
			#print "$1\n$2\n$3\n";
			$cpu = $2;
		}
	}
	close TOPEXEC;

	return $cpu;
}



#############################################################################
