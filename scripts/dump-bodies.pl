#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/elite";
use EDSM qw(log10 ssh_options scp_options);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

use IO::Handle;

############################################################################

show_queries(0);

my $debug		= 0;
my $upload_only		= 0;
my $do_planets		= 1;
my $do_stars		= 1;
my $allow_scp		= 1;

$debug = $ARGV[0] if (@ARGV);
$allow_scp = 0 if ($debug);

#$allow_scp = 0 if ($0 =~ /\.pl\.\S+/);

my $scp			 = '/usr/bin/scp'.scp_options();
my $ssh			 = '/usr/bin/ssh'.ssh_options();
my $remote_server       = 'www@services:/www/edastro.com/mapcharts/files';

my $outer_chunk_size    = 50000;
my $inner_chunk_size    = 1000;

my $dump_prefix		= 'dump';
my $dump_suffix		= 'csv';

$dump_prefix = "test/$dump_prefix" if ($debug);

my %dec_fields = ();
foreach my $f (qw(earthMasses axialTilt rotationalPeriod orbitalPeriod orbitalEccentricity orbitalInclination argOfPeriapsis semiMajorAxis 
		surfacePressure surfaceTemperature absoluteMagnitude solarMasses solarRadius)) {
	$dec_fields{$f} = 1;
}

my %file = ();
$file{'Ammonia world'}			= "$dump_prefix-ammonia-world.$dump_suffix";
$file{'Class I gas giant'}		= "$dump_prefix-giant-class-I.$dump_suffix";
$file{'Class II gas giant'}		= "$dump_prefix-giant-class-II.$dump_suffix";
$file{'Class III gas giant'}		= "$dump_prefix-giant-class-III.$dump_suffix";
$file{'Class IV gas giant'}		= "$dump_prefix-giant-class-IV.$dump_suffix";
$file{'Class V gas giant'}		= "$dump_prefix-giant-class-V.$dump_suffix";
$file{'Earth-like world'}		= "$dump_prefix-earthlike.$dump_suffix";
$file{'Gas giant with ammonia-based life'}		= "$dump_prefix-giant-ammonia-life.$dump_suffix";
$file{'Gas giant with water-based life'}		= "$dump_prefix-giant-water-life.$dump_suffix";
$file{'Helium gas giant'}		= "$dump_prefix-giant-helium.$dump_suffix";
$file{'Helium-rich gas giant'}		= "$dump_prefix-giant-helium-rich.$dump_suffix";
$file{'High metal content world'}	= "$dump_prefix-high-metal-content.$dump_suffix";
$file{'Icy body'}			= "$dump_prefix-icy-body.$dump_suffix";
$file{'Metal-rich body'}		= "$dump_prefix-metal-rich.$dump_suffix";
$file{'Rocky body'}			= "$dump_prefix-rocky-body.$dump_suffix";
$file{'Rocky Ice world'}		= "$dump_prefix-rocky-ice.$dump_suffix";
$file{'Water giant'}			= "$dump_prefix-water-giant.$dump_suffix";
$file{'Water world'}			= "$dump_prefix-water-world.$dump_suffix";

$file{'Carbon Star'}			= "$dump_prefix-carbon-star.$dump_suffix";
$file{'White Dwarf'}			= "$dump_prefix-white-dwarf.$dump_suffix";
$file{'Brown Dwarf'}			= "$dump_prefix-brown-dwarf.$dump_suffix";
$file{'Wolf-Rayet'}			= "$dump_prefix-wolf-rayet.$dump_suffix";
$file{'Black Hole'}			= "$dump_prefix-black-hole.$dump_suffix";
$file{'Neutron Star'}			= "$dump_prefix-neutron-star.$dump_suffix";
$file{'Herbig Ae/Be Star'}		= "$dump_prefix-herbig-star.$dump_suffix";
$file{'T Tauri Star'}			= "$dump_prefix-t-tauri-star.$dump_suffix";
$file{'O Star'}				= "$dump_prefix-star-class-O.$dump_suffix";
$file{'B Star'}				= "$dump_prefix-star-class-B.$dump_suffix";
$file{'A Star'}				= "$dump_prefix-star-class-A.$dump_suffix";
$file{'F Star'}				= "$dump_prefix-star-class-F.$dump_suffix";
$file{'G Star'}				= "$dump_prefix-star-class-G.$dump_suffix";
$file{'K Star'}				= "$dump_prefix-star-class-K.$dump_suffix";
$file{'M Star'}				= "$dump_prefix-star-class-M.$dump_suffix";

