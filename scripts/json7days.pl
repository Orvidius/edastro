#!/usr/bin/perl
use strict;

###########################################################################

use JSON;
use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql);
use ATOMS qw(btrim);

my $debug	= 0;
my $debug_json	= 0;
my $days	= 7;
my $debug_limit	= '';

my $gzip	= '/usr/bin/gzip';
my $scp		= '/usr/bin/scp';

my %fn = ();
$fn{systems}	= "edastro_systems".$days."days.jsonl";
$fn{stars}	= "edastro_stars".$days."days.jsonl";
$fn{planets}	= "edastro_planets".$days."days.jsonl";

if ($debug) {
	$debug_json = 1;
	$days = 1;
	$debug_limit = "limit 1000";
}

my @t = localtime(time - ($days*86400));
my $start = sprintf("%04u-%02u-%02u 00:00:00",$t[5]+1900,$t[4]+1,$t[3]);
@t = localtime;
my $today = sprintf("%04u-%02u-%02u 00:00:00",$t[5]+1900,$t[4]+1,$t[3]);

my $dotcount = 0;

###########################################################################

my %orbit = ();

my @rows = db_mysql('elite',"select * from orbits");
foreach my $r (@rows) {
	$orbit{$$r{orbitType}} = $$r{orbitName};
}

###########################################################################

warn "Systems, $start - $today\n";

my $json = JSON->new->allow_nonref;

my $rows = rows_mysql('elite',"select ID,eddb_id,edsm_id,id64,name,date_added,updated as updateTime,mainStarType,".
			"masscode,coord_x,coord_y,coord_z,sol_dist,region,FSSprogress,bodyCount,nonbodyCount from systems ".
			"where ( (date_added>=? and date_added<?) or (eddn_date>=? and eddn_date<?) or (updateTime>=? and updateTime<?) ) ".
			"and deletionState=0 and id64 is not null order by ID $debug_limit",[($start,$today,$start,$today,$start,$today)]);

warn "Systems, Encoding ".int(@$rows)." records\n";

open OUT, ">$fn{systems}";
while (@$rows) {
	my $r = shift @$rows;

	$$r{coords}{x} = defined($$r{coord_x}) ? $$r{coord_x}+0 : undef;
	$$r{coords}{y} = defined($$r{coord_y}) ? $$r{coord_y}+0 : undef;
	$$r{coords}{z} = defined($$r{coord_z}) ? $$r{coord_z}+0 : undef;
	delete($$r{coord_x});
	delete($$r{coord_y});
	delete($$r{coord_z});
		
	numerify($r);

	print OUT $json->encode($r)."\r\n";
	print $json->encode($r)."\r\n" if ($debug_json);

	$dotcount++;
	print '.' if ($dotcount % 10000 == 0 && !$debug);
}
close OUT;
print "\n";

if (!$debug) {
	warn "Systems, Compressing and sending.\n";
	system("$gzip -c $fn{systems} > $fn{systems}.gz");

	my $size  = (stat($fn{systems}))[7];
	my $epoch  = (stat($fn{systems}))[9];
	my $wc = get_lines($fn{systems});

	open META, ">$fn{systems}.meta";
	print META "$epoch\n";
	print META "$size\n";
	print META "$wc\n";
	close META;

	system("$scp $fn{systems}.gz $fn{systems}.meta www\@services:/www/edastro.com/mapcharts/files/");
}

###########################################################################

warn "Stars, $start - $today\n";

my $rows = rows_mysql('elite',"select starID, edsmID, systemId64, systemId as edsm_sysId, bodyId64, name, subType, 
		isPrimary, isMainStar, isScoopable, updateTime as edsmUpdated, updated as updateTime, date_added, 
		distanceToArrivalLS as distanceToArrival, orbitType, rotationalPeriodTidallyLocked, rotationalPeriod, 
		axialTilt, age, absoluteMagnitude, luminosity, surfaceTemperature, solarMasses, solarRadius, 
		orbitalInclination, argOfPeriapsis, semiMajorAxis, orbitalEccentricity, orbitalPeriod, bodyId, parents, 
		meanAnomaly,ascendingNode,
		parentStarID, parentPlanetID from stars where ( (date_added>=? and date_added<?)
		or (updateTime>=? and updateTime<?) or (eddn_date>=? and eddn_date<?) ) and deletionState=0 and systemId64 is not null order by starID $debug_limit",
		[($start,$today,$start,$today,$start,$today)]);

