#!/usr/bin/perl
use strict;
$|=1;

use JSON::XS;
use Tie::IxHash;
#use Hash::Ordered;
use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql);

my $do_tie = 1;

my $sectorname = $ARGV[0];
my $masscode = $ARGV[1];

die "Usage: $0 <sectorname>\n" if (!$sectorname);

my @rows = db_mysql('elite',"select ID from sectors where name=?",[($sectorname)]);

die "Sector \"$sectorname\" not found.\n" if (!@rows);

my $sectorID = ${$rows[0]}{ID};

print "SectorID: $sectorID ($sectorname)\n";

my @params = ($sectorID);
my $and = '';

if ($masscode) {
	push @params, lc($masscode);
	$and = "and masscode=?";
}

my @systems = db_mysql('elite',"select distinct id64 from systems where sectorID=? $and and deletionState=0 order by name",\@params);

print int(@systems)." systems found\n";

my $sn = lc($sectorname); $sn =~ s/\s+/_/gs; $sn =~ s/\W//gs;
my $fn = "/home/bones/elite/sectordump/$sn.jsonl";

my $count = 0;
my $json = JSON::XS->new;
my %codex = ();

my %codexname;
my @rows = db_mysql('elite',"select name,codexnameID from codexname_local order by preferred, date_added desc");
foreach my $r (@rows) {
	$codexname{$$r{codexnameID}}{local} = $$r{name};
}
my @rows = db_mysql('elite',"select name,id from codexname");
foreach my $r (@rows) {
	$codexname{$$r{id}}{name} = $$r{name};
}


my %speciesname;
my @rows = db_mysql('elite',"select name,speciesID from species_local order by preferred, date_added desc");
foreach my $r (@rows) {
	$speciesname{$$r{speciesID}}{local} = $$r{name};
}
my @rows = db_mysql('elite',"select name,id from species");
foreach my $r (@rows) {
	$speciesname{$$r{id}}{name} = $$r{name};
}


open OUT, ">$fn";
foreach my $s (@systems) {
	my %hash = ();
	tie %hash, "Tie::IxHash" if ($do_tie);
#	tie my %hash, "Hash::Ordered";

	my $id64 = $$s{id64};

	my $rows = rows_mysql('elite',"select name,date_added,updated,coord_x,coord_y,coord_z from systems where id64=? and deletionState=0",[($id64)]);
	foreach my $r (@$rows) {
		$hash{name} = $$r{name};
		$hash{id64} = defined($id64) ? $id64+0 : undef;
		$hash{coords}{x} = defined($$r{coord_x}) ? $$r{coord_x}+0 : undef;
		$hash{coords}{y} = defined($$r{coord_y}) ? $$r{coord_y}+0 : undef;
		$hash{coords}{z} = defined($$r{coord_z}) ? $$r{coord_z}+0 : undef;
		$hash{added} = $$r{date_added};
		$hash{updated} = $$r{updated};
	}
	my $rows = rows_mysql('elite',"select nameID,reportedOn from codex where systemId64=? and deletionState=0",[($id64)]);
	foreach my $r (@$rows) {
		#$$r{odyssey} = $$r{odyssey} ? \1 : \0;
		$$r{name} = $codexname{$$r{nameID}}{name};
		$$r{name_local} = $codexname{$$r{nameID}}{local};
		delete($$r{nameID});
		push @{$hash{codex}}, $r;
		$codex{$id64}{system} = $hash{name};
		push @{$codex{$id64}{codex}}, $r;
	}

	$hash{planets} = get_bodies('planets',$id64);
	$hash{stars}   = get_bodies('stars',$id64);

	print OUT $json->encode(\%hash)."\r\n";

	$count++;
	print '.' if ($count % 100 == 0);
	print "\n" if ($count % 10000 == 0);

}
close OUT;
print "\n";

$fn =~ s/\./-codex\./;
open OUT, ">$fn";
print OUT JSON::XS->new->encode(\%codex);

close OUT;

exit;