my $systems_file			= "$dump_prefix-systems.$dump_suffix";

############################################################################

if ($upload_only) {
	upload_files();
	exit;
}

warn "DEBUG\n" if ($debug);

open SYSTEMS, ">$systems_file";
print SYSTEMS "EDAstro ID,EDSM ID,id64,Name,Coord_X,Coord_Y,Coord_Z,SOL Distance,Stars,Planets,Date Added,FSS Progress,FSS Body Count,Main Star Type\r\n";

my $p_header = "SystemAddress ID64,EDSM SystemID,System,Mass Code,PlanetID,StarID,EDSM_ID,Body ID64,Name,".
	"Landable,Orbit Type,Rings,RingTypes,Arrival Distance,".
	"Terraforming State,Radius,Earth Masses,Surface Gravity,Surface Temperature,Surface Pressure,".
	"Volcanism,Atmosphere,Axial Tilt,Rotational Period,Tidally Locked,Orbital Period,".
	"Semi-major Axis,Orbital Eccentricity,Orbital Inclination,Arg. of Periapsis,meanAnomaly,ascendingNode,".
	"Timestamp,Parent ID,Parent Type,Coord_X,Coord_Y,Coord_Z,RegionID,Main Star Type\r\n";

my $s_header = "SystemAddress ID64,EDSM SystemID,System,Mass Code,PlanetID,StarID,EDSM_ID,Body ID64,Name,".
	"Status,Type,Belts,BeltTypes,Rings,RingTypes,Main Star,Scoopable,Arrival Distance,Age,".
	"Solar Masses,Solar Radius,Surface Temperature,Absolute Magnitude,Spectral Class,Luminosity,".
	"Axial Tilt,Rotational Period,Tidally Locked,Orbital Period,".
	"Semi-major Axis,Orbital Eccentricity,Orbital Inclination,Arg. of Periapsis,meanAnomaly,ascendingNode,".
	"Timestamp,Parent ID,Parent Type,Coord_X,Coord_Y,Coord_Z,RegionID,Main Star Type\r\n";

my %filehandle = ();
foreach my $type (keys %file) {

	if ($type =~ /(wolf|star|carbon|dwarf|black|brown|neutron)/i) {
		next if (!$do_stars);
		open $filehandle{$type}, ">$file{$type}";
		my $FH = $filehandle{$type};
		print $FH $s_header;
	} else {
		next if (!$do_planets);
		open $filehandle{$type}, ">$file{$type}";
		my $FH = $filehandle{$type};
		print $FH $p_header;
	}
}

my @rows = db_mysql('elite',"select max(id) as maxid from systems");
die "Failed to get max system ID\n" if (!@rows);
my $max_sys_id = ${$rows[0]}{maxid};

warn "Max system ID: $max_sys_id\n";

my %sysdata = ();
my @syslist = ();
my $id_chunk = 0;
my $loopcount = 0;
my $count = 0;
my %rowcounter = ();

my %columns = ();

foreach my $table (qw(planets stars)) {
	my @rows = db_mysql('elite',"describe $table");
	foreach my $r (@rows) {
		if ($$r{Type} =~ /^(float|double)/) {
			$columns{$table}{$$r{Field}} = "cast($$r{Field} as decimal(65,20)) $$r{Field}";
		} else {
			$columns{$table}{$$r{Field}} = $$r{Field};
		}
	}
}



print "Looping...\n";

