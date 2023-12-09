#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/elite";
use EDSM qw(log10 id64_sectorcoords);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

############################################################################

show_queries(0);

my $simple_list = 0;
my $skip_type = 0;

my $chunk_size = 1000;

my $planet_types = "'Earth-like world'";
my $and = '';

my $order_by = 'name';
my $limit_to = '';

my $refsys = undef;
my $maxdist = undef;

my $skip_header = 0;

if (@ARGV) {
	$planet_types = "";

	foreach my $arg (@ARGV) {
		my $arg1 = $arg;
		$arg1 =~ s/[^\w\d\s\-\(\)\.\=\:\<\>\!\'\|]+//gs if ($arg1 !~ /^sqrt:/);

		warn "ARG: $arg1\n";

		if ($arg1 =~ /^limit=(\d+)/) {
			$limit_to = $1;
		} elsif ($arg1 =~ /^order=([\w\_\(\)]+)([\-\s\|]+(desc))?/) {
			$order_by = $1;
			$order_by .= ' desc' if ($3);
		} elsif ($arg1=~ /^notnull:([\w\d\_]+)/) {
			$and .= " and $1 is not null";
		} elsif (/^abs:\s*(\w+)([\<\>\=\!]+)([\w\d\.\-]+)/) {
			$and .= " and abs($1)$2$3";
		} elsif ($arg1 =~ /^dist:\s*([\w\d\s\-\+\']+)\|(\d+)/) {
			$refsys = $1;
			$maxdist = $2;
		} elsif ($arg1 =~ /^and:(\w+[\<\>\=\!]+)'([\w\d\.\s\-]+)'/) {
			$and .= " and $1'$2'";
		} elsif ($arg1 =~ /^and:(\w+[\<\>\=\!]+)([\w\d\.\-]+)/) {
			$and .= " and $1'$2'";
		} elsif ($arg =~ /^like:(\w+)=([\w\<\>\=\!\s\'\%\:\+\*\?\[\]\(\)\-\^\$]+)/i) {
			$and .= " and $1 like $2";
		} elsif ($arg =~ /^rlike:(\w+)=([\w\<\>\=\!\s\'\%\:\+\*\?\[\]\(\)\-\^\$]+)/i) {
			$and .= " and $1 rlike $2";
		} elsif ($arg =~ /^notlike:(\w+)=([\w\<\>\=\!\s\'\%\:\+\*\?\[\]\(\)\-\^\$]+)/i) {
			$and .= " and $1 not like $2";
		} elsif ($arg =~ /^binlike:(\w+)=([\w\<\>\=\!\s\'\%\:\+\*\?\[\]\(\)\-\^\$]+)/i) {
			$and .= " and cast($1 as binary) rlike $2";
		} elsif ($arg1=~ /^sqrt:/i) {
			my $string = $arg1;
			$string =~ s/^sqrt://s;
			$string =~ s/--/+/gs;
			$and .= " and sqrt$string";
		} elsif ($arg1 =~ /^(and|rlike|binlike):/) {
			warn "Malformed \"$1\": $arg\n";
		} elsif ($arg1 =~ /^0|1$/) {
			$skip_header = 1 if (int($arg1));
		} elsif ($arg1 =~ /^\-(\S+)/) {
			my $arg2 = $1;

			$simple_list = 1 if ($arg2 =~ /simple/i);
			$skip_type = 1 if ($arg2 =~ /list|notype/i);
		} else {
			$planet_types .= ",'$arg'";
		}
	}

	$planet_types =~ s/^,//;
}
warn "AND:   $and\n" if ($and);
warn "ORDER: $order_by\n" if ($order_by);
warn "LIMIT: $limit_to\n" if ($limit_to);
#exit;

die "Need parameters!\n" if (!$and && (!$order_by || !$limit_to)  && !$planet_types && !$refsys && !$maxdist);

my $where = '';

$where = "subType in ($planet_types) $and" if ($planet_types);

if ($planet_types && !$and) {
	$where = "subType in ($planet_types)";
} elsif (!$planet_types && $and) {
	$where = $and;
	$where =~ s/^\s*and\s+//;
}

if ($refsys && $maxdist) {
	my @ref = db_mysql('elite',"select * from systems where name=?",[($refsys)]);
	die "System not found: $refsys\n" if (!@ref);
	my $ID = ${$ref[0]}{ID};
	my $x = ${$ref[0]}{coord_x};
	my $y = ${$ref[0]}{coord_y};
	my $z = ${$ref[0]}{coord_z};

	my @ids = ();
	my @list = db_mysql('elite',"select distinct id64 from systems where coord_x>=? and coord_x<=? and coord_y>=? and coord_y<=? and coord_z>=? and coord_z<=? and ".
		"sqrt(pow(coord_x-?,2) + pow(coord_y-?,2) + pow(coord_z-?,2))<? and deletionState=0",
		[($x-$maxdist,$x+$maxdist,$y-$maxdist,$y+$maxdist,$z-$maxdist,$z+$maxdist,$x,$y,$z,$maxdist)]);

	foreach my $r (@list) {
		push @ids, $$r{id64} if ($$r{id64});
	}

	$where .= " and systemId64 in (".join(',',@ids).")";
}

my $limit = '';
$limit = "limit $limit_to" if ($limit_to);

$where .= " and deletionState=0" if ($where);
$where =~ s/^\s*and\s+//;

$where .= " order by $order_by";
$where .= " $limit" if ($limit);

warn "SIMPLE MODE\n" if ($simple_list);
warn "WHERE: $where\n" if (length($where)<=1024);

#warn "WHERE: ".substr($where,0,200)."\n";
#exit;

my $cols = columns_mysql('elite',"select planetID from planets where $where");

die "None found.\n" if (!keys %$cols);

my $header = '';

$header = "System,Mass Code,System Stars,Primary Star Type,Primary Star Spectral Class,Primary Star Luminosity,Primary Star Age,".
	"Parent Star,Parent Star Type,Parent Star Spectral Class,Parent Star Luminosity,Parent Star Age,".
	"Parent Body,Parent Body Type,Parent Landable,Parent Terraformable,".
	"Planet Name,Landable,Orbit Type,Type,Rings,RingTypes,Arrival Distance,".
	"Terraforming State,Radius,Earth Masses,Surface Gravity,Surface Temperature,Surface Pressure,".
	"Volcanism,Atmosphere,Axial Tilt,Rotational Period,Tidally Locked,Orbital Period,".
	"Semi-major Axis,Orbital Eccentricity,Orbital Inclination,Arg. of Periapsis,Mean Anomaly,Longitude of Ascending Node,".
	"Coord X,Coord Y,Coord Z,RegionID,Timestamp\r\n" if (!$simple_list);

$header =~ s/,Type,/,/s if ($skip_type);

$header = "Name,Type,EDSM Date,Date Added\r\n" if ($simple_list && !$skip_type);
$header = "Name,EDSM Date,Date Added\r\n" if ($simple_list && $skip_type);

print $header if (!$skip_header);

my %columns = ();

my @colrows = db_mysql('elite',"describe planets");
foreach my $r (@colrows) {
	if ($$r{Type} =~ /^(float|double)/) {
		$columns{$$r{Field}} = "cast($$r{Field} as decimal(65,10)) $$r{Field}";
	} else {
		$columns{$$r{Field}} = $$r{Field};
	}
}

warn "Looping...\n";

my %data = ();

my $count = 0;
while (@{$$cols{planetID}}) {
	my $planetID = shift @{$$cols{planetID}};
	my $r = undef;

	if (!exists($data{$planetID})) {
		my $wherelist = ($planetID);
		my $max = $chunk_size;
		$max = int(@{$$cols{planetID}})-1 if (@{$$cols{planetID}}<$chunk_size);
		$wherelist .= ','.join(@{$$cols{planetID}}[0..$max]) if ($max);
		$wherelist =~ s/,+$//;

		my $bodies = rows_mysql('elite',"select ".join(',',values %columns)." from planets where planetID in ($wherelist)");
		foreach my $rr (@$bodies) {
			foreach my $k (keys %$rr) {
				$$rr{$k} += 0 if ($$rr{$k} =~ /^\-?\d+\.\d+$/);
			}
			$data{$$rr{planetID}} = $rr;
		}
	}

	if (exists($data{$planetID})) {
		$r = \%{$data{$planetID}};
		delete($data{$planetID});
	}

	next if (!$r || ref($r) ne 'HASH');

	my @rows2 = ();

	$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{planetID} = 0 if (!defined($$r{planetID}));

	@rows2 = db_mysql('elite',"select id,type from rings where planet_id='$$r{planetID}' and isStar=0") if (!$simple_list);
	my $ringnum = int(@rows2);

	my %ringtype = ();

	foreach my $r2 (@rows2) {
		$ringtype{$$r2{type}}++;
	}
	my $ringtypes = '';
	foreach my $t (sort keys %ringtype) {
		next if (!$t);
		$ringtypes .= ", " if ($ringtypes);
		$ringtypes .= "$t ($ringtype{$t})";
	}

	my $r2 = undef;
	@rows2 = ();
	@rows2 = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where id64='$$r{systemId64}'") if (!$simple_list);
	if (@rows2) {
		$r2 = shift @rows2;
	} else {
		%$r2 = ();
	}

	my $system_name = $$r2{name};

	my $system_type = '';
	my $orbit_type = '';
	my $primary_name = '';
	my $primary_type = '';
	my $primary_lum = '';
	my $primary_age = '';
	my $primary_class = '';
	my $star_name = '';
	my $star_type = '';
	my $star_lum = '';
	my $star_age = '';
	my $star_class = '';
	my $parent_lum = '';
	my $parent_class = '';
	my $parent_age = '';
	my $parent_name = '';
	my $parent_type = '';
	my $parent_body = '';
	my $parent_landable = '';
	my $parent_terraformable = '';

	my $systemname_safe = $system_name;
	$systemname_safe =~ s/([\\\/\(\)\+\-\?\*])/\\$1/gs;

	if (!$simple_list) {
		$orbit_type = 'planetary' if ($$r{name} =~ /^$systemname_safe \d+\s*$/ || $$r{name} =~ /^$systemname_safe [A-Z]{1,10} \d+\s*$/);
		$orbit_type = 'planetary?' if ($$r{name} =~ /\s+\d\s*$/ && !$orbit_type);
		$orbit_type = 'moon' if ($$r{name} =~ /\s+[a-z]\s*$/);
		$orbit_type = 'moon of moon' if ($$r{name} =~ /\s+[a-z]\s+[a-z]\s*$/);
		$orbit_type = 'moon of moon of moon' if ($$r{name} =~ /\s+[a-z]\s+[a-z]\s+[a-z]\s*$/);
	
		if ($$r{name} ne $system_name) {
			$parent_name = $$r{name};
			$parent_name =~ s/\s+[\w\d]+\s*$//;
			my @pbody = ();
	
			if ($parent_name) {
				@pbody = db_mysql('elite',"select subType,age,spectralClass,luminosity from stars where systemId64=? and name=?",[($$r{systemId64},$parent_name)]);
	
				if (@pbody) {
					$parent_body = 'star';
					$orbit_type = 'planetary' if (!$orbit_type);
					$orbit_type = 'moon of star' if ($orbit_type =~ /moon/);
				} else {
					@pbody = db_mysql('elite',"select subType,isLandable,terraformingState from planets where systemId64=? and name=?",[($$r{systemId64},$parent_name)]);
					if (@pbody) {
						$parent_body = 'planet';
						$orbit_type = 'moon' if (!$orbit_type);
					}
				}
			}
	
			if (!$orbit_type && $parent_name eq $system_name) {
				$orbit_type = 'planetary';
			}
	
			if (@pbody) {
				$parent_type = ${$pbody[0]}{subType};

				if ($parent_body eq 'star') {
					$parent_class = ${$pbody[0]}{spectralClass};
					$parent_lum = ${$pbody[0]}{luminosity};
					$parent_age = ${$pbody[0]}{age};
				}

				if ($parent_body ne 'star') {
					$parent_landable = 'yes' if (${$pbody[0]}{isLandable});
					$parent_landable = 'no' if (!${$pbody[0]}{isLandable});
					$parent_terraformable = 'yes' if (${$pbody[0]}{terraformingState} =~ /candidate/i);
					$parent_terraformable = 'no'  if (${$pbody[0]}{terraformingState} !~ /candidate/i);
				}
			} else {
				$parent_name = '';
			}
	
			if ($system_name) {
				my @primary = db_mysql('elite',"select name,subType,age,spectralClass,luminosity from stars where systemId64=? and name in (?,?)",[($$r{systemId64},$system_name,"$system_name A")]);
				if (@primary) {
					$primary_name = ${$primary[0]}{name};
					$primary_type = ${$primary[0]}{subType};
					$primary_class = ${$primary[0]}{spectralClass};
					$primary_lum = ${$primary[0]}{luminosity};
					$primary_age = ${$primary[0]}{age};
					$system_type = 'multiple' if (${$primary[0]}{name} =~ /\s+A\s*$/);
					$system_type = 'single'   if (${$primary[0]}{name} !~ /\s+A\s*$/);
				}
			}
	
			if ($parent_body eq 'star') {
				$star_name = $parent_name;
				$star_type = $parent_type;
				$star_class = $parent_class;
				$star_lum = $parent_lum;
				$star_age = $parent_age;
			} 

			if ($star_name eq $primary_name) {
				#$star_name = $primary_name;
				$star_type = $primary_type;
				$star_class = $primary_class;
				$star_lum = $primary_lum;
				$star_age = $primary_age;
			}
	
			my $n = 5;
			while ($n>0 && !$star_type && $parent_body ne 'star') {
				$star_name = $parent_name if (!$star_name);
				$star_name =~ s/\s+[\w\d]+\s*$//;
				
				my @stars = db_mysql('elite',"select subType,age,spectralClass,luminosity from stars where systemId64=? and name=?",[($$r{systemId64},$star_name)]);
	
				if (@stars) {
					$star_type = ${$stars[0]}{subType};
					$star_class = ${$stars[0]}{spectralClass};
					$star_lum = ${$stars[0]}{luminosity};
					$star_age = ${$stars[0]}{age};
				}
	
				$n--;
			}
			$star_name = '' if (!$star_type);
		}
	}

	my $locked = 'no';
	$locked = 'yes' if ($$r{rotationalPeriodTidallyLocked});

	my $isLandable = 'no';
	$isLandable = 'yes' if ($$r{isLandable});

	my $masscode = '';

	(undef,undef,undef,$masscode) = id64_sectorcoords($$r{systemId64});

	if ($masscode =~ /^\d+$/) {
		$masscode = chr(ord('A')+$masscode);
	}

	if (!$masscode && $$r{name} =~ /\S+\s+\w\w\-\w\s+([a-zA-Z])(\d+\-)?\d+/) {
		$masscode = uc($1);
	}

	foreach my $key (keys %$r) {
		if (defined($$r{$key}) && $key =~ /Dec$/) {
			$$r{$key} =~ s/\.(\d*[1-9])0+$/\.$1/s;
			$$r{$key} =~ s/\.$//s;
		}
	}

	my @out = ();

	@out = ($system_name,$masscode,$system_type,$primary_type,$primary_class,$primary_lum,$primary_age,$star_name,$star_type,$star_class,$star_lum,$star_age,
		$parent_name,$parent_type,$parent_landable,$parent_terraformable,$$r{name},$isLandable,$orbit_type);
	push @out, $$r{subType} if (!$skip_type);
	push @out, $ringnum,$ringtypes,
		$$r{distanceToArrivalLS},$$r{terraformingState},$$r{radiusDec},$$r{earthMasses},$$r{gravity},$$r{surfaceTemperature},$$r{surfacePressureDec},
		$$r{volcanismType},$$r{atmosphereType},$$r{axialTiltDec},$$r{rotationalPeriodDec},$locked,$$r{orbitalPeriodDec},$$r{semiMajorAxisDec},$$r{orbitalEccentricityDec},
		$$r{orbitalInclinationDec},$$r{argOfPeriapsisDec},$$r{meanAnomaly},$$r{ascendingNodeDec},$$r2{coord_x},$$r2{coord_y},$$r2{coord_z},$$r{region},$$r{updateTime};

	@out = ($$r{name},$$r{subType},$$r{updateTime},$$r{date_added}) if ($simple_list && !$skip_type);
	@out = ($$r{name},$$r{updateTime},$$r{date_added}) if ($simple_list && $skip_type);

	print make_csv(@out)."\r\n";
	$count++;

	warn "$count / ".int(@{$$cols{planetID}})."\n" if ($count % 100000 == 0);
}
warn "$count found\n";