sub get_bodies {
	my $table = shift;
	my $id64 = shift;
	my @list = ();

	my $idfield = 'planetID';
	$idfield = 'starID' if ($table eq 'stars');

	my %data = ();
	tie %data, "Tie::IxHash" if ($do_tie);
#	tie my %data, "Hash::Ordered";

	my $rows = rows_mysql('elite',"select bodyId,speciesID,firstReported from organic where systemId64=?",[($id64)]);
	my %organic = ();
	foreach my $r (@$rows) {
		$organic{$$r{bodyId}}{$$r{speciesID}} = $$r{firstReported};
	}

	my $rows = rows_mysql('elite',"select * from $table where systemId64=? and deletionState=0",[($id64)]);

	foreach my $r (@$rows) {

		# Numeric fields:

		foreach my $key (qw(systemId64 bodyId64 distanceToArrival rotationalPeriod axialTilt surfaceTemperature 
				orbitalInclination argOfPeriapsis semiMajorAxis orbitalEccentricity orbitalPeriod bodyId)) {
			$data{$$r{$idfield}}{$key} = defined($$r{$key}) ? $$r{$key}+0 : undef;
		}
		if ($table eq 'planets') {
			foreach my $key (qw(gravity earthMasses radius surfacePressure)) {
				$data{$$r{$idfield}}{$key} = defined($$r{$key}) ? $$r{$key}+0 : undef;
			}
		}
		if ($table eq 'stars') {
			foreach my $key (qw(age absoluteMagnitude solarMasses solarRadius)) {
				$data{$$r{$idfield}}{$key} = defined($$r{$key}) ? $$r{$key}+0 : undef;
			}
		}

		# Boolean

		foreach my $key (qw(isLandable rotationalPeriodTidallyLocked isPrimary isMainStar isScoopable)) {
			if (defined($$r{$key})) {
				$data{$$r{$idfield}}{$key} = $$r{$key} ? \1 : \0;
			}
		}

		# Copy directly:

		foreach my $key (qw(date_added updated name subType terraformingState volcanismType atmosphereType parents luminosity)) {
			if (defined($$r{$key})) {
				$data{$$r{$idfield}}{$key} = $$r{$key};
			}
		}

		if (keys %{$organic{$$r{bodyId}}}) {
			my @org = ();

			foreach my $speciesID (keys %{$organic{$$r{bodyId}}}) {
				my %o = ();
				$o{local} = $speciesname{$speciesID}{local};
				$o{name} = $speciesname{$speciesID}{name};
				$o{firstReported} = $organic{$$r{bodyId}}{$speciesID};
				push @org, \%o;
			}

			$data{$$r{$idfield}}{organic} = \@org;
		}

	}

	return [()] if (!keys(%data));

	my $idlist = join(',',sort {$a <=> $b} keys %data);
	$idlist =~ s/^,+//;
	$idlist =~ s/,+$//;

	foreach my $type ('rings','belts') {
		my $isStar = $table eq 'stars' ? 1 : 0;
		my $rings = rows_mysql('elite',"select name,type,mass,innerRadius,outerRadius from $type where isStar=? and planet_id in ($idlist)",[($isStar)]);

		foreach my $r (@$rings) {
			push @{$data{$$r{planet_id}}{$type}}, $r;
		}
	}

	if ($table eq 'planets') {
		foreach my $type ('materials','atmospheres') {
			my $dat = rows_mysql('elite',"select * from $type where planet_id in ($idlist)");
			my $typename = $type;
			$typename = 'atmosphere' if ($type eq 'atmospheres');
	
			foreach my $r (@$dat) {
				my $id = $$r{planet_id};
				delete($$r{planet_id});
				delete($$r{id});

				foreach my $k (keys %$r) {
					delete($$r{$k}) if (!defined($$r{$k}));
				}

				push @{$data{$id}{$typename}}, $r;
			}
		}
	}

	foreach my $id (sort {$data{$a}{name} cmp $data{$b}{name}} keys %data) {
		push @list, $data{$id};
	}

	return \@list;
}