while ($id_chunk < $max_sys_id) {
	my @rows = db_mysql('elite',"select ID,edsm_id,id64,name,coord_x,coord_y,coord_z,date_added,sol_dist,FSSprogress,bodyCount,region,mainStarID from systems where ".
				"ID>=? and ID<? and deletionState=0 and id64 is not null",[($id_chunk,$id_chunk+$outer_chunk_size)]);

	$loopcount++;
	print '.'  if ($loopcount % 10 == 0);
	print "\n" if ($loopcount % 1000 == 0);

	flush_files()  if ($loopcount % 10 == 0);

	%sysdata = ();
	@syslist = ();

	while (@rows) {
		my $r = shift @rows;
		if ($$r{id64}) {
			$sysdata{$$r{id64}} = $r;
			push @syslist, $$r{id64};
		}
		delete($sysdata{$$r{id64}}{id64});	# redundant
	}

	while (@syslist) {
		my @sys = splice @syslist, 0, $inner_chunk_size;
		my $id_list = join ',', @sys;
		last if (!@sys);

		my %mainstar = ();

		my @mainstars = db_mysql('elite',"select id64,stars.name,stars.subType from systems,stars where id64 in (".join(',',@sys).") and ".
			"systems.deletionState=0 and stars.deletionState=0 and mainStarID=starID and id64=systemId64");

		foreach my $ms (@mainstars) {
			$mainstar{$$ms{id64}} = $ms;
			delete $mainstar{$$ms{id64}}{id64}; # redundant
		}

		my @rows = ();
		my %ring = ();
		my %belt = ();

		if ($do_planets) {
			my @rows2 = db_mysql('elite',"select ".join(',',values %{$columns{planets}}).",0 as isStar,planetID as localID from planets where deletionState=0 and systemId64 in ($id_list) order by name") if ($id_list);

			my $pidlist = '';
			foreach my $r (@rows2) {
				$pidlist .= ",$$r{planetID}" if (defined($$r{planetID}));
				$sysdata{$$r{systemId64}}{planets}++;
			}
			$pidlist =~ s/^,//;

			while (@rows2) {

				foreach my $k (keys %{$rows2[0]}) {
					if (${$rows2[0]}{$k} =~ /^\-?\d+\.\d+$/) {
						${$rows2[0]}{$k} += 0;
					}
				}

				push @rows, shift @rows2;
			}
	
			my @rings = ();
			@rings = db_mysql('elite',"select id,type,planet_id from rings where planet_id in ($pidlist) and isStar!=1") if ($pidlist);
			while (@rings) {
				my $r = shift @rings;
				$ring{0}{$$r{planet_id}}{$$r{id}} = $$r{type};
			}
		}
		
		if ($do_stars) {
			my @rows2 = db_mysql('elite',"select ".join(',',values %{$columns{stars}}).",1 as isStar,starID as localID from stars where deletionState=0 and systemId64 in ($id_list) order by name") if ($id_list);

			my $pidlist = '';
			foreach my $r (@rows2) {
				$pidlist .= ",$$r{starID}" if (defined($$r{starID}));
				$sysdata{$$r{systemId64}}{stars}++;
			}
			$pidlist =~ s/^,//;
	
			while (@rows2) {

				foreach my $k (keys %{$rows2[0]}) {
					if (${$rows2[0]}{$k} =~ /^\-?\d+\.\d+$/) {
						${$rows2[0]}{$k} += 0;
					}
				}

				push @rows, shift @rows2;
			}
	
			my @rings = ();
			@rings = db_mysql('elite',"select id,type,planet_id from rings where planet_id in ($pidlist) and isStar=1") if ($pidlist);
			while (@rings) {
				my $r = shift @rings;
				$ring{1}{$$r{planet_id}}{$$r{id}} = $$r{type};
			}
	
			my @belts = ();
			@belts = db_mysql('elite',"select id,type,planet_id from belts where planet_id in ($pidlist)") if ($pidlist);
			while (@belts) {
				my $r = shift @belts;
				$belt{1}{$$r{planet_id}}{$$r{id}} = $$r{type};
			}
		}

		foreach my $s (sort {$a <=> $b} @sys) {
			$sysdata{$s}{planets} = 0 if (!$sysdata{$s}{planets});
			$sysdata{$s}{stars} = 0 if (!$sysdata{$s}{stars});
			print SYSTEMS make_csv($sysdata{$s}{ID},$sysdata{$s}{edsm_id},$s,$sysdata{$s}{name},$sysdata{$s}{coord_x},$sysdata{$s}{coord_y},$sysdata{$s}{coord_z},
					$sysdata{$s}{sol_dist},$sysdata{$s}{stars},$sysdata{$s}{planets},$sysdata{$s}{date_added},$sysdata{$s}{FSSprogress},$sysdata{$s}{bodyCount},
					$mainstar{$s}{subType})."\r\n";
			$rowcounter{systems}++;
		}

		my %bodytype = ();
		foreach my $r (@rows) {
			$bodytype{$$r{name}} = $$r{subType};
		}
		
		while (@rows) {
			my $r = shift @rows;

			my $filetype = $$r{subType};
			my ($classification, $minortype) = star_type($$r{subType}) if ($$r{isStar});

			$filetype = $classification if ($classification);
			my $FH = $filehandle{$filetype};
		
			next if (!$file{$filetype} || !defined($FH));

			my $ringnum = int(keys %{$ring{$$r{isStar}}{$$r{localID}}});
			my $beltnum = int(keys %{$belt{$$r{isStar}}{$$r{localID}}});
		
			my %ringtype = ();
			my %belttype = ();
		
			foreach my $ringID (keys %{$ring{$$r{isStar}}{$$r{localID}}}) {
				$ringtype{$ring{$$r{isStar}}{$$r{localID}}{$ringID}}++;
			}
			my $ringtypes = '';
			foreach my $t (sort keys %ringtype) {
				next if (!$t);
				$ringtypes .= ", " if ($ringtypes);
				$ringtypes .= "$t ($ringtype{$t})";
			}
		
			foreach my $beltID (keys %{$belt{$$r{localID}}}) {
				$belttype{$belt{$$r{isStar}}{$$r{localID}}{$beltID}}++;
			}
			my $belttypes = '';
			foreach my $t (sort keys %belttype) {
				next if (!$t);
				$belttypes .= ", " if ($belttypes);
				$belttypes .= "$t ($belttype{$t})";
			}
		
			my $system_name = $sysdata{$$r{systemId64}}{name};

			my $parent_name = '';
			my $parent_type = '';

			if ($$r{name} ne $system_name) {
				$parent_name = $$r{name};
				$parent_name =~ s/\s+[\w\d]+\s*$//;
			}

			if ($parent_name && $bodytype{$parent_name}) {
				$parent_type = $bodytype{$parent_name};
			}

			my $parentID = $$r{parentStar};
			$parentID = $$r{parentPlanet} if (!$parentID);
		
			my $orbit_type = '';
		
			$orbit_type = 'stellar' if ($$r{name} eq $system_name || $$r{name} =~ /\s+[A-Z]\s*$/);
			$orbit_type = 'planetary' if ($$r{name} =~ /\s+\d\s*$/);
			$orbit_type = 'moon' if ($$r{name} =~ /\s+\d\s+[a-z]\s*$/);
			$orbit_type = 'moon of moon' if ($$r{name} =~ /\s+\d\s+[a-z]\s+[a-z]\s*$/);
			$orbit_type = 'moon of moon of moon' if ($$r{name} =~ /\s+\d\s+[a-z]\s+[a-z]\s+[a-z]\s*$/);
			$orbit_type = 'moon of moon of moon of moon' if ($$r{name} =~ /\s+\d\s+[a-z]\s+[a-z]\s+[a-z]\s+[a-z]\s*$/);
		
			my $locked = 'no';
			$locked = 'yes' if ($$r{rotationalPeriodTidallyLocked});
		
			my $isLandable = 'no';
			$isLandable = 'yes' if ($$r{isLandable});

			my $isMainStar = 'no';
			$isMainStar = 'yes' if ($$r{isMainStar});

			my $isScoopable = 'no';
			$isScoopable = 'yes' if ($$r{isScoopable});

			my $position = 'secondary';
			$position = 'primary' if ($$r{isMainStar} || $$r{name} eq "$system_name A");
			$position = 'single' if ($$r{name} eq $system_name);

			my $masscode = '';
		
			if ($$r{name} =~ /\S+\s+\w\w\-\w\s+([a-zA-Z])(\d+\-)?\d+/) {
				$masscode = uc($1);
			}
		
			my $out = '';

			foreach my $k (keys %dec_fields) {
				if ($k eq 'surfaceTemperature' && defined($$r{$k.'Dec'}) && $$r{$k.'Dec'}) {
					$$r{$k} = sprintf("%.6f",$$r{$k.'Dec'});

				} elsif (defined($$r{$k.'Dec'}) && $$r{$k.'Dec'}) {
					$$r{$k} = showdecimal($$r{$k.'Dec'}+0, $k eq 'surfaceTemperature' ? 1 : 0);
				} else {
					$$r{$k} = showdecimal($$r{$k}+0);
				}
			}

			print $FH make_csv($$r{systemId64},$$r{systemId},$system_name,$masscode,$$r{planetID},$$r{starID},$$r{edsmID},$$r{bodyId64},$$r{name},
				$isLandable,$orbit_type,$ringnum,$ringtypes,
				$$r{distanceToArrivalLS},$$r{terraformingState},$$r{radius},$$r{earthMasses},$$r{gravity},$$r{surfaceTemperature},$$r{surfacePressure},
				$$r{volcanismType},$$r{atmosphereType},$$r{axialTilt},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},$$r{semiMajorAxis},$$r{orbitalEccentricity},
				$$r{orbitalInclination},$$r{argOfPeriapsis},$$r{meanAnomaly},$$r{ascendingNode},$$r{updateTime},$parentID,$parent_type,
				$sysdata{$$r{systemId64}}{coord_x},$sysdata{$$r{systemId64}}{coord_y},$sysdata{$$r{systemId64}}{coord_z},$sysdata{$$r{systemId64}}{region},
				$mainstar{$$r{systemId64}}{subType}).
				"\r\n" if (!$$r{isStar});

			print $FH make_csv($$r{systemId64},$$r{systemId},$system_name,$masscode,$$r{planetID},$$r{starID},$$r{edsmID},$$r{bodyId64},$$r{name},
				$position,$$r{subType},$beltnum,$belttypes,
				$ringnum,$ringtypes,$isMainStar,$isScoopable,
				$$r{distanceToArrivalLS},$$r{age},$$r{solarMasses},$$r{solarRadius},$$r{surfaceTemperature},$$r{absoluteMagnitude},
				$$r{spectralClass},$$r{luminosity},$$r{axialTilt},$$r{rotationalPeriod},$locked,$$r{orbitalPeriod},$$r{semiMajorAxis},
				$$r{orbitalEccentricity},$$r{orbitalInclination},$$r{argOfPeriapsis},$$r{meanAnomaly},$$r{ascendingNode},$$r{updateTime},$parentID,$parent_type,
				$sysdata{$$r{systemId64}}{coord_x},$sysdata{$$r{systemId64}}{coord_y},$sysdata{$$r{systemId64}}{coord_z},$sysdata{$$r{systemId64}}{region},
				$mainstar{$$r{systemId64}}{subType}).
				"\r\n" if ($$r{isStar});

			$rowcounter{$filetype}++;
			$count++;
		}
	
		last if ($debug && $count);
	}

	$id_chunk += $outer_chunk_size;
	last if ($debug && $count);
}