warn "Stars, Encoding ".int(@$rows)." records\n";

open OUT, ">$fn{stars}";
while (@$rows) {
	my $r = shift @$rows;

	if ($$r{parents}) {
		my @list = ();
		foreach my $p (split /\s*;\s*/, btrim($$r{parents})) {
			my ($pp,$n) = split /\s*:\s*/, $p;

			if ($pp && defined($n)) {
				my %hash = ();
				$hash{$pp} = $n+0;
				push @list, \%hash;
			}
		}
		delete($$r{parents});
		@{$$r{parents}} = @list;
		
	} else {
		delete($$r{parents});
		@{$$r{parents}} = ();
	}

	$$r{isScoopable} = $$r{isScoopabe} ? \1 : \0;
	$$r{isPrimary}   = $$r{isPrimary} ? \1 : \0;
	$$r{isMainStar}  = $$r{isMainStar} ? \1 : \0;
	$$r{rotationalPeriodTidallyLocked} = $$r{rotationalPeriodTidallyLocked} ? \1 : \0;

	$$r{orbitType} = $orbit{$$r{orbitType}};

	foreach my $belts (qw(belts rings)) {
		@{$$r{$belts}} = db_mysql('elite',"select name,type,mass,innerRadius,outerRadius from $belts where planet_id=? and isStar=1",[($$r{starID})]);
	}

	numerify($r);

	print OUT $json->encode($r)."\r\n";
	print $json->encode($r)."\r\n" if ($debug_json);

	$dotcount++;
	print '.' if ($dotcount % 10000 == 0 && !$debug);
}
close OUT;
print "\n";

if (!$debug) {
	warn "Stars, Compressing and sending.\n";
	system("$gzip -c $fn{stars} > $fn{stars}.gz");

	my $size  = (stat($fn{stars}))[7];
	my $epoch  = (stat($fn{stars}))[9];
	my $wc = get_lines($fn{stars});

	open META, ">$fn{stars}.meta";
	print META "$epoch\n";
	print META "$size\n";
	print META "$wc\n";
	close META;

	system("$scp $fn{stars}.gz $fn{stars}.meta www\@services:/www/edastro.com/mapcharts/files/");
}


###########################################################################

warn "Planets, $start - $today\n";

my $rows = rows_mysql('elite',"select planetID, edsmID, systemId64, systemId as edsm_sysId, bodyId64, name, subType,
		isLandable, updateTime as edsmUpdated, updated as updateTime, date_added, distanceToArrivalLS as distanceToArrival, 
		orbitType, rotationalPeriodTidallyLocked, rotationalPeriod, axialTilt, gravity, surfaceTemperature, earthMasses, radius, 
		orbitalInclination, argOfPeriapsis, semiMajorAxis, orbitalEccentricity, orbitalPeriod, terraformingState, 
		meanAnomaly,ascendingNode,
		volcanismType, atmosphereType, surfacePressure, bodyId, parents, parentStarID,
		parentPlanetID from planets where ( (date_added>=? and date_added<?)
		or (updateTime>=? and updateTime<?)  or (eddn_date>=? and eddn_date<?) ) and deletionState=0 and systemId64 is not null order by planetID $debug_limit",
		[($start,$today,$start,$today,$start,$today)]);

warn "Planets, Encoding ".int(@$rows)." records\n";

