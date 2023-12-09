#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

############################################################################

show_queries(0);

my $star_types = "'Earth-like world'";
my $simple_list = 0;
my $skip_type = 0;

my $refsys = undef;
my $maxdist = undef;

#if (@ARGV) {
#	$star_types = "";
#
#	foreach my $arg (@ARGV) {
#		$arg =~ s/[^\w\d\s\-\(\)\.]+//gs;
#		$star_types .= ",'$arg'";
#	}
#
#	$star_types =~ s/^,//;
#}
my $and = '';

if (@ARGV) {
	$star_types = "";

	foreach my $arg (@ARGV) {
		my $arg1 = $arg;
		$arg1 =~ s/[^\w\d\s\-\(\)\.\=\:\<\>\!\'\|]+//gs;

		if ($arg1 =~ /^dist:\s*([\w\d\s\-\+\']+)\|(\d+)/) {
                        $refsys = $1;
                        $maxdist = $2;
		} elsif ($arg1 =~ /^and:(\w+[\<\>\=\!]+)'([\w\d\.\s\-]+)'/) {
			$and .= " and $1'$2'";
		} elsif ($arg1 =~ /^and:(\w+[\<\>\=\!]+)([\w\d\.\-]+)/) {
			$and .= " and $1'$2'";
		} elsif ($arg =~ /^rlike:(\w+)=([\w\<\>\=\!\s\'\%\:\+\*\?\[\]\(\)\-\^\$]+)/i) {
			$and .= " and $1 rlike $2";
		} elsif ($arg =~ /^binlike:(\w+)=([\w\<\>\=\!\s\'\%\:\+\*\?\[\]\(\)\-\^\$]+)/i) {
			$and .= " and cast($1 as binary) rlike $2";
		} elsif ($arg1 =~ /^(and|rlike|binlike):/) {
			warn "Malformed \"$1\": $arg\n";
		} elsif ($arg1 =~ /^\-(\S+)/) {
			my $arg2 = $1;

			$simple_list = 1 if ($arg2 =~ /simple/i);
			$skip_type = 1 if ($arg2 =~ /list/i);
		} else {
			$star_types .= ",'$arg'";
		}
	}

	$star_types =~ s/^,//;
}
#warn "AND: $and\n" if ($and);
#exit;

die "Need parameters!\n" if (!$and && !$star_types && !$refsys && !$maxdist);

my $where = "subType in ($star_types) $and" if ($star_types);

if ($star_types && !$and) {
	$where = "subType in ($star_types)";
} elsif (!$star_types && $and) {
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

$where .= " and deletionState=0" if ($where);
$where =~ s/^\s*and\s+//;

warn "SIMPLE MODE\n" if ($simple_list);
warn "WHERE: $where\n" if (length($where)<=1024);
#exit;

my %columns = ();

my @colrows = db_mysql('elite',"describe stars");
foreach my $r (@colrows) {
        if ($$r{Type} =~ /^(float|double)/) {
                $columns{$$r{Field}} = "cast($$r{Field} as decimal(65,10)) $$r{Field}";
        } else {
                $columns{$$r{Field}} = $$r{Field};
        }
}

my $rows = rows_mysql('elite',"select ".join(',',values %columns)." from stars where $where order by name");

warn int(@$rows)." rows\n";

print "System,Status,Star,Mass Code,Type,Belts,Main Star,Scoopable,Arrival Distance,Age,".
	"Solar Masses,Solar Radius,Surface Temperature,Absolute Magnitude,Spectral Class,Luminosity,".
	"Axial Tilt,Rotational Period,Tidally Locked,Orbital Period,".
	"Semi-major Axis,Orbital Eccentricity,Orbital Inclination,Arg. of Periapsis,Mean Anomaly,Longitude of Ascending Node,".
	"System Bodies,Ssytem Stars,System Planets,".
	"Coord X,Coord Y,Coord Z,RegionID,Timestamp,EDSM Discoverer,EDSM Discovery Date\r\n" if (!$simple_list);;

print "Name,Type,EDSM Date,Date Added\r\n" if ($simple_list && !$skip_type);
print "Name,EDSM Date,Date Added\r\n" if ($simple_list && $skip_type);

my $count = 0;
while (@$rows) {
	my $r = shift @$rows;

	foreach my $k (keys %$r) {
		$$r{$k} += 0 if ($$r{$k} =~ /^\-?\d+\.\d+$/);
	}

	$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{starID} = 0 if (!defined($$r{starID}));

	my @rows2 = db_mysql('elite',"select id from belts where planet_id='$$r{starID}' and isStar=1") if (!$simple_list);
	my $num = int(@rows2);

	my $r2 = undef;
	@rows2 = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where id64='$$r{systemId64}' and deletionState=0") if (!$simple_list);
	if (@rows2) {
		$r2 = shift @rows2;
	} else {
		%$r2 = ();
	}

	my $locked = 'no';
	$locked = 'yes' if ($$r{rotationalPeriodTidallyLocked});

	my $isMainStar = 'no';
	$isMainStar = 'yes' if ($$r{isMainStar});

	my $isScoopable = 'no';
	$isScoopable = 'yes' if ($$r{isScoopable});

	my $masscode = '';

	my $position = 'secondary';
	$position = 'primary' if ($$r{isMainStar} || $$r{name} eq "$$r2{name} A");
	$position = 'single' if ($$r{name} eq $$r2{name});

	if ($$r{name} =~ /\S+\s+\w\w\-\w\s+([a-zA-Z])(\d+\-)?\d+/) {
		$masscode = uc($1);
	}

	my @counts = db_mysql('elite',"select count(*) as num from stars where systemId64=? and deletionState=0",[($$r{systemId64})]);
	my $starcount = ${$counts[0]}{num}+0;
	my @counts = db_mysql('elite',"select count(*) as num from planets where systemId64=? and deletionState=0",[($$r{systemId64})]);
	my $planetcount = ${$counts[0]}{num}+0;

	if (!$simple_list) {
	print make_csv($$r2{name},$position,$$r{name},$masscode,$$r{subType},$num,$isMainStar,$isScoopable,$$r{distanceToArrivalLS},$$r{age},
		$$r{solarMasses},$$r{solarRadius},$$r{surfaceTemperature},$$r{absoluteMagnitude},$$r{spectralClass},$$r{luminosity},$$r{axialTilt},
		$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},$$r{semiMajorAxis},$$r{orbitalEccentricity},$$r{orbitalInclination},$$r{argOfPeriapsis},
		$$r{meanAnomaly},$$r{ascendingNode},".int($starcount+$planetcount).",$starcount,$planetcount,
		$$r2{coord_x},$$r2{coord_y},$$r2{coord_z},$$r{region},$$r{updateTime},$$r{commanderName},$$r{discoveryDate})."\r\n";

	} elsif ($simple_list && !$skip_type) {
		print make_csv($$r{name},$$r{subType},$$r{updateTime},$$r{date_added})."\r\n";
	} else {
		print make_csv($$r{name},$$r{updateTime},$$r{date_added})."\r\n";
	}
	$count++;
}
warn "$count found\n";