eval {

	my $data = columns_mysql('elite',"select id64 from navsystems");
	my @ids = ();

	if ($$data{id64} && ref($$data{id64}) eq 'ARRAY' && @{$$data{id64}}) {
		warn "NAV/ROUTE Systems: ".int(@{$$data{id64}})."\n";
	} else {
		warn "NAV/ROUTE Systems: None found.\n";
	}

	while ($$data{id64} && ref($$data{id64}) eq 'ARRAY' && @{$$data{id64}}) {
		push @ids, shift @{$$data{id64}};

		if (@ids >= 250 || !@{$$data{id64}}) {

			my $rows = rows_mysql('elite',"select * from navsystems where id64 in (".join(',',@ids).")");

			while ($rows && ref($rows) eq 'ARRAY' && @$rows) {
				my $r = shift @$rows;

				print SYSTEMS ",,$$r{id64},$$r{name},$$r{coord_x},$$r{coord_y},$$r{coord_z},,,,$$r{created},,\r\n";
				$rowcounter{systems}++;
			}
			@ids = ();
		}
		last if (!@{$$data{id64}})
	}
};

print "\n";

close SYSTEMS;
foreach my $type (keys %file) {
	next if (!defined($filehandle{$type}));
	close $filehandle{$type};
}

upload_files();