open OUT, ">$fn{planets}";
while (@$rows) {
	my $r = shift @$rows;

	if ($$r{parents}) {
		my @list = ();
		foreach my $p (split /\s*;\s*/, btrim($$r{parents})) {
			my ($pp,$n) = split /\s*:\s*/, $p;

			if ($pp && defined($n)) {
				my %hash = ();
				$hash{$pp} = $n+0;
				push @list, \%hash;
			}
		}
		delete($$r{parents});
		@{$$r{parents}} = @list;
		
	} else {
		delete($$r{parents});
		@{$$r{parents}} = ();
	}

	$$r{isLandable} = $$r{isLandable} ? \1 : \0;
	$$r{rotationalPeriodTidallyLocked} = $$r{rotationalPeriodTidallyLocked} ? \1 : \0;

	$$r{orbitType} = $orbit{$$r{orbitType}};

	@{$$r{rings}} = db_mysql('elite',"select name,type,mass,innerRadius,outerRadius from rings where planet_id=? and isStar=0",[($$r{planetID})]);

	my @data = db_mysql('elite',"select * from atmospheres where planet_id=?",[($$r{planetID})]);
	if (@data) {
		$$r{atmosphereComposition} = shift @data;
		delete($$r{atmosphereComposition}{id});
		delete($$r{atmosphereComposition}{planet_id});

		foreach my $k (keys %{$$r{atmosphereComposition}}) {
			delete($$r{atmosphereComposition}{$k}) if (!$$r{atmosphereComposition}{$k});
			$$r{atmosphereComposition}{$k} += 0 if ($$r{atmosphereComposition}{$k});
		}
	} else {
		%{$$r{atmosphereComposition}} = ();
	}

	my @data = db_mysql('elite',"select * from materials where planet_id=?",[($$r{planetID})]);
	if (@data) {
		$$r{materials} = shift @data;
		delete($$r{materials}{id});
		delete($$r{materials}{planet_id});

		foreach my $k (keys %{$$r{materials}}) {
			delete($$r{materials}{$k}) if (!$$r{materials}{$k});
			$$r{materials}{$k} += 0 if ($$r{materials}{$k});
		}
	} else {
		%{$$r{materials}} = ();
	}

	numerify($r);

	print OUT $json->encode($r)."\r\n";
	print $json->encode($r)."\r\n" if ($debug_json);

	$dotcount++;
	print '.' if ($dotcount % 10000 == 0 && !$debug);
}
close OUT;
print "\n";

if (!$debug) {
	warn "Planets, Compressing and sending.\n";
	system("$gzip -c $fn{planets} > $fn{planets}.gz");

	my $size  = (stat($fn{planets}))[7];
	my $epoch  = (stat($fn{planets}))[9];
	my $wc = get_lines($fn{planets});

	open META, ">$fn{planets}.meta";
	print META "$epoch\n";
	print META "$size\n";
	print META "$wc\n";
	close META;

	system("$scp $fn{planets}.gz $fn{planets}.meta www\@services:/www/edastro.com/mapcharts/files/");
}

exit;

###########################################################################

sub numerify {
	my $href = shift;

	foreach my $k (keys %$href) {
		$$href{$k} += 0 if ($k =~ /^(id|ID|starID|planetID|sol_dist|eddb_id|edsm_id|edsmID|region|id64|systemId64|bodyId64|absoluteMagnitude|distanceToArrival)$/);
		$$href{$k} += 0 if ($k =~ /(Id64|starID|planetID|temperature|radius|mass|gravity|inclination|tilt|age|periapsis|period|axis|eccentricity|edsm_sysId|pressure)/i &&
					$k !~ /rotationalPeriodTidallyLocked/);

		if ($k =~ /^(belts|rings)$/) {
			foreach my $r (@{$$href{$k}}) {
				foreach my $kk (keys %$r) {
					$$r{$kk} += 0 if ($kk =~ /mass|radius/i);
				}
			}
		}
		if ($k =~ /^(materials|atmosphereComposition)$/) {
			foreach my $kk (keys %{$$href{$k}}) {
				$$href{$k}{$kk} += 0;
			}
		}
	}
}

sub get_lines {
	my $fn = shift;
	open WC, "/usr/bin/wc -l $fn |";
	my @lines = <WC>;
	close WC;
	my $wc = join('',@lines);
	chomp $wc;
	$wc-- if (int($wc));
	return $wc;
}

###########################################################################