my_system("$ssh www\@services 'cd /www/edastro.com/mapcharts ; ./update-spreadsheets.pl'") if (!$debug && $allow_scp);

exit;

############################################################################

sub showdecimal {
        my $text = shift;
	my $allow_zeroes = shift;

        if ($text =~ /^\s*[\+\-\d]\.(\d+)+e[\+\-]?(\d+)\s*$/i) {
                my $digits = length($1) + $2;
                $text = sprintf("%.".$digits."f",$text);
        } elsif ($text =~ /^\s*[\+\-\d]\.(\d+)+e\+?(\d+)\s*$/i) {
                $text = sprintf("%f",$text);
        }

	if (!$allow_zeroes) {
		$text =~ s/\.0+$//;
		$text =~ s/(\.\d*?)0+$/$1/;
	}
        return $text;
}

sub upload_files {
	compress_send($systems_file,$rowcounter{systems});

	foreach my $type (keys %file) {
		next if (!defined($filehandle{$type}) && !$upload_only);
		compress_send($file{$type},$rowcounter{$type});
	}
}

############################################################################
sub compress_send {
	my $fn = shift;
	my $wc = shift;

	if ($debug || !$allow_scp) {
		warn "FILE: $fn\n";
		return;
	}

	warn "UPLOAD: $fn\n";

	my $zipf = $fn; $zipf =~ s/\.\w+$/.zip/;
	my $meta = "$fn.meta";
	my $stat = "$fn.txt";

	my $size  = (stat($fn))[7];
	my $epoch = (stat($fn))[9];

	$wc = 0 if (!$wc);

	if (!$wc) {
		open WC, "/usr/bin/wc -l $fn |";
		my @lines = <WC>;
		close WC;
		$wc = join('',@lines);
		chomp $wc;
		$wc-- if (int($wc));
	}

	open META, ">$meta";
	print META "$epoch\n";
	print META "$size\n";
	print META "$wc\n";
	close META;

	open STAT, ">$stat";
	print STAT "File:  $fn\n";
	print STAT "Epoch: $epoch\n";
	print STAT "Bytes: $size\n";
	print STAT "Lines: $wc\n";
	close STAT;

	#if (!$upload_only) {
		unlink $zipf;

		my $exec = "/usr/bin/zip temp-$$-$zipf $fn ; /bin/mv temp-$$-$zipf $zipf ; /usr/bin/chown www:www $zipf";
		print "# $exec\n";
		system($exec);
	#}

	my_system("$scp $zipf $meta $remote_server/") if (!$debug && $allow_scp);

	#my_system("./push2mediafire.pl $zipf") if (!$debug && $allow_scp);
	#my_system("./push2mediafire.pl $stat") if (!$debug && $allow_scp);
}

sub flush_files {
	#SYSTEMS->flush();

	foreach my $type (keys %file) {
		next if (!defined($filehandle{$type}));
		my $FH = $filehandle{$type};
		$FH->flush();
	}
}

sub star_type {
	my $orig = shift;
	my $type = $orig;
	my $subtype = $orig;
	
	if ($orig =~ /White Dwarf \((\S+)\)/i) {
		$type = 'White Dwarf';
		$subtype = $1;
	} elsif ($orig =~ /Wolf-Rayet (\S+) /i) {
		$type = 'Wolf-Rayet';
		$subtype = $1;
	} elsif ($orig =~ /Wolf-Rayet/i) {
		$type = 'Wolf-Rayet';
		$subtype = '';
	} elsif ($orig =~ /(\S+)\s+\(Brown dwarf\)/i) {
		$type = 'Brown Dwarf';
		$subtype = $1;
	} elsif ($orig =~ /(M?S)-type/) {
		$type = 'Carbon Star';
		$subtype = $1;
	} elsif ($orig =~ /^(MS|C|CN|CJ) Star/) {
		$type = 'Carbon Star';
		$subtype = $1;
	} elsif ($orig =~ /^(\S) \((.*)\) Star/) {
		$type = "$1 Star";
		$subtype = $2;
	}

	return $type, $subtype;
}

sub my_system {
	my $string = shift;
	print "# $string\n";
	#print TXT "$string\n";
	system($string);
}

############################################################################





