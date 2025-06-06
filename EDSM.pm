package EDSM;

# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use strict;

use Encode qw(encode_utf8);
use POSIX qw(floor);
use Data::Dumper;
use File::Basename;
#use Tie::IxHash;

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(btrim epoch2date date2epoch parse_csv);

use utf8;
use feature qw( unicode_strings );

our $logname;

our $large_check;
our $allow_updates;
our $force_updates;
our $edsm_debug;
our $edsm_verbose;
our $edsm_use_names;
our $allow_bodyID_deletion;

our %obj_exists;
our %table;
our %columns;
our %skipkey;
our %typekey;
our %typekey2;
our %ringtype;
our %datecolumn;
our %parentkey;

our %nonnull_blankOK;
our %nonnull;
our %nonzero;
our %nonnegative;
our %add_decimal;

our @systemstringlist;
our %systemstrings;

our @regionmap;

our %atmo_map;
our %volc_map;
our %planet_map;
our %star_map;
our %terr_map;

our $scp;
our $ssh;
our $remote_server;


my $db;


BEGIN { # Export functions first because of possible circular dependancies
   use Exporter;
   use vars qw(@ISA $VERSION @EXPORT_OK);

   $VERSION = 2.01;
   @ISA = qw(Exporter);
   @EXPORT_OK = qw(import_field import_directly check_updates edsm_debug $large_check $allow_updates $force_updates $edsm_debug $edsm_verbose
		$edsm_use_names update_object add_object object_exists object_newer load_objects dump_objects %table %columns %typekey log10
		id64_sectorcoords id64_subsector estimated_coordinates64 estimated_coords load_sectors letter_ord commify system_coordinates
		id64_to_name get_id64_by_name init_regionmap findRegion $allow_bodyID_deletion key_findcreate_local key_findcreate codex_entry codex_ok 
		reset_system_trackers load_mappings %atmo_map %volc_map %planet_map %star_map %terr_map logger $logname set_logname log_mysql
		completion_report id64_sectorID update_systemcounts compress_send scp_options ssh_options);

	%obj_exists	= ();

	$scp                 = '/usr/bin/scp -P222';
	$ssh                 = '/usr/bin/ssh -p222';
	$remote_server       = 'www@services:/www/edastro.com/mapcharts/files';

	$large_check	= 0;
	$allow_updates	= 1;
	$force_updates	= 0;
	$edsm_debug	= 0;
	$edsm_verbose	= 0;
	$edsm_use_names	= 0;
	$allow_bodyID_deletion = 0;

	$logname	= $0;
	$logname =~ s/\s+//s;
	$logname = basename($logname);

	$db		= 'elite';

	$table{system}		= 'systems';
	$table{barycenter}	= 'barycenters';
	$table{star}		= 'stars';
	$table{planet}		= 'planets';
	$table{ring}		= 'rings';
	$table{belt}		= 'belts';
	$table{POI}		= 'POI';
	$table{GEC}		= 'POI';
	$table{station}		= 'stations';
	$table{codex_edsm}	= 'codex_edsm';

	$typekey{system}	= 'ID';
	$typekey{barycenter}	= 'ID';
	$typekey{star}		= 'starID';
	$typekey{planet}	= 'planetID';
	$typekey{ring}		= 'id';
	$typekey{belt}		= 'id';
	$typekey{POI}		= 'edsm_id';
	$typekey{GEC}		= 'gec_id';
	$typekey{station}	= 'id';
	$typekey{codex_edsm}	= 'id';

	$skipkey{codex_edsm}	= 'id';

	#$typekey2{belt}		= 'name';
	#$typekey2{ring}		= 'name';

	$datecolumn{system}	= 'updateTime';
	$datecolumn{barycenter}	= 'updateTime';
	$datecolumn{planet}	= 'updateTime';
	$datecolumn{star}	= 'updateTime';
	$datecolumn{station}	= 'updateTime';
	$datecolumn{codex_edsm}	= 'reportedOn';
	
	@{$columns{system}}	= qw(edsm_id id64 name updateTime eddn_date coord_x coord_y coord_z sectorID SystemGovernment SystemSecurity SystemEconomy SystemSecondEconomy SystemAllegiance);
	@{$columns{barycenter}}	= qw(ID edsmID bodyId64 systemId systemId64 eddn_date updateTime orbitalInclination argOfPeriapsis semiMajorAxis
					orbitalEccentricity orbitalPeriod meanAnomaly ascendingNode bodyId parents);
	@{$columns{star}}	= qw(starID edsmID bodyId64 systemId systemId64 name subType isMainStar eddn_date updateTime offset distanceToArrival distanceToArrivalLS
					rotationalPeriodTidallyLocked rotationalPeriod axialTilt isScoopable age absoluteMagnitude luminosity spectralClass
					surfaceTemperature solarMasses solarRadius orbitalInclination argOfPeriapsis semiMajorAxis 
					orbitalEccentricity orbitalPeriod meanAnomaly ascendingNode bodyId parents commanderName discoveryDate);
	@{$columns{planet}}	= qw(planetID edsmID bodyId64 systemId systemId64 name subType isLandable eddn_date updateTime offset distanceToArrival distanceToArrivalLS
					rotationalPeriodTidallyLocked rotationalPeriod axialTilt gravity surfaceTemperature earthMasses radius 
					orbitalInclination argOfPeriapsis semiMajorAxis orbitalEccentricity orbitalPeriod terraformingState 
					volcanismType atmosphereType surfacePressure meanAnomaly ascendingNode bodyId parents commanderName discoveryDate);
	@{$columns{ring}}	= qw(id planet_id isStar name type mass innerRadius outerRadius);
	@{$columns{belt}}	= qw(id planet_id isStar name type mass innerRadius outerRadius);
	@{$columns{POI}}	= qw(edsm_id name type systemId64 coord_x coord_y coord_z galMapSearch galMapUrl descriptionHtml hidden iconoverride);
	@{$columns{GEC}}	= qw(gec_id name type systemId64 coord_x coord_y coord_z galMapSearch galMapUrl descriptionHtml summary score poiUrl hidden callsign iconoverride);
	@{$columns{station}}	= qw(edsmID systemId64 systemId systemName bodyID bodyName name type distanceToArrival allegiance government economy secondEconomy 
					haveMarket haveShipyard haveOutfitting haveColonization updateTime updated eddnDate marketID padsL padsM padsS services);
	@{$columns{codex_edsm}}	= qw(systemId64 systemId systemName type name region reportedOn);

	$ringtype{planet}{ring}	= 1;
	$ringtype{star}{ring}	= 1;
	$ringtype{star}{belt}	= 1;

	%nonnull_blankOK = ();
	%nonnull = ();
	%nonzero = ();
	%nonnegative = ();
	%add_decimal = ();

	@systemstringlist = qw(SystemGovernment SystemSecurity SystemEconomy SystemSecondEconomy SystemAllegiance);
	%systemstrings = ();

	foreach my $nz (qw(gravity earthMasses radius orbitalPeriod rotationalPeriod semiMajorAxis solarMasses solarRadius surfaceTemperature surfaceGravity sectorID)) {
		$nonzero{$nz} = 1;
		$nonnegative{$nz} = 1;
	}
	$nonnegative{distanceToArrival}=1;
	$nonnegative{distanceToArrivalLS}=1;

	foreach my $nn (qw(edsm_date eddn_date eddb_date date_added updateTime updated systemId systemId64 id64 bodyId64 edsm_id edsmID discoveryDate commander adj_date spectralClass
				meanAnomaly ascendingNode eddnDate allegiance government economy secondEconomy haveMarket haveShipyard haveOutfitting marketID bodyID bodyName
				padsL padsM padsS)) {
		$nonnull{$nn} = 1;
	}

	foreach my $nn (@systemstringlist) {
		$nonnull_blankOK{$nn} = 1;
	}

	foreach my $ad (qw(surfaceTemperature surfacePressure gravity earthMasses radius absoluteMagnitude solarMasses solarRadius axialTilt rotationalPeriod orbitalPeriod orbitalEccentricity orbitalInclination argOfPeriapsis semiMajorAxis)) {
		$add_decimal{$ad} = 1;
		#print "ADD DECIMAL: $ad\n";
	}
	show_queries(0);
}

sub check_updates {
	$large_check = shift;
	$allow_updates = shift;
	$force_updates = shift;
}

sub edsm_debug {
	$edsm_debug = shift;
	$edsm_verbose = shift;
	#show_queries($edsm_debug);
}


sub update_object {
	my $type = shift;
	my $key  = $typekey{$type};
	my $key2 = $typekey2{$type};
	my $href = shift;
	my $iref = shift;
	my $date_field = shift;
	my $date_check = shift;

	my $rows; @$rows = ();

	if (!$table{$type}) {
		print "! Unknown type: $type\n" if ($edsm_verbose || $edsm_debug);
		return;
	}

# We won't have keys for auto-increment columns:
#
#	if (!$$href{$key}) {
#		print "! Missing key for $type '$$href{name}'\n" if ($edsm_verbose || $edsm_debug);
#		return;
#	}

	my $this_exists = object_exists($type,$$href{$key},$href);

	foreach my $var (keys %$href) {
		delete($$href{$var}) if (($$href{$var}==0 && $nonzero{$var}) || ($$href{$var}<0 && $nonnegative{$var}));
	}

	foreach my $var (@systemstringlist) {
		if (exists($$href{$var})) {
			$$href{$var} = systemstrings_ID($$href{$var});
		}
	}

	$$href{distanceToArrivalLS} = $$href{distanceToArrival} if ($$href{distanceToArrival} && !$$href{distanceToArrivalLS});

	if ($type =~ /^(star|planet|barycenter)$/ && !$$href{bodyId64} && $$href{bodyId} && $$href{systemId64}) {
		$$href{bodyId64} = ($$href{bodyId} << 55) | $$href{systemId64};
	}

	if ($type eq 'station' && $$href{name} =~ /^Pilgrim.+s Ruin$/) {
		$$href{name} = "Pilgrim's Ruin";
	}

	my $identification = '';
	$identification = $key.':'.$$href{$key} if ($$href{$key});
	$identification = "planetID:$$href{planetID}" if (!$identification && $$href{planetID});
	$identification = "starID:$$href{starID}" if (!$identification && $$href{starID});
	$identification = "ID:$$href{ID}" if (!$identification && $$href{ID});
	$identification = "id64:$$href{id64}" if (!$identification && $$href{id64});
	$identification = "bodyId64:$$href{bodyId64}" if (!$identification && $$href{bodyId64});
	$identification = "edsm_id:$$href{edsm_id}" if (!$identification && $$href{edsm_id});
	$identification = "edsmID:$$href{edsmID}" if (!$identification && $$href{edsmID});
	$identification = "name:$$href{name}" if (!$identification && $$href{name});

	my $field64 = undef;
	$field64 = 'id64' if ($type eq 'system');
	$field64 = 'bodyId64' if ($type eq 'star' || $type eq 'planet' || $type eq 'barycenter');

	print "SYSTEM: [$edsm_debug/$edsm_verbose] $identification - $$href{name} ($$href{coord_x},$$href{coord_y},$$href{coord_z})\n" if ($type eq 'system');
	print "OBJECT: [$edsm_debug/$edsm_verbose] $identification - $$href{name}\n" if ($type ne 'system');

	if ($large_check && !$allow_updates && !$force_updates && $this_exists) {
		print "! Changes not permitted for [$identification] '$$href{name}'\n" if ($edsm_verbose || $edsm_debug);
		return;
	}

	if ($large_check && $this_exists && !$force_updates && !object_newer($type,$$href{$key},$$href{$datecolumn{$type}})) {
		print "! Changes are not newer for [$identification] '$$href{name}'\n" if ($edsm_verbose || $edsm_debug);
		return;
	}

	if ($type eq 'codex_edsm') {
		$rows = rows_mysql($db,"select * from $table{$type} where systemId64=? and type=? and reportedOn=? order by deletionState",
				[($$href{systemId64},$$href{type},$$href{reportedOn})]);

	} elsif (!$large_check || $this_exists) {
		my $order = '';
		$order = 'order by deletionState' if ($table{$type} =~ /^(stars|planets|systems)$/);
		$order = 'order by deletionState,id64' if ($table{$type} eq 'systems');

		if ($edsm_use_names && !@$rows && $$href{name}) {
			$rows = rows_mysql($db,"select * from $table{$type} where name=? $order",[($$href{name})]);
		}

		if (!@$rows && $type eq 'station' && $$href{marketID}) {
			$rows = rows_mysql($db,"select * from $table{$type} where marketID=? $order",[($$href{marketID})]);  # for stations only
		}

		if (!@$rows && $type eq 'system' && $$href{id64}) {
			$rows = rows_mysql($db,"select * from $table{$type} where id64=? $order",[($$href{id64})]);  # for systems only
		}

		if (!@$rows && $type =~ /^(planet|star|barycenter)$/ && $$href{bodyId64}) {
			$rows = rows_mysql($db,"select * from $table{$type} where bodyId64=? $order",[($$href{bodyId64})]);  # for bodies only

			if (@$rows > 1 && defined($$href{name}) && $type =~ /^(planet|star)$/) {
				# Duplicate BODY IDs
				$rows = rows_mysql($db,"select * from $table{$type} where bodyId64=? and name=? $order",[($$href{bodyId64},$$href{name})]);
			}
		}

		if (!@$rows && $type =~ /^(planet|star|barycenter|stations)$/ && $$href{edsmID}) {
			$rows = rows_mysql($db,"select * from $table{$type} where edsmID=? $order",[($$href{edsmID})]);  # for bodies/stations only
		}

		if (!@$rows && $type eq 'system' && $$href{edsm_id}) {
			$rows = rows_mysql($db,"select * from $table{$type} where edsm_id=? $order",[($$href{edsm_id})]);  # for systems only
		}

		if (!@$rows && $type eq 'planet' && $$href{planetID}) {
			$rows = rows_mysql($db,"select * from $table{$type} where planetID=? $order",[($$href{planetID})]);  # for planets only
		}

		if (!@$rows && $type eq 'star' && $$href{starID}) {
			$rows = rows_mysql($db,"select * from $table{$type} where starID=? $order",[($$href{starID})]);  # for stars only
		}

		if (!@$rows && $type eq 'barycenter' && $$href{ID}) {
			$rows = rows_mysql($db,"select * from $table{$type} where ID=? $order",[($$href{ID})]);  # for barycenter only
		}

		if (!@$rows && $type =~ /^(star|planet|system)$/ && $$href{name} && $field64 && !$$href{$field64}) {
			# Only permit this check if we don't have an id64, and existing row has no id64 either.

			$rows = rows_mysql($db,"select * from $table{$type} where name=? and $field64 is null $order",[($$href{name})]);
			if (@$rows != 1) {
				@$rows = ();
			}
		}

		if (!@$rows && $$href{$key}) {	# Failing the above, we use the actual key, if it has been provided
			$rows = rows_mysql($db,"select * from $table{$type} where $key=? $order",[($$href{$key})]);

		} elsif (!$edsm_use_names && !@$rows && $$href{name} && $field64 && !$$href{$field64} && $type ne 'barycenter') {	
			# check name last when no key is found, unless edsm_use_names=true, in which case we check it first (above)
			# Only permit this check if we don't have an id64, and existing row has no id64 either.

			$rows = rows_mysql($db,"select * from $table{$type} where name=? and $field64 is null $order",[($$href{name})]);
		} 

		if (!@$rows && $$href{name} && $field64 && $$href{$field64} && $type ne 'barycenter') { 
			# If ALL of the above has failed, and we have an id64, look by name for a row that has no id64:

			$rows = rows_mysql($db,"select * from $table{$type} where name=? and $field64 is null $order",[($$href{name})]);
		} 
	}

	if (0 && @$rows) {
		foreach my $r (@$rows) {
			warn Dumper($r)."\n\n";
		}
	}

	# Sector info

	if ($type eq 'system' && $$href{id64} && !$$href{sectorID}) {
		my ($x,$y,$z) = id64_sectorcoords($$href{id64});

		if (!$$href{sectorID}) {
			my @sec = db_mysql($db,"select ID,id64sectorID from sectors where sector_x=? and sector_y=? and sector_z=? order by name limit 1",[($x,$y,$z)]);
			foreach my $s (@sec) {
				$$href{sectorID} = $$s{ID};
				my $id64sectorID = id64_sectorID($$href{id64});

				if (!$$s{id64sectorID} || ($id64sectorID && $id64sectorID!=$$s{id64sectorID})) {
					db_mysql($db,"update sectors set id64sectorID=? where ID=?",[($id64sectorID,$$s{ID})]);
				}
			}
		}
		if (!$$href{sectorID} && $$href{name} =~ /^([\w\s]+)\s+([A-Z][A-Z]\-[A-Z]\s+[a-z])/) {
			my $sector_name = btrim($1);
			my $code = $2;
			my $id64sectorID = id64_sectorID($$href{id64});

			if ($sector_name !~ /\s(Region|Sector)\s*$/i && $sector_name !~ /^[A-Z ]+$/ && $sector_name !~ /^[A-Z][a-z]+\d+/) {
				my @sec = db_mysql($db,"select ID,id64sectorID from sectors where name=? and sector_x=? and sector_y=? and sector_z=?",[($sector_name,$x,$y,$z)]);
				if (@sec) {
					$$href{sectorID} = ${$sec[0]}{ID};
				} elsif ($code !~ /AA-A [gh]/) {
					$$href{sectorID} = log_mysql($db,"insert into sectors (name,id64sectorID,sector_x,sector_y,sector_z,created) values (?,?,?,?,?,NOW())",[($sector_name,$id64sectorID,$x,$y,$z)]);
				}
			}
		}
	}

	# parents
	if ($type =~ /^(planet|star|barycenter)$/) {
		if (ref($$href{parents}) eq 'ARRAY') {
			my @parents = ();
			foreach my $r (@{$$href{parents}}) {
				foreach my $k (keys %$r) {
					push @parents, "$k:$$r{$k}";
				}
			}

			$$href{parents} = join(';',@parents);
		}
	}

	if (@$rows && $date_check && $date_field && $allow_updates && !$force_updates) {
		if (${$$rows[0]}{$date_field} && date2epoch($date_check) < date2epoch(${$$rows[0]}{$date_field})) {
			print "! Cannot update newer entry with older data [$identification] '$$href{name}'\n" if ($edsm_verbose || $edsm_debug);
			return;
		}
	}

	if (@$rows && !$allow_updates && !$force_updates) {
		print "! Changes not permitted for [$identification] '$$href{name}'\n" if ($edsm_verbose || $edsm_debug);

	} else {
		my %tabledata = ();
		if (@$rows) {
			%tabledata = %{$$rows[0]};
		}
		

		# Update or Insert as needed:

		my $action_taken = '';
		my $index_value = '';
		eval {
			my $tempkey = $key;
			$tempkey = 'name' if (!$tabledata{$key} && $tabledata{name});
			$tempkey = 'id64' if (!$tabledata{$key} && $tabledata{id64});

			if ($type eq 'codex_edsm') {
				$tempkey = 'id';
				$$href{$tempkey} = $tabledata{$tempkey} if ($tabledata{$tempkey});
			}
			
			($action_taken,$index_value) = update_table($db,$table{$type},$tempkey,$columns{$type},$href,\%tabledata);
		};


		# Track for future instances of the same object:

		add_object($type,$$href{$key});


		# If it's a star or planet, there may be additional sub-tables to deal with:


		if (!$action_taken && !$force_updates && !$allow_updates) {
			# Do nothing

		} elsif ($type eq 'planet') {
			# Update materials and atmospheres

			my $parentKeyval  = $tabledata{planetID};
			$parentKeyval = $index_value if ($index_value);

			my $edsmID = $$href{edsmID};
			$edsmID = $tabledata{edsmID} if (!$edsmID && $tabledata{edsmID});

			if ($parentKeyval) { foreach my $k (qw(materials atmospheres)) {
				if (ref($$href{$k}) ne 'HASH') {
					%{$$href{$k}} = ();
				}
				my @list  = keys %{$$href{$k}};
				my $rows2; @$rows2 = (); 

				$rows2 = rows_mysql($db,"select * from $k where planet_id=?",[($parentKeyval)]) 
					if ($force_updates || $allow_updates || $action_taken eq 'update');

				if (($allow_updates || $force_updates) && @$rows2 && @list) {

					# Both exist, do update maybe

					my @vals = ();
					my $update = '';
					
					foreach my $m (@list) {
						if (different(${$$rows2[0]}{dbMaterialName($m)},$$href{$k}{$m})) {
							push @vals, $$href{$k}{$m};
							$update .= ",".dbMaterialName($m)."=?";
						}
					}
					$update =~ s/^,//;

					if ($update) {
						#push @vals, $$href{$key};
						#col_mysql(\@list,$k,'planet_id','float',$db,"update $k set $update where planet_id=?",[(@vals)]);

						push @vals, $parentKeyval;
						$update .= ",planet_id=?";
						$update =~ s/^,//;

						push @vals, ${$$rows2[0]}{id};
						col_mysql(\@list,$k,'planet_id','float',$db,"update $k set $update where id=?",[(@vals)]);
					}

				} elsif (!@$rows2 && @list) {

					# Do insert

					my @vals = ();
					my ($vars, $ques) = ('','');

					#push @vals, $$href{$key};
					push @vals, $parentKeyval;
					
					foreach my $m (@list) {
						push @vals, $$href{$k}{$m};
						$vars .= ",".dbMaterialName($m);
						$ques .= ",?";
					}


					col_mysql(\@list,$k,'planet_id','float',$db,"insert into $k (planet_id$vars) values (?$ques)",[(@vals)]);

				} elsif (($allow_updates || $force_updates) && @$rows2 && !@list) {

					# Do delete
					col_mysql(\@list,$k,'planet_id','float',$db,"delete from $k where planet_id=?", [($parentKeyval)]);

				} # else do nothing, if neither exist, etc.
			} } else {
				print "! Could not find primary key value for $type '$$href{name}'\n" if ($edsm_verbose || $edsm_debug);
			}
		}

		if (!$action_taken && !$force_updates && !$allow_updates) {
			# Do nothing

		} elsif ($type =~ /^(planet|star)$/) { 
			foreach my $rtype (keys %{$ringtype{$type}}) {

				# Update rings
				my $ring_t = $table{$rtype};
				my @list   = ();
				my %hash   = ();
				my $rows2; @$rows2 = ();
				my $isStar = 0; $isStar = 1 if ($type eq 'star');
	
				my $parentKeyname = 'planetID';
				$parentKeyname = 'starID' if ($type eq 'star');
				my $parentKeyval  = $tabledata{$parentKeyname};
				$parentKeyval = $index_value if ($index_value);

				my $edsmID = $$href{edsmID};
				$edsmID = $tabledata{edsmID} if (!$edsmID && $tabledata{edsmID});

				if (!$parentKeyval) {
					print "! Cannot determine parent object's key value for $rtype! $$href{name} ($tabledata{$parentKeyname},$index_value)\n";
					next;
				}

				$rows2 = rows_mysql($db,"select * from $ring_t where planet_id=? and isStar=?", [($parentKeyval,$isStar)])
						if ($allow_updates || $force_updates || $action_taken eq 'update');

				foreach my $r2 (@$rows2) {
					if ($$r2{name} =~ /([A-Z])\s+(Ring|Belt)\s*$/i) {
						print "FOUND RING: ".uc($1)." = ($$r2{planet_id}) $$r2{name}\n" if ($edsm_verbose || $edsm_debug);
						%{$hash{uc($1)}} = %$r2;
					}
				}
	
				if (ref($$href{$ring_t}) eq 'ARRAY') {	# The hash shares the DB name in this case, not the "rtype"
					@list = @{$$href{$ring_t}};
				}
	
				foreach my $ring (@list) {
					$$ring{planet_id} = $parentKeyval;
					$$ring{isStar} = $isStar;
	
					my $cname   = uc($$ring{name});
					if ($$ring{name} =~ /([A-Z])\s+(Ring|Belt)\s*$/i) {
						$cname = uc($1);
					}
					my $dbhash; %$dbhash = ();
					if (ref($hash{$cname}) eq 'HASH') {
						$dbhash = $hash{$cname};
					}
	
					if ((($allow_updates || $force_updates) && $$dbhash{name}) || !$$dbhash{name}) {

						update_table($db,$ring_t,$typekey{$rtype},$columns{$rtype},$ring,$dbhash,$typekey2{$rtype});
					}
	
					delete($hash{$cname});
				}
	
				foreach my $n (keys %hash) {
					do_mysql($db,"delete from $ring_t where id=?",[($hash{$n}{id})]);
				}
			}
		}
	}
}

sub update_table {
	my ($udb,$table,$key,$columns,$sref,$tref,$key2) = @_;

	my $action_taken = '';
	my $index_value = undef;

	my %source = %$sref;
	my %target = %$tref;

	print "update_table [$edsm_debug/$edsm_verbose] $udb,$table,$key\n";

	#print 'Source: '.Dumper($sref)."\n\n";
	#print 'Target: '.Dumper($tref)."\n\n";

	#print "NON-ZERO: ".join(',',keys %nonzero)."\n";
	#print "NON-NULL: ".join(',',keys %nonnull)."\n";
	#print "NON-NEGATIVE: ".join(',',keys %nonnegative)."\n";
	#print "ADD DECIMALS: ".join(',',keys %add_decimal)."\n";

	if ($target{$key}) {
		# Do an update
		
		my $update  = '';
		my @params  = ();
		my $changes = 0;
		my $changecoords = 0;
		
		load_mappings() if (!keys %atmo_map);

		# Sanity check, in case it contains raw journal strings:

		if (0) {
		if ($table eq 'stars' && $source{subType} && $star_map{$source{subType}}) {
			if ($source{subType} =~ /^D/) {
				$source{subType} = 'White Dwarf ('.$source{subType}.') Star' 
			} else {
				$source{subType} = $star_map{$source{subType}};
			}

		}
		if ($table eq 'planets' && $source{subType} && $planet_map{$source{subType}}) {
			$source{subType} = $planet_map{$source{subType}};
			$source{volcanismType} = $volc_map{$source{volcanismType}} if ($source{volcanismType} && $volc_map{$source{volcanismType}});
			$source{atmosphereType} = $atmo_map{$source{atmosphereType}} if ($source{atmosphereType} && $atmo_map{$source{atmosphereType}});
			$source{terraformingState} = $terr_map{$source{terraformingState}} if ($source{terraformingState} && $terr_map{$source{terraformingState}});
		}
		}

		foreach my $f (@$columns) {
#print "$f: $source{$f} <> $target{$f}\n";
			if (exists($source{$f}) && $target{$f} ne $source{$f} && $f ne $key && (!$key2 || $f ne $key2)) {
				
				# Special rules for distanceToArrival, don't replace a float with an integer
				next if ($f =~ /^distanceToArrival(LS)?$/ && $source{$f}==floor($source{$f}) && $source{$f}>=$target{$f}-1 && $source{$f}<=$target{$f}+1);
				next if ($f =~ /^distanceToArrival(LS)?$/ && $source{$f}==floor($source{$f}) && $target{$f}!=floor($target{$f}) && $target{$f}>0);
				# Don't overwrite it with a zero, if it's already non-zero.
				next if ($f =~ /^distanceToArrival(LS)?$/ && !$source{$f} && defined($source{$f}) && $target{$f}>0);

				# Check that we're not overwriting with a zero for some fields
				next if ($nonzero{$f} && $source{$f}+0 == 0);
				next if ($nonnegative{$f} && $source{$f}+0 < 0);
				next if ($nonnull{$f} && (!defined($source{$f}) || $source{$f} eq ''));
				next if ($nonnull_blankOK{$f} && !defined($source{$f}));

				next if (!$source{$f} && $f =~ /updateTime|date|updated|created/i);
				next if (($f eq 'edsm_id' || $f eq 'edsmID' || $f eq 'systemId') && !$source{$f});
				next if ($f eq 'spectralClass' && (!$source{$f} || $source{$f} !~ /\d/) && $target{$f} =~ /\d/);

				if ($table eq 'codex_edsm' && $f eq 'reportedOn' && (!$source{$f} || $source{$f} lt '2014-01-01 00:00:00' || $source{$f} !~ /^\d{4}-\d{2}-\d{2}/) && ($target{$f} =~ /^\d{4}-\d{2}-\d{2}/ && $target{$f} gt '2014-01-01 00:00:00')) {
					$source{$f} = $target{$f}; # Don't change reported date if new one is newer/empty/invalid
				}

				if ($f eq 'updateTime' && $table =~ /planets|stars|systems/ && $source{$f} =~ /\d{4}-\d{2}-\d{2}/ && (!$target{edsm_date} || $source{$f} lt $target{edsm_date})) {
					$update .= ",edsm_date=?";
					push @params, $source{$f};
					$changes++;
				}

				$update .= ",$f=?";
				push @params, $source{$f};

				if (($table eq 'stars' || $table eq 'planets') && $add_decimal{$f}) {
					$update .= ",$f"."Dec=?";
					push @params, $source{$f};
				}

				if ($table =~ /^(planets|stars|barycenters)$/ && $f eq 'meanAnomaly' && $source{$f}) {
					my $date = $source{meanAnomalyDate};
					$date = $source{updateTime} if (!$date);

					if ($date) {
						$update .= ",meanAnomalyDate=?";
						push @params, $date;
					}
				}

				if ($table eq 'systems' && defined($source{coord_x}) && defined($source{coord_z})) {
					my $regID = findRegion($source{coord_x},$source{coord_y},$source{coord_z});
					if ($regID && (!$target{region} || $regID!=$target{region})) {
						$update .= ",region=?";
						push @params, $regID;
					}
				}

				if ($table eq 'systems' && $f eq 'id64' && $source{id64}) {
					my ($massID,$boxID,$boxnum) = id64_subsector($source{id64},1);
					my $sectorID = id64_sectorID($source{id64});

					$update .= ",id64sectorID=?,id64mass=?,id64boxelID=?,id64boxelnum=?";
					push @params, ($sectorID,$massID,$boxID,$boxnum);
				}

				$changes++ if ($changes || (!$target{$f} && $source{$f}) || ($f !~ /^coord_(x|y|z)$/ && $source{$f} !~ /\./) || different($target{$f},$source{$f}));
					# Only update if we already have valid changes, or find something that is 
					# overwriting a zero/null, or the change is over 5%, or is a non-coordinate 
					# field without a decimal. 
				$changecoords = 1 if ($f =~ /coord_/);
			}
		}

		if ($allow_bodyID_deletion && $table =~ /^(planets|stars|barycenters)$/ && !$source{bodyId64} && $target{bodyId64} && $update !~ /bodyId64/) {
			$update .= ",bodyId64=?";
			push @params, undef;
		}

		if ($table eq 'systems' && $changecoords) {
			$update .= ",sol_dist=?";
			push @params, sqrt($source{coord_x}**2 + $source{coord_y}**2 + $source{coord_z}**2);
		}

		if (($table eq 'systems' and $source{id64}) || ($table =~ /^(stars|planets|barycenters)$/ && $source{bodyId64} && $source{systemId64})) {	
			$update .= ",deletionState=?";
			push @params, 0;
		}

		
		$update =~ s/^,//;

		my $where = "$key=?";
		push @params, $target{$key};
		
		if ($changes) {
			my $sql = "update $table set $update where $where";
			print "$udb: $sql [".join(',',@params)."]\n" if ($edsm_verbose || $edsm_debug);
			rows_mysql($udb,$sql,\@params) if (!$edsm_debug);

			$action_taken = 'update';

			if ($source{systemId64} && $table =~ /^(stars|planets|barycenters)$/) {
				eval {
					log_mysql('elite',"update systems set complete=null where id64=? and complete is not null and complete=0",[($source{systemId64})]);
				};
			}
		} else {
			print "\tNo changes.\n" if ($edsm_verbose || $edsm_debug);
		}
	
	} else {
		# Do an insert

		if ($table =~ /^(stars|planets)$/ && $source{systemId64}) {
			reset_system_trackers($source{systemId64});
		}
		
		my $vars = my $vals = '';
		my @params = ();
		
		push @params, $source{$key};
		
		foreach my $f (@$columns) {
			if (($source{$f} || $source{$f} eq '0' || $source{$f} eq '0.0') && $f ne $key) {
				$vars .= ",$f";
				$vals .= ",?";
				push @params, $source{$f};

				if (($table eq 'stars' || $table eq 'planets') && $add_decimal{$f}) {
					$vars .= ",$f"."Dec";
					$vals .= ",?";
					push @params, $source{$f};
				}

				if ($table =~ /^(planets|stars|barycenters)$/ && $f eq 'meanAnomaly' && $source{$f}) {
					my $date = $source{meanAnomalyDate};
					$date = $source{updateTime} if (!$date);

					if ($date) {
						$vars .= ",meanAnomalyDate";
						$vals .= ",?";
						push @params, $date;
					}
				}
			}
		}

		if ($table =~ /^(systems|planets|stars|barycenters)$/) {
			if ($source{updateTime}) {
				$vars .= ",edsm_date";
				$vals .= ",?";
				push @params, $source{updateTime};
			}
		}
		if ($table =~ /^(systems|planets|stars|barycenters|stations)$/) {
			$vars .= ",date_added";

			if ($source{updateTime}) {
				$vals .= ",?";
				push @params, $source{updateTime};
			} elsif ($source{edsm_date}) {
				$vals .= ",?";
				push @params, $source{edsm_date};
			} else {
				$vals .= ",NOW()";
			}
		}

		if ($table eq 'systems' && $source{id64}) {
			my ($massID,$boxID,$boxnum) = id64_subsector($source{id64},1);
			my $sectorID = id64_sectorID($source{id64});
			$vars .= ",id64sectorID,id64mass,id64boxelID,id64boxelnum";
			$vals .= ",?,?,?,?";
			push @params, ($sectorID,$massID,$boxID,$boxnum);
		}

		if ($table eq 'systems') {
			$vars .= ",day_added";

			if ($source{updateTime}) {
				$vals .= ",cast(? as date)";
				push @params, $source{updateTime};
			} elsif ($source{edsm_date}) {
				$vals .= ",cast(? as date)";
				push @params, $source{edsm_date};
			} else {
				$vals .= ",NOW()";
			}

			if (defined($source{coord_x}) && defined($source{coord_y}) && defined($source{coord_z})) {
				$vars .= ",sol_dist";
				$vals .= ",?";
				push @params, sqrt($source{coord_x}**2 + $source{coord_y}**2 + $source{coord_z}**2);
			}

			if ($source{id64}) {
				$vars .= ",masscode";
				$vals .= ",?";
				push @params, chr(ord('a')+($source{id64} & 7));
			}

			if (defined($source{coord_x}) && defined($source{coord_z})) {
				my $regID = findRegion($source{coord_x},$source{coord_y},$source{coord_z});
				if ($regID) {
					$vars .= ",region";
					$vals .= ",?";
					push @params, $regID;
				}
			}

		}

		$vars =~ s/^,//;
		$vals =~ s/^,//;
		
		if ($vars && $vals) {
			
			my $sql = '';
			if (!$skipkey{$table} || $key ne $skipkey{$table}) {
				$sql = "insert into $table ($key,$vars) values (?,$vals)";
			} else {
				$sql = "insert into $table ($vars) values ($vals)";
				shift @params;
			}

			print "$udb: $sql [".join(',',@params)."]\n" if ($edsm_verbose || $edsm_debug);
			$index_value = rows_mysql($udb,$sql,\@params) if (!$edsm_debug);

			$action_taken = 'insert';

			if ($source{systemId64} && $table =~ /^(stars|planets|barycenters)$/) {
				eval {
					log_mysql('elite',"update systems set complete=null where id64=? and complete is not null and complete=0",[($source{systemId64})]);
				};

				update_systemcounts($source{systemId64});
			}
		} else {
			print "\tNothing to do.\n" if ($edsm_debug);
		}
	}

	return ($action_taken,$index_value);
}

sub import_field {
	my ($outref,$outfield,$inref,$infield,$index) = @_;

	return if (ref($outref) ne 'HASH' || ref($inref) ne 'HASH');

	if ($infield =~ /(\S+)\/(\S+)/) {
		if (defined($$inref{$1}{$2}) && !ref($$inref{$1}{$2})) { 
			$$outref{$outfield} = $$inref{$1}{$2};
		} elsif (defined($$inref{$1}{$2}) && ref($$inref{$1}{$2}) eq 'ARRAY') {
			$$outref{$outfield} = ${$$inref{$1}{$2}}[$index];
		}
	} else {
		if (defined($$inref{$infield}) && !ref($$inref{$infield})) {
			$$outref{$outfield} = $$inref{$infield};
		} elsif (defined($$inref{$infield}) && ref($$inref{$infield}) eq 'ARRAY') {
			$$outref{$outfield} = ${$$inref{$infield}}[$index];
		}
	}

	#$$outref{$outfield} = decode("UTF-8", $$outref{$outfield});
	#$$outref{$outfield} =~ s/[^\s\w\d\-\_\+\.\(\)\,\*\!\@\#\$\%\^\&\=\~\<\>\\\/\?\[\]\{\}]+//gs;
}

sub import_directly {
	my ($outref,$inref,$infield) = @_;
	return import_field($outref,$infield,$inref,$infield);
}

sub col_mysql {
	my $listref	= shift;
	my $table	= shift;
	my $key		= shift;
	my $datatype	= shift;
	my @sql		= @_;
	my $ok		= 0;

	eval {
		rows_mysql(@sql) if (!$edsm_debug);
		$ok = 1;
	};

	if (!$ok || $edsm_debug) {
		# Fix columns, add missing, alphabetical order

		my $rows = rows_mysql($db,"SELECT `COLUMN_NAME` FROM `INFORMATION_SCHEMA`.`COLUMNS` WHERE `TABLE_SCHEMA`='$db' AND `TABLE_NAME`='$table'");
		if (!@$rows) {
			# borked, can't fix it
			return;
		}

		my %hash = ();
		my %elements = ();

		foreach my $r (@$rows) {
			next if ($$r{COLUMN_NAME} eq $key);
			$hash{$$r{COLUMN_NAME}} = 1;
			$elements{$$r{COLUMN_NAME}} = 1;
		}

		foreach my $mat (@$listref) {
			$elements{dbMaterialName($mat)} = 1;
		}
		my @elems = sort { $a cmp $b } keys %elements;

		my $i = 0;
		foreach my $mat (@elems) {
			my $after = " after $key";

			if ($i > 0) {
				$after = " after `".$elems[$i-1]."`";
			}

			if (!$hash{$mat}) {
				eval {
					rows_mysql($db,"alter table $table add column `$mat` $datatype $after");
				};
			}

			$i++;
		}

		# Try again

		eval {
			do_mysql(@sql) if (!$edsm_debug);
			$ok = 1;
		};
	}

	return $ok;
}

sub dbMaterialName {
	my $name = lc(shift);
	$name =~ s/\s+//gs;
	$name =~ s/[^\w\d\_]+//gs;
	return $name;
}

sub do_mysql {
	my $db	= shift;
	my $sql	= shift;

	print "$db: $sql [".join(',',@_)."]\n" if ($edsm_verbose || $edsm_debug);
	rows_mysql($db,$sql,[(@_)]) if (!$edsm_debug);
}

sub add_object {
	return if ($_[0] eq 'codex_edsm');
	$obj_exists{$_[0]}{$_[1]} = $_[2];
}

sub object_exists {
	return $obj_exists{$_[0]}{$_[1]};
}

sub object_newer {
	my ($type, $id, $date) = @_;
	return 1 if ($date && $date gt $obj_exists{$type}{$id});
	return 0;
}

sub dump_objects {
	%{$obj_exists{$_[0]}} = ();
}

sub load_objects {
	my $type = shift;
	my $key  = $typekey{$type};

	return if ($type eq 'codex_edsm');

	if ($type eq 'bodies' || $type eq 'body') {
		load_objects('planet');
		load_objects('star');
		return;
	}

	print "Loading list of $table{$type}.\n";
	my $rows = rows_mysql($db,"select $key,$datecolumn{$type} from $table{$type}");
	print int(@$rows)." $type rows read.\n";
	foreach my $r (@$rows) {
		add_object($type,$$r{$key},$$r{$datecolumn{$type}});
	}
	print "Keys generated ($type).\n";
}

sub different {
	my ($var1, $var2) = @_;
	my $diff = 0;

	#return 1 if ($force_updates);

	if ($var1 == $var2) {
		return 0;	
	}
	if (!$var1 || !$var2) {
		return 1;
	}

	if ($var1 > $var2) {
		$diff = ($var1 - $var2) / $var1;
	} else {
		$diff = ($var2 - $var1) / $var2;
	}
	$diff = 0 - $diff if ($diff < 0);

	return 1 if ($diff >= 0.05);
	return 0;
}

sub log10 {
	my $n = shift;
	return 0 if (!$n); # || $n<0);
	return log($n)/log(10);
}

sub letter_ord {
	return ord(shift)-ord('A');
}

sub load_sectors {
	my $file = shift;
	$file = "/home/bones/elite/scripts/sector-list-stable.csv" if (!$file);
	open SECTORCSV, "<$file";

	my %sector = ();

	while (<SECTORCSV>) {
		chomp;
		my ($s,$c,$x,$y,$z,$x1,$y1,$z1,$x2,$y2,$z2,$bx,$bz,@extra) = parse_csv($_);
		$sector{$s}{x} = floor(($x+ 65)/1280)*1280-65;
		$sector{$s}{y} = floor(($y+ 25)/1280)*1280-25;
		$sector{$s}{z} = floor(($z-215)/1280)*1280+215;
	}

	close SECTORCSV;

	return \%sector;
}

sub id64_to_name {
	my $id64 = shift;
	my ($masscode, $sub, $num) = id64_subsector($id64);
	my ($sx, $sy, $sz) = id64_sectorcoords($id64);
	my $sectorID = id64_sectorID($id64);

	my @rows = db_mysql('elite',"select name from sectors where (sector_x=? and sector_y=? and sector_z=?) or id64sectorID=?",[($sx,$sy,$sz,$sectorID)]);

	if (@rows) {
		my $name = ${$rows[0]}{name};
		
		my $wrap_amount = 26**3;
		my $wrap_num = floor($sub/$wrap_amount);
		
		$sub = $sub % $wrap_amount;
		
		my $l1 = chr(ord('A') + ($sub % 26));
		$sub = floor($sub/26);
		my $l2 = chr(ord('A') + ($sub % 26));
		$sub = floor($sub/26);
		my $l3 = chr(ord('A') + ($sub % 26));
		
		my $insert = '';
		$insert = $wrap_num . '-' if ($wrap_num);
		
		$name = "$name $l1$l2-$l3 $masscode$insert$num";
		return $name;
	}
	return undef;
}

sub id64_subsector {
	my $id64 = shift;
	my $numeric_masscode = shift;
	# http://disc.thargoid.space/ID64

	my $masscode = $id64 & 7;
	my $boxbits = 7 - $masscode;
	my $boxmask = (1<<$boxbits)-1;

	my $sub = 0;
	$sub = (($id64 >> ($boxbits*2+16)) & $boxmask) | ((($id64 >> ($boxbits+10)) & $boxmask)<<7) | ((($id64 >> 3) & $boxmask)<<14) if ($boxbits); # otherwise h-mass = 0

	my $num = ($id64 & 0x7FFFFFFFFFFFFF) >> (23 + 3*$boxbits);

	if ($numeric_masscode) {
		return ($masscode,$sub,$num);
	}
	return (chr(ord('a')+$masscode),$sub,$num);
}

sub id64_sectorcoords {
	my $id64 = shift;
	# http://disc.thargoid.space/ID64

	my $masscode = $id64 & 7;
	my $bitshift = 7-$masscode;	# inverse mass code

	my $x = 127 & ($id64 >> (16 + $bitshift*3)); 
	my $y = 63  & ($id64 >> (10 + $bitshift*2)); 
	my $z = 127 & ($id64 >> (3 + $bitshift)); 

	return ($x,$y,$z,$masscode);
}

sub id64_sectorID {
	my $id64 = shift;
	return undef if (!$id64);
	my ($x,$y,$z,undef) = id64_sectorcoords($id64);
	return $x << 13 | $y < 7 | $z;
}

sub estimated_coordinates64 {
	my $id64 = shift;
	
	my $galaxy_center_x = -65;
	my $galaxy_center_y = -25;
	my $galaxy_center_z = 25815;
	my $sectoroffset_z  = -1065;

	my ($masscode,$subsector,$num) = id64_subsector($id64);

	my $bitcount = letter_ord(uc($masscode));
	my $size = 1 << $bitcount;
	my $width = 128 >> $bitcount;

	# Uses fixed bit widths for non-contiguous boxel lettering:
	my $mask = 127;
	my $shiftbits = 7;

	# Coords within the boxel, 10ly resolution
	my $x = 10 * ($subsector & $mask)*$size;
	my $y = 10 * (($subsector >> $shiftbits) & $mask)*$size;
	my $z = 10 * (($subsector >> ($shiftbits*2)) & $mask)*$size;

	my ($sx,$sy,$sz,$mc) = id64_sectorcoords($id64);

	$sx -= 39; 
	$sy -= 32;
	$sz -= 18;

	my $error = $size * 5;
	my $ex = $sx*1280 + $x + $error + $galaxy_center_x;
	my $ey = $sy*1280 + $y + $error + $galaxy_center_y;
	my $ez = $sz*1280 + $z + $error + $sectoroffset_z;

	#print "$id64 = $ex, $ey, $ez (+/- $error)\n";
	return ($ex, $ey, $ez, $error, $x+$error, $y+$error, $z+$error);
}

sub estimated_coords {
	my $name = shift;
	my $sector = shift;
	my $id64;

	my $subsector = 0;
	my ($sectorname,$l1,$l2,$l3,$masscode,$n) = ();
	if ($name =~ /^(.*\S)\s+([A-Z])([A-Z])\-([A-Z])\s+([a-z])(\d*)\-\d+/i) {
		($sectorname,$l1,$l2,$l3,$masscode,$n) = ($1,$2,$3,$4,$5,$6);
	} elsif ($name =~ /^(.*\S)\s+([A-Z])([A-Z])\-([A-Z])\s+([a-z])(\d*)$/i) {
		($sectorname,$l1,$l2,$l3,$masscode,$n) = ($1,$2,$3,$4,$5,0);
	}

	return (undef,undef,undef) if (!$sectorname || !exists($$sector{$sectorname}));

	if ($sectorname && $l1 && $l2 && $l3 && $masscode) {
		$subsector = ($n*17576) + (letter_ord(uc($l3))*676) + (letter_ord(uc($l2))*26) + letter_ord(uc($l1));
	}

	my $bitcount = letter_ord(uc($masscode));
	my $size = 1 << $bitcount;
	my $width = 128 >> $bitcount;
	my $brightness = 8-$bitcount;
	$brightness = 1 if ($brightness < 1);

	## Assumes boxel lettering wraps and continues:
	#my $mask = $width-1;
	#my $shiftbits = $bitcount;

	# Uses fixed bit widths for non-contiguous boxel lettering:
	my $mask = 127;
	my $shiftbits = 7;

	my $x = ($subsector & $mask)*$size;
	my $y = (($subsector >> $shiftbits) & $mask)*$size;
	my $z = (($subsector >> ($shiftbits*2)) & $mask)*$size;

	my $est_x = $$sector{$sectorname}{x} + ($x*10) + ($size*5);
	my $est_y = $$sector{$sectorname}{y} + ($y*10) + ($size*5);
	my $est_z = $$sector{$sectorname}{z} + ($z*10) + ($size*5);

	return ( $est_x, $est_y, $est_z, $width, $size );

}

sub system_coordinates {
	my $sys = btrim(shift);
	$sys =~ s/\s+/ /gs;

	my $galaxy_center_x = -65;
	my $galaxy_center_y = -25;
	my $galaxy_center_z = 25815;
	my $sectoroffset_z  = -1065;

	my ($x,$y,$z,$error,$id64) = ();
	my @rows = ();

	if ($sys =~ /^\s*(\d+)\s*$/) {
		# Must be id64

		($x,$y,$z,$error) = estimated_coordinates64($1);
		@rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where id64=?",[($1)]);
	} else {
		# Assume name instead

		@rows = db_mysql('elite',"select coord_x,coord_y,coord_z,id64 from systems where name=?",[($sys)]);
	}

	if (@rows) {
		if (defined(${$rows[0]}{coord_x}) && defined(${$rows[0]}{coord_y}) && defined(${$rows[0]}{coord_z})) {
			$x = ${$rows[0]}{coord_x};
			$y = ${$rows[0]}{coord_y};
			$z = ${$rows[0]}{coord_z};
			$error = undef;

		} elsif (${$rows[0]}{id64} =~ /^\s*(\d+)\s*$/) {		# May have gotten ID64 above without coordinates
			($x,$y,$z,$error) = estimated_coordinates64($1);
		}
	} elsif ($sys =~ /^\s*(\S[\s\w\'\-]+?)\s+[A-Za-z][A-Za-z]\-[A-Za-z]\s+[A-Za-z]\d+/i) {	# Proc-gen name
		my $secname = btrim(uc($1));
		my %sechash = ();

		open SECTORCSV, "</home/bones/elite/scripts/sector-list-stable.csv";
		while (<SECTORCSV>) {
			chomp;
			my @v = parse_csv($_);
			my $sec = btrim(uc($v[0]));
			if ($sec eq $secname) {
				$sechash{$sec}{x} = floor(($v[2]-$galaxy_center_x)/1280)*1280 + $galaxy_center_x;
				$sechash{$sec}{y} = floor(($v[3]-$galaxy_center_y)/1280)*1280 + $galaxy_center_y;
				$sechash{$sec}{z} = floor(($v[4]-$sectoroffset_z)/1280)*1280 + $sectoroffset_z;
				($x,$y,$z,undef,$error) = estimated_coords(uc($sys),\%sechash);
				$error *= 5;
				last;
			}
		}
		close SECTORCSV;
	}
		
	return ($x,$y,$z,$error);
}


sub completion_report {
	my $sys = btrim(shift);
	my $boxel = '';
	my $sector = '';
	my $subsector = '';
	my $id64 = 0;
	my $sectorID = undef;
	my $boxelID = undef;
	my $massID = undef;

	my @sys = db_mysql($db,"select id64,s.id64sectorID,id64mass,id64boxelID,sectors.name from systems s,sectors where s.name=? and deletionState=0 and s.sectorID=sectors.ID limit 1",[($sys)]);
	if (@sys) {
		$id64 = ${$sys[0]}{id64};
		$sector = ${$sys[0]}{name};
		$subsector = $sector;
		$sectorID = ${$sys[0]}{id64sectorID};
		$boxelID = ${$sys[0]}{id64boxelID};
		$massID = ${$sys[0]}{id64mass};
	}

	if ($sys =~ /^\s*((([a-zA-Z0-9\-\_]+\s+)*)([A-Za-z][A-Za-z]\-[A-Za-z]\s+[A-Za-z]\d+))\-\d+\s*$/) {

		$boxel = $4;
		$subsector = $1;
		$sector = btrim($2);

	} elsif ($sys =~ /^\s*((([a-zA-Z0-9\-\_]+\s+)*)([A-Za-z][A-Za-z]\-[A-Za-z]\s+[A-Za-z]))\d+\s*$/) {

		$boxel = $4;
		$subsector = $1;
		$sector = btrim($2);
	}

	return (error=>'Not a valid system name') if (!$boxel || !$sector);

#print "Boxel: $boxel\n";

	my %hash = ();
	#tie %hash, "Tie::IxHash";
	$hash{boxel} = $boxel;
	$hash{sector} = $sector;
	$hash{subsector} = $subsector;
	$hash{highest} = 0;
	my $max = 0;

	my $rows = [()];

	my $subsec_safe = $subsector;
	$subsec_safe =~ s/(['"\\%_])/\\$1/gs;

	if (!$sectorID || !$massID || !$boxelID) {
		$rows = rows_mysql('elite',"select name,id64,bodyCount,numStars,numPlanets,complete,FSSprogress from systems where name like '$subsec_safe\%' and deletionState=0") if ($subsec_safe);
	} else {
		$rows = rows_mysql('elite',"select name,id64,bodyCount,numStars,numPlanets,complete,FSSprogress from systems where (name like '$subsec_safe\%' or (id64sectorID=? and id64mass=? and id64boxelID=?)) and deletionState=0",[($sectorID,$massID,$boxelID)]);
	}

	my @nav =  db_mysql('elite',"select max(id64boxelnum) as maxNum from navsystems where name like '$subsec_safe\%' and id64sectorID=? and id64mass=? and id64boxelID=?",[($sectorID,$massID,$boxelID)]);
	if (@nav) {
		$max = $hash{highest} = ${$nav[0]}{maxNum};
	}
	
	return (error=>'No data for boxel') if (!$rows || ref($rows) ne 'ARRAY' || !@$rows);

	my %found = ();

	foreach my $type (qw(unknown complete incomplete missing)) {
		@{$hash{$type}} = ();
	}

	foreach my $r (@$rows) {
		my ($masscode,$subsector,$num) = id64_subsector($$r{id64});
		next if ($found{$num});

		next if ($sector && $$r{name} =~ /\s[A-Z][A-Z]\-[A-Z]\s[a-z]/ && $$r{name} !~ /^$sector/i);

		if (!$$r{complete} && $$r{FSSprogress}>=1) {
		#if (1) {
			my @stars = db_mysql('elite',"select starID as ID from stars where systemId64=? and deletionState=0",[($$r{id64})]);
			my @planets = db_mysql('elite',"select planetID as ID from planets where systemId64=? and deletionState=0",[($$r{id64})]);
	
			if (int(@stars)+int(@planets) >= $$r{bodyCount}) {

				update_systemcounts($$r{id64});
				$$r{complete} = 1;
			}
		}


		$found{$num}=1;

#print "$num: $$r{name} ($$r{bodyCount} / $$r{complete})\n";

		$max = $num if ($num > $max);

		if ($$r{bodyCount} && $$r{complete} == 1) {

			push @{$hash{complete}}, $num;

		} elsif ($$r{bodyCount} && $$r{complete} != 1) {

			push @{$hash{incomplete}}, $num;

		} elsif (!$$r{bodyCount}) {

			push @{$hash{unknown}}, $num;

		}
	}

	$hash{highest} = $max;

	for (my $i=0; $i<=$max; $i++) {
		push @{$hash{missing}}, $i if (!$found{$i});
	}

	@{$hash{unknown}} = sort {$a <=> $b} @{$hash{unknown}} if (ref($hash{unknown}) eq 'ARRAY');
	@{$hash{complete}} = sort {$a <=> $b} @{$hash{complete}} if (ref($hash{complete}) eq 'ARRAY');
	@{$hash{incomplete}} = sort {$a <=> $b} @{$hash{incomplete}} if (ref($hash{incomplete}) eq 'ARRAY');

	return %hash;
}

sub update_systemcounts {
	my $id64 = shift;
	my $verbose = shift;
	return if !$id64;

	my @rows = db_mysql($db,"select count(*) as num from stars where systemId64=? and deletionState=0",[($id64)]);
	my $numstars = ${$rows[0]}{num};

	my @rows = db_mysql($db,"select count(*) as num from planets where systemId64=? and terraformingState='Candidate for terraforming' and deletionState=0",[($id64)]);
	my $numterra = ${$rows[0]}{num};

	my @rows = db_mysql($db,"select count(*) as num from planets where systemId64=? and isLandable=1 and deletionState=0",[($id64)]);
	my $numLandables = ${$rows[0]}{num};

#	my @rows = db_mysql($db,"select count(*) as num from planets where systemId64=? and deletionState=0",[($id64)]);
#	my $numplanets = ${$rows[0]}{num};
#
#	my @rows = db_mysql($db,"select count(*) as num from planets where systemId64=? and subType='Earth-like world' and deletionState=0",[($id64)]);
#	my $numELW = ${$rows[0]}{num};
#
#	my @rows = db_mysql($db,"select count(*) as num from planets where systemId64=? and subType='Ammonia world' and deletionState=0",[($id64)]);
#	my $numAW = ${$rows[0]}{num};
#
#	my @rows = db_mysql($db,"select count(*) as num from planets where systemId64=? and subType='Water world' and deletionState=0",[($id64)]);
#	my $numWW = ${$rows[0]}{num};

	my $rows = rows_mysql($db,"select distinct subType,count(*) as num from planets where systemId64=? and deletionState=0 group by subType",[($id64)]);
	my ($numplanets,$numELW,$numAW,$numWW) = (0,0,0,0);

	if (ref($rows) eq 'ARRAY' && int(@$rows)) {
		foreach my $r (@$rows) {
			$numplanets += $$r{num};
			$numELW += $$r{num} if ($$r{subType} =~ /Earth-like world/i);
			$numAW += $$r{num}  if ($$r{subType} =~ /Ammonia world/i);
			$numWW += $$r{num}  if ($$r{subType} =~ /Water world/i);
		}
	}

	print "$id64: Stars=$numstars, Planets=$numplanets, ELW=$numELW, AW=$numAW, WW=$numWW, Terra=$numterra\n" if ($verbose);

	db_mysql($db,"update systems set numStars=?,numPlanets=?,numELW=?,numAW=?,numWW=?,numTerra=?,numLandables=?,updated=updated where id64=? and ".
		"(numstars is null or numplanets is null or numELW is null or numAW is null or numWW is null or numTerra is null or numLandables is null or ".
		"numstars!=? or numplanets!=? or numELW!=? or numAW!=? or numWW!=? or numTerra!=? or numLandables!=?)",
			[($numstars,$numplanets,$numELW,$numAW,$numWW,$numterra,$numLandables,$id64,$numstars,$numplanets,$numELW,$numAW,$numWW,$numterra,$numLandables)]);

	my @rows = db_mysql($db,"select ID,bodyCount,complete,FSSprogress from systems where id64=? and deletionState=0",[($id64)]);

	foreach my $r (@rows) {
		if (!$$r{complete} && $$r{FSSprogress}>=1 && $numstars+$numplanets>=$$r{bodyCount}) {
			db_mysql($db,"update systems set complete=1,updated=updated where ID=?",[($$r{ID})]);
			
		}
	}
}


sub key_findcreate {
	my $table = shift;
	my $ugly_name = shift;
	my $pretty_name = shift;

	return key_findcreate_local($table,$ugly_name,$pretty_name,1);
}

sub key_findcreate_local {
	my $table = shift;
	my $ugly_name = shift;
	my $pretty_name = shift;
	my $skip_localization = shift;
	my $table2 = $table.'_local';
	my $IDname = $table.'ID';

	my $mainID = undef;
	my $localID = undef;

	return undef if (!$ugly_name);

	my @rows = db_mysql($db,"select id from $table where name=?",[($ugly_name)]);
	foreach my $r (@rows) {
		$mainID = $$r{id};
	}

	if (!$mainID) {
		$mainID = log_mysql($db,"insert into $table (name,date_added) values (?,NOW())",[($ugly_name)]);
	}

	return $mainID if (!$pretty_name || $skip_localization);

	my @rows = db_mysql($db,"select id from $table2 where $IDname=? and name=?",[($mainID,$pretty_name)]);
	foreach my $r (@rows) {
		$localID = $$r{id};
	}

	if (!$localID && $pretty_name && $pretty_name !~ /[^\s\w\d\|\-\_\+\=\\\/\[\]\{\}\(\)\<\>\,\.\?\'\"\;\:\!\~\`\!\@\#\$\%\^\&\*]/ && $pretty_name !~ /[^[:print:]]/) {
		$localID = log_mysql($db,"insert into $table2 (name,$IDname,date_added) values (?,?,NOW())",[($pretty_name,$mainID)]);
	}

	return $mainID;
}

sub codex_entry {
	my $href = shift;
	my %hash = %$href;
	my $skip_localization = shift;

	foreach my $v (qw(Name SubCategory Category)) {
		$hash{$v} =~ s/^\s*\$//;
		$hash{$v} =~ s/;\s*$//;
		$hash{$v} =~ s/_Name$//si;
		$hash{$v}  = lc ($hash{$v});
	}
#print "CODEX: $hash{Name} ($hash{SystemAddress})\n";

	return if (!$hash{Name} || !codex_ok($hash{Name}));

	$hash{Region} =~ s/[^\d]+//gs;
	$hash{regionID} = $hash{Region};
	$hash{timestamp} =~ s/T/ /;
	$hash{timestamp} =~ s/Z//;
	$hash{timestamp} =~ s/\.\d+\s*$//;
	$hash{reportedOn} = $hash{timestamp};

	if (exists($hash{odyssey}) && defined($hash{odyssey})) {
		$hash{odyssey} = $hash{odyssey} ? 1 : 0;
	}

	$hash{nameID}        = key_findcreate_local('codexname',$hash{Name},$hash{Name_Localised},$skip_localization);
	$hash{subcategoryID} = key_findcreate_local('codexsubcat',$hash{SubCategory},$hash{SubCategory_Localised},$skip_localization) if ($hash{SubCategory});
	$hash{categoryID}    = key_findcreate_local('codexcat',$hash{Category},$hash{Category_Localised},$skip_localization) if ($hash{Category});
	
	my @rows = ();

	@rows = db_mysql($db,"select * from codex where systemId64=? and nameID=?",[($hash{SystemAddress},$hash{nameID})]) if ($hash{SystemAddress}>=1000);

	if (!$hash{SystemAddress} || $hash{SystemAddress}<1000) {
		return if (!$hash{System});
		my @sys = db_mysql($db,"select id64 from systems where name=? and deletionState=0",[($hash{System})]);
		return if (!@sys);
		$hash{SystemAddress} = ${$sys[0]}{id64};
		@rows = db_mysql($db,"select * from codex where systemId64=? and nameID=?",[(${$sys[0]}{id64},$hash{nameID})]);
	} 

	$hash{systemId64} = $hash{SystemAddress};

	if (!$hash{regionID} && $hash{Region_Localised}) {
		my @reg = db_mysql($db,"select id from regions where name=?",[($hash{Region_Localised})]);
		foreach my $r (@reg) {
			$hash{regionID} = $$r{id};
		}
	}


#print "CODEX: $hash{Name} ($hash{SystemAddress}) ".int(@rows)."\n";
	my @list = qw(systemId64 regionID nameID subcategoryID categoryID reportedOn odyssey);

	my @params = ();
	my $upd = '';
	my $vars = '';
	my $vals = '';

	foreach my $v (keys %hash) {
		$hash{$v} = btrim($hash{$v}) if ($hash{$v} =~ /\s/);
	}
	foreach my $key (@list) {
		if ( ($key eq 'odyssey' && defined($hash{$key}) && $hash{$key} != ${$rows[0]}{$key}) ||
		    ($key ne 'reportedOn' && $hash{$key} && $hash{$key} ne ${$rows[0]}{$key}) ) {
			$upd .= ",$key=?";
			$vars .= ",$key";
			$vals .= ",?";
			push @params, $hash{$key};
		}
		if ($key eq 'reportedOn' && $hash{$key} =~ /^\d{4}-\d{2}-\d{2}/ && $hash{$key} gt '2014-01-01 00:00:00' && 
				(!${$rows[0]}{$key} || $hash{$key} lt ${$rows[0]}{$key})) {
			$upd .= ",$key=?";
			$vars .= ",$key";
			$vals .= ",?";
			push @params, $hash{$key};
		}
	}
	$upd =~ s/^,+//;
	$vars =~ s/^,+//;
	$vals =~ s/^,+//;

	return if (!@params);

	eval {
		if (@rows && ${$rows[0]}{id}) {
			# Do update
	
			push @params, ${$rows[0]}{id};
			log_mysql($db,"update codex set $upd where id=?",\@params);
		} else {
			# Do insert
	
			log_mysql($db,"insert into codex ($vars) values ($vals)",\@params);
		}
	};
}

sub codex_ok {
	my $name = lc(shift);
	$name =~ s/^\s*\$//;
	$name =~ s/;\s*$//;

	return 1 if ($name =~ /^codex_ent_green_/i);
	return 0 if ($name =~ /^codex_ent_gas_vents/i);
	return 0 if ($name =~ /_type(super|hyper)?(giant)?$/i);
	return 0 if ($name eq lc('codex_ent_neutron_stars') || $name eq lc('codex_ent_black_holes'));
	return 0 if ($name =~ /^codex_ent_icefumarole_/i || $name =~ /^codex_ent_icegeysers_/i || $name =~ /^codex_ent_gas_vents_/i);
	return 0 if ($name =~ /^codex_ent_geysers_/i || $name =~ /^codex_ent_fumarole_/i || $name =~ /^codex_ent_lava_spouts_/i);
	return 0 if ($name =~ /^codex_ent_trf_/i || $name =~ /^codex_ent_standard_/i);
	return 0 if ($name eq lc('codex_ent_supermassiveblack_holes'));
	return 0 if ($name eq lc('codex_ent_earth_likes'));

	return 1;
}

sub load_systemstrings {
	%systemstrings = ();

	my $rows = rows_mysql('elite',"select ID,string from systemstrings");
	foreach my $r (@$rows) {
		$systemstrings{$$r{string}} = $$r{ID};
	}
}

sub systemstrings_ID {
	my $s = shift;

	if (!exists($systemstrings{$s})) {
		# double-check:
		load_systemstrings();	# This also serves as the first load on script execution, since nothing is in the hash at that point

		if (!exists($systemstrings{$s})) {
			return log_mysql('elite',"insert into systemstrings (string,created) values (?,now())",[($s)]);
		} else {
			return $systemstrings{$s};
		}
	} else {
		return $systemstrings{$s};
	}
}

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}

sub reset_system_trackers {
	my $id64 = shift;
	return if (!$id64);
	eval {
		log_mysql('elite',"update systems set planetscore=null where id64=?",[($id64)]);
	};
}

sub get_id64_by_name {
	my $name = shift;
	
	my @rows = db_mysql('elite',"select id64 from systems where name=? and deletionState=0 and id64 is not null",[($name)]);
	if (@rows) {
		return ${$rows[0]}{id64};
	} else {
		return undef;
	}
}

sub findRegion {
	# From:  https://github.com/klightspeed/EliteDangerousRegionMap

	my ($x, $y, $z) = @_;
	my $x0 = -49985;
	my $y0 = -40985;
	my $z0 = -24105;

	init_regionmap() if (!@regionmap);
	
	my $px = floor(($x - $x0) * 83 / 4096);
	my $pz = floor(($z - $z0) * 83 / 4096);

	if ($px < 0 || $pz < 0 || $pz > int(@regionmap)){
		return undef;
	} else {
		my $row = $regionmap[$pz];
		my $rx = 0;
		my $pv = 0;

		foreach my $v (@$row) {
			my $rl = $$v[0];

			if ($px < $rx + $rl){
				$pv = $$v[1];
				last;
			} else {
				$rx += $rl;
			}
		}

		if ($pv == 0){
			return 0;
		} else {
			return $pv;
		}
	}

	return undef;
}

sub init_regionmap {
	@regionmap = (
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[1225, 0], [4, 41], [819, 0]],
        [[1225, 0], [8, 41], [815, 0]],
        [[1225, 0], [12, 41], [811, 0]],
        [[1224, 0], [17, 41], [807, 0]],
        [[1224, 0], [22, 41], [802, 0]],
        [[1224, 0], [26, 41], [798, 0]],
        [[1224, 0], [31, 41], [793, 0]],
        [[1224, 0], [35, 41], [789, 0]],
        [[1223, 0], [40, 41], [785, 0]],
        [[1223, 0], [44, 41], [781, 0]],
        [[1223, 0], [49, 41], [776, 0]],
        [[1223, 0], [53, 41], [772, 0]],
        [[1223, 0], [55, 41], [770, 0]],
        [[1222, 0], [60, 41], [766, 0]],
        [[977, 0], [89, 41], [156, 0], [64, 41], [762, 0]],
        [[956, 0], [130, 41], [136, 0], [68, 41], [758, 0]],
        [[955, 0], [145, 41], [122, 0], [72, 41], [754, 0]],
        [[955, 0], [157, 41], [110, 0], [75, 41], [751, 0]],
        [[955, 0], [168, 41], [98, 0], [80, 41], [747, 0]],
        [[955, 0], [177, 41], [89, 0], [83, 41], [744, 0]],
        [[955, 0], [186, 41], [80, 0], [87, 41], [740, 0]],
        [[955, 0], [195, 41], [71, 0], [90, 41], [737, 0]],
        [[956, 0], [201, 41], [64, 0], [94, 41], [733, 0]],
        [[956, 0], [206, 41], [58, 0], [97, 41], [731, 0]],
        [[956, 0], [213, 41], [51, 0], [100, 41], [728, 0]],
        [[956, 0], [220, 41], [44, 0], [104, 41], [724, 0]],
        [[956, 0], [226, 41], [38, 0], [107, 41], [721, 0]],
        [[956, 0], [232, 41], [32, 0], [110, 41], [718, 0]],
        [[956, 0], [238, 41], [25, 0], [115, 41], [714, 0]],
        [[956, 0], [244, 41], [19, 0], [117, 41], [712, 0]],
        [[956, 0], [249, 41], [14, 0], [121, 41], [708, 0]],
        [[956, 0], [255, 41], [8, 0], [123, 41], [706, 0]],
        [[956, 0], [260, 41], [3, 0], [127, 41], [702, 0]],
        [[956, 0], [393, 41], [699, 0]],
        [[956, 0], [395, 41], [697, 0]],
        [[956, 0], [398, 41], [694, 0]],
        [[956, 0], [401, 41], [691, 0]],
        [[957, 0], [403, 41], [688, 0]],
        [[957, 0], [405, 41], [686, 0]],
        [[957, 0], [408, 41], [683, 0]],
        [[957, 0], [411, 41], [680, 0]],
        [[957, 0], [414, 41], [677, 0]],
        [[957, 0], [416, 41], [675, 0]],
        [[957, 0], [419, 41], [672, 0]],
        [[957, 0], [421, 41], [670, 0]],
        [[957, 0], [424, 41], [667, 0]],
        [[957, 0], [427, 41], [664, 0]],
        [[957, 0], [429, 41], [662, 0]],
        [[957, 0], [432, 41], [659, 0]],
        [[955, 0], [3, 31], [434, 41], [656, 0]],
        [[942, 0], [16, 31], [436, 41], [654, 0]],
        [[930, 0], [28, 31], [439, 41], [651, 0]],
        [[920, 0], [38, 31], [442, 41], [648, 0]],
        [[911, 0], [47, 31], [444, 41], [646, 0]],
        [[902, 0], [56, 31], [446, 41], [644, 0]],
        [[896, 0], [62, 31], [448, 41], [642, 0]],
        [[888, 0], [70, 31], [451, 41], [639, 0]],
        [[881, 0], [77, 31], [453, 41], [637, 0]],
        [[874, 0], [84, 31], [456, 41], [634, 0]],
        [[868, 0], [90, 31], [458, 41], [632, 0]],
        [[862, 0], [96, 31], [461, 41], [629, 0]],
        [[856, 0], [102, 31], [463, 41], [627, 0]],
        [[850, 0], [108, 31], [466, 41], [624, 0]],
        [[845, 0], [113, 31], [468, 41], [622, 0]],
        [[839, 0], [120, 31], [469, 41], [620, 0]],
        [[834, 0], [125, 31], [472, 41], [617, 0]],
        [[830, 0], [129, 31], [473, 41], [616, 0]],
        [[825, 0], [134, 31], [476, 41], [613, 0]],
        [[820, 0], [139, 31], [478, 41], [611, 0]],
        [[816, 0], [143, 31], [480, 41], [609, 0]],
        [[812, 0], [147, 31], [483, 41], [606, 0]],
        [[807, 0], [152, 31], [485, 41], [604, 0]],
        [[803, 0], [156, 31], [487, 41], [602, 0]],
        [[798, 0], [161, 31], [489, 41], [600, 0]],
        [[794, 0], [165, 31], [491, 41], [598, 0]],
        [[790, 0], [169, 31], [494, 41], [595, 0]],
        [[787, 0], [172, 31], [495, 41], [594, 0]],
        [[783, 0], [176, 31], [497, 41], [592, 0]],
        [[779, 0], [180, 31], [500, 41], [589, 0]],
        [[775, 0], [185, 31], [501, 41], [587, 0]],
        [[771, 0], [189, 31], [503, 41], [585, 0]],
        [[767, 0], [193, 31], [505, 41], [583, 0]],
        [[764, 0], [196, 31], [507, 41], [581, 0]],
        [[761, 0], [199, 31], [509, 41], [579, 0]],
        [[757, 0], [203, 31], [511, 41], [577, 0]],
        [[754, 0], [206, 31], [514, 41], [574, 0]],
        [[750, 0], [210, 31], [516, 41], [572, 0]],
        [[748, 0], [212, 31], [517, 41], [571, 0]],
        [[744, 0], [216, 31], [519, 41], [569, 0]],
        [[741, 0], [219, 31], [521, 41], [567, 0]],
        [[738, 0], [222, 31], [523, 41], [565, 0]],
        [[734, 0], [227, 31], [524, 41], [563, 0]],
        [[731, 0], [230, 31], [526, 41], [561, 0]],
        [[728, 0], [233, 31], [528, 41], [559, 0]],
        [[725, 0], [236, 31], [530, 41], [557, 0]],
        [[722, 0], [239, 31], [532, 41], [555, 0]],
        [[719, 0], [242, 31], [534, 41], [553, 0]],
        [[716, 0], [245, 31], [536, 41], [551, 0]],
        [[713, 0], [248, 31], [537, 41], [550, 0]],
        [[710, 0], [251, 31], [539, 41], [548, 0]],
        [[707, 0], [254, 31], [541, 41], [546, 0]],
        [[705, 0], [256, 31], [543, 41], [544, 0]],
        [[702, 0], [259, 31], [545, 41], [542, 0]],
        [[699, 0], [262, 31], [547, 41], [540, 0]],
        [[696, 0], [265, 31], [549, 41], [538, 0]],
        [[693, 0], [268, 31], [550, 41], [537, 0]],
        [[690, 0], [272, 31], [551, 41], [535, 0]],
        [[688, 0], [274, 31], [553, 41], [533, 0]],
        [[686, 0], [276, 31], [555, 41], [531, 0]],
        [[683, 0], [279, 31], [556, 41], [530, 0]],
        [[680, 0], [282, 31], [558, 41], [528, 0]],
        [[678, 0], [284, 31], [560, 41], [526, 0]],
        [[675, 0], [287, 31], [562, 41], [524, 0]],
        [[673, 0], [289, 31], [564, 41], [522, 0]],
        [[670, 0], [292, 31], [565, 41], [521, 0]],
        [[667, 0], [295, 31], [567, 41], [519, 0]],
        [[665, 0], [297, 31], [569, 41], [517, 0]],
        [[663, 0], [299, 31], [571, 41], [515, 0]],
        [[660, 0], [302, 31], [572, 41], [514, 0]],
        [[658, 0], [304, 31], [574, 41], [512, 0]],
        [[656, 0], [306, 31], [576, 41], [510, 0]],
        [[653, 0], [310, 31], [576, 41], [509, 0]],
        [[651, 0], [312, 31], [578, 41], [507, 0]],
        [[648, 0], [315, 31], [580, 41], [505, 0]],
        [[646, 0], [317, 31], [581, 41], [504, 0]],
        [[644, 0], [319, 31], [583, 41], [502, 0]],
        [[641, 0], [322, 31], [585, 41], [500, 0]],
        [[639, 0], [324, 31], [586, 41], [499, 0]],
        [[637, 0], [326, 31], [588, 41], [497, 0]],
        [[634, 0], [329, 31], [590, 41], [495, 0]],
        [[633, 0], [330, 31], [591, 41], [494, 0]],
        [[630, 0], [333, 31], [593, 41], [492, 0]],
        [[628, 0], [335, 31], [594, 41], [491, 0]],
        [[626, 0], [337, 31], [596, 41], [489, 0]],
        [[624, 0], [339, 31], [598, 41], [487, 0]],
        [[621, 0], [342, 31], [599, 41], [486, 0]],
        [[619, 0], [345, 31], [600, 41], [484, 0]],
        [[617, 0], [347, 31], [601, 41], [483, 0]],
        [[615, 0], [349, 31], [603, 41], [481, 0]],
        [[613, 0], [351, 31], [605, 41], [479, 0]],
        [[611, 0], [353, 31], [606, 41], [478, 0]],
        [[609, 0], [355, 31], [607, 41], [477, 0]],
        [[607, 0], [357, 31], [609, 41], [475, 0]],
        [[605, 0], [359, 31], [611, 41], [473, 0]],
        [[603, 0], [361, 31], [612, 41], [472, 0]],
        [[601, 0], [363, 31], [614, 41], [470, 0]],
        [[599, 0], [365, 31], [615, 41], [469, 0]],
        [[596, 0], [368, 31], [617, 41], [467, 0]],
        [[594, 0], [370, 31], [618, 41], [466, 0]],
        [[592, 0], [372, 31], [620, 41], [464, 0]],
        [[590, 0], [374, 31], [621, 41], [463, 0]],
        [[589, 0], [376, 31], [487, 41], [2, 37], [133, 41], [461, 0]],
        [[587, 0], [378, 31], [487, 41], [4, 37], [132, 41], [460, 0]],
        [[585, 0], [380, 31], [486, 41], [7, 37], [132, 41], [458, 0]],
        [[583, 0], [382, 31], [485, 41], [10, 37], [131, 41], [457, 0]],
        [[581, 0], [384, 31], [485, 41], [12, 37], [131, 41], [455, 0]],
        [[579, 0], [386, 31], [484, 41], [15, 37], [130, 41], [454, 0]],
        [[577, 0], [388, 31], [484, 41], [17, 37], [130, 41], [452, 0]],
        [[575, 0], [390, 31], [483, 41], [19, 37], [130, 41], [451, 0]],
        [[573, 0], [392, 31], [483, 41], [21, 37], [130, 41], [449, 0]],
        [[571, 0], [394, 31], [482, 41], [24, 37], [129, 41], [448, 0]],
        [[570, 0], [395, 31], [482, 41], [26, 37], [127, 41], [2, 37], [446, 0]],
        [[568, 0], [397, 31], [481, 41], [29, 37], [124, 41], [4, 37], [445, 0]],
        [[566, 0], [399, 31], [481, 41], [30, 37], [123, 41], [5, 37], [444, 0]],
        [[564, 0], [401, 31], [480, 41], [33, 37], [120, 41], [8, 37], [442, 0]],
        [[562, 0], [403, 31], [480, 41], [35, 37], [117, 41], [10, 37], [441, 0]],
        [[561, 0], [405, 31], [478, 41], [38, 37], [115, 41], [11, 37], [440, 0]],
        [[559, 0], [407, 31], [478, 41], [40, 37], [112, 41], [14, 37], [438, 0]],
        [[557, 0], [409, 31], [477, 41], [43, 37], [109, 41], [16, 37], [437, 0]],
        [[555, 0], [411, 31], [477, 41], [44, 37], [108, 41], [18, 37], [435, 0]],
        [[553, 0], [413, 31], [476, 41], [47, 37], [105, 41], [20, 37], [434, 0]],
        [[551, 0], [415, 31], [476, 41], [49, 37], [102, 41], [23, 37], [432, 0]],
        [[550, 0], [416, 31], [475, 41], [51, 37], [101, 41], [24, 37], [431, 0]],
        [[548, 0], [418, 31], [475, 41], [53, 37], [98, 41], [26, 37], [430, 0]],
        [[547, 0], [419, 31], [474, 41], [56, 37], [95, 41], [28, 37], [429, 0]],
        [[545, 0], [421, 31], [474, 41], [58, 37], [93, 41], [30, 37], [427, 0]],
        [[543, 0], [423, 31], [473, 41], [60, 37], [91, 41], [32, 37], [426, 0]],
        [[541, 0], [425, 31], [473, 41], [62, 37], [88, 41], [35, 37], [424, 0]],
        [[540, 0], [426, 31], [472, 41], [65, 37], [85, 41], [37, 37], [423, 0]],
        [[538, 0], [428, 31], [472, 41], [67, 37], [83, 41], [38, 37], [422, 0]],
        [[536, 0], [430, 31], [471, 41], [70, 37], [80, 41], [41, 37], [420, 0]],
        [[534, 0], [433, 31], [469, 41], [72, 37], [78, 41], [43, 37], [419, 0]],
        [[533, 0], [434, 31], [469, 41], [74, 37], [75, 41], [45, 37], [418, 0]],
        [[531, 0], [436, 31], [469, 41], [75, 37], [74, 41], [46, 37], [417, 0]],
        [[530, 0], [437, 31], [468, 41], [78, 37], [71, 41], [49, 37], [415, 0]],
        [[528, 0], [439, 31], [468, 41], [79, 37], [70, 41], [50, 37], [414, 0]],
        [[526, 0], [441, 31], [467, 41], [82, 37], [67, 41], [53, 37], [412, 0]],
        [[525, 0], [442, 31], [467, 41], [84, 37], [64, 41], [55, 37], [411, 0]],
        [[523, 0], [444, 31], [466, 41], [87, 37], [61, 41], [57, 37], [410, 0]],
        [[460, 0], [2, 29], [59, 0], [446, 31], [466, 41], [88, 37], [60, 41], [58, 37], [409, 0]],
        [[458, 0], [5, 29], [57, 0], [447, 31], [465, 41], [91, 37], [57, 41], [61, 37], [407, 0]],
        [[457, 0], [6, 29], [55, 0], [449, 31], [464, 41], [93, 37], [55, 41], [63, 37], [406, 0]],
        [[456, 0], [8, 29], [53, 0], [450, 31], [464, 41], [95, 37], [52, 41], [66, 37], [404, 0]],
        [[454, 0], [11, 29], [50, 0], [452, 31], [463, 41], [98, 37], [50, 41], [67, 37], [403, 0]],
        [[453, 0], [12, 29], [49, 0], [453, 31], [463, 41], [99, 37], [48, 41], [69, 37], [402, 0]],
        [[452, 0], [14, 29], [46, 0], [455, 31], [463, 41], [101, 37], [45, 41], [71, 37], [401, 0]],
        [[450, 0], [17, 29], [43, 0], [457, 31], [462, 41], [103, 37], [44, 41], [72, 37], [400, 0]],
        [[449, 0], [18, 29], [42, 0], [459, 31], [460, 41], [106, 37], [41, 41], [75, 37], [398, 0]],
        [[447, 0], [21, 29], [39, 0], [461, 31], [460, 41], [107, 37], [39, 41], [77, 37], [397, 0]],
        [[446, 0], [23, 29], [37, 0], [462, 31], [459, 41], [110, 37], [37, 41], [78, 37], [396, 0]],
        [[445, 0], [25, 29], [34, 0], [464, 31], [459, 41], [112, 37], [34, 41], [81, 37], [394, 0]],
        [[443, 0], [28, 29], [32, 0], [465, 31], [458, 41], [114, 37], [32, 41], [83, 37], [393, 0]],
        [[442, 0], [29, 29], [30, 0], [467, 31], [458, 41], [116, 37], [30, 41], [84, 37], [392, 0]],
        [[440, 0], [32, 29], [27, 0], [469, 31], [457, 41], [118, 37], [28, 41], [86, 37], [391, 0]],
        [[439, 0], [33, 29], [26, 0], [470, 31], [457, 41], [119, 37], [26, 41], [88, 37], [390, 0]],
        [[438, 0], [35, 29], [24, 0], [471, 31], [456, 41], [122, 37], [24, 41], [90, 37], [388, 0]],
        [[436, 0], [38, 29], [21, 0], [473, 31], [456, 41], [123, 37], [22, 41], [92, 37], [387, 0]],
        [[435, 0], [40, 29], [19, 0], [474, 31], [455, 41], [126, 37], [19, 41], [94, 37], [386, 0]],
        [[434, 0], [41, 29], [17, 0], [476, 31], [455, 41], [127, 37], [17, 41], [96, 37], [385, 0]],
        [[433, 0], [43, 29], [15, 0], [477, 31], [454, 41], [130, 37], [15, 41], [98, 37], [383, 0]],
        [[431, 0], [46, 29], [12, 0], [479, 31], [454, 41], [131, 37], [13, 41], [100, 37], [382, 0]],
        [[430, 0], [47, 29], [11, 0], [480, 31], [453, 41], [134, 37], [10, 41], [102, 37], [381, 0]],
        [[429, 0], [49, 29], [8, 0], [483, 31], [452, 41], [135, 37], [9, 41], [103, 37], [380, 0]],
        [[427, 0], [52, 29], [6, 0], [484, 31], [451, 41], [138, 37], [6, 41], [105, 37], [379, 0]],
        [[426, 0], [53, 29], [4, 0], [486, 31], [451, 41], [140, 37], [3, 41], [108, 37], [377, 0]],
        [[425, 0], [55, 29], [2, 0], [487, 31], [450, 41], [142, 37], [2, 41], [109, 37], [376, 0]],
        [[423, 0], [58, 29], [488, 31], [450, 41], [254, 37], [375, 0]],
        [[422, 0], [60, 29], [487, 31], [449, 41], [256, 37], [374, 0]],
        [[421, 0], [61, 29], [487, 31], [449, 41], [257, 37], [373, 0]],
        [[420, 0], [63, 29], [486, 31], [448, 41], [260, 37], [371, 0]],
        [[418, 0], [66, 29], [485, 31], [448, 41], [261, 37], [370, 0]],
        [[417, 0], [67, 29], [485, 31], [447, 41], [263, 37], [369, 0]],
        [[415, 0], [70, 29], [484, 31], [447, 41], [264, 37], [368, 0]],
        [[414, 0], [72, 29], [483, 31], [446, 41], [266, 37], [367, 0]],
        [[413, 0], [73, 29], [483, 31], [445, 41], [268, 37], [366, 0]],
        [[412, 0], [75, 29], [482, 31], [445, 41], [270, 37], [364, 0]],
        [[411, 0], [77, 29], [481, 31], [445, 41], [270, 37], [364, 0]],
        [[409, 0], [79, 29], [482, 31], [443, 41], [273, 37], [362, 0]],
        [[408, 0], [81, 29], [481, 31], [443, 41], [274, 37], [361, 0]],
        [[407, 0], [83, 29], [480, 31], [442, 41], [276, 37], [360, 0]],
        [[406, 0], [84, 29], [480, 31], [442, 41], [277, 37], [359, 0]],
        [[404, 0], [87, 29], [479, 31], [441, 41], [279, 37], [358, 0]],
        [[403, 0], [89, 29], [478, 31], [441, 41], [281, 37], [356, 0]],
        [[402, 0], [91, 29], [477, 31], [440, 41], [283, 37], [355, 0]],
        [[401, 0], [92, 29], [477, 31], [439, 41], [285, 37], [354, 0]],
        [[399, 0], [95, 29], [476, 31], [439, 41], [286, 37], [353, 0]],
        [[398, 0], [97, 29], [475, 31], [439, 41], [287, 37], [352, 0]],
        [[397, 0], [98, 29], [475, 31], [438, 41], [289, 37], [351, 0]],
        [[396, 0], [100, 29], [474, 31], [437, 41], [291, 37], [350, 0]],
        [[395, 0], [102, 29], [473, 31], [437, 41], [292, 37], [349, 0]],
        [[393, 0], [104, 29], [473, 31], [436, 41], [295, 37], [347, 0]],
        [[392, 0], [106, 29], [472, 31], [436, 41], [296, 37], [346, 0]],
        [[391, 0], [108, 29], [472, 31], [434, 41], [298, 37], [345, 0]],
        [[390, 0], [110, 29], [471, 31], [434, 41], [299, 37], [344, 0]],
        [[389, 0], [111, 29], [471, 31], [258, 41], [2, 34], [173, 41], [301, 37], [343, 0]],
        [[388, 0], [110, 29], [473, 31], [257, 41], [6, 34], [170, 41], [302, 37], [342, 0]],
        [[386, 0], [111, 29], [474, 31], [257, 41], [10, 34], [165, 41], [304, 37], [341, 0]],
        [[335, 0], [1, 29], [49, 0], [111, 29], [475, 31], [257, 41], [13, 34], [162, 41], [305, 37], [340, 0]],
        [[333, 0], [4, 29], [47, 0], [110, 29], [477, 31], [257, 41], [16, 34], [158, 41], [307, 37], [339, 0]],
        [[332, 0], [6, 29], [45, 0], [110, 29], [478, 31], [256, 41], [20, 34], [155, 41], [308, 37], [338, 0]],
        [[331, 0], [8, 29], [43, 0], [109, 29], [480, 31], [50, 41], [29, 34], [177, 41], [24, 34], [150, 41], [310, 37], [337, 0]],
        [[330, 0], [10, 29], [41, 0], [109, 29], [481, 31], [50, 41], [50, 34], [156, 41], [27, 34], [147, 41], [311, 37], [336, 0]],
        [[329, 0], [12, 29], [38, 0], [109, 29], [483, 31], [50, 41], [63, 34], [142, 41], [31, 34], [143, 41], [313, 37], [335, 0]],
        [[328, 0], [14, 29], [36, 0], [109, 29], [485, 31], [49, 41], [74, 34], [131, 41], [34, 34], [140, 41], [315, 37], [333, 0]],
        [[327, 0], [16, 29], [34, 0], [109, 29], [486, 31], [49, 41], [84, 34], [121, 41], [38, 34], [135, 41], [317, 37], [332, 0]],
        [[326, 0], [18, 29], [32, 0], [108, 29], [488, 31], [49, 41], [93, 34], [111, 41], [42, 34], [132, 41], [318, 37], [331, 0]],
        [[325, 0], [20, 29], [30, 0], [108, 29], [489, 31], [49, 41], [101, 34], [103, 41], [45, 34], [128, 41], [320, 37], [330, 0]],
        [[324, 0], [21, 29], [29, 0], [108, 29], [490, 31], [49, 41], [108, 34], [96, 41], [48, 34], [125, 41], [321, 37], [329, 0]],
        [[323, 0], [23, 29], [27, 0], [108, 29], [491, 31], [49, 41], [113, 34], [91, 41], [50, 34], [122, 41], [323, 37], [328, 0]],
        [[322, 0], [25, 29], [24, 0], [108, 29], [493, 31], [49, 41], [119, 34], [84, 41], [54, 34], [119, 41], [324, 37], [327, 0]],
        [[321, 0], [27, 29], [22, 0], [108, 29], [494, 31], [49, 41], [126, 34], [77, 41], [57, 34], [115, 41], [326, 37], [326, 0]],
        [[319, 0], [30, 29], [20, 0], [107, 29], [496, 31], [49, 41], [132, 34], [71, 41], [60, 34], [112, 41], [327, 37], [325, 0]],
        [[318, 0], [32, 29], [18, 0], [107, 29], [497, 31], [49, 41], [137, 34], [66, 41], [62, 34], [109, 41], [329, 37], [324, 0]],
        [[317, 0], [34, 29], [16, 0], [107, 29], [498, 31], [49, 41], [143, 34], [59, 41], [66, 34], [106, 41], [330, 37], [323, 0]],
        [[316, 0], [36, 29], [14, 0], [106, 29], [500, 31], [49, 41], [148, 34], [54, 41], [69, 34], [102, 41], [332, 37], [322, 0]],
        [[315, 0], [38, 29], [12, 0], [106, 29], [501, 31], [49, 41], [154, 34], [48, 41], [72, 34], [99, 41], [333, 37], [321, 0]],
        [[314, 0], [40, 29], [10, 0], [106, 29], [502, 31], [49, 41], [158, 34], [43, 41], [75, 34], [96, 41], [335, 37], [320, 0]],
        [[313, 0], [42, 29], [7, 0], [106, 29], [504, 31], [49, 41], [163, 34], [38, 41], [78, 34], [92, 41], [337, 37], [319, 0]],
        [[313, 0], [42, 29], [6, 0], [106, 29], [505, 31], [49, 41], [166, 34], [35, 41], [80, 34], [90, 41], [338, 37], [318, 0]],
        [[312, 0], [44, 29], [4, 0], [106, 29], [507, 31], [48, 41], [171, 34], [30, 41], [83, 34], [87, 41], [339, 37], [317, 0]],
        [[310, 0], [47, 29], [2, 0], [105, 29], [509, 31], [48, 41], [175, 34], [25, 41], [86, 34], [84, 41], [341, 37], [316, 0]],
        [[309, 0], [154, 29], [510, 31], [48, 41], [179, 34], [21, 41], [89, 34], [81, 41], [1, 36], [341, 37], [315, 0]],
        [[308, 0], [154, 29], [511, 31], [48, 41], [183, 34], [17, 41], [92, 34], [77, 41], [3, 36], [341, 37], [314, 0]],
        [[307, 0], [154, 29], [512, 31], [48, 41], [187, 34], [13, 41], [94, 34], [75, 41], [5, 36], [340, 37], [313, 0]],
        [[306, 0], [153, 29], [514, 31], [48, 41], [191, 34], [8, 41], [97, 34], [72, 41], [9, 36], [338, 37], [312, 0]],
        [[305, 0], [153, 29], [515, 31], [48, 41], [195, 34], [4, 41], [100, 34], [69, 41], [10, 36], [338, 37], [311, 0]],
        [[304, 0], [153, 29], [516, 31], [48, 41], [301, 34], [66, 41], [13, 36], [337, 37], [310, 0]],
        [[303, 0], [152, 29], [518, 31], [48, 41], [304, 34], [63, 41], [15, 36], [337, 37], [308, 0]],
        [[302, 0], [152, 29], [519, 31], [48, 41], [306, 34], [60, 41], [18, 36], [336, 37], [307, 0]],
        [[301, 0], [152, 29], [520, 31], [48, 41], [308, 34], [57, 41], [20, 36], [335, 37], [307, 0]],
        [[300, 0], [152, 29], [521, 31], [48, 41], [310, 34], [55, 41], [23, 36], [333, 37], [306, 0]],
        [[299, 0], [152, 29], [522, 31], [48, 41], [313, 34], [51, 41], [25, 36], [333, 37], [305, 0]],
        [[298, 0], [154, 29], [521, 31], [48, 41], [315, 34], [49, 41], [27, 36], [332, 37], [304, 0]],
        [[297, 0], [156, 29], [520, 31], [48, 41], [317, 34], [46, 41], [30, 36], [331, 37], [303, 0]],
        [[296, 0], [157, 29], [521, 31], [14, 41], [33, 33], [320, 34], [43, 41], [32, 36], [330, 37], [302, 0]],
        [[295, 0], [159, 29], [517, 31], [50, 33], [322, 34], [40, 41], [35, 36], [329, 37], [301, 0]],
        [[294, 0], [161, 29], [503, 31], [63, 33], [324, 34], [38, 41], [37, 36], [328, 37], [300, 0]],
        [[293, 0], [163, 29], [491, 31], [74, 33], [326, 34], [35, 41], [39, 36], [328, 37], [299, 0]],
        [[292, 0], [165, 29], [480, 31], [84, 33], [329, 34], [32, 41], [41, 36], [327, 37], [298, 0]],
        [[291, 0], [166, 29], [472, 31], [92, 33], [331, 34], [29, 41], [44, 36], [326, 37], [297, 0]],
        [[291, 0], [167, 29], [465, 31], [98, 33], [332, 34], [28, 41], [45, 36], [326, 37], [296, 0]],
        [[290, 0], [169, 29], [457, 31], [105, 33], [335, 34], [24, 41], [48, 36], [325, 37], [295, 0]],
        [[289, 0], [171, 29], [450, 31], [111, 33], [337, 34], [22, 41], [50, 36], [324, 37], [294, 0]],
        [[288, 0], [173, 29], [442, 31], [118, 33], [339, 34], [19, 41], [53, 36], [323, 37], [293, 0]],
        [[287, 0], [174, 29], [436, 31], [124, 33], [341, 34], [17, 41], [54, 36], [323, 37], [292, 0]],
        [[286, 0], [176, 29], [429, 31], [130, 33], [343, 34], [14, 41], [57, 36], [322, 37], [291, 0]],
        [[285, 0], [178, 29], [423, 31], [135, 33], [345, 34], [12, 41], [59, 36], [321, 37], [290, 0]],
        [[284, 0], [180, 29], [417, 31], [140, 33], [347, 34], [9, 41], [61, 36], [321, 37], [289, 0]],
        [[283, 0], [182, 29], [411, 31], [145, 33], [349, 34], [7, 41], [63, 36], [320, 37], [288, 0]],
        [[282, 0], [183, 29], [406, 31], [150, 33], [351, 34], [4, 41], [66, 36], [319, 37], [287, 0]],
        [[281, 0], [185, 29], [402, 31], [153, 33], [353, 34], [2, 41], [67, 36], [318, 37], [287, 0]],
        [[280, 0], [187, 29], [396, 31], [158, 33], [354, 34], [70, 36], [317, 37], [286, 0]],
        [[279, 0], [189, 29], [391, 31], [162, 33], [354, 34], [71, 36], [317, 37], [285, 0]],
        [[278, 0], [190, 29], [386, 31], [167, 33], [353, 34], [74, 36], [316, 37], [284, 0]],
        [[277, 0], [192, 29], [381, 31], [171, 33], [353, 34], [76, 36], [315, 37], [283, 0]],
        [[276, 0], [194, 29], [376, 31], [175, 33], [352, 34], [78, 36], [315, 37], [282, 0]],
        [[275, 0], [196, 29], [371, 31], [179, 33], [352, 34], [80, 36], [314, 37], [281, 0]],
        [[274, 0], [198, 29], [366, 31], [183, 33], [351, 34], [83, 36], [313, 37], [280, 0]],
        [[273, 0], [200, 29], [361, 31], [187, 33], [351, 34], [84, 36], [313, 37], [279, 0]],
        [[273, 0], [200, 29], [359, 31], [189, 33], [350, 34], [87, 36], [312, 37], [278, 0]],
        [[272, 0], [202, 29], [358, 31], [189, 33], [350, 34], [88, 36], [312, 37], [277, 0]],
        [[271, 0], [204, 29], [357, 31], [189, 33], [349, 34], [91, 36], [311, 37], [276, 0]],
        [[270, 0], [206, 29], [357, 31], [188, 33], [349, 34], [92, 36], [311, 37], [275, 0]],
        [[269, 0], [207, 29], [357, 31], [188, 33], [348, 34], [95, 36], [309, 37], [275, 0]],
        [[268, 0], [209, 29], [356, 31], [188, 33], [348, 34], [96, 36], [309, 37], [274, 0]],
        [[267, 0], [211, 29], [356, 31], [187, 33], [347, 34], [99, 36], [308, 37], [273, 0]],
        [[266, 0], [213, 29], [355, 31], [187, 33], [347, 34], [100, 36], [308, 37], [272, 0]],
        [[265, 0], [215, 29], [354, 31], [187, 33], [346, 34], [103, 36], [307, 37], [271, 0]],
        [[264, 0], [217, 29], [353, 31], [187, 33], [346, 34], [105, 36], [306, 37], [270, 0]],
        [[263, 0], [219, 29], [353, 31], [186, 33], [345, 34], [107, 36], [306, 37], [269, 0]],
        [[263, 0], [219, 29], [353, 31], [186, 33], [345, 34], [109, 36], [305, 37], [268, 0]],
        [[262, 0], [221, 29], [352, 31], [186, 33], [344, 34], [111, 36], [305, 37], [267, 0]],
        [[261, 0], [223, 29], [351, 31], [186, 33], [343, 34], [113, 36], [305, 37], [266, 0]],
        [[260, 0], [225, 29], [351, 31], [185, 33], [343, 34], [115, 36], [303, 37], [266, 0]],
        [[259, 0], [226, 29], [351, 31], [185, 33], [342, 34], [117, 36], [303, 37], [265, 0]],
        [[258, 0], [228, 29], [350, 31], [185, 33], [342, 34], [119, 36], [302, 37], [264, 0]],
        [[258, 0], [229, 29], [350, 31], [184, 33], [341, 34], [122, 36], [301, 37], [263, 0]],
        [[257, 0], [231, 29], [349, 31], [184, 33], [341, 34], [123, 36], [301, 37], [262, 0]],
        [[256, 0], [233, 29], [67, 31], [3, 29], [278, 31], [184, 33], [340, 34], [125, 36], [301, 37], [261, 0]],
        [[255, 0], [234, 29], [66, 31], [5, 29], [277, 31], [184, 33], [340, 34], [127, 36], [300, 37], [260, 0]],
        [[254, 0], [236, 29], [63, 31], [7, 29], [278, 31], [183, 33], [339, 34], [129, 36], [300, 37], [259, 0]],
        [[253, 0], [238, 29], [61, 31], [9, 29], [121, 31], [1, 29], [155, 31], [183, 33], [339, 34], [131, 36], [298, 37], [259, 0]],
        [[252, 0], [240, 29], [59, 31], [10, 29], [119, 31], [3, 29], [155, 31], [183, 33], [339, 34], [132, 36], [298, 37], [258, 0]],
        [[251, 0], [242, 29], [56, 31], [13, 29], [116, 31], [6, 29], [154, 31], [183, 33], [338, 34], [134, 36], [298, 37], [257, 0]],
        [[251, 0], [242, 29], [55, 31], [15, 29], [113, 31], [8, 29], [155, 31], [182, 33], [337, 34], [137, 36], [297, 37], [256, 0]],
        [[250, 0], [244, 29], [53, 31], [17, 29], [110, 31], [11, 29], [154, 31], [182, 33], [337, 34], [138, 36], [297, 37], [255, 0]],
        [[249, 0], [246, 29], [50, 31], [19, 29], [109, 31], [12, 29], [154, 31], [182, 33], [336, 34], [140, 36], [297, 37], [254, 0]],
        [[248, 0], [248, 29], [48, 31], [21, 29], [105, 31], [16, 29], [154, 31], [181, 33], [336, 34], [142, 36], [296, 37], [253, 0]],
        [[247, 0], [250, 29], [45, 31], [24, 29], [103, 31], [17, 29], [154, 31], [181, 33], [335, 34], [144, 36], [296, 37], [252, 0]],
        [[246, 0], [251, 29], [44, 31], [26, 29], [100, 31], [20, 29], [153, 31], [181, 33], [335, 34], [146, 36], [294, 37], [252, 0]],
        [[245, 0], [253, 29], [42, 31], [27, 29], [98, 31], [22, 29], [153, 31], [181, 33], [334, 34], [148, 36], [294, 37], [251, 0]],
        [[244, 0], [255, 29], [39, 31], [30, 29], [95, 31], [25, 29], [153, 31], [180, 33], [334, 34], [150, 36], [293, 37], [250, 0]],
        [[244, 0], [256, 29], [37, 31], [32, 29], [92, 31], [27, 29], [150, 31], [183, 33], [333, 34], [152, 36], [293, 37], [249, 0]],
        [[243, 0], [257, 29], [36, 31], [33, 29], [91, 31], [29, 29], [147, 31], [185, 33], [333, 34], [153, 36], [293, 37], [248, 0]],
        [[242, 0], [259, 29], [33, 31], [36, 29], [88, 31], [31, 29], [143, 31], [189, 33], [332, 34], [155, 36], [292, 37], [248, 0]],
        [[241, 0], [261, 29], [31, 31], [38, 29], [85, 31], [34, 29], [138, 31], [193, 33], [332, 34], [157, 36], [291, 37], [247, 0]],
        [[240, 0], [263, 29], [29, 31], [39, 29], [83, 31], [36, 29], [135, 31], [196, 33], [331, 34], [159, 36], [291, 37], [246, 0]],
        [[240, 0], [264, 29], [26, 31], [42, 29], [81, 31], [38, 29], [131, 31], [199, 33], [331, 34], [160, 36], [291, 37], [245, 0]],
        [[239, 0], [266, 29], [24, 31], [44, 29], [78, 31], [40, 29], [127, 31], [203, 33], [330, 34], [162, 36], [291, 37], [244, 0]],
        [[238, 0], [267, 29], [23, 31], [45, 29], [76, 31], [43, 29], [123, 31], [206, 33], [330, 34], [164, 36], [290, 37], [243, 0]],
        [[237, 0], [269, 29], [20, 31], [48, 29], [73, 31], [45, 29], [120, 31], [209, 33], [329, 34], [166, 36], [290, 37], [242, 0]],
        [[236, 0], [271, 29], [18, 31], [50, 29], [70, 31], [48, 29], [116, 31], [201, 33], [340, 34], [168, 36], [288, 37], [242, 0]],
        [[235, 0], [273, 29], [16, 31], [51, 29], [69, 31], [50, 29], [112, 31], [178, 33], [365, 34], [170, 36], [288, 37], [241, 0]],
        [[234, 0], [275, 29], [13, 31], [54, 29], [66, 31], [52, 29], [109, 31], [175, 33], [371, 34], [171, 36], [288, 37], [240, 0]],
        [[234, 0], [275, 29], [12, 31], [56, 29], [64, 31], [54, 29], [106, 31], [177, 33], [370, 34], [173, 36], [288, 37], [239, 0]],
        [[233, 0], [277, 29], [10, 31], [58, 29], [61, 31], [56, 29], [103, 31], [180, 33], [370, 34], [174, 36], [287, 37], [239, 0]],
        [[232, 0], [279, 29], [8, 31], [59, 29], [59, 31], [59, 29], [99, 31], [183, 33], [369, 34], [177, 36], [286, 37], [238, 0]],
        [[231, 0], [281, 29], [6, 31], [61, 29], [56, 31], [61, 29], [96, 31], [186, 33], [369, 34], [178, 36], [286, 37], [237, 0]],
        [[231, 0], [282, 29], [3, 31], [64, 29], [54, 31], [63, 29], [92, 31], [189, 33], [368, 34], [181, 36], [285, 37], [236, 0]],
        [[230, 0], [284, 29], [1, 31], [65, 29], [52, 31], [65, 29], [89, 31], [192, 33], [368, 34], [182, 36], [285, 37], [235, 0]],
        [[229, 0], [352, 29], [50, 31], [67, 29], [86, 31], [195, 33], [366, 34], [184, 36], [285, 37], [234, 0]],
        [[228, 0], [354, 29], [47, 31], [69, 29], [83, 31], [198, 33], [366, 34], [185, 36], [285, 37], [233, 0]],
        [[227, 0], [355, 29], [45, 31], [72, 29], [79, 31], [201, 33], [365, 34], [187, 36], [284, 37], [233, 0]],
        [[227, 0], [356, 29], [42, 31], [74, 29], [77, 31], [203, 33], [364, 34], [190, 36], [283, 37], [232, 0]],
        [[226, 0], [358, 29], [40, 31], [76, 29], [74, 31], [205, 33], [364, 34], [191, 36], [283, 37], [231, 0]],
        [[225, 0], [359, 29], [39, 31], [77, 29], [71, 31], [208, 33], [364, 34], [192, 36], [283, 37], [230, 0]],
        [[224, 0], [361, 29], [36, 31], [80, 29], [68, 31], [210, 33], [363, 34], [194, 36], [282, 37], [230, 0]],
        [[223, 0], [363, 29], [34, 31], [81, 29], [65, 31], [213, 33], [363, 34], [195, 36], [282, 37], [229, 0]],
        [[223, 0], [363, 29], [32, 31], [84, 29], [62, 31], [215, 33], [362, 34], [198, 36], [281, 37], [228, 0]],
        [[222, 0], [365, 29], [29, 31], [86, 29], [59, 31], [218, 33], [361, 34], [200, 36], [281, 37], [227, 0]],
        [[221, 0], [367, 29], [27, 31], [88, 29], [56, 31], [220, 33], [361, 34], [201, 36], [280, 37], [227, 0]],
        [[220, 0], [369, 29], [24, 31], [90, 29], [53, 31], [223, 33], [360, 34], [203, 36], [280, 37], [226, 0]],
        [[219, 0], [370, 29], [23, 31], [92, 29], [50, 31], [225, 33], [309, 34], [1, 36], [50, 34], [204, 36], [280, 37], [225, 0]],
        [[219, 0], [371, 29], [20, 31], [94, 29], [47, 31], [228, 33], [308, 34], [4, 36], [47, 34], [207, 36], [279, 37], [224, 0]],
        [[218, 0], [373, 29], [18, 31], [96, 29], [44, 31], [230, 33], [308, 34], [6, 36], [45, 34], [208, 36], [279, 37], [223, 0]],
        [[217, 0], [374, 29], [16, 31], [98, 29], [43, 31], [232, 33], [306, 34], [9, 36], [43, 34], [209, 36], [278, 37], [223, 0]],
        [[217, 0], [375, 29], [14, 31], [100, 29], [39, 31], [235, 33], [306, 34], [11, 36], [40, 34], [211, 36], [278, 37], [222, 0]],
        [[216, 0], [377, 29], [11, 31], [102, 29], [37, 31], [237, 33], [306, 34], [14, 36], [37, 34], [212, 36], [278, 37], [221, 0]],
        [[215, 0], [378, 29], [10, 31], [104, 29], [34, 31], [239, 33], [305, 34], [17, 36], [34, 34], [214, 36], [278, 37], [220, 0]],
        [[214, 0], [380, 29], [8, 31], [105, 29], [31, 31], [242, 33], [305, 34], [19, 36], [32, 34], [216, 36], [276, 37], [220, 0]],
        [[213, 0], [382, 29], [5, 31], [108, 29], [28, 31], [244, 33], [304, 34], [22, 36], [29, 34], [218, 36], [276, 37], [219, 0]],
        [[212, 0], [384, 29], [3, 31], [109, 29], [26, 31], [246, 33], [304, 34], [25, 36], [25, 34], [220, 36], [276, 37], [218, 0]],
        [[212, 0], [384, 29], [1, 31], [112, 29], [23, 31], [248, 33], [303, 34], [28, 36], [23, 34], [221, 36], [276, 37], [217, 0]],
        [[211, 0], [498, 29], [21, 31], [250, 33], [303, 34], [30, 36], [20, 34], [223, 36], [275, 37], [217, 0]],
        [[210, 0], [500, 29], [18, 31], [252, 33], [303, 34], [32, 36], [18, 34], [225, 36], [274, 37], [216, 0]],
        [[209, 0], [501, 29], [15, 31], [255, 33], [302, 34], [35, 36], [15, 34], [227, 36], [274, 37], [215, 0]],
        [[209, 0], [502, 29], [13, 31], [256, 33], [302, 34], [37, 36], [13, 34], [228, 36], [274, 37], [214, 0]],
        [[208, 0], [503, 29], [11, 31], [258, 33], [301, 34], [40, 36], [10, 34], [230, 36], [273, 37], [214, 0]],
        [[207, 0], [505, 29], [8, 31], [260, 33], [301, 34], [42, 36], [8, 34], [231, 36], [273, 37], [213, 0]],
        [[207, 0], [505, 29], [6, 31], [262, 33], [301, 34], [44, 36], [5, 34], [233, 36], [273, 37], [212, 0]],
        [[206, 0], [507, 29], [3, 31], [265, 33], [299, 34], [47, 36], [3, 34], [234, 36], [273, 37], [211, 0]],
        [[205, 0], [508, 29], [268, 33], [298, 34], [286, 36], [273, 37], [210, 0]],
        [[204, 0], [508, 29], [269, 33], [298, 34], [287, 36], [272, 37], [210, 0]],
        [[204, 0], [506, 29], [271, 33], [298, 34], [288, 36], [272, 37], [209, 0]],
        [[203, 0], [505, 29], [273, 33], [297, 34], [291, 36], [271, 37], [208, 0]],
        [[202, 0], [504, 29], [275, 33], [297, 34], [292, 36], [271, 37], [207, 0]],
        [[201, 0], [503, 29], [277, 33], [296, 34], [294, 36], [270, 37], [207, 0]],
        [[201, 0], [501, 29], [279, 33], [296, 34], [295, 36], [270, 37], [206, 0]],
        [[200, 0], [500, 29], [281, 33], [163, 34], [4, 35], [129, 34], [296, 36], [270, 37], [205, 0]],
        [[199, 0], [499, 29], [283, 33], [163, 34], [9, 35], [123, 34], [298, 36], [269, 37], [205, 0]],
        [[198, 0], [499, 29], [284, 33], [162, 34], [14, 35], [119, 34], [299, 36], [269, 37], [204, 0]],
        [[198, 0], [497, 29], [286, 33], [162, 34], [18, 35], [114, 34], [301, 36], [269, 37], [203, 0]],
        [[197, 0], [496, 29], [289, 33], [161, 34], [23, 35], [109, 34], [302, 36], [269, 37], [202, 0]],
        [[196, 0], [495, 29], [291, 33], [161, 34], [27, 35], [104, 34], [304, 36], [268, 37], [202, 0]],
        [[196, 0], [493, 29], [293, 33], [161, 34], [31, 35], [100, 34], [305, 36], [268, 37], [201, 0]],
        [[195, 0], [492, 29], [295, 33], [160, 34], [36, 35], [96, 34], [306, 36], [268, 37], [200, 0]],
        [[194, 0], [492, 29], [296, 33], [160, 34], [40, 35], [91, 34], [308, 36], [268, 37], [199, 0]],
        [[194, 0], [490, 29], [298, 33], [160, 34], [43, 35], [88, 34], [309, 36], [267, 37], [199, 0]],
        [[193, 0], [489, 29], [300, 33], [160, 34], [46, 35], [84, 34], [311, 36], [267, 37], [198, 0]],
        [[192, 0], [489, 29], [301, 33], [160, 34], [50, 35], [80, 34], [312, 36], [266, 37], [198, 0]],
        [[191, 0], [488, 29], [303, 33], [159, 34], [54, 35], [76, 34], [314, 36], [266, 37], [197, 0]],
        [[191, 0], [486, 29], [305, 33], [159, 34], [58, 35], [72, 34], [315, 36], [266, 37], [196, 0]],
        [[190, 0], [485, 29], [307, 33], [159, 34], [61, 35], [69, 34], [316, 36], [46, 37], [2, 38], [218, 37], [195, 0]],
        [[189, 0], [485, 29], [308, 33], [158, 34], [65, 35], [65, 34], [318, 36], [43, 37], [5, 38], [217, 37], [195, 0]],
        [[188, 0], [484, 29], [310, 33], [158, 34], [68, 35], [62, 34], [320, 36], [40, 37], [7, 38], [217, 37], [194, 0]],
        [[188, 0], [482, 29], [312, 33], [158, 34], [72, 35], [57, 34], [322, 36], [38, 37], [9, 38], [217, 37], [193, 0]],
        [[187, 0], [482, 29], [313, 33], [158, 34], [75, 35], [54, 34], [323, 36], [36, 37], [11, 38], [216, 37], [193, 0]],
        [[186, 0], [481, 29], [316, 33], [157, 34], [78, 35], [50, 34], [325, 36], [34, 37], [13, 38], [216, 37], [192, 0]],
        [[186, 0], [480, 29], [317, 33], [156, 34], [81, 35], [48, 34], [326, 36], [32, 37], [14, 38], [217, 37], [191, 0]],
        [[185, 0], [479, 29], [319, 33], [13, 34], [50, 18], [93, 34], [84, 35], [44, 34], [328, 36], [30, 37], [16, 38], [216, 37], [191, 0]],
        [[185, 0], [478, 29], [316, 33], [81, 18], [2, 35], [77, 34], [87, 35], [41, 34], [329, 36], [28, 37], [18, 38], [216, 37], [190, 0]],
        [[184, 0], [477, 29], [306, 33], [93, 18], [13, 35], [66, 34], [90, 35], [38, 34], [330, 36], [26, 37], [20, 38], [216, 37], [189, 0]],
        [[183, 0], [476, 29], [297, 33], [104, 18], [24, 35], [55, 34], [92, 35], [35, 34], [332, 36], [24, 37], [22, 38], [216, 37], [188, 0]],
        [[182, 0], [476, 29], [289, 33], [113, 18], [34, 35], [44, 34], [96, 35], [32, 34], [333, 36], [22, 37], [24, 38], [215, 37], [188, 0]],
        [[182, 0], [474, 29], [284, 33], [120, 18], [42, 35], [36, 34], [99, 35], [28, 34], [335, 36], [20, 37], [26, 38], [215, 37], [187, 0]],
        [[181, 0], [473, 29], [279, 33], [127, 18], [48, 35], [30, 34], [102, 35], [25, 34], [336, 36], [18, 37], [28, 38], [215, 37], [186, 0]],
        [[180, 0], [473, 29], [274, 33], [133, 18], [55, 35], [23, 34], [104, 35], [22, 34], [338, 36], [16, 37], [30, 38], [214, 37], [186, 0]],
        [[179, 0], [472, 29], [270, 33], [139, 18], [61, 35], [17, 34], [107, 35], [19, 34], [339, 36], [14, 37], [32, 38], [214, 37], [185, 0]],
        [[179, 0], [471, 29], [266, 33], [144, 18], [65, 35], [12, 34], [109, 35], [18, 34], [339, 36], [13, 37], [33, 38], [214, 37], [185, 0]],
        [[178, 0], [470, 29], [263, 33], [149, 18], [70, 35], [7, 34], [112, 35], [14, 34], [341, 36], [11, 37], [35, 38], [214, 37], [184, 0]],
        [[178, 0], [469, 29], [258, 33], [155, 18], [76, 35], [1, 34], [115, 35], [11, 34], [342, 36], [9, 37], [37, 38], [214, 37], [183, 0]],
        [[177, 0], [468, 29], [256, 33], [158, 18], [195, 35], [8, 34], [344, 36], [7, 37], [39, 38], [213, 37], [183, 0]],
        [[176, 0], [468, 29], [252, 33], [163, 18], [198, 35], [5, 34], [345, 36], [5, 37], [41, 38], [213, 37], [182, 0]],
        [[176, 0], [466, 29], [250, 33], [167, 18], [200, 35], [3, 34], [346, 36], [2, 37], [44, 38], [213, 37], [181, 0]],
        [[175, 0], [466, 29], [246, 33], [172, 18], [203, 35], [347, 36], [46, 38], [213, 37], [180, 0]],
        [[174, 0], [465, 29], [244, 33], [176, 18], [205, 35], [344, 36], [48, 38], [212, 37], [180, 0]],
        [[174, 0], [464, 29], [241, 33], [180, 18], [208, 35], [340, 36], [50, 38], [212, 37], [179, 0]],
        [[173, 0], [463, 29], [239, 33], [184, 18], [210, 35], [337, 36], [52, 38], [212, 37], [178, 0]],
        [[172, 0], [463, 29], [236, 33], [188, 18], [212, 35], [334, 36], [54, 38], [211, 37], [178, 0]],
        [[172, 0], [462, 29], [2, 32], [232, 33], [191, 18], [214, 35], [331, 36], [55, 38], [212, 37], [177, 0]],
        [[171, 0], [461, 29], [5, 32], [231, 33], [191, 18], [216, 35], [328, 36], [57, 38], [211, 37], [177, 0]],
        [[170, 0], [461, 29], [6, 32], [231, 33], [191, 18], [218, 35], [325, 36], [59, 38], [211, 37], [176, 0]],
        [[170, 0], [460, 29], [8, 32], [231, 33], [190, 18], [220, 35], [322, 36], [61, 38], [211, 37], [175, 0]],
        [[169, 0], [459, 29], [11, 32], [230, 33], [190, 18], [223, 35], [318, 36], [63, 38], [210, 37], [175, 0]],
        [[168, 0], [459, 29], [12, 32], [230, 33], [190, 18], [225, 35], [315, 36], [65, 38], [210, 37], [174, 0]],
        [[168, 0], [457, 29], [15, 32], [229, 33], [189, 18], [228, 35], [311, 36], [68, 38], [210, 37], [173, 0]],
        [[167, 0], [457, 29], [17, 32], [229, 33], [188, 18], [230, 35], [308, 36], [69, 38], [210, 37], [173, 0]],
        [[166, 0], [457, 29], [19, 32], [228, 33], [188, 18], [232, 35], [305, 36], [71, 38], [210, 37], [172, 0]],
        [[166, 0], [455, 29], [21, 32], [228, 33], [188, 18], [234, 35], [302, 36], [73, 38], [210, 37], [171, 0]],
        [[165, 0], [455, 29], [23, 32], [228, 33], [187, 18], [236, 35], [299, 36], [75, 38], [209, 37], [171, 0]],
        [[165, 0], [454, 29], [25, 32], [227, 33], [187, 18], [238, 35], [296, 36], [77, 38], [209, 37], [170, 0]],
        [[164, 0], [453, 29], [27, 32], [227, 33], [187, 18], [240, 35], [293, 36], [79, 38], [209, 37], [169, 0]],
        [[163, 0], [453, 29], [29, 32], [226, 33], [187, 18], [242, 35], [290, 36], [80, 38], [209, 37], [169, 0]],
        [[163, 0], [452, 29], [31, 32], [226, 33], [186, 18], [244, 35], [287, 36], [82, 38], [209, 37], [168, 0]],
        [[162, 0], [451, 29], [33, 32], [226, 33], [195, 18], [237, 35], [284, 36], [84, 38], [208, 37], [168, 0]],
        [[161, 0], [451, 29], [35, 32], [225, 33], [206, 18], [228, 35], [281, 36], [86, 38], [208, 37], [167, 0]],
        [[161, 0], [450, 29], [37, 32], [224, 33], [215, 18], [221, 35], [278, 36], [88, 38], [208, 37], [166, 0]],
        [[162, 0], [447, 29], [39, 32], [225, 33], [221, 18], [216, 35], [275, 36], [90, 38], [207, 37], [166, 0]],
        [[163, 0], [445, 29], [41, 32], [224, 33], [221, 18], [218, 35], [272, 36], [92, 38], [207, 37], [165, 0]],
        [[165, 0], [441, 29], [44, 32], [223, 33], [221, 18], [220, 35], [269, 36], [93, 38], [208, 37], [164, 0]],
        [[166, 0], [439, 29], [45, 32], [223, 33], [221, 18], [221, 35], [267, 36], [95, 38], [207, 37], [164, 0]],
        [[168, 0], [436, 29], [47, 32], [223, 33], [220, 18], [223, 35], [264, 36], [97, 38], [207, 37], [163, 0]],
        [[169, 0], [434, 29], [49, 32], [222, 33], [220, 18], [225, 35], [261, 36], [99, 38], [206, 37], [163, 0]],
        [[171, 0], [431, 29], [51, 32], [221, 33], [219, 18], [227, 35], [259, 36], [100, 38], [207, 37], [162, 0]],
        [[173, 0], [427, 29], [53, 32], [222, 33], [218, 18], [229, 35], [256, 36], [102, 38], [206, 37], [162, 0]],
        [[174, 0], [425, 29], [55, 32], [221, 33], [218, 18], [231, 35], [252, 36], [105, 38], [206, 37], [161, 0]],
        [[176, 0], [422, 29], [57, 32], [220, 33], [218, 18], [233, 35], [249, 36], [107, 38], [206, 37], [160, 0]],
        [[177, 0], [419, 29], [59, 32], [221, 33], [217, 18], [235, 35], [246, 36], [109, 38], [206, 37], [159, 0]],
        [[179, 0], [416, 29], [61, 32], [220, 33], [217, 18], [236, 35], [244, 36], [110, 38], [206, 37], [159, 0]],
        [[181, 0], [413, 29], [63, 32], [219, 33], [217, 18], [238, 35], [241, 36], [112, 38], [206, 37], [158, 0]],
        [[183, 0], [410, 29], [65, 32], [218, 33], [216, 18], [241, 35], [238, 36], [114, 38], [205, 37], [158, 0]],
        [[184, 0], [408, 29], [66, 32], [219, 33], [215, 18], [242, 35], [236, 36], [116, 38], [205, 37], [157, 0]],
        [[185, 0], [406, 29], [68, 32], [216, 33], [217, 18], [244, 35], [233, 36], [118, 38], [204, 37], [157, 0]],
        [[187, 0], [402, 29], [70, 32], [213, 33], [220, 18], [246, 35], [230, 36], [119, 38], [205, 37], [156, 0]],
        [[189, 0], [399, 29], [72, 32], [209, 33], [223, 18], [247, 35], [228, 36], [121, 38], [205, 37], [155, 0]],
        [[189, 0], [398, 29], [74, 32], [204, 33], [227, 18], [249, 35], [225, 36], [123, 38], [204, 37], [155, 0]],
        [[188, 0], [398, 29], [76, 32], [200, 33], [230, 18], [250, 35], [223, 36], [125, 38], [204, 37], [154, 0]],
        [[187, 0], [397, 29], [79, 32], [195, 33], [234, 18], [252, 35], [220, 36], [127, 38], [203, 37], [154, 0]],
        [[187, 0], [396, 29], [80, 32], [192, 33], [236, 18], [255, 35], [217, 36], [128, 38], [204, 37], [153, 0]],
        [[186, 0], [396, 29], [82, 32], [188, 33], [239, 18], [256, 35], [215, 36], [130, 38], [204, 37], [152, 0]],
        [[186, 0], [395, 29], [84, 32], [184, 33], [242, 18], [258, 35], [212, 36], [132, 38], [39, 37], [3, 38], [161, 37], [152, 0]],
        [[185, 0], [395, 29], [85, 32], [181, 33], [245, 18], [259, 35], [211, 36], [133, 38], [37, 37], [5, 38], [161, 37], [151, 0]],
        [[185, 0], [394, 29], [87, 32], [178, 33], [247, 18], [261, 35], [209, 36], [133, 38], [36, 37], [6, 38], [161, 37], [151, 0]],
        [[184, 0], [394, 29], [89, 32], [174, 33], [250, 18], [262, 35], [209, 36], [133, 38], [33, 37], [9, 38], [161, 37], [150, 0]],
        [[183, 0], [394, 29], [90, 32], [171, 33], [253, 18], [264, 35], [208, 36], [133, 38], [31, 37], [10, 38], [161, 37], [150, 0]],
        [[183, 0], [392, 29], [93, 32], [167, 33], [256, 18], [265, 35], [208, 36], [133, 38], [28, 37], [13, 38], [161, 37], [149, 0]],
        [[182, 0], [392, 29], [95, 32], [164, 33], [257, 18], [268, 35], [207, 36], [132, 38], [27, 37], [15, 38], [161, 37], [148, 0]],
        [[181, 0], [392, 29], [96, 32], [161, 33], [260, 18], [269, 35], [207, 36], [132, 38], [25, 37], [17, 38], [160, 37], [148, 0]],
        [[181, 0], [391, 29], [98, 32], [157, 33], [263, 18], [271, 35], [206, 36], [132, 38], [22, 37], [20, 38], [160, 37], [147, 0]],
        [[180, 0], [391, 29], [100, 32], [154, 33], [265, 18], [272, 35], [206, 36], [132, 38], [20, 37], [21, 38], [160, 37], [147, 0]],
        [[179, 0], [391, 29], [101, 32], [151, 33], [268, 18], [274, 35], [205, 36], [131, 38], [18, 37], [24, 38], [160, 37], [146, 0]],
        [[179, 0], [390, 29], [103, 32], [147, 33], [271, 18], [276, 35], [204, 36], [131, 38], [16, 37], [26, 38], [160, 37], [145, 0]],
        [[178, 0], [390, 29], [105, 32], [144, 33], [273, 18], [277, 35], [204, 36], [131, 38], [14, 37], [27, 38], [160, 37], [145, 0]],
        [[178, 0], [389, 29], [107, 32], [141, 33], [274, 18], [279, 35], [204, 36], [130, 38], [12, 37], [30, 38], [160, 37], [144, 0]],
        [[177, 0], [388, 29], [109, 32], [138, 33], [277, 18], [281, 35], [203, 36], [130, 38], [10, 37], [32, 38], [159, 37], [144, 0]],
        [[177, 0], [387, 29], [111, 32], [135, 33], [279, 18], [282, 35], [202, 36], [131, 38], [8, 37], [33, 38], [160, 37], [143, 0]],
        [[176, 0], [387, 29], [113, 32], [132, 33], [281, 18], [283, 35], [202, 36], [131, 38], [5, 37], [36, 38], [159, 37], [143, 0]],
        [[175, 0], [387, 29], [114, 32], [132, 33], [281, 18], [285, 35], [201, 36], [130, 38], [4, 37], [38, 38], [159, 37], [142, 0]],
        [[175, 0], [386, 29], [116, 32], [132, 33], [280, 18], [286, 35], [201, 36], [130, 38], [1, 37], [40, 38], [159, 37], [142, 0]],
        [[174, 0], [386, 29], [118, 32], [131, 33], [280, 18], [288, 35], [200, 36], [171, 38], [159, 37], [141, 0]],
        [[174, 0], [385, 29], [119, 32], [132, 33], [279, 18], [289, 35], [200, 36], [171, 38], [158, 37], [141, 0]],
        [[173, 0], [385, 29], [121, 32], [131, 33], [278, 18], [292, 35], [199, 36], [171, 38], [158, 37], [140, 0]],
        [[173, 0], [384, 29], [123, 32], [130, 33], [278, 18], [293, 35], [199, 36], [170, 38], [159, 37], [139, 0]],
        [[172, 0], [384, 29], [124, 32], [131, 33], [277, 18], [294, 35], [199, 36], [170, 38], [158, 37], [139, 0]],
        [[172, 0], [383, 29], [126, 32], [130, 33], [277, 18], [295, 35], [198, 36], [170, 38], [159, 37], [138, 0]],
        [[171, 0], [383, 29], [128, 32], [130, 33], [276, 18], [297, 35], [197, 36], [170, 38], [158, 37], [138, 0]],
        [[170, 0], [383, 29], [129, 32], [130, 33], [275, 18], [299, 35], [197, 36], [170, 38], [158, 37], [137, 0]],
        [[170, 0], [381, 29], [132, 32], [130, 33], [274, 18], [301, 35], [196, 36], [169, 38], [158, 37], [137, 0]],
        [[169, 0], [381, 29], [134, 32], [129, 33], [274, 18], [302, 35], [196, 36], [169, 38], [158, 37], [136, 0]],
        [[168, 0], [381, 29], [136, 32], [129, 33], [273, 18], [303, 35], [196, 36], [169, 38], [158, 37], [135, 0]],
        [[168, 0], [380, 29], [137, 32], [129, 33], [273, 18], [305, 35], [195, 36], [168, 38], [158, 37], [135, 0]],
        [[167, 0], [380, 29], [139, 32], [128, 33], [273, 18], [306, 35], [195, 36], [168, 38], [158, 37], [134, 0]],
        [[167, 0], [379, 29], [141, 32], [128, 33], [272, 18], [180, 35], [2, 19], [125, 35], [194, 36], [169, 38], [157, 37], [134, 0]],
        [[166, 0], [379, 29], [143, 32], [127, 33], [272, 18], [180, 35], [4, 19], [124, 35], [195, 36], [167, 38], [158, 37], [133, 0]],
        [[166, 0], [379, 29], [143, 32], [128, 33], [270, 18], [180, 35], [7, 19], [123, 35], [194, 36], [168, 38], [157, 37], [133, 0]],
        [[165, 0], [378, 29], [146, 32], [127, 33], [270, 18], [103, 35], [2, 19], [75, 35], [8, 19], [124, 35], [193, 36], [168, 38], [157, 37], [132, 0]],
        [[165, 0], [377, 29], [147, 32], [128, 33], [269, 18], [103, 35], [5, 19], [71, 35], [11, 19], [123, 35], [193, 36], [167, 38], [157, 37], [132, 0]],
        [[164, 0], [377, 29], [149, 32], [127, 33], [269, 18], [102, 35], [9, 19], [68, 35], [13, 19], [122, 35], [193, 36], [167, 38], [157, 37], [131, 0]],
        [[164, 0], [376, 29], [151, 32], [126, 33], [269, 18], [102, 35], [11, 19], [65, 35], [16, 19], [122, 35], [192, 36], [167, 38], [156, 37], [131, 0]],
        [[163, 0], [376, 29], [153, 32], [126, 33], [268, 18], [102, 35], [14, 19], [62, 35], [18, 19], [119, 35], [2, 19], [189, 36], [169, 38], [157, 37], [130, 0]],
        [[162, 0], [376, 29], [154, 32], [126, 33], [268, 18], [101, 35], [17, 19], [59, 35], [21, 19], [116, 35], [4, 19], [187, 36], [171, 38], [156, 37], [130, 0]],
        [[162, 0], [375, 29], [156, 32], [126, 33], [266, 18], [102, 35], [20, 19], [56, 35], [23, 19], [113, 35], [6, 19], [185, 36], [173, 38], [156, 37], [129, 0]],
        [[161, 0], [375, 29], [158, 32], [125, 33], [266, 18], [102, 35], [23, 19], [52, 35], [26, 19], [111, 35], [8, 19], [182, 36], [174, 38], [156, 37], [129, 0]],
        [[161, 0], [374, 29], [160, 32], [125, 33], [265, 18], [101, 35], [26, 19], [50, 35], [27, 19], [109, 35], [10, 19], [179, 36], [177, 38], [156, 37], [128, 0]],
        [[160, 0], [375, 29], [160, 32], [125, 33], [265, 18], [101, 35], [28, 19], [47, 35], [30, 19], [106, 35], [12, 19], [177, 36], [178, 38], [156, 37], [128, 0]],
        [[160, 0], [374, 29], [162, 32], [124, 33], [265, 18], [7, 19], [94, 35], [31, 19], [44, 35], [32, 19], [103, 35], [14, 19], [175, 36], [180, 38], [156, 37], [127, 0]],
        [[159, 0], [374, 29], [164, 32], [124, 33], [264, 18], [13, 19], [87, 35], [34, 19], [41, 35], [34, 19], [101, 35], [16, 19], [173, 36], [182, 38], [156, 37], [126, 0]],
        [[159, 0], [373, 29], [165, 32], [124, 33], [1, 17], [263, 18], [19, 19], [81, 35], [37, 19], [38, 35], [36, 19], [99, 35], [18, 19], [170, 36], [183, 38], [156, 37], [126, 0]],
        [[158, 0], [373, 29], [167, 32], [121, 33], [3, 17], [263, 18], [25, 19], [75, 35], [39, 19], [35, 35], [39, 19], [96, 35], [20, 19], [168, 36], [185, 38], [156, 37], [125, 0]],
        [[157, 0], [373, 29], [169, 32], [117, 33], [6, 17], [262, 18], [32, 19], [68, 35], [42, 19], [32, 35], [42, 19], [93, 35], [22, 19], [165, 36], [188, 38], [155, 37], [125, 0]],
        [[157, 0], [372, 29], [170, 32], [115, 33], [9, 17], [261, 18], [36, 19], [64, 35], [45, 19], [29, 35], [43, 19], [91, 35], [24, 19], [163, 36], [189, 38], [156, 37], [124, 0]],
        [[156, 0], [372, 29], [172, 32], [112, 33], [11, 17], [261, 18], [41, 19], [58, 35], [48, 19], [26, 35], [46, 19], [88, 35], [26, 19], [161, 36], [191, 38], [155, 37], [124, 0]],
        [[156, 0], [371, 29], [174, 32], [108, 33], [15, 17], [260, 18], [45, 19], [54, 35], [50, 19], [24, 35], [48, 19], [86, 35], [27, 19], [159, 36], [192, 38], [156, 37], [123, 0]],
        [[155, 0], [371, 29], [175, 32], [106, 33], [17, 17], [260, 18], [50, 19], [49, 35], [52, 19], [21, 35], [50, 19], [84, 35], [30, 19], [155, 36], [195, 38], [155, 37], [123, 0]],
        [[155, 0], [370, 29], [177, 32], [103, 33], [20, 17], [259, 18], [54, 19], [44, 35], [55, 19], [19, 35], [52, 19], [81, 35], [32, 19], [153, 36], [197, 38], [155, 37], [122, 0]],
        [[154, 0], [370, 29], [179, 32], [101, 33], [21, 17], [259, 18], [57, 19], [41, 35], [57, 19], [17, 35], [53, 19], [79, 35], [34, 19], [151, 36], [198, 38], [155, 37], [122, 0]],
        [[154, 0], [369, 29], [180, 32], [98, 33], [24, 17], [259, 18], [61, 19], [37, 35], [59, 19], [14, 35], [56, 19], [77, 35], [35, 19], [149, 36], [200, 38], [155, 37], [121, 0]],
        [[153, 0], [369, 29], [182, 32], [95, 33], [27, 17], [257, 18], [65, 19], [33, 35], [62, 19], [11, 35], [59, 19], [73, 35], [38, 19], [147, 36], [202, 38], [154, 37], [121, 0]],
        [[153, 0], [368, 29], [184, 32], [92, 33], [29, 17], [257, 18], [69, 19], [29, 35], [64, 19], [9, 35], [60, 19], [72, 35], [39, 19], [145, 36], [203, 38], [155, 37], [120, 0]],
        [[152, 0], [368, 29], [186, 32], [89, 33], [32, 17], [256, 18], [72, 19], [26, 35], [66, 19], [6, 35], [63, 19], [69, 35], [41, 19], [142, 36], [206, 38], [154, 37], [120, 0]],
        [[152, 0], [368, 29], [186, 32], [87, 33], [34, 17], [256, 18], [76, 19], [21, 35], [70, 19], [3, 35], [64, 19], [67, 35], [44, 19], [139, 36], [207, 38], [155, 37], [119, 0]],
        [[151, 0], [368, 29], [188, 32], [84, 33], [36, 17], [256, 18], [79, 19], [18, 35], [139, 19], [64, 35], [46, 19], [137, 36], [209, 38], [154, 37], [119, 0]],
        [[151, 0], [367, 29], [190, 32], [81, 33], [39, 17], [255, 18], [82, 19], [15, 35], [140, 19], [62, 35], [48, 19], [135, 36], [211, 38], [154, 37], [118, 0]],
        [[150, 0], [367, 29], [191, 32], [79, 33], [41, 17], [255, 18], [85, 19], [11, 35], [143, 19], [60, 35], [49, 19], [132, 36], [213, 38], [154, 37], [118, 0]],
        [[150, 0], [366, 29], [193, 32], [76, 33], [44, 17], [253, 18], [89, 19], [8, 35], [144, 19], [58, 35], [51, 19], [130, 36], [215, 38], [153, 37], [118, 0]],
        [[149, 0], [366, 29], [195, 32], [73, 33], [46, 17], [253, 18], [93, 19], [3, 35], [147, 19], [55, 35], [53, 19], [128, 36], [216, 38], [154, 37], [117, 0]],
        [[149, 0], [365, 29], [196, 32], [72, 33], [48, 17], [252, 18], [95, 19], [1, 35], [148, 19], [53, 35], [55, 19], [126, 36], [218, 38], [154, 37], [116, 0]],
        [[148, 0], [366, 29], [197, 32], [69, 33], [50, 17], [252, 18], [245, 19], [52, 35], [56, 19], [124, 36], [219, 38], [154, 37], [116, 0]],
        [[148, 0], [365, 29], [199, 32], [66, 33], [52, 17], [252, 18], [247, 19], [49, 35], [58, 19], [122, 36], [221, 38], [154, 37], [115, 0]],
        [[147, 0], [365, 29], [200, 32], [64, 33], [55, 17], [251, 18], [248, 19], [47, 35], [60, 19], [119, 36], [224, 38], [153, 37], [115, 0]],
        [[147, 0], [364, 29], [202, 32], [61, 33], [57, 17], [251, 18], [250, 19], [44, 35], [62, 19], [117, 36], [225, 38], [154, 37], [114, 0]],
        [[146, 0], [364, 29], [204, 32], [58, 33], [60, 17], [249, 18], [252, 19], [42, 35], [64, 19], [47, 36], [1, 19], [67, 36], [227, 38], [153, 37], [114, 0]],
        [[146, 0], [363, 29], [206, 32], [56, 33], [61, 17], [249, 18], [254, 19], [39, 35], [67, 19], [44, 36], [3, 19], [65, 36], [229, 38], [153, 37], [113, 0]],
        [[145, 0], [363, 29], [207, 32], [54, 33], [64, 17], [248, 18], [255, 19], [38, 35], [68, 19], [42, 36], [5, 19], [62, 36], [231, 38], [153, 37], [113, 0]],
        [[145, 0], [362, 29], [209, 32], [51, 33], [66, 17], [248, 18], [257, 19], [35, 35], [70, 19], [40, 36], [7, 19], [60, 36], [233, 38], [153, 37], [112, 0]],
        [[144, 0], [362, 29], [211, 32], [48, 33], [69, 17], [247, 18], [258, 19], [33, 35], [72, 19], [38, 36], [9, 19], [58, 36], [234, 38], [153, 37], [112, 0]],
        [[144, 0], [362, 29], [211, 32], [47, 33], [70, 17], [247, 18], [259, 19], [31, 35], [74, 19], [36, 36], [11, 19], [56, 36], [236, 38], [152, 37], [112, 0]],
        [[143, 0], [362, 29], [213, 32], [44, 33], [72, 17], [247, 18], [260, 19], [30, 35], [75, 19], [34, 36], [13, 19], [54, 36], [237, 38], [153, 37], [111, 0]],
        [[143, 0], [361, 29], [215, 32], [41, 33], [75, 17], [246, 18], [262, 19], [27, 35], [77, 19], [32, 36], [15, 19], [51, 36], [240, 38], [152, 37], [111, 0]],
        [[142, 0], [361, 29], [216, 32], [40, 33], [76, 17], [245, 18], [264, 19], [25, 35], [79, 19], [30, 36], [17, 19], [49, 36], [241, 38], [153, 37], [110, 0]],
        [[142, 0], [360, 29], [218, 32], [37, 33], [79, 17], [244, 18], [266, 19], [22, 35], [81, 19], [28, 36], [19, 19], [47, 36], [243, 38], [152, 37], [110, 0]],
        [[141, 0], [360, 29], [220, 32], [34, 33], [81, 17], [244, 18], [267, 19], [20, 35], [83, 19], [25, 36], [22, 19], [45, 36], [245, 38], [152, 37], [109, 0]],
        [[141, 0], [361, 29], [220, 32], [32, 33], [83, 17], [243, 18], [268, 19], [19, 35], [84, 19], [23, 36], [23, 19], [44, 36], [246, 38], [152, 37], [109, 0]],
        [[140, 0], [363, 29], [219, 32], [30, 33], [85, 17], [243, 18], [270, 19], [16, 35], [86, 19], [21, 36], [25, 19], [41, 36], [249, 38], [152, 37], [108, 0]],
        [[140, 0], [365, 29], [218, 32], [27, 33], [87, 17], [243, 18], [271, 19], [14, 35], [88, 19], [19, 36], [27, 19], [39, 36], [250, 38], [152, 37], [108, 0]],
        [[139, 0], [367, 29], [218, 32], [25, 33], [89, 17], [242, 18], [272, 19], [12, 35], [90, 19], [17, 36], [29, 19], [37, 36], [252, 38], [152, 37], [107, 0]],
        [[138, 0], [369, 29], [217, 32], [23, 33], [91, 17], [241, 18], [275, 19], [9, 35], [92, 19], [15, 36], [31, 19], [34, 36], [254, 38], [152, 37], [107, 0]],
        [[138, 0], [370, 29], [217, 32], [21, 33], [93, 17], [240, 18], [275, 19], [9, 35], [93, 19], [13, 36], [33, 19], [33, 36], [255, 38], [152, 37], [106, 0]],
        [[138, 0], [371, 29], [217, 32], [18, 33], [95, 17], [240, 18], [277, 19], [6, 35], [95, 19], [11, 36], [35, 19], [30, 36], [257, 38], [152, 37], [106, 0]],
        [[137, 0], [373, 29], [216, 32], [17, 33], [96, 17], [240, 18], [278, 19], [4, 35], [97, 19], [9, 36], [36, 19], [29, 36], [259, 38], [152, 37], [105, 0]],
        [[137, 0], [375, 29], [215, 32], [14, 33], [99, 17], [239, 18], [280, 19], [1, 35], [99, 19], [7, 36], [39, 19], [26, 36], [260, 38], [152, 37], [105, 0]],
        [[136, 0], [377, 29], [215, 32], [12, 33], [100, 17], [239, 18], [381, 19], [5, 36], [41, 19], [24, 36], [262, 38], [152, 37], [104, 0]],
        [[136, 0], [378, 29], [215, 32], [9, 33], [103, 17], [238, 18], [382, 19], [3, 36], [42, 19], [23, 36], [264, 38], [151, 37], [104, 0]],
        [[135, 0], [380, 29], [214, 32], [8, 33], [104, 17], [238, 18], [383, 19], [1, 36], [44, 19], [20, 36], [266, 38], [151, 37], [104, 0]],
        [[135, 0], [382, 29], [213, 32], [5, 33], [107, 17], [236, 18], [430, 19], [18, 36], [268, 38], [151, 37], [103, 0]],
        [[134, 0], [384, 29], [213, 32], [3, 33], [108, 17], [236, 18], [431, 19], [16, 36], [269, 38], [151, 37], [103, 0]],
        [[134, 0], [385, 29], [212, 32], [1, 33], [110, 17], [236, 18], [432, 19], [13, 36], [272, 38], [151, 37], [102, 0]],
        [[133, 0], [387, 29], [211, 32], [112, 17], [235, 18], [433, 19], [11, 36], [274, 38], [150, 37], [102, 0]],
        [[133, 0], [388, 29], [209, 32], [113, 17], [235, 18], [433, 19], [10, 36], [275, 38], [149, 37], [103, 0]],
        [[133, 0], [389, 29], [206, 32], [116, 17], [234, 18], [434, 19], [8, 36], [277, 38], [146, 37], [105, 0]],
        [[132, 0], [392, 29], [203, 32], [117, 17], [234, 18], [435, 19], [6, 36], [277, 38], [1, 39], [143, 37], [108, 0]],
        [[132, 0], [393, 29], [201, 32], [119, 17], [233, 18], [436, 19], [4, 36], [276, 38], [4, 39], [140, 37], [110, 0]],
        [[131, 0], [395, 29], [198, 32], [121, 17], [232, 18], [438, 19], [2, 36], [275, 38], [6, 39], [138, 37], [112, 0]],
        [[131, 0], [396, 29], [195, 32], [124, 17], [231, 18], [439, 19], [274, 38], [9, 39], [135, 37], [114, 0]],
        [[130, 0], [396, 29], [195, 32], [125, 17], [231, 18], [440, 19], [271, 38], [11, 39], [132, 37], [117, 0]],
        [[130, 0], [395, 29], [195, 32], [126, 17], [231, 18], [440, 19], [269, 38], [14, 39], [129, 37], [119, 0]],
        [[129, 0], [395, 29], [194, 32], [129, 17], [230, 18], [441, 19], [266, 38], [16, 39], [127, 37], [121, 0]],
        [[129, 0], [395, 29], [193, 32], [130, 17], [229, 18], [443, 19], [263, 38], [19, 39], [123, 37], [124, 0]],
        [[129, 0], [394, 29], [193, 32], [132, 17], [228, 18], [444, 19], [261, 38], [20, 39], [122, 37], [125, 0]],
        [[128, 0], [394, 29], [192, 32], [134, 17], [228, 18], [444, 19], [259, 38], [23, 39], [118, 37], [128, 0]],
        [[127, 0], [394, 29], [192, 32], [135, 17], [228, 18], [445, 19], [256, 38], [25, 39], [116, 37], [130, 0]],
        [[127, 0], [393, 29], [192, 32], [137, 17], [227, 18], [446, 19], [253, 38], [28, 39], [113, 37], [132, 0]],
        [[129, 0], [391, 29], [191, 32], [138, 17], [227, 18], [447, 19], [250, 38], [30, 39], [113, 37], [132, 0]],
        [[131, 0], [388, 29], [190, 32], [141, 17], [226, 18], [448, 19], [247, 38], [33, 39], [112, 37], [132, 0]],
        [[134, 0], [384, 29], [190, 32], [142, 17], [226, 18], [448, 19], [245, 38], [35, 39], [113, 37], [131, 0]],
        [[136, 0], [381, 29], [190, 32], [144, 17], [224, 18], [451, 19], [241, 38], [38, 39], [112, 37], [131, 0]],
        [[138, 0], [378, 29], [190, 32], [145, 17], [224, 18], [451, 19], [240, 38], [39, 39], [113, 37], [130, 0]],
        [[141, 0], [375, 29], [188, 32], [147, 17], [224, 18], [452, 19], [237, 38], [42, 39], [112, 37], [130, 0]],
        [[143, 0], [372, 29], [188, 32], [149, 17], [223, 18], [453, 19], [234, 38], [44, 39], [112, 37], [130, 0]],
        [[144, 0], [370, 29], [188, 32], [150, 17], [223, 18], [453, 19], [232, 38], [47, 39], [112, 37], [129, 0]],
        [[147, 0], [366, 29], [188, 32], [152, 17], [222, 18], [454, 19], [229, 38], [49, 39], [112, 37], [129, 0]],
        [[149, 0], [364, 29], [186, 32], [154, 17], [222, 18], [455, 19], [226, 38], [52, 39], [112, 37], [128, 0]],
        [[151, 0], [361, 29], [186, 32], [156, 17], [220, 18], [457, 19], [224, 38], [53, 39], [112, 37], [128, 0]],
        [[154, 0], [357, 29], [186, 32], [157, 17], [55, 18], [4, 9], [161, 18], [458, 19], [221, 38], [56, 39], [112, 37], [127, 0]],
        [[156, 0], [354, 29], [186, 32], [159, 17], [51, 18], [8, 9], [160, 18], [458, 19], [219, 38], [58, 39], [112, 37], [127, 0]],
        [[158, 0], [1, 28], [350, 29], [186, 32], [160, 17], [48, 18], [11, 9], [160, 18], [459, 19], [216, 38], [61, 39], [112, 37], [126, 0]],
        [[157, 0], [4, 28], [348, 29], [184, 32], [162, 17], [44, 18], [15, 9], [160, 18], [460, 19], [213, 38], [63, 39], [112, 37], [126, 0]],
        [[157, 0], [6, 28], [345, 29], [184, 32], [164, 17], [40, 18], [18, 9], [160, 18], [461, 19], [210, 38], [66, 39], [112, 37], [125, 0]],
        [[156, 0], [10, 28], [341, 29], [184, 32], [165, 17], [37, 18], [22, 9], [159, 18], [461, 19], [208, 38], [68, 39], [112, 37], [125, 0]],
        [[156, 0], [12, 28], [338, 29], [184, 32], [167, 17], [33, 18], [25, 9], [159, 18], [462, 19], [205, 38], [71, 39], [111, 37], [125, 0]],
        [[156, 0], [13, 28], [337, 29], [183, 32], [168, 17], [31, 18], [27, 9], [158, 18], [464, 19], [203, 38], [72, 39], [112, 37], [124, 0]],
        [[155, 0], [17, 28], [333, 29], [183, 32], [169, 17], [28, 18], [30, 9], [158, 18], [465, 19], [200, 38], [75, 39], [111, 37], [124, 0]],
        [[155, 0], [19, 28], [330, 29], [183, 32], [171, 17], [24, 18], [34, 9], [157, 18], [465, 19], [200, 38], [75, 39], [112, 37], [123, 0]],
        [[154, 0], [22, 28], [328, 29], [181, 32], [173, 17], [21, 18], [37, 9], [157, 18], [466, 19], [199, 38], [76, 39], [111, 37], [123, 0]],
        [[154, 0], [25, 28], [324, 29], [181, 32], [175, 17], [18, 18], [39, 9], [157, 18], [467, 19], [199, 38], [75, 39], [111, 37], [123, 0]],
        [[153, 0], [28, 28], [321, 29], [181, 32], [176, 17], [15, 18], [43, 9], [156, 18], [468, 19], [198, 38], [76, 39], [111, 37], [122, 0]],
        [[153, 0], [30, 28], [318, 29], [181, 32], [178, 17], [11, 18], [46, 9], [156, 18], [468, 19], [199, 38], [75, 39], [111, 37], [122, 0]],
        [[153, 0], [32, 28], [315, 29], [181, 32], [179, 17], [9, 18], [48, 9], [155, 18], [470, 19], [198, 38], [76, 39], [111, 37], [121, 0]],
        [[152, 0], [36, 28], [312, 29], [180, 32], [180, 17], [6, 18], [52, 9], [154, 18], [471, 19], [198, 38], [75, 39], [111, 37], [121, 0]],
        [[152, 0], [38, 28], [309, 29], [180, 32], [182, 17], [3, 18], [54, 9], [154, 18], [472, 19], [197, 38], [76, 39], [110, 37], [121, 0]],
        [[151, 0], [41, 28], [306, 29], [180, 32], [183, 17], [1, 18], [56, 9], [154, 18], [472, 19], [198, 38], [75, 39], [111, 37], [120, 0]],
        [[151, 0], [43, 28], [304, 29], [179, 32], [182, 17], [59, 9], [154, 18], [109, 19], [2, 10], [362, 19], [197, 38], [75, 39], [111, 37], [120, 0]],
        [[151, 0], [45, 28], [301, 29], [179, 32], [181, 17], [62, 9], [77, 18], [25, 9], [26, 10], [25, 18], [108, 19], [6, 10], [359, 19], [198, 38], [75, 39], [110, 37], [120, 0]],
        [[150, 0], [49, 28], [297, 29], [179, 32], [180, 17], [64, 9], [65, 18], [37, 9], [38, 10], [13, 18], [108, 19], [8, 10], [358, 19], [197, 38], [75, 39], [111, 37], [119, 0]],
        [[150, 0], [51, 28], [295, 29], [177, 32], [179, 17], [67, 9], [55, 18], [47, 9], [48, 10], [3, 18], [107, 19], [11, 10], [357, 19], [197, 38], [75, 39], [110, 37], [119, 0]],
        [[149, 0], [54, 28], [292, 29], [177, 32], [178, 17], [70, 9], [47, 18], [54, 9], [55, 10], [103, 19], [13, 10], [356, 19], [196, 38], [75, 39], [111, 37], [118, 0]],
        [[149, 0], [56, 28], [289, 29], [177, 32], [177, 17], [72, 9], [41, 18], [60, 9], [61, 10], [97, 19], [15, 10], [355, 19], [196, 38], [75, 39], [110, 37], [118, 0]],
        [[148, 0], [60, 28], [285, 29], [177, 32], [176, 17], [74, 9], [35, 18], [66, 9], [67, 10], [90, 19], [19, 10], [352, 19], [196, 38], [75, 39], [111, 37], [117, 0]],
        [[148, 0], [62, 28], [283, 29], [176, 32], [175, 17], [76, 9], [29, 18], [72, 9], [73, 10], [84, 19], [21, 10], [351, 19], [196, 38], [75, 39], [110, 37], [117, 0]],
        [[147, 0], [65, 28], [280, 29], [176, 32], [174, 17], [79, 9], [23, 18], [77, 9], [78, 10], [78, 19], [24, 10], [350, 19], [195, 38], [75, 39], [111, 37], [116, 0]],
        [[147, 0], [68, 28], [276, 29], [176, 32], [173, 17], [81, 9], [19, 18], [81, 9], [82, 10], [74, 19], [26, 10], [348, 19], [196, 38], [75, 39], [110, 37], [116, 0]],
        [[147, 0], [69, 28], [275, 29], [175, 32], [172, 17], [83, 9], [15, 18], [85, 9], [86, 10], [70, 19], [27, 10], [348, 19], [195, 38], [75, 39], [110, 37], [116, 0]],
        [[146, 0], [73, 28], [271, 29], [175, 32], [172, 17], [84, 9], [11, 18], [89, 9], [90, 10], [65, 19], [31, 10], [345, 19], [196, 38], [74, 39], [111, 37], [115, 0]],
        [[146, 0], [75, 28], [268, 29], [175, 32], [173, 17], [85, 9], [6, 18], [93, 9], [94, 10], [61, 19], [32, 10], [345, 19], [195, 38], [75, 39], [110, 37], [115, 0]],
        [[145, 0], [78, 28], [266, 29], [174, 32], [175, 17], [84, 9], [2, 18], [97, 9], [98, 10], [56, 19], [35, 10], [344, 19], [195, 38], [74, 39], [110, 37], [115, 0]],
        [[145, 0], [80, 28], [263, 29], [174, 32], [176, 17], [183, 9], [102, 10], [52, 19], [37, 10], [343, 19], [195, 38], [74, 39], [110, 37], [114, 0]],
        [[145, 0], [83, 28], [259, 29], [174, 32], [178, 17], [182, 9], [105, 10], [48, 19], [40, 10], [341, 19], [195, 38], [74, 39], [110, 37], [114, 0]],
        [[144, 0], [86, 28], [257, 29], [173, 32], [179, 17], [182, 9], [108, 10], [45, 19], [42, 10], [340, 19], [195, 38], [74, 39], [110, 37], [113, 0]],
        [[144, 0], [88, 28], [254, 29], [173, 32], [181, 17], [181, 9], [112, 10], [41, 19], [44, 10], [338, 19], [195, 38], [74, 39], [110, 37], [113, 0]],
        [[143, 0], [91, 28], [251, 29], [173, 32], [182, 17], [181, 9], [115, 10], [37, 19], [47, 10], [337, 19], [194, 38], [75, 39], [109, 37], [113, 0]],
        [[143, 0], [94, 28], [248, 29], [172, 32], [184, 17], [180, 9], [118, 10], [33, 19], [50, 10], [336, 19], [194, 38], [74, 39], [110, 37], [112, 0]],
        [[143, 0], [96, 28], [245, 29], [172, 32], [185, 17], [180, 9], [121, 10], [30, 19], [51, 10], [336, 19], [193, 38], [75, 39], [109, 37], [112, 0]],
        [[142, 0], [99, 28], [242, 29], [172, 32], [187, 17], [179, 9], [123, 10], [28, 19], [53, 10], [334, 19], [194, 38], [74, 39], [109, 37], [112, 0]],
        [[142, 0], [101, 28], [240, 29], [171, 32], [188, 17], [179, 9], [126, 10], [24, 19], [55, 10], [334, 19], [193, 38], [74, 39], [110, 37], [111, 0]],
        [[141, 0], [104, 28], [237, 29], [172, 32], [189, 17], [178, 9], [129, 10], [21, 19], [57, 10], [332, 19], [194, 38], [74, 39], [109, 37], [111, 0]],
        [[141, 0], [107, 28], [233, 29], [174, 32], [188, 17], [178, 9], [132, 10], [17, 19], [60, 10], [331, 19], [193, 38], [74, 39], [110, 37], [110, 0]],
        [[141, 0], [109, 28], [231, 29], [175, 32], [188, 17], [177, 9], [134, 10], [15, 19], [62, 10], [330, 19], [193, 38], [74, 39], [109, 37], [110, 0]],
        [[140, 0], [110, 28], [230, 29], [177, 32], [187, 17], [177, 9], [137, 10], [12, 19], [63, 10], [329, 19], [193, 38], [74, 39], [109, 37], [110, 0]],
        [[140, 0], [110, 28], [229, 29], [179, 32], [187, 17], [176, 9], [139, 10], [9, 19], [66, 10], [328, 19], [193, 38], [74, 39], [109, 37], [109, 0]],
        [[139, 0], [111, 28], [229, 29], [180, 32], [186, 17], [176, 9], [142, 10], [6, 19], [67, 10], [328, 19], [192, 38], [74, 39], [109, 37], [109, 0]],
        [[139, 0], [110, 28], [229, 29], [183, 32], [185, 17], [175, 9], [145, 10], [2, 19], [70, 10], [326, 19], [193, 38], [73, 39], [110, 37], [108, 0]],
        [[138, 0], [111, 28], [228, 29], [185, 32], [184, 17], [175, 9], [219, 10], [325, 19], [192, 38], [74, 39], [109, 37], [108, 0]],
        [[138, 0], [110, 28], [229, 29], [186, 32], [184, 17], [174, 9], [220, 10], [325, 19], [191, 38], [74, 39], [109, 37], [108, 0]],
        [[138, 0], [110, 28], [228, 29], [188, 32], [183, 17], [174, 9], [222, 10], [323, 19], [192, 38], [74, 39], [107, 37], [109, 0]],
        [[137, 0], [110, 28], [229, 29], [189, 32], [183, 17], [173, 9], [223, 10], [323, 19], [191, 38], [74, 39], [105, 37], [111, 0]],
        [[137, 0], [110, 28], [228, 29], [191, 32], [182, 17], [173, 9], [225, 10], [321, 19], [192, 38], [73, 39], [102, 37], [114, 0]],
        [[137, 0], [110, 28], [227, 29], [193, 32], [182, 17], [172, 9], [226, 10], [321, 19], [191, 38], [74, 39], [98, 37], [117, 0]],
        [[136, 0], [110, 28], [228, 29], [194, 32], [181, 17], [172, 9], [228, 10], [320, 19], [191, 38], [73, 39], [95, 37], [120, 0]],
        [[136, 0], [110, 28], [227, 29], [196, 32], [181, 17], [171, 9], [229, 10], [319, 19], [191, 38], [74, 39], [92, 37], [122, 0]],
        [[136, 0], [109, 28], [228, 29], [197, 32], [180, 17], [171, 9], [231, 10], [318, 19], [191, 38], [73, 39], [89, 37], [125, 0]],
        [[135, 0], [110, 28], [227, 29], [199, 32], [180, 17], [170, 9], [232, 10], [318, 19], [190, 38], [73, 39], [86, 37], [128, 0]],
        [[135, 0], [109, 28], [227, 29], [201, 32], [179, 17], [170, 9], [234, 10], [316, 19], [191, 38], [73, 39], [82, 37], [131, 0]],
        [[134, 0], [110, 28], [227, 29], [202, 32], [178, 17], [170, 9], [235, 10], [316, 19], [190, 38], [73, 39], [79, 37], [134, 0]],
        [[134, 0], [109, 28], [227, 29], [204, 32], [176, 17], [171, 9], [236, 10], [315, 19], [191, 38], [73, 39], [76, 37], [136, 0]],
        [[134, 0], [109, 28], [227, 29], [205, 32], [173, 17], [173, 9], [238, 10], [314, 19], [190, 38], [73, 39], [73, 37], [139, 0]],
        [[136, 0], [107, 28], [226, 29], [207, 32], [170, 17], [175, 9], [239, 10], [314, 19], [189, 38], [74, 39], [70, 37], [2, 39], [139, 0]],
        [[138, 0], [104, 28], [226, 29], [209, 32], [167, 17], [177, 9], [241, 10], [312, 19], [190, 38], [73, 39], [67, 37], [6, 39], [138, 0]],
        [[141, 0], [101, 28], [226, 29], [210, 32], [1, 16], [163, 17], [179, 9], [242, 10], [312, 19], [189, 38], [73, 39], [64, 37], [9, 39], [138, 0]],
        [[144, 0], [97, 28], [226, 29], [210, 32], [3, 16], [160, 17], [181, 9], [243, 10], [311, 19], [190, 38], [73, 39], [60, 37], [12, 39], [138, 0]],
        [[147, 0], [94, 28], [226, 29], [209, 32], [5, 16], [157, 17], [183, 9], [245, 10], [310, 19], [189, 38], [73, 39], [58, 37], [15, 39], [137, 0]],
        [[150, 0], [90, 28], [226, 29], [209, 32], [7, 16], [155, 17], [184, 9], [246, 10], [309, 19], [190, 38], [73, 39], [54, 37], [18, 39], [137, 0]],
        [[152, 0], [88, 28], [225, 29], [209, 32], [9, 16], [152, 17], [186, 9], [247, 10], [309, 19], [189, 38], [73, 39], [51, 37], [21, 39], [137, 0]],
        [[155, 0], [85, 28], [225, 29], [208, 32], [11, 16], [149, 17], [188, 9], [249, 10], [308, 19], [188, 38], [73, 39], [48, 37], [25, 39], [136, 0]],
        [[158, 0], [81, 28], [225, 29], [208, 32], [13, 16], [146, 17], [190, 9], [250, 10], [307, 19], [189, 38], [73, 39], [45, 37], [27, 39], [136, 0]],
        [[160, 0], [79, 28], [225, 29], [208, 32], [14, 16], [144, 17], [191, 9], [251, 10], [307, 19], [188, 38], [73, 39], [42, 37], [30, 39], [136, 0]],
        [[163, 0], [75, 28], [225, 29], [208, 32], [16, 16], [141, 17], [193, 9], [252, 10], [306, 19], [189, 38], [73, 39], [39, 37], [33, 39], [135, 0]],
        [[165, 0], [73, 28], [225, 29], [207, 32], [18, 16], [139, 17], [194, 9], [253, 10], [306, 19], [188, 38], [73, 39], [36, 37], [36, 39], [135, 0]],
        [[165, 0], [73, 28], [224, 29], [207, 32], [20, 16], [136, 17], [196, 9], [255, 10], [305, 19], [187, 38], [73, 39], [33, 37], [39, 39], [135, 0]],
        [[165, 0], [72, 28], [225, 29], [206, 32], [22, 16], [133, 17], [198, 9], [256, 10], [304, 19], [188, 38], [73, 39], [29, 37], [43, 39], [134, 0]],
        [[164, 0], [73, 28], [224, 29], [206, 32], [24, 16], [131, 17], [199, 9], [257, 10], [304, 19], [187, 38], [73, 39], [27, 37], [45, 39], [134, 0]],
        [[164, 0], [72, 28], [225, 29], [205, 32], [26, 16], [128, 17], [201, 9], [258, 10], [303, 19], [188, 38], [72, 39], [24, 37], [48, 39], [134, 0]],
        [[164, 0], [72, 28], [224, 29], [205, 32], [29, 16], [124, 17], [203, 9], [260, 10], [302, 19], [187, 38], [73, 39], [20, 37], [52, 39], [133, 0]],
        [[163, 0], [73, 28], [223, 29], [205, 32], [31, 16], [122, 17], [204, 9], [261, 10], [301, 19], [187, 38], [73, 39], [17, 37], [55, 39], [133, 0]],
        [[163, 0], [72, 28], [224, 29], [205, 32], [32, 16], [119, 17], [206, 9], [262, 10], [301, 19], [187, 38], [73, 39], [14, 37], [58, 39], [132, 0]],
        [[163, 0], [72, 28], [223, 29], [205, 32], [33, 16], [118, 17], [207, 9], [263, 10], [300, 19], [187, 38], [73, 39], [11, 37], [61, 39], [132, 0]],
        [[162, 0], [72, 28], [224, 29], [204, 32], [36, 16], [115, 17], [208, 9], [264, 10], [300, 19], [187, 38], [72, 39], [9, 37], [63, 39], [132, 0]],
        [[162, 0], [72, 28], [223, 29], [204, 32], [38, 16], [112, 17], [210, 9], [265, 10], [299, 19], [187, 38], [73, 39], [5, 37], [66, 39], [132, 0]],
        [[162, 0], [72, 28], [223, 29], [203, 32], [40, 16], [110, 17], [211, 9], [267, 10], [298, 19], [187, 38], [72, 39], [2, 37], [70, 39], [131, 0]],
        [[161, 0], [72, 28], [223, 29], [203, 32], [42, 16], [107, 17], [213, 9], [268, 10], [298, 19], [186, 38], [144, 39], [131, 0]],
        [[161, 0], [72, 28], [223, 29], [202, 32], [44, 16], [105, 17], [206, 9], [277, 10], [297, 19], [187, 38], [144, 39], [130, 0]],
        [[160, 0], [72, 28], [223, 29], [203, 32], [45, 16], [102, 17], [190, 9], [296, 10], [297, 19], [186, 38], [144, 39], [130, 0]],
        [[160, 0], [72, 28], [224, 29], [201, 32], [47, 16], [100, 17], [181, 9], [307, 10], [47, 19], [2, 10], [247, 19], [186, 38], [144, 39], [130, 0]],
        [[159, 0], [73, 28], [226, 29], [198, 32], [49, 16], [98, 17], [177, 9], [313, 10], [45, 19], [4, 10], [247, 19], [186, 38], [144, 39], [129, 0]],
        [[159, 0], [72, 28], [229, 29], [195, 32], [51, 16], [95, 17], [180, 9], [314, 10], [42, 19], [6, 10], [246, 19], [186, 38], [144, 39], [129, 0]],
        [[159, 0], [72, 28], [230, 29], [193, 32], [53, 16], [93, 17], [181, 9], [315, 10], [39, 19], [8, 10], [247, 19], [186, 38], [143, 39], [129, 0]],
        [[159, 0], [72, 28], [232, 29], [191, 32], [54, 16], [91, 17], [182, 9], [316, 10], [38, 19], [9, 10], [246, 19], [186, 38], [144, 39], [128, 0]],
        [[158, 0], [72, 28], [235, 29], [188, 32], [56, 16], [88, 17], [184, 9], [317, 10], [36, 19], [11, 10], [246, 19], [185, 38], [144, 39], [128, 0]],
        [[158, 0], [72, 28], [237, 29], [185, 32], [58, 16], [86, 17], [185, 9], [318, 10], [33, 19], [14, 10], [245, 19], [186, 38], [143, 39], [128, 0]],
        [[157, 0], [72, 28], [239, 29], [183, 32], [60, 16], [84, 17], [186, 9], [319, 10], [31, 19], [16, 10], [245, 19], [185, 38], [144, 39], [127, 0]],
        [[157, 0], [72, 28], [242, 29], [179, 32], [62, 16], [81, 17], [189, 9], [319, 10], [29, 19], [18, 10], [244, 19], [185, 38], [144, 39], [127, 0]],
        [[157, 0], [72, 28], [243, 29], [177, 32], [64, 16], [79, 17], [190, 9], [320, 10], [27, 19], [20, 10], [244, 19], [185, 38], [143, 39], [127, 0]],
        [[156, 0], [72, 28], [246, 29], [175, 32], [65, 16], [77, 17], [191, 9], [321, 10], [25, 19], [22, 10], [243, 19], [185, 38], [144, 39], [126, 0]],
        [[156, 0], [72, 28], [248, 29], [172, 32], [68, 16], [74, 17], [192, 9], [322, 10], [23, 19], [24, 10], [243, 19], [185, 38], [143, 39], [126, 0]],
        [[156, 0], [72, 28], [250, 29], [169, 32], [70, 16], [71, 17], [194, 9], [323, 10], [21, 19], [26, 10], [242, 19], [185, 38], [143, 39], [126, 0]],
        [[155, 0], [72, 28], [253, 29], [166, 32], [72, 16], [69, 17], [195, 9], [324, 10], [19, 19], [28, 10], [242, 19], [184, 38], [144, 39], [125, 0]],
        [[155, 0], [72, 28], [255, 29], [163, 32], [74, 16], [67, 17], [196, 9], [325, 10], [17, 19], [29, 10], [242, 19], [185, 38], [143, 39], [125, 0]],
        [[155, 0], [72, 28], [256, 29], [162, 32], [75, 16], [65, 17], [198, 9], [325, 10], [15, 19], [31, 10], [242, 19], [184, 38], [143, 39], [125, 0]],
        [[155, 0], [71, 28], [258, 29], [160, 32], [77, 16], [62, 17], [200, 9], [326, 10], [13, 19], [33, 10], [241, 19], [184, 38], [144, 39], [124, 0]],
        [[154, 0], [72, 28], [258, 29], [159, 32], [79, 16], [60, 17], [201, 9], [327, 10], [11, 19], [35, 10], [241, 19], [184, 38], [143, 39], [124, 0]],
        [[154, 0], [72, 28], [257, 29], [160, 32], [80, 16], [58, 17], [202, 9], [328, 10], [9, 19], [37, 10], [240, 19], [184, 38], [143, 39], [124, 0]],
        [[154, 0], [71, 28], [258, 29], [159, 32], [82, 16], [56, 17], [203, 9], [329, 10], [7, 19], [39, 10], [240, 19], [184, 38], [142, 39], [124, 0]],
        [[153, 0], [72, 28], [257, 29], [159, 32], [84, 16], [53, 17], [205, 9], [330, 10], [5, 19], [41, 10], [239, 19], [184, 38], [143, 39], [123, 0]],
        [[153, 0], [71, 28], [258, 29], [158, 32], [86, 16], [51, 17], [206, 9], [331, 10], [3, 19], [42, 10], [240, 19], [181, 38], [145, 39], [123, 0]],
        [[153, 0], [71, 28], [257, 29], [158, 32], [88, 16], [49, 17], [207, 9], [377, 10], [239, 19], [178, 38], [148, 39], [123, 0]],
        [[152, 0], [71, 28], [258, 29], [158, 32], [89, 16], [47, 17], [209, 9], [377, 10], [239, 19], [174, 38], [152, 39], [122, 0]],
        [[152, 0], [71, 28], [257, 29], [158, 32], [91, 16], [45, 17], [210, 9], [378, 10], [238, 19], [172, 38], [154, 39], [122, 0]],
        [[152, 0], [71, 28], [257, 29], [157, 32], [93, 16], [43, 17], [211, 9], [378, 10], [239, 19], [168, 38], [157, 39], [122, 0]],
        [[151, 0], [72, 28], [256, 29], [158, 32], [94, 16], [41, 17], [212, 9], [379, 10], [238, 19], [166, 38], [160, 39], [121, 0]],
        [[151, 0], [71, 28], [257, 29], [157, 32], [96, 16], [39, 17], [213, 9], [380, 10], [238, 19], [162, 38], [163, 39], [121, 0]],
        [[151, 0], [71, 28], [256, 29], [157, 32], [98, 16], [37, 17], [214, 9], [381, 10], [237, 19], [159, 38], [166, 39], [121, 0]],
        [[150, 0], [72, 28], [256, 29], [157, 32], [99, 16], [35, 17], [215, 9], [382, 10], [237, 19], [155, 38], [169, 39], [121, 0]],
        [[150, 0], [71, 28], [256, 29], [157, 32], [101, 16], [32, 17], [218, 9], [382, 10], [236, 19], [153, 38], [172, 39], [120, 0]],
        [[150, 0], [71, 28], [256, 29], [156, 32], [104, 16], [29, 17], [219, 9], [382, 10], [237, 19], [149, 38], [175, 39], [120, 0]],
        [[150, 0], [70, 28], [256, 29], [156, 32], [106, 16], [27, 17], [220, 9], [18, 10], [36, 5], [329, 10], [236, 19], [146, 38], [178, 39], [120, 0]],
        [[149, 0], [71, 28], [256, 29], [156, 32], [107, 16], [25, 17], [221, 9], [7, 10], [59, 5], [318, 10], [236, 19], [142, 38], [182, 39], [119, 0]],
        [[149, 0], [71, 28], [255, 29], [156, 32], [109, 16], [23, 17], [220, 9], [76, 5], [311, 10], [235, 19], [140, 38], [184, 39], [119, 0]],
        [[148, 0], [71, 28], [256, 29], [155, 32], [111, 16], [21, 17], [215, 9], [89, 5], [305, 10], [234, 19], [137, 38], [187, 39], [119, 0]],
        [[148, 0], [71, 28], [255, 29], [156, 32], [112, 16], [19, 17], [211, 9], [99, 5], [300, 10], [235, 19], [134, 38], [190, 39], [118, 0]],
        [[148, 0], [71, 28], [255, 29], [155, 32], [114, 16], [17, 17], [207, 9], [109, 5], [296, 10], [234, 19], [131, 38], [193, 39], [118, 0]],
        [[147, 0], [72, 28], [254, 29], [155, 32], [116, 16], [15, 17], [203, 9], [119, 5], [292, 10], [234, 19], [127, 38], [196, 39], [118, 0]],
        [[147, 0], [71, 28], [255, 29], [155, 32], [117, 16], [13, 17], [199, 9], [128, 5], [288, 10], [234, 19], [125, 38], [198, 39], [118, 0]],
        [[147, 0], [71, 28], [254, 29], [155, 32], [119, 16], [11, 17], [197, 9], [135, 5], [285, 10], [234, 19], [121, 38], [202, 39], [117, 0]],
        [[147, 0], [71, 28], [254, 29], [154, 32], [121, 16], [9, 17], [194, 9], [143, 5], [282, 10], [233, 19], [118, 38], [205, 39], [117, 0]],
        [[146, 0], [71, 28], [254, 29], [155, 32], [122, 16], [7, 17], [191, 9], [150, 5], [280, 10], [232, 19], [115, 38], [209, 39], [116, 0]],
        [[146, 0], [71, 28], [254, 29], [154, 32], [124, 16], [5, 17], [189, 9], [157, 5], [277, 10], [232, 19], [111, 38], [212, 39], [116, 0]],
        [[146, 0], [71, 28], [253, 29], [154, 32], [126, 16], [3, 17], [187, 9], [163, 5], [274, 10], [232, 19], [109, 38], [214, 39], [116, 0]],
        [[145, 0], [71, 28], [254, 29], [154, 32], [127, 16], [1, 17], [184, 9], [170, 5], [272, 10], [232, 19], [105, 38], [217, 39], [116, 0]],
        [[145, 0], [71, 28], [253, 29], [154, 32], [129, 16], [181, 9], [176, 5], [270, 10], [231, 19], [102, 38], [221, 39], [115, 0]],
        [[145, 0], [71, 28], [253, 29], [154, 32], [130, 16], [178, 9], [181, 5], [267, 10], [232, 19], [99, 38], [223, 39], [115, 0]],
        [[145, 0], [70, 28], [253, 29], [154, 32], [132, 16], [174, 9], [186, 5], [266, 10], [231, 19], [96, 38], [226, 39], [115, 0]],
        [[144, 0], [71, 28], [253, 29], [153, 32], [134, 16], [170, 9], [192, 5], [264, 10], [231, 19], [92, 38], [229, 39], [115, 0]],
        [[144, 0], [71, 28], [253, 29], [153, 32], [135, 16], [167, 9], [197, 5], [261, 10], [231, 19], [90, 38], [232, 39], [114, 0]],
        [[144, 0], [71, 28], [252, 29], [153, 32], [137, 16], [163, 9], [202, 5], [260, 10], [231, 19], [86, 38], [235, 39], [114, 0]],
        [[143, 0], [71, 28], [253, 29], [152, 32], [139, 16], [160, 9], [207, 5], [258, 10], [230, 19], [83, 38], [238, 39], [114, 0]],
        [[143, 0], [71, 28], [252, 29], [153, 32], [141, 16], [155, 9], [212, 5], [257, 10], [191, 19], [1, 20], [37, 19], [80, 38], [241, 39], [114, 0]],
        [[143, 0], [71, 28], [252, 29], [152, 32], [143, 16], [152, 9], [217, 5], [254, 10], [189, 19], [4, 20], [37, 19], [77, 38], [244, 39], [113, 0]],
        [[143, 0], [70, 28], [252, 29], [152, 32], [145, 16], [149, 9], [221, 5], [253, 10], [186, 19], [6, 20], [37, 19], [74, 38], [247, 39], [113, 0]],
        [[142, 0], [71, 28], [252, 29], [152, 32], [146, 16], [145, 9], [226, 5], [252, 10], [183, 19], [9, 20], [37, 19], [70, 38], [2, 20], [248, 39], [113, 0]],
        [[142, 0], [71, 28], [251, 29], [152, 32], [148, 16], [143, 9], [229, 5], [250, 10], [181, 19], [11, 20], [37, 19], [67, 38], [6, 20], [247, 39], [113, 0]],
        [[142, 0], [70, 28], [252, 29], [152, 32], [149, 16], [139, 9], [234, 5], [249, 10], [177, 19], [14, 20], [37, 19], [65, 38], [8, 20], [248, 39], [112, 0]],
        [[142, 0], [70, 28], [252, 29], [151, 32], [151, 16], [136, 9], [238, 5], [248, 10], [174, 19], [17, 20], [37, 19], [61, 38], [11, 20], [248, 39], [112, 0]],
        [[141, 0], [71, 28], [251, 29], [151, 32], [153, 16], [133, 9], [242, 5], [246, 10], [172, 19], [19, 20], [37, 19], [58, 38], [15, 20], [247, 39], [112, 0]],
        [[141, 0], [70, 28], [252, 29], [151, 32], [154, 16], [130, 9], [246, 5], [245, 10], [169, 19], [22, 20], [37, 19], [54, 38], [18, 20], [248, 39], [111, 0]],
        [[141, 0], [70, 28], [251, 29], [151, 32], [156, 16], [127, 9], [248, 5], [2, 6], [244, 10], [165, 19], [25, 20], [37, 19], [52, 38], [20, 20], [248, 39], [111, 0]],
        [[140, 0], [73, 28], [249, 29], [151, 32], [157, 16], [124, 9], [250, 5], [4, 6], [242, 10], [163, 19], [28, 20], [36, 19], [49, 38], [24, 20], [247, 39], [111, 0]],
        [[140, 0], [77, 28], [244, 29], [151, 32], [159, 16], [121, 9], [251, 5], [7, 6], [241, 10], [160, 19], [30, 20], [37, 19], [45, 38], [27, 20], [247, 39], [111, 0]],
        [[140, 0], [80, 28], [241, 29], [150, 32], [161, 16], [118, 9], [253, 5], [9, 6], [240, 10], [157, 19], [33, 20], [36, 19], [42, 38], [30, 20], [248, 39], [110, 0]],
        [[140, 0], [84, 28], [237, 29], [150, 32], [162, 16], [116, 9], [253, 5], [12, 6], [238, 10], [154, 19], [36, 20], [37, 19], [39, 38], [33, 20], [247, 39], [110, 0]],
        [[139, 0], [88, 28], [233, 29], [150, 32], [164, 16], [113, 9], [255, 5], [14, 6], [237, 10], [151, 19], [38, 20], [37, 19], [36, 38], [36, 20], [247, 39], [110, 0]],
        [[139, 0], [91, 28], [230, 29], [150, 32], [165, 16], [111, 9], [255, 5], [16, 6], [236, 10], [149, 19], [41, 20], [36, 19], [34, 38], [38, 20], [247, 39], [110, 0]],
        [[139, 0], [94, 28], [227, 29], [149, 32], [167, 16], [108, 9], [256, 5], [19, 6], [235, 10], [146, 19], [43, 20], [37, 19], [30, 38], [42, 20], [247, 39], [109, 0]],
        [[138, 0], [99, 28], [222, 29], [150, 32], [166, 16], [107, 9], [258, 5], [21, 6], [234, 10], [143, 19], [46, 20], [36, 19], [27, 38], [45, 20], [247, 39], [109, 0]],
        [[138, 0], [102, 28], [218, 29], [150, 32], [166, 16], [109, 9], [256, 5], [23, 6], [233, 10], [140, 19], [49, 20], [36, 19], [25, 38], [47, 20], [247, 39], [109, 0]],
        [[138, 0], [105, 28], [215, 29], [149, 32], [167, 16], [109, 9], [256, 5], [25, 6], [232, 10], [137, 19], [51, 20], [37, 19], [21, 38], [51, 20], [246, 39], [109, 0]],
        [[138, 0], [105, 28], [215, 29], [149, 32], [166, 16], [111, 9], [254, 5], [28, 6], [230, 10], [135, 19], [54, 20], [36, 19], [18, 38], [54, 20], [246, 39], [109, 0]],
        [[137, 0], [106, 28], [214, 29], [149, 32], [166, 16], [112, 9], [254, 5], [29, 6], [230, 10], [132, 19], [56, 20], [37, 19], [14, 38], [58, 20], [246, 39], [108, 0]],
        [[137, 0], [105, 28], [215, 29], [149, 32], [165, 16], [114, 9], [252, 5], [32, 6], [229, 10], [128, 19], [60, 20], [36, 19], [11, 38], [61, 20], [246, 39], [108, 0]],
        [[137, 0], [105, 28], [214, 29], [149, 32], [165, 16], [116, 9], [251, 5], [33, 6], [228, 10], [126, 19], [62, 20], [37, 19], [7, 38], [64, 20], [246, 39], [108, 0]],
        [[137, 0], [105, 28], [214, 29], [149, 32], [164, 16], [117, 9], [250, 5], [36, 6], [227, 10], [123, 19], [64, 20], [37, 19], [5, 38], [67, 20], [245, 39], [108, 0]],
        [[136, 0], [106, 28], [214, 29], [148, 32], [164, 16], [119, 9], [249, 5], [37, 6], [227, 10], [120, 19], [67, 20], [36, 19], [2, 38], [70, 20], [246, 39], [107, 0]],
        [[136, 0], [105, 28], [214, 29], [149, 32], [163, 16], [120, 9], [248, 5], [40, 6], [225, 10], [118, 19], [69, 20], [36, 19], [72, 20], [246, 39], [107, 0]],
        [[136, 0], [105, 28], [214, 29], [148, 32], [163, 16], [122, 9], [247, 5], [41, 6], [225, 10], [36, 19], [2, 10], [77, 19], [72, 20], [33, 19], [74, 20], [246, 39], [107, 0]],
        [[136, 0], [105, 28], [214, 29], [73, 32], [2, 30], [73, 32], [162, 16], [124, 9], [245, 5], [43, 6], [224, 10], [34, 19], [5, 10], [73, 19], [75, 20], [30, 19], [78, 20], [246, 39], [106, 0]],
        [[135, 0], [105, 28], [214, 29], [73, 32], [5, 30], [70, 32], [163, 16], [124, 9], [245, 5], [45, 6], [223, 10], [32, 19], [6, 10], [71, 19], [77, 20], [27, 19], [81, 20], [246, 39], [106, 0]],
        [[135, 0], [105, 28], [214, 29], [73, 32], [8, 30], [67, 32], [162, 16], [126, 9], [243, 5], [47, 6], [222, 10], [30, 19], [9, 10], [68, 19], [80, 20], [24, 19], [84, 20], [245, 39], [106, 0]],
        [[135, 0], [105, 28], [213, 29], [73, 32], [11, 30], [64, 32], [162, 16], [127, 9], [243, 5], [49, 6], [221, 10], [27, 19], [12, 10], [65, 19], [82, 20], [21, 19], [87, 20], [245, 39], [106, 0]],
        [[135, 0], [105, 28], [213, 29], [73, 32], [13, 30], [62, 32], [161, 16], [129, 9], [241, 5], [51, 6], [221, 10], [24, 19], [14, 10], [62, 19], [86, 20], [17, 19], [90, 20], [246, 39], [105, 0]],
        [[134, 0], [105, 28], [214, 29], [72, 32], [16, 30], [59, 32], [161, 16], [131, 9], [240, 5], [53, 6], [219, 10], [22, 19], [17, 10], [59, 19], [88, 20], [14, 19], [94, 20], [245, 39], [105, 0]],
        [[134, 0], [105, 28], [213, 29], [73, 32], [19, 30], [56, 32], [160, 16], [132, 9], [239, 5], [55, 6], [219, 10], [19, 19], [19, 10], [57, 19], [90, 20], [12, 19], [96, 20], [245, 39], [105, 0]],
        [[134, 0], [105, 28], [213, 29], [73, 32], [21, 30], [53, 32], [160, 16], [134, 9], [238, 5], [56, 6], [218, 10], [17, 19], [22, 10], [53, 19], [94, 20], [8, 19], [99, 20], [245, 39], [105, 0]],
        [[134, 0], [105, 28], [213, 29], [72, 32], [24, 30], [51, 32], [160, 16], [134, 9], [237, 5], [58, 6], [218, 10], [15, 19], [23, 10], [52, 19], [95, 20], [6, 19], [102, 20], [245, 39], [31, 0], [3, 39], [70, 0]],
        [[134, 0], [104, 28], [213, 29], [73, 32], [26, 30], [48, 32], [160, 16], [136, 9], [236, 5], [59, 6], [217, 10], [13, 19], [25, 10], [49, 19], [99, 20], [2, 19], [105, 20], [245, 39], [26, 0], [8, 39], [70, 0]],
        [[133, 0], [105, 28], [213, 29], [1, 27], [71, 32], [29, 30], [46, 32], [159, 16], [138, 9], [234, 5], [62, 6], [216, 10], [10, 19], [28, 10], [46, 19], [208, 20], [245, 39], [22, 0], [13, 39], [69, 0]],
        [[133, 0], [105, 28], [212, 29], [5, 27], [68, 32], [31, 30], [43, 32], [159, 16], [139, 9], [17, 5], [2, 4], [215, 5], [63, 6], [215, 10], [8, 19], [30, 10], [44, 19], [210, 20], [245, 39], [17, 0], [18, 39], [69, 0]],
        [[133, 0], [105, 28], [212, 29], [7, 27], [65, 32], [35, 30], [39, 32], [159, 16], [141, 9], [14, 5], [4, 4], [214, 5], [65, 6], [215, 10], [5, 19], [33, 10], [41, 19], [213, 20], [244, 39], [13, 0], [22, 39], [69, 0]],
        [[133, 0], [104, 28], [213, 29], [10, 27], [62, 32], [37, 30], [37, 32], [159, 16], [142, 9], [11, 5], [7, 4], [213, 5], [66, 6], [215, 10], [2, 19], [35, 10], [38, 19], [216, 20], [245, 39], [7, 0], [27, 39], [69, 0]],
        [[132, 0], [105, 28], [212, 29], [14, 27], [59, 32], [39, 30], [34, 32], [159, 16], [143, 9], [9, 5], [9, 4], [212, 5], [69, 6], [251, 10], [35, 19], [218, 20], [245, 39], [2, 0], [32, 39], [69, 0]],
        [[132, 0], [105, 28], [212, 29], [17, 27], [55, 32], [43, 30], [31, 32], [158, 16], [145, 9], [6, 5], [12, 4], [211, 5], [70, 6], [250, 10], [33, 19], [221, 20], [279, 39], [68, 0]],
        [[132, 0], [104, 28], [213, 29], [19, 27], [53, 32], [45, 30], [28, 32], [158, 16], [146, 9], [5, 5], [13, 4], [210, 5], [72, 6], [250, 10], [29, 19], [224, 20], [279, 39], [68, 0]],
        [[132, 0], [104, 28], [212, 29], [23, 27], [49, 32], [48, 30], [26, 32], [158, 16], [147, 9], [2, 5], [16, 4], [209, 5], [73, 6], [249, 10], [27, 19], [226, 20], [279, 39], [68, 0]],
        [[131, 0], [105, 28], [212, 29], [26, 27], [46, 32], [50, 30], [24, 32], [157, 16], [148, 9], [19, 4], [207, 5], [75, 6], [249, 10], [24, 19], [229, 20], [278, 39], [68, 0]],
        [[131, 0], [105, 28], [211, 29], [29, 27], [44, 32], [52, 30], [21, 32], [157, 16], [148, 9], [20, 4], [207, 5], [76, 6], [248, 10], [22, 19], [231, 20], [278, 39], [68, 0]],
        [[131, 0], [105, 28], [104, 29], [1, 27], [106, 29], [32, 27], [40, 32], [55, 30], [19, 32], [157, 16], [146, 9], [23, 4], [205, 5], [78, 6], [248, 10], [19, 19], [233, 20], [279, 39], [67, 0]],
        [[131, 0], [104, 28], [105, 29], [5, 27], [102, 29], [35, 27], [37, 32], [58, 30], [15, 32], [157, 16], [145, 9], [25, 4], [205, 5], [79, 6], [247, 10], [17, 19], [235, 20], [279, 39], [67, 0]],
        [[131, 0], [104, 28], [105, 29], [8, 27], [98, 29], [36, 27], [2, 30], [34, 32], [61, 30], [13, 32], [156, 16], [145, 9], [27, 4], [203, 5], [81, 6], [247, 10], [13, 19], [239, 20], [278, 39], [67, 0]],
        [[130, 0], [105, 28], [105, 29], [11, 27], [95, 29], [36, 27], [5, 30], [31, 32], [63, 30], [10, 32], [156, 16], [144, 9], [29, 4], [203, 5], [83, 6], [245, 10], [11, 19], [241, 20], [278, 39], [67, 0]],
        [[130, 0], [104, 28], [105, 29], [16, 27], [90, 29], [37, 27], [8, 30], [28, 32], [65, 30], [8, 32], [155, 16], [144, 9], [31, 4], [201, 5], [85, 6], [245, 10], [8, 19], [243, 20], [278, 39], [67, 0]],
        [[130, 0], [104, 28], [105, 29], [19, 27], [87, 29], [36, 27], [12, 30], [24, 32], [69, 30], [4, 32], [156, 16], [142, 9], [33, 4], [201, 5], [86, 6], [244, 10], [5, 19], [247, 20], [278, 39], [66, 0]],
        [[130, 0], [104, 28], [105, 29], [23, 27], [83, 29], [36, 27], [14, 30], [22, 32], [71, 30], [2, 32], [155, 16], [142, 9], [35, 4], [199, 5], [88, 6], [244, 10], [2, 19], [249, 20], [278, 39], [66, 0]],
        [[130, 0], [104, 28], [104, 29], [27, 27], [79, 29], [37, 27], [17, 30], [18, 32], [74, 30], [154, 16], [141, 9], [37, 4], [199, 5], [89, 6], [243, 10], [251, 20], [278, 39], [66, 0]],
        [[129, 0], [104, 28], [105, 29], [31, 27], [75, 29], [36, 27], [21, 30], [15, 32], [76, 30], [152, 16], [140, 9], [39, 4], [197, 5], [91, 6], [243, 10], [250, 20], [278, 39], [66, 0]],
        [[129, 0], [104, 28], [105, 29], [34, 27], [72, 29], [36, 27], [24, 30], [12, 32], [79, 30], [148, 16], [139, 9], [41, 4], [196, 5], [93, 6], [242, 10], [251, 20], [277, 39], [66, 0]],
        [[129, 0], [104, 28], [105, 29], [37, 27], [69, 29], [35, 27], [27, 30], [9, 32], [81, 30], [146, 16], [139, 9], [43, 4], [195, 5], [94, 6], [241, 10], [251, 20], [278, 39], [65, 0]],
        [[129, 0], [104, 28], [104, 29], [41, 27], [65, 29], [36, 27], [29, 30], [7, 32], [84, 30], [143, 16], [138, 9], [44, 4], [194, 5], [96, 6], [241, 10], [250, 20], [278, 39], [65, 0]],
        [[129, 0], [103, 28], [105, 29], [45, 27], [61, 29], [36, 27], [32, 30], [4, 32], [86, 30], [140, 16], [138, 9], [46, 4], [193, 5], [97, 6], [240, 10], [250, 20], [278, 39], [65, 0]],
        [[128, 0], [104, 28], [105, 29], [48, 27], [58, 29], [35, 27], [125, 30], [137, 16], [137, 9], [48, 4], [192, 5], [99, 6], [240, 10], [250, 20], [277, 39], [65, 0]],
        [[128, 0], [104, 28], [105, 29], [52, 27], [53, 29], [36, 27], [127, 30], [135, 16], [136, 9], [50, 4], [191, 5], [100, 6], [239, 10], [250, 20], [277, 39], [65, 0]],
        [[128, 0], [104, 28], [104, 29], [56, 27], [50, 29], [36, 27], [130, 30], [131, 16], [136, 9], [51, 4], [190, 5], [102, 6], [238, 10], [250, 20], [278, 39], [64, 0]],
        [[127, 0], [104, 28], [105, 29], [60, 27], [46, 29], [35, 27], [133, 30], [128, 16], [135, 9], [54, 4], [189, 5], [103, 6], [238, 10], [250, 20], [277, 39], [64, 0]],
        [[127, 0], [104, 28], [105, 29], [63, 27], [42, 29], [36, 27], [135, 30], [126, 16], [134, 9], [55, 4], [188, 5], [105, 6], [237, 10], [250, 20], [277, 39], [64, 0]],
        [[127, 0], [104, 28], [104, 29], [68, 27], [38, 29], [36, 27], [138, 30], [122, 16], [134, 9], [57, 4], [187, 5], [106, 6], [237, 10], [249, 20], [277, 39], [64, 0]],
        [[127, 0], [104, 28], [104, 29], [71, 27], [35, 29], [35, 27], [141, 30], [119, 16], [134, 9], [58, 4], [186, 5], [108, 6], [236, 10], [250, 20], [277, 39], [63, 0]],
        [[127, 0], [104, 28], [104, 29], [74, 27], [31, 29], [36, 27], [142, 30], [118, 16], [133, 9], [60, 4], [185, 5], [108, 6], [236, 10], [250, 20], [277, 39], [63, 0]],
        [[126, 0], [104, 28], [105, 29], [77, 27], [28, 29], [36, 27], [144, 30], [115, 16], [133, 9], [61, 4], [186, 5], [108, 6], [236, 10], [249, 20], [277, 39], [63, 0]],
        [[126, 0], [104, 28], [104, 29], [81, 27], [25, 29], [35, 27], [145, 30], [114, 16], [132, 9], [64, 4], [187, 5], [107, 6], [235, 10], [249, 20], [277, 39], [63, 0]],
        [[126, 0], [104, 28], [104, 29], [85, 27], [20, 29], [36, 27], [144, 30], [115, 16], [131, 9], [65, 4], [189, 5], [106, 6], [235, 10], [249, 20], [276, 39], [63, 0]],
        [[126, 0], [104, 28], [104, 29], [89, 27], [16, 29], [36, 27], [144, 30], [114, 16], [131, 9], [67, 4], [190, 5], [105, 6], [234, 10], [249, 20], [276, 39], [63, 0]],
        [[126, 0], [103, 28], [4, 27], [101, 29], [92, 27], [13, 29], [35, 27], [144, 30], [114, 16], [131, 9], [68, 4], [191, 5], [105, 6], [233, 10], [249, 20], [277, 39], [62, 0]],
        [[125, 0], [104, 28], [9, 27], [95, 29], [97, 27], [9, 29], [35, 27], [144, 30], [114, 16], [130, 9], [70, 4], [192, 5], [104, 6], [233, 10], [248, 20], [277, 39], [62, 0]],
        [[125, 0], [104, 28], [14, 27], [90, 29], [100, 27], [5, 29], [36, 27], [143, 30], [114, 16], [130, 9], [71, 4], [194, 5], [103, 6], [232, 10], [249, 20], [276, 39], [62, 0]],
        [[125, 0], [104, 28], [18, 27], [86, 29], [103, 27], [2, 29], [35, 27], [144, 30], [114, 16], [128, 9], [74, 4], [192, 5], [105, 6], [232, 10], [248, 20], [276, 39], [62, 0]],
        [[125, 0], [103, 28], [24, 27], [81, 29], [140, 27], [144, 30], [113, 16], [128, 9], [75, 4], [192, 5], [105, 6], [232, 10], [248, 20], [276, 39], [62, 0]],
        [[125, 0], [103, 28], [29, 27], [75, 29], [141, 27], [143, 30], [113, 16], [128, 9], [77, 4], [190, 5], [107, 6], [232, 10], [247, 20], [277, 39], [61, 0]],
        [[125, 0], [103, 28], [32, 27], [72, 29], [141, 27], [143, 30], [113, 16], [128, 9], [77, 4], [190, 5], [108, 6], [231, 10], [248, 20], [276, 39], [61, 0]],
        [[124, 0], [104, 28], [36, 27], [68, 29], [140, 27], [143, 30], [113, 16], [128, 9], [79, 4], [81, 5], [10, 2], [97, 5], [110, 6], [230, 10], [248, 20], [276, 39], [61, 0]],
        [[124, 0], [104, 28], [41, 27], [63, 29], [140, 27], [143, 30], [113, 16], [127, 9], [80, 4], [67, 5], [38, 2], [82, 5], [111, 6], [231, 10], [247, 20], [276, 39], [61, 0]],
        [[124, 0], [103, 28], [47, 27], [57, 29], [141, 27], [143, 30], [112, 16], [127, 9], [82, 4], [59, 5], [53, 2], [74, 5], [112, 6], [230, 10], [247, 20], [276, 39], [61, 0]],
        [[124, 0], [103, 28], [51, 27], [53, 29], [140, 27], [143, 30], [113, 16], [125, 9], [84, 4], [53, 5], [65, 2], [67, 5], [114, 6], [229, 10], [248, 20], [275, 39], [61, 0]],
        [[124, 0], [103, 28], [56, 27], [48, 29], [140, 27], [143, 30], [112, 16], [125, 9], [86, 4], [47, 5], [75, 2], [62, 5], [115, 6], [229, 10], [247, 20], [276, 39], [60, 0]],
        [[123, 0], [104, 28], [60, 27], [43, 29], [141, 27], [142, 30], [113, 16], [124, 9], [87, 4], [43, 5], [83, 2], [57, 5], [116, 6], [229, 10], [247, 20], [276, 39], [60, 0]],
        [[123, 0], [103, 28], [66, 27], [38, 29], [140, 27], [143, 30], [112, 16], [124, 9], [89, 4], [38, 5], [91, 2], [52, 5], [118, 6], [229, 10], [246, 20], [276, 39], [60, 0]],
        [[123, 0], [103, 28], [71, 27], [33, 29], [140, 27], [143, 30], [111, 16], [125, 9], [89, 4], [34, 5], [98, 2], [48, 5], [120, 6], [228, 10], [246, 20], [276, 39], [60, 0]],
        [[123, 0], [103, 28], [75, 27], [29, 29], [140, 27], [142, 30], [112, 16], [124, 9], [91, 4], [30, 5], [105, 2], [44, 5], [121, 6], [227, 10], [247, 20], [275, 39], [60, 0]],
        [[123, 0], [103, 28], [80, 27], [24, 29], [140, 27], [142, 30], [111, 16], [124, 9], [93, 4], [26, 5], [110, 2], [41, 5], [123, 6], [227, 10], [246, 20], [275, 39], [60, 0]],
        [[123, 0], [103, 28], [83, 27], [20, 29], [140, 27], [142, 30], [112, 16], [123, 9], [94, 4], [24, 5], [115, 2], [38, 5], [123, 6], [227, 10], [246, 20], [275, 39], [60, 0]],
        [[122, 0], [104, 28], [88, 27], [15, 29], [140, 27], [142, 30], [114, 16], [120, 9], [96, 4], [20, 5], [121, 2], [34, 5], [125, 6], [226, 10], [246, 20], [276, 39], [59, 0]],
        [[122, 0], [103, 28], [93, 27], [11, 29], [140, 27], [142, 30], [116, 16], [117, 9], [97, 4], [17, 5], [126, 2], [32, 5], [126, 6], [226, 10], [246, 20], [275, 39], [59, 0]],
        [[122, 0], [103, 28], [98, 27], [6, 29], [139, 27], [142, 30], [119, 16], [114, 9], [99, 4], [14, 5], [131, 2], [28, 5], [127, 6], [226, 10], [246, 20], [275, 39], [59, 0]],
        [[122, 0], [103, 28], [243, 27], [142, 30], [121, 16], [111, 9], [100, 4], [12, 5], [135, 2], [25, 5], [129, 6], [225, 10], [246, 20], [275, 39], [59, 0]],
        [[122, 0], [103, 28], [243, 27], [142, 30], [123, 16], [108, 9], [102, 4], [8, 5], [140, 2], [23, 5], [130, 6], [225, 10], [245, 20], [275, 39], [59, 0]],
        [[122, 0], [103, 28], [242, 27], [142, 30], [125, 16], [106, 9], [103, 4], [6, 5], [145, 2], [19, 5], [131, 6], [225, 10], [245, 20], [275, 39], [59, 0]],
        [[121, 0], [103, 28], [243, 27], [142, 30], [128, 16], [103, 9], [104, 4], [3, 5], [149, 2], [17, 5], [132, 6], [224, 10], [246, 20], [275, 39], [58, 0]],
        [[121, 0], [103, 28], [243, 27], [142, 30], [129, 16], [101, 9], [105, 4], [1, 5], [153, 2], [14, 5], [134, 6], [224, 10], [245, 20], [275, 39], [58, 0]],
        [[121, 0], [103, 28], [243, 27], [141, 30], [132, 16], [98, 9], [105, 4], [157, 2], [11, 5], [135, 6], [224, 10], [245, 20], [275, 39], [58, 0]],
        [[121, 0], [103, 28], [242, 27], [142, 30], [134, 16], [95, 9], [104, 4], [160, 2], [10, 5], [136, 6], [223, 10], [245, 20], [275, 39], [58, 0]],
        [[121, 0], [102, 28], [243, 27], [141, 30], [137, 16], [92, 9], [104, 4], [163, 2], [7, 5], [138, 6], [223, 10], [244, 20], [275, 39], [58, 0]],
        [[121, 0], [102, 28], [243, 27], [141, 30], [139, 16], [90, 9], [102, 4], [167, 2], [5, 5], [139, 6], [222, 10], [245, 20], [274, 39], [58, 0]],
        [[120, 0], [103, 28], [243, 27], [141, 30], [141, 16], [87, 9], [101, 4], [171, 2], [2, 5], [140, 6], [222, 10], [245, 20], [275, 39], [57, 0]],
        [[120, 0], [103, 28], [242, 27], [141, 30], [144, 16], [84, 9], [100, 4], [174, 2], [1, 5], [141, 6], [222, 10], [244, 20], [275, 39], [57, 0]],
        [[120, 0], [103, 28], [242, 27], [141, 30], [145, 16], [82, 9], [100, 4], [177, 2], [140, 6], [222, 10], [244, 20], [275, 39], [57, 0]],
        [[120, 0], [103, 28], [242, 27], [141, 30], [146, 16], [81, 9], [98, 4], [181, 2], [139, 6], [222, 10], [244, 20], [274, 39], [57, 0]],
        [[120, 0], [102, 28], [242, 27], [141, 30], [147, 16], [80, 9], [97, 4], [184, 2], [139, 6], [221, 10], [244, 20], [274, 39], [57, 0]],
        [[120, 0], [102, 28], [242, 27], [141, 30], [146, 16], [80, 9], [97, 4], [187, 2], [137, 6], [221, 10], [244, 20], [274, 39], [57, 0]],
        [[120, 0], [102, 28], [242, 27], [140, 30], [147, 16], [79, 9], [96, 4], [190, 2], [137, 6], [221, 10], [243, 20], [274, 39], [57, 0]],
        [[119, 0], [103, 28], [242, 27], [140, 30], [146, 16], [79, 9], [96, 4], [193, 2], [135, 6], [221, 10], [244, 20], [274, 39], [56, 0]],
        [[119, 0], [103, 28], [242, 27], [140, 30], [146, 16], [79, 9], [95, 4], [195, 2], [135, 6], [220, 10], [244, 20], [274, 39], [56, 0]],
        [[119, 0], [103, 28], [241, 27], [141, 30], [146, 16], [78, 9], [94, 4], [199, 2], [133, 6], [220, 10], [244, 20], [274, 39], [56, 0]],
        [[119, 0], [102, 28], [242, 27], [140, 30], [146, 16], [78, 9], [94, 4], [201, 2], [133, 6], [220, 10], [243, 20], [274, 39], [56, 0]],
        [[119, 0], [102, 28], [242, 27], [140, 30], [146, 16], [78, 9], [93, 4], [203, 2], [133, 6], [219, 10], [243, 20], [274, 39], [56, 0]],
        [[119, 0], [102, 28], [242, 27], [140, 30], [145, 16], [78, 9], [92, 4], [207, 2], [131, 6], [219, 10], [244, 20], [273, 39], [56, 0]],
        [[119, 0], [102, 28], [241, 27], [140, 30], [146, 16], [77, 9], [92, 4], [209, 2], [131, 6], [219, 10], [243, 20], [273, 39], [56, 0]],
        [[118, 0], [103, 28], [241, 27], [140, 30], [145, 16], [78, 9], [91, 4], [211, 2], [130, 6], [219, 10], [243, 20], [273, 39], [56, 0]],
        [[118, 0], [103, 28], [241, 27], [140, 30], [144, 16], [78, 9], [92, 4], [212, 2], [130, 6], [218, 10], [243, 20], [273, 39], [56, 0]],
        [[118, 0], [102, 28], [242, 27], [139, 30], [145, 16], [77, 9], [94, 4], [212, 2], [129, 6], [218, 10], [243, 20], [274, 39], [55, 0]],
        [[118, 0], [102, 28], [241, 27], [140, 30], [144, 16], [78, 9], [95, 4], [213, 2], [128, 6], [218, 10], [242, 20], [274, 39], [55, 0]],
        [[118, 0], [102, 28], [241, 27], [140, 30], [144, 16], [77, 9], [97, 4], [213, 2], [128, 6], [217, 10], [243, 20], [273, 39], [55, 0]],
        [[118, 0], [102, 28], [241, 27], [139, 30], [145, 16], [77, 9], [98, 4], [213, 2], [127, 6], [217, 10], [243, 20], [273, 39], [55, 0]],
        [[118, 0], [102, 28], [241, 27], [139, 30], [144, 16], [77, 9], [99, 4], [214, 2], [127, 6], [216, 10], [243, 20], [273, 39], [55, 0]],
        [[117, 0], [103, 28], [241, 27], [139, 30], [144, 16], [76, 9], [101, 4], [214, 2], [126, 6], [217, 10], [242, 20], [273, 39], [55, 0]],
        [[117, 0], [103, 28], [240, 27], [140, 30], [143, 16], [76, 9], [103, 4], [213, 2], [127, 6], [216, 10], [242, 20], [273, 39], [55, 0]],
        [[117, 0], [102, 28], [241, 27], [139, 30], [144, 16], [76, 9], [104, 4], [211, 2], [128, 6], [216, 10], [242, 20], [273, 39], [55, 0]],
        [[117, 0], [102, 28], [241, 27], [139, 30], [143, 16], [76, 9], [106, 4], [209, 2], [130, 6], [216, 10], [242, 20], [273, 39], [54, 0]],
        [[117, 0], [102, 28], [241, 27], [139, 30], [143, 16], [76, 9], [106, 4], [208, 2], [131, 6], [216, 10], [242, 20], [273, 39], [54, 0]],
        [[117, 0], [102, 28], [241, 27], [138, 30], [144, 16], [75, 9], [108, 4], [207, 2], [132, 6], [215, 10], [242, 20], [273, 39], [54, 0]],
        [[116, 0], [103, 28], [240, 27], [139, 30], [143, 16], [75, 9], [110, 4], [204, 2], [134, 6], [215, 10], [242, 20], [273, 39], [54, 0]],
        [[116, 0], [103, 28], [240, 27], [139, 30], [143, 16], [75, 9], [111, 4], [202, 2], [136, 6], [215, 10], [241, 20], [273, 39], [54, 0]],
        [[116, 0], [103, 28], [240, 27], [139, 30], [142, 16], [75, 9], [112, 4], [202, 2], [136, 6], [215, 10], [241, 20], [273, 39], [54, 0]],
        [[116, 0], [102, 28], [240, 27], [139, 30], [143, 16], [75, 9], [114, 4], [199, 2], [138, 6], [214, 10], [242, 20], [272, 39], [54, 0]],
        [[116, 0], [102, 28], [240, 27], [139, 30], [143, 16], [74, 9], [115, 4], [198, 2], [139, 6], [214, 10], [242, 20], [272, 39], [54, 0]],
        [[116, 0], [102, 28], [240, 27], [139, 30], [142, 16], [75, 9], [116, 4], [196, 2], [141, 6], [214, 10], [241, 20], [273, 39], [53, 0]],
        [[116, 0], [102, 28], [240, 27], [138, 30], [143, 16], [74, 9], [118, 4], [194, 2], [142, 6], [214, 10], [241, 20], [273, 39], [53, 0]],
        [[116, 0], [102, 28], [240, 27], [138, 30], [142, 16], [75, 9], [119, 4], [192, 2], [143, 6], [214, 10], [241, 20], [273, 39], [53, 0]],
        [[115, 0], [103, 28], [239, 27], [139, 30], [142, 16], [74, 9], [121, 4], [190, 2], [145, 6], [213, 10], [241, 20], [273, 39], [53, 0]],
        [[115, 0], [103, 28], [239, 27], [139, 30], [142, 16], [74, 9], [121, 4], [189, 2], [146, 6], [214, 10], [241, 20], [272, 39], [53, 0]],
        [[115, 0], [102, 28], [240, 27], [138, 30], [142, 16], [74, 9], [123, 4], [187, 2], [148, 6], [213, 10], [241, 20], [272, 39], [53, 0]],
        [[115, 0], [102, 28], [240, 27], [138, 30], [142, 16], [73, 9], [125, 4], [185, 2], [149, 6], [213, 10], [241, 20], [272, 39], [53, 0]],
        [[115, 0], [102, 28], [240, 27], [138, 30], [141, 16], [74, 9], [126, 4], [183, 2], [151, 6], [212, 10], [241, 20], [273, 39], [52, 0]],
        [[115, 0], [102, 28], [240, 27], [138, 30], [141, 16], [73, 9], [127, 4], [183, 2], [151, 6], [212, 10], [241, 20], [273, 39], [52, 0]],
        [[115, 0], [102, 28], [239, 27], [138, 30], [142, 16], [3, 8], [70, 9], [128, 4], [181, 2], [153, 6], [212, 10], [240, 20], [273, 39], [52, 0]],
        [[115, 0], [102, 28], [239, 27], [138, 30], [141, 16], [6, 8], [68, 9], [129, 4], [179, 2], [154, 6], [212, 10], [240, 20], [273, 39], [52, 0]],
        [[115, 0], [102, 28], [239, 27], [138, 30], [141, 16], [9, 8], [64, 9], [131, 4], [177, 2], [155, 6], [212, 10], [241, 20], [272, 39], [52, 0]],
        [[114, 0], [103, 28], [239, 27], [138, 30], [140, 16], [13, 8], [61, 9], [132, 4], [175, 2], [157, 6], [212, 10], [240, 20], [272, 39], [52, 0]],
        [[114, 0], [102, 28], [240, 27], [137, 30], [141, 16], [15, 8], [58, 9], [134, 4], [173, 2], [158, 6], [212, 10], [240, 20], [272, 39], [52, 0]],
        [[114, 0], [102, 28], [239, 27], [138, 30], [141, 16], [18, 8], [55, 9], [134, 4], [172, 2], [160, 6], [211, 10], [240, 20], [272, 39], [52, 0]],
        [[114, 0], [102, 28], [239, 27], [138, 30], [140, 16], [22, 8], [51, 9], [136, 4], [172, 2], [159, 6], [211, 10], [240, 20], [272, 39], [52, 0]],
        [[114, 0], [102, 28], [239, 27], [138, 30], [140, 16], [25, 8], [48, 9], [137, 4], [172, 2], [158, 6], [211, 10], [240, 20], [272, 39], [52, 0]],
        [[114, 0], [102, 28], [239, 27], [137, 30], [141, 16], [27, 8], [45, 9], [139, 4], [172, 2], [158, 6], [211, 10], [239, 20], [273, 39], [51, 0]],
        [[114, 0], [102, 28], [239, 27], [137, 30], [140, 16], [31, 8], [42, 9], [140, 4], [172, 2], [157, 6], [211, 10], [240, 20], [272, 39], [51, 0]],
        [[114, 0], [102, 28], [239, 27], [137, 30], [140, 16], [33, 8], [40, 9], [140, 4], [173, 2], [157, 6], [210, 10], [240, 20], [272, 39], [51, 0]],
        [[114, 0], [102, 28], [238, 27], [138, 30], [140, 16], [36, 8], [36, 9], [142, 4], [173, 2], [156, 6], [210, 10], [240, 20], [272, 39], [51, 0]],
        [[113, 0], [103, 28], [238, 27], [138, 30], [139, 16], [36, 8], [37, 9], [143, 4], [173, 2], [155, 6], [210, 10], [240, 20], [272, 39], [51, 0]],
        [[113, 0], [102, 28], [239, 27], [137, 30], [140, 16], [36, 8], [36, 9], [145, 4], [173, 2], [155, 6], [210, 10], [239, 20], [272, 39], [51, 0]],
        [[113, 0], [102, 28], [239, 27], [137, 30], [140, 16], [36, 8], [36, 9], [145, 4], [174, 2], [154, 6], [210, 10], [239, 20], [272, 39], [51, 0]],
        [[113, 0], [102, 28], [239, 27], [137, 30], [139, 16], [36, 8], [36, 9], [147, 4], [173, 2], [154, 6], [210, 10], [239, 20], [272, 39], [51, 0]],
        [[113, 0], [102, 28], [239, 27], [137, 30], [139, 16], [36, 8], [36, 9], [148, 4], [173, 2], [154, 6], [209, 10], [239, 20], [272, 39], [51, 0]],
        [[113, 0], [102, 28], [239, 27], [137, 30], [139, 16], [35, 8], [37, 9], [149, 4], [173, 2], [153, 6], [209, 10], [240, 20], [271, 39], [51, 0]],
        [[113, 0], [102, 28], [238, 27], [137, 30], [140, 16], [35, 8], [36, 9], [151, 4], [173, 2], [152, 6], [210, 10], [239, 20], [271, 39], [51, 0]],
        [[113, 0], [102, 28], [238, 27], [137, 30], [139, 16], [36, 8], [36, 9], [152, 4], [173, 2], [152, 6], [209, 10], [239, 20], [272, 39], [50, 0]],
        [[113, 0], [102, 28], [238, 27], [137, 30], [139, 16], [36, 8], [35, 9], [153, 4], [174, 2], [151, 6], [209, 10], [239, 20], [272, 39], [50, 0]],
        [[113, 0], [102, 28], [238, 27], [137, 30], [139, 16], [35, 8], [36, 9], [154, 4], [173, 2], [151, 6], [209, 10], [239, 20], [272, 39], [50, 0]],
        [[113, 0], [101, 28], [239, 27], [137, 30], [138, 16], [36, 8], [35, 9], [156, 4], [173, 2], [151, 6], [208, 10], [239, 20], [272, 39], [50, 0]],
        [[113, 0], [101, 28], [239, 27], [136, 30], [139, 16], [36, 8], [35, 9], [157, 4], [173, 2], [150, 6], [208, 10], [239, 20], [272, 39], [50, 0]],
        [[112, 0], [102, 28], [239, 27], [136, 30], [139, 16], [35, 8], [36, 9], [157, 4], [174, 2], [149, 6], [209, 10], [238, 20], [272, 39], [50, 0]],
        [[112, 0], [102, 28], [238, 27], [137, 30], [139, 16], [35, 8], [35, 9], [159, 4], [173, 2], [150, 6], [208, 10], [238, 20], [272, 39], [50, 0]],
        [[112, 0], [102, 28], [238, 27], [137, 30], [138, 16], [36, 8], [35, 9], [159, 4], [174, 2], [149, 6], [208, 10], [239, 20], [271, 39], [50, 0]],
        [[112, 0], [102, 28], [238, 27], [137, 30], [138, 16], [35, 8], [36, 9], [158, 4], [176, 2], [148, 6], [208, 10], [239, 20], [271, 39], [50, 0]],
        [[112, 0], [102, 28], [238, 27], [137, 30], [138, 16], [35, 8], [35, 9], [158, 4], [178, 2], [148, 6], [207, 10], [239, 20], [271, 39], [50, 0]],
        [[112, 0], [102, 28], [238, 27], [136, 30], [139, 16], [35, 8], [35, 9], [157, 4], [179, 2], [148, 6], [207, 10], [239, 20], [271, 39], [50, 0]],
        [[112, 0], [102, 28], [238, 27], [136, 30], [138, 16], [35, 8], [36, 9], [156, 4], [181, 2], [147, 6], [208, 10], [238, 20], [271, 39], [50, 0]],
        [[112, 0], [102, 28], [238, 27], [136, 30], [138, 16], [35, 8], [35, 9], [156, 4], [183, 2], [147, 6], [207, 10], [238, 20], [271, 39], [50, 0]],
        [[112, 0], [102, 28], [238, 27], [136, 30], [103, 16], [4, 8], [31, 16], [35, 8], [35, 9], [155, 4], [184, 2], [147, 6], [207, 10], [238, 20], [272, 39], [49, 0]],
        [[112, 0], [102, 28], [237, 27], [137, 30], [103, 16], [8, 8], [27, 16], [35, 8], [35, 9], [154, 4], [186, 2], [146, 6], [207, 10], [238, 20], [272, 39], [49, 0]],
        [[112, 0], [101, 28], [238, 27], [137, 30], [103, 16], [13, 8], [21, 16], [35, 8], [35, 9], [154, 4], [188, 2], [145, 6], [207, 10], [238, 20], [272, 39], [49, 0]],
        [[112, 0], [101, 28], [238, 27], [136, 30], [103, 16], [19, 8], [16, 16], [35, 8], [35, 9], [153, 4], [189, 2], [146, 6], [206, 10], [238, 20], [272, 39], [49, 0]],
        [[111, 0], [102, 28], [238, 27], [136, 30], [103, 16], [23, 8], [12, 16], [35, 8], [35, 9], [152, 4], [191, 2], [145, 6], [206, 10], [239, 20], [271, 39], [49, 0]],
        [[111, 0], [108, 28], [232, 27], [136, 30], [103, 16], [28, 8], [7, 16], [35, 8], [34, 9], [152, 4], [192, 2], [145, 6], [207, 10], [238, 20], [271, 39], [49, 0]],
        [[111, 0], [120, 28], [220, 27], [136, 30], [103, 16], [32, 8], [2, 16], [35, 8], [35, 9], [151, 4], [65, 2], [20, 1], [109, 2], [144, 6], [207, 10], [238, 20], [271, 39], [49, 0]],
        [[111, 0], [132, 28], [208, 27], [136, 30], [103, 16], [69, 8], [35, 9], [150, 4], [61, 2], [25, 1], [109, 2], [145, 6], [206, 10], [238, 20], [271, 39], [49, 0]],
        [[111, 0], [144, 28], [196, 27], [135, 30], [103, 16], [70, 8], [35, 9], [149, 4], [58, 2], [29, 1], [110, 2], [144, 6], [206, 10], [238, 20], [271, 39], [49, 0]],
        [[111, 0], [157, 28], [182, 27], [136, 30], [103, 16], [70, 8], [34, 9], [152, 4], [53, 2], [32, 1], [111, 2], [143, 6], [206, 10], [238, 20], [271, 39], [49, 0]],
        [[111, 0], [166, 28], [173, 27], [136, 30], [103, 16], [69, 8], [35, 9], [152, 4], [51, 2], [34, 1], [111, 2], [143, 6], [206, 10], [238, 20], [271, 39], [49, 0]],
        [[111, 0], [169, 28], [170, 27], [136, 30], [103, 16], [69, 8], [35, 9], [154, 4], [47, 2], [36, 1], [112, 2], [143, 6], [205, 10], [238, 20], [23, 39], [11, 20], [237, 39], [49, 0]],
        [[111, 0], [169, 28], [170, 27], [136, 30], [103, 16], [69, 8], [35, 9], [155, 4], [43, 2], [39, 1], [112, 2], [143, 6], [205, 10], [239, 20], [10, 39], [23, 20], [237, 39], [49, 0]],
        [[111, 0], [169, 28], [170, 27], [136, 30], [103, 16], [69, 8], [34, 9], [157, 4], [40, 2], [41, 1], [113, 2], [142, 6], [206, 10], [271, 20], [237, 39], [49, 0]],
        [[111, 0], [169, 28], [170, 27], [136, 30], [102, 16], [70, 8], [34, 9], [158, 4], [37, 2], [42, 1], [114, 2], [142, 6], [206, 10], [271, 20], [237, 39], [49, 0]],
        [[111, 0], [169, 28], [170, 27], [136, 30], [102, 16], [75, 8], [29, 9], [160, 4], [34, 2], [43, 1], [115, 2], [142, 6], [205, 10], [271, 20], [237, 39], [49, 0]],
        [[111, 0], [169, 28], [170, 27], [135, 30], [103, 16], [79, 8], [25, 9], [161, 4], [31, 2], [45, 1], [115, 2], [142, 6], [205, 10], [272, 20], [237, 39], [48, 0]],
        [[111, 0], [169, 28], [170, 27], [135, 30], [103, 16], [84, 8], [19, 9], [163, 4], [29, 2], [46, 1], [116, 2], [141, 6], [205, 10], [272, 20], [237, 39], [48, 0]],
        [[111, 0], [169, 28], [170, 27], [135, 30], [103, 16], [88, 8], [15, 9], [164, 4], [27, 2], [47, 1], [116, 2], [141, 6], [205, 10], [272, 20], [237, 39], [48, 0]],
        [[111, 0], [169, 28], [170, 27], [135, 30], [103, 16], [93, 8], [10, 9], [166, 4], [23, 2], [49, 1], [116, 2], [141, 6], [205, 10], [272, 20], [237, 39], [48, 0]],
        [[111, 0], [169, 28], [169, 27], [136, 30], [102, 16], [97, 8], [7, 9], [166, 4], [22, 2], [50, 1], [117, 2], [140, 6], [205, 10], [272, 20], [237, 39], [48, 0]],
        [[110, 0], [170, 28], [169, 27], [136, 30], [102, 16], [102, 8], [1, 9], [169, 4], [19, 2], [50, 1], [118, 2], [141, 6], [204, 10], [272, 20], [237, 39], [48, 0]],
        [[110, 0], [170, 28], [169, 27], [136, 30], [102, 16], [103, 8], [170, 4], [17, 2], [51, 1], [119, 2], [140, 6], [205, 10], [271, 20], [237, 39], [48, 0]],
        [[110, 0], [169, 28], [170, 27], [136, 30], [102, 16], [103, 8], [171, 4], [14, 2], [53, 1], [119, 2], [140, 6], [205, 10], [271, 20], [237, 39], [48, 0]],
        [[110, 0], [169, 28], [170, 27], [135, 30], [103, 16], [103, 8], [172, 4], [12, 2], [54, 1], [119, 2], [140, 6], [205, 10], [271, 20], [237, 39], [48, 0]],
        [[110, 0], [169, 28], [170, 27], [135, 30], [103, 16], [103, 8], [174, 4], [9, 2], [55, 1], [120, 2], [139, 6], [205, 10], [271, 20], [237, 39], [48, 0]],
        [[110, 0], [169, 28], [170, 27], [135, 30], [103, 16], [102, 8], [176, 4], [7, 2], [56, 1], [120, 2], [140, 6], [204, 10], [271, 20], [237, 39], [48, 0]],
        [[110, 0], [169, 28], [170, 27], [135, 30], [102, 16], [103, 8], [177, 4], [6, 2], [56, 1], [121, 2], [139, 6], [32, 10], [2, 6], [170, 10], [271, 20], [237, 39], [48, 0]],
        [[110, 0], [169, 28], [170, 27], [135, 30], [102, 16], [103, 8], [178, 4], [3, 2], [58, 1], [121, 2], [139, 6], [25, 10], [9, 6], [170, 10], [271, 20], [237, 39], [48, 0]],
        [[110, 0], [169, 28], [170, 27], [135, 30], [102, 16], [103, 8], [179, 4], [1, 2], [58, 1], [122, 2], [139, 6], [18, 10], [16, 6], [170, 10], [271, 20], [237, 39], [48, 0]],
        [[110, 0], [169, 28], [170, 27], [135, 30], [102, 16], [102, 8], [181, 4], [58, 1], [123, 2], [138, 6], [11, 10], [23, 6], [170, 10], [272, 20], [236, 39], [48, 0]],
        [[110, 0], [169, 28], [170, 27], [135, 30], [102, 16], [102, 8], [180, 4], [59, 1], [123, 2], [138, 6], [6, 10], [28, 6], [170, 10], [272, 20], [236, 39], [48, 0]],
        [[110, 0], [169, 28], [170, 27], [135, 30], [102, 16], [102, 8], [179, 4], [60, 1], [123, 2], [173, 6], [170, 10], [271, 20], [236, 39], [48, 0]],
        [[110, 0], [169, 28], [169, 27], [136, 30], [102, 16], [102, 8], [179, 4], [60, 1], [123, 2], [173, 6], [170, 10], [271, 20], [236, 39], [48, 0]],
        [[110, 0], [169, 28], [169, 27], [136, 30], [101, 16], [103, 8], [178, 4], [61, 1], [124, 2], [172, 6], [159, 10], [10, 11], [1, 10], [271, 20], [236, 39], [48, 0]],
        [[110, 0], [169, 28], [169, 27], [135, 30], [102, 16], [103, 8], [177, 4], [62, 1], [124, 2], [172, 6], [147, 10], [23, 11], [271, 20], [236, 39], [48, 0]],
        [[110, 0], [169, 28], [169, 27], [135, 30], [102, 16], [102, 8], [177, 4], [62, 1], [125, 2], [172, 6], [135, 10], [35, 11], [271, 20], [236, 39], [48, 0]],
        [[110, 0], [169, 28], [169, 27], [135, 30], [102, 16], [102, 8], [177, 4], [62, 1], [126, 2], [171, 6], [123, 10], [47, 11], [271, 20], [236, 39], [48, 0]],
        [[110, 0], [169, 28], [169, 27], [135, 30], [102, 16], [102, 8], [176, 4], [63, 1], [126, 2], [172, 6], [110, 10], [59, 11], [271, 20], [236, 39], [48, 0]],
        [[110, 0], [169, 28], [169, 27], [135, 30], [102, 16], [102, 8], [176, 4], [63, 1], [126, 2], [172, 6], [98, 10], [71, 11], [271, 20], [237, 39], [47, 0]],
        [[110, 0], [169, 28], [169, 27], [135, 30], [102, 16], [102, 8], [175, 4], [69, 1], [122, 2], [171, 6], [86, 10], [83, 11], [271, 20], [237, 39], [47, 0]],
        [[110, 0], [169, 28], [169, 27], [135, 30], [102, 16], [102, 8], [174, 4], [72, 1], [120, 2], [171, 6], [74, 10], [95, 11], [271, 20], [237, 39], [47, 0]],
        [[110, 0], [168, 28], [170, 27], [135, 30], [102, 16], [102, 8], [174, 4], [75, 1], [117, 2], [171, 6], [65, 10], [104, 11], [271, 20], [237, 39], [47, 0]],
        [[110, 0], [168, 28], [170, 27], [135, 30], [102, 16], [101, 8], [174, 4], [77, 1], [116, 2], [171, 6], [53, 10], [116, 11], [271, 20], [237, 39], [47, 0]],
        [[109, 0], [169, 28], [170, 27], [135, 30], [102, 16], [101, 8], [174, 4], [79, 1], [115, 2], [170, 6], [41, 10], [129, 11], [270, 20], [237, 39], [47, 0]],
        [[109, 0], [169, 28], [169, 27], [136, 30], [101, 16], [102, 8], [173, 4], [82, 1], [113, 2], [170, 6], [29, 10], [141, 11], [270, 20], [237, 39], [47, 0]],
        [[109, 0], [169, 28], [169, 27], [136, 30], [101, 16], [102, 8], [173, 4], [83, 1], [112, 2], [170, 6], [17, 10], [153, 11], [270, 20], [237, 39], [47, 0]],
        [[109, 0], [169, 28], [169, 27], [136, 30], [101, 16], [102, 8], [172, 4], [85, 1], [111, 2], [170, 6], [5, 10], [165, 11], [270, 20], [237, 39], [47, 0]],
        [[109, 0], [169, 28], [169, 27], [136, 30], [101, 16], [102, 8], [172, 4], [86, 1], [110, 2], [170, 6], [170, 11], [270, 20], [237, 39], [47, 0]],
        [[109, 0], [169, 28], [169, 27], [135, 30], [102, 16], [102, 8], [172, 4], [88, 1], [109, 2], [170, 6], [169, 11], [270, 20], [237, 39], [47, 0]],
        [[109, 0], [169, 28], [169, 27], [135, 30], [102, 16], [102, 8], [171, 4], [90, 1], [108, 2], [170, 6], [169, 11], [270, 20], [237, 39], [47, 0]],
        [[109, 0], [169, 28], [169, 27], [135, 30], [102, 16], [102, 8], [171, 4], [90, 1], [108, 2], [170, 6], [169, 11], [270, 20], [237, 39], [47, 0]],
        [[109, 0], [169, 28], [169, 27], [135, 30], [102, 16], [102, 8], [171, 4], [91, 1], [107, 2], [170, 6], [169, 11], [270, 20], [237, 39], [47, 0]],
        [[109, 0], [169, 28], [169, 27], [135, 30], [102, 16], [102, 8], [170, 4], [93, 1], [106, 2], [170, 6], [169, 11], [270, 20], [237, 39], [47, 0]],
        [[109, 0], [169, 28], [169, 27], [135, 30], [102, 16], [113, 8], [159, 4], [94, 1], [105, 2], [170, 6], [169, 11], [270, 20], [237, 39], [47, 0]],
        [[109, 0], [169, 28], [169, 27], [135, 30], [102, 16], [125, 8], [147, 4], [94, 1], [105, 2], [170, 6], [169, 11], [270, 20], [237, 39], [47, 0]],
        [[109, 0], [169, 28], [169, 27], [135, 30], [102, 16], [135, 8], [137, 4], [95, 1], [105, 2], [169, 6], [169, 11], [270, 20], [237, 39], [47, 0]],
        [[109, 0], [169, 28], [169, 27], [135, 30], [102, 16], [135, 8], [136, 4], [96, 1], [105, 2], [169, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [169, 27], [135, 30], [102, 16], [135, 8], [136, 4], [97, 1], [104, 2], [169, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [169, 27], [135, 30], [102, 16], [135, 8], [136, 4], [97, 1], [104, 2], [169, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [169, 27], [135, 30], [102, 16], [135, 8], [136, 4], [98, 1], [103, 2], [169, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [169, 27], [135, 30], [102, 16], [135, 8], [136, 4], [98, 1], [103, 2], [169, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [169, 27], [135, 30], [102, 16], [135, 8], [135, 4], [99, 1], [103, 2], [169, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [169, 27], [135, 30], [102, 16], [135, 8], [135, 4], [100, 1], [102, 2], [169, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [102, 16], [135, 8], [135, 4], [100, 1], [102, 2], [169, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [102, 16], [135, 8], [135, 4], [100, 1], [102, 2], [169, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [38, 15], [64, 16], [134, 8], [136, 4], [100, 1], [102, 2], [169, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [34, 16], [134, 8], [136, 4], [101, 1], [101, 2], [169, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [34, 16], [134, 8], [136, 4], [101, 1], [101, 2], [169, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [34, 16], [134, 8], [136, 4], [101, 1], [101, 2], [169, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [33, 16], [135, 8], [136, 4], [101, 1], [102, 2], [26, 6], [7, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [33, 16], [135, 8], [136, 4], [101, 1], [135, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [33, 16], [135, 8], [136, 4], [101, 1], [135, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [33, 16], [135, 8], [136, 4], [101, 1], [135, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [33, 16], [135, 8], [136, 4], [101, 1], [135, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [33, 16], [135, 8], [136, 4], [101, 1], [135, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [33, 16], [135, 8], [136, 4], [101, 1], [135, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [33, 16], [135, 8], [136, 4], [101, 1], [135, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [34, 16], [134, 8], [136, 4], [101, 1], [135, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [34, 16], [134, 8], [136, 4], [101, 1], [135, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [34, 16], [134, 8], [136, 4], [100, 1], [136, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [34, 16], [135, 8], [135, 4], [100, 1], [136, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [34, 16], [135, 8], [135, 4], [100, 1], [136, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [34, 16], [135, 8], [135, 4], [100, 1], [136, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [34, 16], [135, 8], [135, 4], [101, 1], [135, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [34, 16], [135, 8], [136, 4], [103, 1], [132, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [34, 16], [135, 8], [136, 4], [106, 1], [129, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [34, 16], [135, 8], [136, 4], [109, 1], [126, 2], [135, 6], [169, 11], [271, 20], [202, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [34, 16], [135, 8], [136, 4], [112, 1], [123, 2], [135, 6], [169, 11], [270, 20], [203, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [34, 16], [135, 8], [136, 4], [115, 1], [120, 2], [135, 6], [169, 11], [270, 20], [203, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [30, 16], [4, 15], [135, 8], [137, 4], [117, 1], [116, 2], [136, 6], [169, 11], [270, 20], [203, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [68, 15], [10, 16], [24, 15], [135, 8], [137, 4], [120, 1], [113, 2], [136, 6], [169, 11], [270, 20], [203, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [102, 15], [135, 8], [137, 4], [124, 1], [109, 2], [136, 6], [169, 11], [270, 20], [203, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [102, 15], [135, 8], [33, 4], [2, 8], [103, 4], [126, 1], [106, 2], [136, 6], [169, 11], [270, 20], [203, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [102, 15], [135, 8], [24, 4], [11, 8], [103, 4], [129, 1], [103, 2], [136, 6], [169, 11], [270, 20], [203, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [101, 30], [102, 15], [135, 8], [18, 4], [17, 8], [103, 4], [128, 1], [104, 2], [136, 6], [169, 11], [270, 20], [203, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [102, 30], [101, 15], [136, 8], [8, 4], [26, 8], [103, 4], [128, 1], [104, 2], [136, 6], [169, 11], [270, 20], [203, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [102, 30], [101, 15], [170, 8], [104, 4], [127, 1], [104, 2], [136, 6], [169, 11], [270, 20], [203, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [102, 30], [101, 15], [170, 8], [104, 4], [126, 1], [105, 2], [135, 6], [170, 11], [270, 20], [203, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [102, 30], [101, 15], [170, 8], [105, 4], [125, 1], [104, 2], [136, 6], [170, 11], [34, 20], [7, 21], [229, 20], [203, 39], [81, 0]],
        [[109, 0], [169, 28], [203, 27], [102, 30], [101, 15], [170, 8], [105, 4], [124, 1], [105, 2], [136, 6], [170, 11], [34, 20], [28, 21], [208, 20], [203, 39], [81, 0]],
        [[109, 0], [169, 28], [204, 27], [101, 30], [102, 15], [170, 8], [104, 4], [124, 1], [105, 2], [136, 6], [170, 11], [34, 20], [48, 21], [188, 20], [203, 39], [81, 0]],
        [[109, 0], [170, 28], [203, 27], [101, 30], [102, 15], [170, 8], [105, 4], [123, 1], [105, 2], [136, 6], [170, 11], [33, 20], [70, 21], [167, 20], [203, 39], [81, 0]],
        [[109, 0], [170, 28], [203, 27], [101, 30], [102, 15], [170, 8], [106, 4], [121, 1], [106, 2], [136, 6], [170, 11], [33, 20], [90, 21], [147, 20], [203, 39], [81, 0]],
        [[110, 0], [169, 28], [203, 27], [101, 30], [102, 15], [170, 8], [106, 4], [121, 1], [106, 2], [136, 6], [169, 11], [34, 20], [101, 21], [136, 20], [203, 39], [81, 0]],
        [[110, 0], [169, 28], [203, 27], [101, 30], [102, 15], [170, 8], [107, 4], [119, 1], [106, 2], [137, 6], [169, 11], [34, 20], [101, 21], [136, 20], [203, 39], [81, 0]],
        [[110, 0], [169, 28], [203, 27], [101, 30], [102, 15], [171, 8], [106, 4], [119, 1], [106, 2], [137, 6], [169, 11], [34, 20], [101, 21], [136, 20], [203, 39], [81, 0]],
        [[110, 0], [169, 28], [203, 27], [101, 30], [102, 15], [171, 8], [107, 4], [117, 1], [107, 2], [137, 6], [169, 11], [34, 20], [101, 21], [136, 20], [203, 39], [81, 0]],
        [[110, 0], [169, 28], [203, 27], [101, 30], [102, 15], [171, 8], [107, 4], [116, 1], [108, 2], [137, 6], [169, 11], [34, 20], [101, 21], [136, 20], [203, 39], [81, 0]],
        [[110, 0], [169, 28], [203, 27], [101, 30], [102, 15], [171, 8], [108, 4], [115, 1], [108, 2], [136, 6], [170, 11], [34, 20], [101, 21], [136, 20], [203, 39], [81, 0]],
        [[110, 0], [169, 28], [203, 27], [101, 30], [102, 15], [171, 8], [109, 4], [113, 1], [108, 2], [137, 6], [170, 11], [34, 20], [101, 21], [136, 20], [203, 39], [81, 0]],
        [[110, 0], [169, 28], [203, 27], [101, 30], [102, 15], [172, 8], [108, 4], [112, 1], [109, 2], [137, 6], [170, 11], [34, 20], [101, 21], [136, 20], [11, 21], [192, 39], [81, 0]],
        [[110, 0], [169, 28], [203, 27], [102, 30], [102, 15], [171, 8], [109, 4], [110, 1], [110, 2], [137, 6], [170, 11], [34, 20], [101, 21], [136, 20], [32, 21], [171, 39], [81, 0]],
        [[110, 0], [169, 28], [203, 27], [102, 30], [102, 15], [171, 8], [110, 4], [109, 1], [110, 2], [137, 6], [170, 11], [34, 20], [101, 21], [136, 20], [52, 21], [151, 39], [81, 0]],
        [[110, 0], [169, 28], [203, 27], [102, 30], [102, 15], [171, 8], [110, 4], [108, 1], [110, 2], [137, 6], [170, 11], [35, 20], [101, 21], [136, 20], [67, 21], [136, 39], [81, 0]],
        [[110, 0], [169, 28], [203, 27], [102, 30], [102, 15], [172, 8], [110, 4], [106, 1], [111, 2], [137, 6], [170, 11], [35, 20], [101, 21], [136, 20], [67, 21], [135, 39], [82, 0]],
        [[110, 0], [169, 28], [203, 27], [102, 30], [102, 15], [172, 8], [111, 4], [104, 1], [115, 2], [134, 6], [170, 11], [35, 20], [101, 21], [136, 20], [67, 21], [135, 39], [82, 0]],
        [[110, 0], [169, 28], [203, 27], [102, 30], [102, 15], [172, 8], [112, 4], [103, 1], [118, 2], [131, 6], [170, 11], [34, 20], [102, 21], [135, 20], [68, 21], [135, 39], [82, 0]],
        [[110, 0], [169, 28], [204, 27], [101, 30], [102, 15], [172, 8], [113, 4], [101, 1], [124, 2], [126, 6], [170, 11], [34, 20], [102, 21], [135, 20], [68, 21], [135, 39], [82, 0]],
        [[108, 0], [171, 28], [204, 27], [101, 30], [102, 15], [173, 8], [113, 4], [99, 1], [128, 2], [123, 6], [170, 11], [34, 20], [102, 21], [135, 20], [68, 21], [135, 39], [82, 0]],
        [[88, 0], [191, 28], [204, 27], [101, 30], [103, 15], [172, 8], [114, 4], [97, 1], [133, 2], [119, 6], [170, 11], [34, 20], [101, 21], [136, 20], [68, 21], [135, 39], [82, 0]],
        [[76, 0], [203, 28], [204, 27], [101, 30], [103, 15], [172, 8], [115, 4], [95, 1], [138, 2], [115, 6], [170, 11], [34, 20], [101, 21], [136, 20], [68, 21], [135, 39], [82, 0]],
        [[77, 0], [202, 28], [204, 27], [101, 30], [103, 15], [172, 8], [116, 4], [93, 1], [143, 2], [110, 6], [171, 11], [34, 20], [101, 21], [136, 20], [68, 21], [135, 39], [82, 0]],
        [[77, 0], [203, 28], [203, 27], [102, 30], [102, 15], [173, 8], [116, 4], [91, 1], [148, 2], [106, 6], [171, 11], [34, 20], [101, 21], [136, 20], [68, 21], [135, 39], [82, 0]],
        [[77, 0], [203, 28], [203, 27], [102, 30], [102, 15], [173, 8], [117, 4], [89, 1], [152, 2], [103, 6], [170, 11], [35, 20], [101, 21], [136, 20], [68, 21], [135, 39], [82, 0]],
        [[77, 0], [203, 28], [203, 27], [102, 30], [102, 15], [173, 8], [118, 4], [86, 1], [153, 2], [104, 6], [170, 11], [35, 20], [101, 21], [136, 20], [68, 21], [135, 39], [82, 0]],
        [[77, 0], [203, 28], [203, 27], [102, 30], [102, 15], [174, 8], [118, 4], [84, 1], [154, 2], [104, 6], [170, 11], [35, 20], [101, 21], [136, 20], [68, 21], [135, 39], [82, 0]],
        [[77, 0], [203, 28], [203, 27], [102, 30], [103, 15], [173, 8], [119, 4], [82, 1], [155, 2], [104, 6], [170, 11], [34, 20], [102, 21], [136, 20], [68, 21], [135, 39], [82, 0]],
        [[77, 0], [203, 28], [203, 27], [102, 30], [103, 15], [173, 8], [119, 4], [2, 3], [79, 1], [1, 3], [155, 2], [103, 6], [171, 11], [34, 20], [102, 21], [136, 20], [67, 21], [136, 39], [82, 0]],
        [[77, 0], [203, 28], [204, 27], [101, 30], [103, 15], [174, 8], [117, 4], [4, 3], [76, 1], [4, 3], [153, 2], [104, 6], [173, 11], [32, 20], [102, 21], [136, 20], [67, 21], [136, 39], [82, 0]],
        [[77, 0], [203, 28], [204, 27], [101, 30], [103, 15], [174, 8], [116, 4], [7, 3], [73, 1], [6, 3], [152, 2], [104, 6], [182, 11], [23, 20], [102, 21], [136, 20], [67, 21], [136, 39], [82, 0]],
        [[77, 0], [203, 28], [204, 27], [102, 30], [102, 15], [174, 8], [116, 4], [8, 3], [70, 1], [9, 3], [150, 2], [105, 6], [190, 11], [15, 20], [102, 21], [135, 20], [68, 21], [136, 39], [82, 0]],
        [[77, 0], [203, 28], [204, 27], [102, 30], [102, 15], [175, 8], [114, 4], [11, 3], [66, 1], [11, 3], [150, 2], [105, 6], [199, 11], [6, 20], [101, 21], [136, 20], [68, 21], [136, 39], [82, 0]],
        [[77, 0], [203, 28], [204, 27], [30, 30], [4, 27], [68, 30], [103, 15], [174, 8], [113, 4], [14, 3], [62, 1], [14, 3], [149, 2], [104, 6], [206, 11], [101, 21], [136, 20], [68, 21], [136, 39], [82, 0]],
        [[77, 0], [203, 28], [204, 27], [21, 30], [13, 27], [68, 30], [103, 15], [175, 8], [112, 4], [16, 3], [58, 1], [17, 3], [148, 2], [104, 6], [205, 11], [102, 21], [136, 20], [68, 21], [135, 39], [83, 0]],
        [[77, 0], [203, 28], [204, 27], [12, 30], [22, 27], [68, 30], [103, 15], [175, 8], [111, 4], [20, 3], [53, 1], [20, 3], [146, 2], [105, 6], [205, 11], [102, 21], [136, 20], [68, 21], [135, 39], [83, 0]],
        [[77, 0], [203, 28], [204, 27], [4, 30], [30, 27], [68, 30], [103, 15], [176, 8], [109, 4], [23, 3], [49, 1], [23, 3], [145, 2], [105, 6], [205, 11], [102, 21], [136, 20], [68, 21], [135, 39], [83, 0]],
        [[77, 0], [204, 28], [237, 27], [68, 30], [103, 15], [176, 8], [108, 4], [27, 3], [43, 1], [26, 3], [145, 2], [105, 6], [205, 11], [102, 21], [136, 20], [68, 21], [135, 39], [83, 0]],
        [[77, 0], [204, 28], [238, 27], [67, 30], [103, 15], [176, 8], [108, 4], [29, 3], [38, 1], [30, 3], [143, 2], [105, 6], [206, 11], [102, 21], [136, 20], [68, 21], [135, 39], [83, 0]],
        [[77, 0], [204, 28], [238, 27], [68, 30], [103, 15], [176, 8], [106, 4], [35, 3], [29, 1], [35, 3], [142, 2], [105, 6], [206, 11], [102, 21], [136, 20], [68, 21], [135, 39], [83, 0]],
        [[78, 0], [203, 28], [238, 27], [68, 30], [103, 15], [176, 8], [105, 4], [42, 3], [16, 1], [42, 3], [142, 2], [105, 6], [206, 11], [102, 21], [136, 20], [68, 21], [135, 39], [83, 0]],
        [[78, 0], [203, 28], [238, 27], [68, 30], [103, 15], [177, 8], [103, 4], [102, 3], [140, 2], [106, 6], [206, 11], [102, 21], [136, 20], [68, 21], [135, 39], [83, 0]],
        [[78, 0], [203, 28], [238, 27], [68, 30], [103, 15], [177, 8], [102, 4], [104, 3], [139, 2], [106, 6], [205, 11], [102, 21], [137, 20], [67, 21], [136, 39], [83, 0]],
        [[78, 0], [203, 28], [238, 27], [68, 30], [103, 15], [177, 8], [102, 4], [105, 3], [138, 2], [105, 6], [206, 11], [102, 21], [136, 20], [68, 21], [136, 39], [83, 0]],
        [[78, 0], [203, 28], [238, 27], [69, 30], [103, 15], [177, 8], [100, 4], [106, 3], [137, 2], [106, 6], [206, 11], [102, 21], [136, 20], [68, 21], [136, 39], [83, 0]],
        [[78, 0], [203, 28], [239, 27], [68, 30], [103, 15], [177, 8], [99, 4], [108, 3], [136, 2], [106, 6], [206, 11], [105, 21], [133, 20], [68, 21], [136, 39], [83, 0]],
        [[78, 0], [203, 28], [239, 27], [68, 30], [103, 15], [178, 8], [97, 4], [110, 3], [134, 2], [107, 6], [206, 11], [114, 21], [124, 20], [68, 21], [136, 39], [83, 0]],
        [[78, 0], [203, 28], [239, 27], [68, 30], [103, 15], [178, 8], [97, 4], [111, 3], [133, 2], [106, 6], [207, 11], [122, 21], [116, 20], [68, 21], [136, 39], [83, 0]],
        [[78, 0], [203, 28], [239, 27], [68, 30], [103, 15], [179, 8], [95, 4], [112, 3], [133, 2], [106, 6], [207, 11], [129, 21], [109, 20], [68, 21], [136, 39], [83, 0]],
        [[78, 0], [204, 28], [238, 27], [68, 30], [104, 15], [178, 8], [94, 4], [114, 3], [131, 2], [107, 6], [207, 11], [137, 21], [101, 20], [68, 21], [135, 39], [84, 0]],
        [[78, 0], [204, 28], [238, 27], [69, 30], [103, 15], [179, 8], [93, 4], [115, 3], [130, 2], [107, 6], [206, 11], [147, 21], [92, 20], [68, 21], [135, 39], [84, 0]],
        [[78, 0], [204, 28], [238, 27], [69, 30], [103, 15], [179, 8], [83, 4], [3, 3], [6, 4], [117, 3], [128, 2], [107, 6], [207, 11], [156, 21], [83, 20], [68, 21], [135, 39], [84, 0]],
        [[78, 0], [204, 28], [239, 27], [68, 30], [103, 15], [180, 8], [81, 4], [5, 3], [4, 4], [118, 3], [128, 2], [107, 6], [207, 11], [164, 21], [75, 20], [68, 21], [135, 39], [84, 0]],
        [[78, 0], [204, 28], [239, 27], [68, 30], [104, 15], [179, 8], [80, 4], [7, 3], [2, 4], [120, 3], [127, 2], [107, 6], [207, 11], [173, 21], [65, 20], [68, 21], [136, 39], [84, 0]],
        [[79, 0], [203, 28], [239, 27], [68, 30], [104, 15], [180, 8], [79, 4], [130, 3], [125, 2], [108, 6], [207, 11], [181, 21], [57, 20], [68, 21], [136, 39], [84, 0]],
        [[79, 0], [203, 28], [239, 27], [69, 30], [103, 15], [180, 8], [78, 4], [132, 3], [124, 2], [107, 6], [208, 11], [190, 21], [48, 20], [68, 21], [136, 39], [84, 0]],
        [[79, 0], [203, 28], [239, 27], [69, 30], [104, 15], [180, 8], [76, 4], [133, 3], [123, 2], [108, 6], [207, 11], [200, 21], [39, 20], [68, 21], [136, 39], [84, 0]],
        [[79, 0], [203, 28], [31, 27], [4, 42], [204, 27], [69, 30], [104, 15], [181, 8], [74, 4], [135, 3], [122, 2], [108, 6], [207, 11], [208, 21], [31, 20], [68, 21], [136, 39], [84, 0]],
        [[79, 0], [204, 28], [22, 27], [12, 42], [204, 27], [69, 30], [104, 15], [181, 8], [73, 4], [137, 3], [120, 2], [108, 6], [208, 11], [217, 21], [22, 20], [68, 21], [136, 39], [84, 0]],
        [[79, 0], [204, 28], [15, 27], [19, 42], [205, 27], [68, 30], [104, 15], [182, 8], [71, 4], [138, 3], [120, 2], [108, 6], [208, 11], [223, 21], [16, 20], [68, 21], [136, 39], [84, 0]],
        [[79, 0], [204, 28], [7, 27], [27, 42], [205, 27], [68, 30], [105, 15], [181, 8], [70, 4], [140, 3], [118, 2], [109, 6], [208, 11], [232, 21], [7, 20], [68, 21], [136, 39], [84, 0]],
        [[79, 0], [202, 28], [36, 42], [205, 27], [69, 30], [104, 15], [182, 8], [68, 4], [142, 3], [117, 2], [109, 6], [208, 11], [307, 21], [135, 39], [85, 0]],
        [[79, 0], [193, 28], [45, 42], [205, 27], [69, 30], [104, 15], [183, 8], [67, 4], [143, 3], [115, 2], [109, 6], [208, 11], [308, 21], [135, 39], [85, 0]],
        [[79, 0], [185, 28], [53, 42], [205, 27], [69, 30], [105, 15], [182, 8], [66, 4], [145, 3], [114, 2], [109, 6], [208, 11], [307, 21], [136, 39], [85, 0]],
        [[79, 0], [176, 28], [62, 42], [206, 27], [68, 30], [105, 15], [183, 8], [64, 4], [146, 3], [113, 2], [109, 6], [209, 11], [307, 21], [136, 39], [85, 0]],
        [[80, 0], [166, 28], [71, 42], [206, 27], [68, 30], [105, 15], [184, 8], [62, 4], [148, 3], [112, 2], [109, 6], [209, 11], [307, 21], [136, 39], [85, 0]],
        [[80, 0], [158, 28], [80, 42], [205, 27], [69, 30], [104, 15], [184, 8], [61, 4], [150, 3], [110, 2], [110, 6], [209, 11], [307, 21], [136, 39], [85, 0]],
        [[80, 0], [149, 28], [89, 42], [205, 27], [69, 30], [105, 15], [184, 8], [59, 4], [152, 3], [109, 2], [110, 6], [209, 11], [307, 21], [136, 39], [85, 0]],
        [[80, 0], [141, 28], [97, 42], [206, 27], [68, 30], [105, 15], [185, 8], [57, 4], [153, 3], [108, 2], [110, 6], [209, 11], [308, 21], [136, 39], [85, 0]],
        [[80, 0], [132, 28], [106, 42], [206, 27], [68, 30], [105, 15], [185, 8], [56, 4], [155, 3], [107, 2], [111, 6], [208, 11], [308, 21], [135, 39], [86, 0]],
        [[80, 0], [126, 28], [112, 42], [206, 27], [69, 30], [104, 15], [186, 8], [55, 4], [156, 3], [105, 2], [114, 6], [206, 11], [308, 21], [135, 39], [86, 0]],
        [[80, 0], [117, 28], [121, 42], [206, 27], [69, 30], [105, 15], [185, 8], [54, 4], [157, 3], [105, 2], [118, 6], [202, 11], [308, 21], [135, 39], [86, 0]],
        [[80, 0], [108, 28], [130, 42], [206, 27], [69, 30], [105, 15], [186, 8], [52, 4], [159, 3], [103, 2], [122, 6], [199, 11], [307, 21], [136, 39], [86, 0]],
        [[80, 0], [100, 28], [138, 42], [206, 27], [69, 30], [105, 15], [187, 8], [50, 4], [161, 3], [102, 2], [125, 6], [195, 11], [308, 21], [136, 39], [86, 0]],
        [[80, 0], [91, 28], [148, 42], [206, 27], [68, 30], [106, 15], [187, 8], [48, 4], [163, 3], [100, 2], [129, 6], [192, 11], [308, 21], [136, 39], [86, 0]],
        [[81, 0], [82, 28], [156, 42], [206, 27], [69, 30], [105, 15], [145, 8], [2, 7], [41, 8], [46, 4], [164, 3], [100, 2], [132, 6], [189, 11], [308, 21], [136, 39], [86, 0]],
        [[81, 0], [73, 28], [165, 42], [206, 27], [69, 30], [105, 15], [70, 8], [2, 7], [71, 8], [5, 7], [40, 8], [46, 4], [165, 3], [11, 2], [1, 3], [86, 2], [136, 6], [186, 11], [308, 21], [136, 39], [86, 0]],
        [[81, 0], [64, 28], [174, 42], [206, 27], [69, 30], [106, 15], [66, 8], [6, 7], [69, 8], [6, 7], [41, 8], [44, 4], [167, 3], [8, 2], [4, 3], [84, 2], [140, 6], [183, 11], [308, 21], [136, 39], [86, 0]],
        [[81, 0], [56, 28], [182, 42], [206, 27], [69, 30], [106, 15], [64, 8], [8, 7], [67, 8], [9, 7], [41, 8], [42, 4], [169, 3], [6, 2], [6, 3], [83, 2], [143, 6], [179, 11], [309, 21], [136, 39], [86, 0]],
        [[81, 0], [47, 28], [191, 42], [207, 27], [69, 30], [105, 15], [61, 8], [12, 7], [64, 8], [12, 7], [41, 8], [40, 4], [171, 3], [4, 2], [8, 3], [81, 2], [147, 6], [176, 11], [309, 21], [135, 39], [87, 0]],
        [[81, 0], [41, 28], [197, 42], [207, 27], [69, 30], [106, 15], [59, 8], [13, 7], [63, 8], [13, 7], [41, 8], [39, 4], [172, 3], [3, 2], [9, 3], [80, 2], [149, 6], [175, 11], [308, 21], [136, 39], [87, 0]],
        [[81, 0], [32, 28], [207, 42], [206, 27], [69, 30], [106, 15], [56, 8], [16, 7], [61, 8], [16, 7], [41, 8], [38, 4], [173, 3], [1, 2], [11, 3], [79, 2], [149, 6], [175, 11], [308, 21], [102, 39], [3, 0], [31, 39], [87, 0]],
        [[81, 0], [23, 28], [216, 42], [206, 27], [69, 30], [106, 15], [53, 8], [20, 7], [58, 8], [18, 7], [42, 8], [35, 4], [188, 3], [77, 2], [149, 6], [176, 11], [308, 21], [102, 39], [11, 0], [23, 39], [87, 0]],
        [[82, 0], [14, 28], [224, 42], [206, 27], [70, 30], [106, 15], [50, 8], [22, 7], [56, 8], [21, 7], [42, 8], [34, 4], [189, 3], [76, 2], [149, 6], [175, 11], [309, 21], [102, 39], [20, 0], [14, 39], [87, 0]],
        [[82, 0], [5, 28], [233, 42], [207, 27], [69, 30], [106, 15], [48, 8], [25, 7], [54, 8], [23, 7], [42, 8], [32, 4], [191, 3], [74, 2], [150, 6], [175, 11], [309, 21], [102, 39], [29, 0], [5, 39], [87, 0]],
        [[77, 0], [243, 42], [207, 27], [69, 30], [106, 15], [45, 8], [28, 7], [52, 8], [25, 7], [43, 8], [30, 4], [192, 3], [73, 2], [150, 6], [176, 11], [309, 21], [102, 39], [121, 0]],
        [[68, 0], [253, 42], [206, 27], [69, 30], [107, 15], [41, 8], [32, 7], [49, 8], [28, 7], [41, 8], [2, 7], [28, 4], [194, 3], [72, 2], [150, 6], [176, 11], [309, 21], [102, 39], [121, 0]],
        [[60, 0], [261, 42], [206, 27], [70, 30], [106, 15], [39, 8], [34, 7], [47, 8], [31, 7], [39, 8], [4, 7], [26, 4], [196, 3], [70, 2], [151, 6], [175, 11], [309, 21], [103, 39], [121, 0]],
        [[51, 0], [270, 42], [207, 27], [69, 30], [106, 15], [37, 8], [37, 7], [45, 8], [33, 7], [36, 8], [7, 7], [24, 4], [198, 3], [68, 2], [151, 6], [176, 11], [309, 21], [102, 39], [122, 0]],
        [[42, 0], [279, 42], [207, 27], [69, 30], [107, 15], [34, 8], [2, 15], [37, 7], [43, 8], [35, 7], [35, 8], [9, 7], [22, 4], [200, 3], [67, 2], [151, 6], [176, 11], [309, 21], [102, 39], [122, 0]],
        [[34, 0], [287, 42], [207, 27], [70, 30], [106, 15], [31, 8], [6, 15], [37, 7], [40, 8], [38, 7], [33, 8], [11, 7], [21, 4], [201, 3], [65, 2], [151, 6], [177, 11], [309, 21], [102, 39], [122, 0]],
        [[27, 0], [294, 42], [207, 27], [70, 30], [107, 15], [28, 8], [8, 15], [37, 7], [39, 8], [40, 7], [31, 8], [12, 7], [20, 4], [203, 3], [63, 2], [152, 6], [176, 11], [310, 21], [102, 39], [122, 0]],
        [[18, 0], [304, 42], [206, 27], [70, 30], [107, 15], [26, 8], [10, 15], [37, 7], [37, 8], [42, 7], [30, 8], [14, 7], [18, 4], [204, 3], [63, 2], [152, 6], [176, 11], [310, 21], [102, 39], [122, 0]],
        [[15, 0], [307, 42], [207, 27], [70, 30], [106, 15], [23, 8], [14, 15], [37, 7], [34, 8], [45, 7], [28, 8], [16, 7], [16, 4], [206, 3], [61, 2], [152, 6], [177, 11], [309, 21], [103, 39], [122, 0]],
        [[15, 0], [307, 42], [207, 27], [70, 30], [107, 15], [20, 8], [16, 15], [38, 7], [31, 8], [48, 7], [26, 8], [18, 7], [14, 4], [208, 3], [59, 2], [153, 6], [177, 11], [309, 21], [103, 39], [122, 0]],
        [[15, 0], [307, 42], [207, 27], [70, 30], [107, 15], [17, 8], [20, 15], [37, 7], [29, 8], [50, 7], [25, 8], [20, 7], [12, 4], [210, 3], [57, 2], [154, 6], [176, 11], [310, 21], [103, 39], [122, 0]],
        [[15, 0], [307, 42], [207, 27], [70, 30], [108, 15], [14, 8], [22, 15], [38, 7], [27, 8], [52, 7], [22, 8], [23, 7], [10, 4], [212, 3], [55, 2], [154, 6], [177, 11], [310, 21], [103, 39], [122, 0]],
        [[15, 0], [307, 42], [208, 27], [70, 30], [107, 15], [11, 8], [25, 15], [38, 7], [25, 8], [55, 7], [20, 8], [25, 7], [9, 4], [213, 3], [54, 2], [154, 6], [177, 11], [310, 21], [102, 39], [123, 0]],
        [[15, 0], [308, 42], [207, 27], [70, 30], [107, 15], [9, 8], [28, 15], [38, 7], [22, 8], [58, 7], [18, 8], [28, 7], [6, 4], [215, 3], [54, 2], [152, 6], [178, 11], [310, 21], [102, 39], [123, 0]],
        [[15, 0], [308, 42], [207, 27], [70, 30], [108, 15], [5, 8], [31, 15], [38, 7], [21, 8], [60, 7], [16, 8], [30, 7], [4, 4], [216, 3], [56, 2], [150, 6], [177, 11], [311, 21], [102, 39], [123, 0]],
        [[15, 0], [308, 42], [208, 27], [70, 30], [107, 15], [3, 8], [34, 15], [38, 7], [18, 8], [62, 7], [15, 8], [32, 7], [2, 4], [218, 3], [56, 2], [149, 6], [177, 11], [310, 21], [103, 39], [123, 0]],
        [[15, 0], [308, 42], [208, 27], [70, 30], [144, 15], [38, 7], [16, 8], [65, 7], [13, 8], [34, 7], [220, 3], [56, 2], [147, 6], [178, 11], [310, 21], [103, 39], [123, 0]],
        [[16, 0], [307, 42], [208, 27], [70, 30], [145, 15], [38, 7], [14, 8], [67, 7], [11, 8], [36, 7], [220, 3], [56, 2], [146, 6], [178, 11], [310, 21], [103, 39], [123, 0]],
        [[16, 0], [307, 42], [208, 27], [70, 30], [145, 15], [38, 7], [12, 8], [70, 7], [9, 8], [38, 7], [220, 3], [57, 2], [144, 6], [177, 11], [311, 21], [103, 39], [123, 0]],
        [[16, 0], [308, 42], [207, 27], [71, 30], [145, 15], [38, 7], [9, 8], [73, 7], [7, 8], [40, 7], [220, 3], [57, 2], [142, 6], [178, 11], [311, 21], [102, 39], [124, 0]],
        [[16, 0], [308, 42], [208, 27], [70, 30], [145, 15], [38, 7], [7, 8], [76, 7], [4, 8], [44, 7], [219, 3], [57, 2], [140, 6], [179, 11], [311, 21], [102, 39], [124, 0]],
        [[16, 0], [308, 42], [208, 27], [70, 30], [146, 15], [38, 7], [5, 8], [77, 7], [3, 8], [46, 7], [219, 3], [57, 2], [139, 6], [179, 11], [310, 21], [103, 39], [124, 0]],
        [[16, 0], [308, 42], [208, 27], [71, 30], [145, 15], [39, 7], [2, 8], [80, 7], [1, 8], [49, 7], [217, 3], [59, 2], [137, 6], [178, 11], [311, 21], [103, 39], [124, 0]],
        [[16, 0], [308, 42], [209, 27], [70, 30], [146, 15], [171, 7], [217, 3], [59, 2], [135, 6], [179, 11], [311, 21], [103, 39], [124, 0]],
        [[16, 0], [309, 42], [208, 27], [70, 30], [146, 15], [172, 7], [217, 3], [60, 2], [133, 6], [179, 11], [311, 21], [103, 39], [124, 0]],
        [[17, 0], [308, 42], [208, 27], [71, 30], [146, 15], [173, 7], [216, 3], [60, 2], [131, 6], [179, 11], [312, 21], [103, 39], [124, 0]],
        [[17, 0], [308, 42], [209, 27], [70, 30], [146, 15], [174, 7], [216, 3], [60, 2], [130, 6], [179, 11], [312, 21], [102, 39], [125, 0]],
        [[17, 0], [308, 42], [209, 27], [70, 30], [147, 15], [174, 7], [215, 3], [61, 2], [128, 6], [180, 11], [311, 21], [103, 39], [125, 0]],
        [[17, 0], [308, 42], [209, 27], [71, 30], [146, 15], [175, 7], [216, 3], [60, 2], [127, 6], [180, 11], [311, 21], [103, 39], [125, 0]],
        [[17, 0], [308, 42], [209, 27], [71, 30], [147, 15], [176, 7], [214, 3], [62, 2], [125, 6], [179, 11], [312, 21], [103, 39], [125, 0]],
        [[17, 0], [309, 42], [209, 27], [70, 30], [147, 15], [178, 7], [213, 3], [62, 2], [123, 6], [180, 11], [312, 21], [103, 39], [125, 0]],
        [[17, 0], [309, 42], [209, 27], [71, 30], [147, 15], [178, 7], [213, 3], [62, 2], [122, 6], [180, 11], [312, 21], [103, 39], [125, 0]],
        [[17, 0], [309, 42], [209, 27], [71, 30], [147, 15], [180, 7], [212, 3], [63, 2], [119, 6], [181, 11], [312, 21], [102, 39], [126, 0]],
        [[18, 0], [308, 42], [210, 27], [70, 30], [148, 15], [181, 7], [211, 3], [62, 2], [119, 6], [180, 11], [312, 21], [103, 39], [126, 0]],
        [[18, 0], [309, 42], [209, 27], [71, 30], [147, 15], [182, 7], [211, 3], [60, 2], [119, 6], [181, 11], [312, 21], [103, 39], [126, 0]],
        [[18, 0], [309, 42], [209, 27], [71, 30], [148, 15], [183, 7], [210, 3], [59, 2], [119, 6], [181, 11], [312, 21], [103, 39], [126, 0]],
        [[18, 0], [309, 42], [210, 27], [70, 30], [148, 15], [185, 7], [208, 3], [58, 2], [119, 6], [181, 11], [313, 21], [103, 39], [126, 0]],
        [[18, 0], [309, 42], [210, 27], [71, 30], [148, 15], [186, 7], [207, 3], [56, 2], [120, 6], [181, 11], [313, 21], [103, 39], [126, 0]],
        [[18, 0], [309, 42], [210, 27], [71, 30], [148, 15], [187, 7], [207, 3], [54, 2], [120, 6], [182, 11], [313, 21], [103, 39], [126, 0]],
        [[18, 0], [310, 42], [209, 27], [72, 30], [148, 15], [188, 7], [206, 3], [52, 2], [121, 6], [181, 11], [313, 21], [103, 39], [127, 0]],
        [[19, 0], [309, 42], [210, 27], [71, 30], [149, 15], [189, 7], [205, 3], [51, 2], [120, 6], [182, 11], [313, 21], [103, 39], [127, 0]],
        [[19, 0], [309, 42], [210, 27], [71, 30], [149, 15], [192, 7], [203, 3], [49, 2], [121, 6], [182, 11], [313, 21], [103, 39], [127, 0]],
        [[19, 0], [309, 42], [210, 27], [72, 30], [149, 15], [193, 7], [202, 3], [47, 2], [121, 6], [182, 11], [314, 21], [103, 39], [127, 0]],
        [[19, 0], [309, 42], [211, 27], [71, 30], [150, 15], [194, 7], [200, 3], [46, 2], [122, 6], [182, 11], [314, 21], [103, 39], [127, 0]],
        [[19, 0], [310, 42], [210, 27], [71, 30], [150, 15], [197, 7], [198, 3], [44, 2], [122, 6], [183, 11], [313, 21], [104, 39], [127, 0]],
        [[19, 0], [310, 42], [210, 27], [72, 30], [150, 15], [198, 7], [197, 3], [42, 2], [123, 6], [182, 11], [314, 21], [103, 39], [128, 0]],
        [[19, 0], [310, 42], [211, 27], [71, 30], [150, 15], [201, 7], [195, 3], [40, 2], [123, 6], [183, 11], [314, 21], [103, 39], [128, 0]],
        [[20, 0], [309, 42], [211, 27], [72, 30], [150, 15], [203, 7], [193, 3], [38, 2], [124, 6], [183, 11], [314, 21], [103, 39], [128, 0]],
        [[20, 0], [310, 42], [210, 27], [72, 30], [151, 15], [205, 7], [191, 3], [36, 2], [124, 6], [183, 11], [315, 21], [103, 39], [128, 0]],
        [[20, 0], [310, 42], [211, 27], [71, 30], [151, 15], [207, 7], [189, 3], [36, 2], [124, 6], [183, 11], [314, 21], [103, 39], [129, 0]],
        [[20, 0], [310, 42], [211, 27], [72, 30], [151, 15], [209, 7], [187, 3], [34, 2], [124, 6], [184, 11], [314, 21], [103, 39], [129, 0]],
        [[20, 0], [310, 42], [211, 27], [72, 30], [151, 15], [213, 7], [184, 3], [32, 2], [124, 6], [184, 11], [315, 21], [103, 39], [129, 0]],
        [[20, 0], [310, 42], [212, 27], [72, 30], [151, 15], [216, 7], [181, 3], [30, 2], [125, 6], [184, 11], [315, 21], [103, 39], [129, 0]],
        [[21, 0], [310, 42], [211, 27], [72, 30], [152, 15], [219, 7], [178, 3], [28, 2], [125, 6], [185, 11], [315, 21], [103, 39], [129, 0]],
        [[21, 0], [310, 42], [211, 27], [72, 30], [152, 15], [224, 7], [174, 3], [26, 2], [126, 6], [184, 11], [315, 21], [104, 39], [129, 0]],
        [[21, 0], [310, 42], [212, 27], [72, 30], [152, 15], [229, 7], [169, 3], [24, 2], [126, 6], [185, 11], [315, 21], [103, 39], [130, 0]],
        [[21, 0], [311, 42], [211, 27], [72, 30], [153, 15], [236, 7], [162, 3], [22, 2], [127, 6], [185, 11], [315, 21], [103, 39], [130, 0]],
        [[21, 0], [311, 42], [211, 27], [73, 30], [153, 15], [235, 7], [162, 3], [21, 2], [128, 6], [184, 11], [316, 21], [103, 39], [130, 0]],
        [[22, 0], [310, 42], [212, 27], [72, 30], [153, 15], [235, 7], [163, 3], [19, 2], [130, 6], [183, 11], [316, 21], [103, 39], [130, 0]],
        [[22, 0], [310, 42], [212, 27], [72, 30], [154, 15], [234, 7], [164, 3], [17, 2], [133, 6], [181, 11], [315, 21], [104, 39], [130, 0]],
        [[22, 0], [311, 42], [211, 27], [73, 30], [153, 15], [234, 7], [165, 3], [15, 2], [135, 6], [179, 11], [316, 21], [103, 39], [131, 0]],
        [[22, 0], [311, 42], [212, 27], [72, 30], [154, 15], [233, 7], [166, 3], [13, 2], [138, 6], [177, 11], [316, 21], [103, 39], [131, 0]],
        [[22, 0], [311, 42], [212, 27], [73, 30], [154, 15], [232, 7], [167, 3], [10, 2], [142, 6], [175, 11], [316, 21], [103, 39], [131, 0]],
        [[22, 0], [311, 42], [213, 27], [72, 30], [154, 15], [232, 7], [167, 3], [9, 2], [145, 6], [172, 11], [317, 21], [103, 39], [131, 0]],
        [[23, 0], [311, 42], [212, 27], [72, 30], [155, 15], [230, 7], [169, 3], [7, 2], [148, 6], [170, 11], [316, 21], [104, 39], [131, 0]],
        [[23, 0], [311, 42], [212, 27], [73, 30], [155, 15], [229, 7], [170, 3], [5, 2], [150, 6], [168, 11], [317, 21], [104, 39], [131, 0]],
        [[23, 0], [311, 42], [213, 27], [73, 30], [155, 15], [228, 7], [171, 3], [3, 2], [153, 6], [166, 11], [317, 21], [103, 39], [132, 0]],
        [[23, 0], [311, 42], [213, 27], [73, 30], [36, 15], [1, 14], [118, 15], [228, 7], [172, 3], [1, 2], [156, 6], [164, 11], [316, 21], [104, 39], [132, 0]],
        [[23, 0], [312, 42], [212, 27], [34, 30], [3, 27], [36, 30], [34, 15], [4, 14], [118, 15], [227, 7], [172, 3], [159, 6], [161, 11], [317, 21], [104, 39], [132, 0]],
        [[23, 0], [312, 42], [213, 27], [30, 30], [6, 27], [37, 30], [31, 15], [6, 14], [119, 15], [226, 7], [171, 3], [161, 6], [160, 11], [317, 21], [104, 39], [132, 0]],
        [[24, 0], [311, 42], [213, 27], [28, 30], [9, 27], [36, 30], [29, 15], [9, 14], [118, 15], [226, 7], [169, 3], [165, 6], [158, 11], [317, 21], [104, 39], [132, 0]],
        [[24, 0], [311, 42], [214, 27], [25, 30], [11, 27], [37, 30], [26, 15], [11, 14], [119, 15], [224, 7], [169, 3], [168, 6], [155, 11], [318, 21], [103, 39], [133, 0]],
        [[24, 0], [312, 42], [213, 27], [22, 30], [14, 27], [37, 30], [24, 15], [14, 14], [119, 15], [223, 7], [168, 3], [170, 6], [154, 11], [317, 21], [104, 39], [133, 0]],
        [[24, 0], [312, 42], [213, 27], [20, 30], [17, 27], [37, 30], [21, 15], [16, 14], [120, 15], [222, 7], [167, 3], [173, 6], [151, 11], [318, 21], [104, 39], [133, 0]],
        [[24, 0], [312, 42], [214, 27], [16, 30], [20, 27], [37, 30], [19, 15], [19, 14], [120, 15], [221, 7], [165, 3], [176, 6], [150, 11], [318, 21], [104, 39], [133, 0]],
        [[25, 0], [311, 42], [214, 27], [14, 30], [23, 27], [37, 30], [15, 15], [23, 14], [120, 15], [220, 7], [164, 3], [177, 6], [2, 12], [147, 11], [319, 21], [104, 39], [133, 0]],
        [[25, 0], [312, 42], [214, 27], [10, 30], [26, 27], [37, 30], [13, 15], [25, 14], [120, 15], [220, 7], [163, 3], [177, 6], [5, 12], [145, 11], [318, 21], [104, 39], [134, 0]],
        [[25, 0], [312, 42], [214, 27], [8, 30], [29, 27], [37, 30], [10, 15], [28, 14], [120, 15], [219, 7], [162, 3], [177, 6], [8, 12], [143, 11], [318, 21], [104, 39], [134, 0]],
        [[25, 0], [312, 42], [214, 27], [5, 30], [32, 27], [37, 30], [8, 15], [30, 14], [121, 15], [218, 7], [160, 3], [179, 6], [10, 12], [140, 11], [319, 21], [104, 39], [134, 0]],
        [[25, 0], [313, 42], [214, 27], [2, 30], [35, 27], [37, 30], [5, 15], [33, 14], [121, 15], [217, 7], [159, 3], [179, 6], [12, 12], [139, 11], [319, 21], [104, 39], [134, 0]],
        [[25, 0], [313, 42], [251, 27], [37, 30], [3, 15], [35, 14], [121, 15], [217, 7], [157, 3], [181, 6], [14, 12], [136, 11], [319, 21], [104, 39], [135, 0]],
        [[26, 0], [312, 42], [251, 27], [37, 30], [39, 14], [121, 15], [215, 7], [157, 3], [181, 6], [17, 12], [134, 11], [319, 21], [104, 39], [135, 0]],
        [[26, 0], [312, 42], [252, 27], [35, 30], [40, 14], [122, 15], [214, 7], [156, 3], [182, 6], [18, 12], [133, 11], [319, 21], [104, 39], [135, 0]],
        [[26, 0], [313, 42], [251, 27], [33, 30], [43, 14], [122, 15], [213, 7], [154, 3], [183, 6], [21, 12], [130, 11], [320, 21], [104, 39], [135, 0]],
        [[26, 0], [313, 42], [252, 27], [30, 30], [45, 14], [123, 15], [212, 7], [153, 3], [183, 6], [24, 12], [128, 11], [320, 21], [104, 39], [135, 0]],
        [[26, 0], [313, 42], [252, 27], [28, 30], [48, 14], [123, 15], [211, 7], [151, 3], [185, 6], [25, 12], [126, 11], [320, 21], [104, 39], [136, 0]],
        [[27, 0], [313, 42], [252, 27], [25, 30], [50, 14], [124, 15], [210, 7], [150, 3], [185, 6], [28, 12], [124, 11], [320, 21], [104, 39], [136, 0]],
        [[27, 0], [313, 42], [252, 27], [23, 30], [53, 14], [123, 15], [210, 7], [148, 3], [186, 6], [31, 12], [122, 11], [320, 21], [104, 39], [136, 0]],
        [[27, 0], [313, 42], [253, 27], [20, 30], [56, 14], [123, 15], [209, 7], [146, 3], [188, 6], [33, 12], [119, 11], [321, 21], [104, 39], [136, 0]],
        [[27, 0], [313, 42], [253, 27], [18, 30], [58, 14], [124, 15], [208, 7], [145, 3], [188, 6], [36, 12], [117, 11], [320, 21], [105, 39], [136, 0]],
        [[27, 0], [314, 42], [253, 27], [15, 30], [61, 14], [124, 15], [211, 7], [32, 3], [5, 7], [102, 3], [189, 6], [38, 12], [115, 11], [321, 21], [104, 39], [137, 0]],
        [[28, 0], [313, 42], [253, 27], [13, 30], [63, 14], [125, 15], [247, 7], [101, 3], [190, 6], [40, 12], [113, 11], [321, 21], [104, 39], [137, 0]],
        [[28, 0], [313, 42], [253, 27], [11, 30], [66, 14], [125, 15], [246, 7], [99, 3], [191, 6], [42, 12], [112, 11], [321, 21], [104, 39], [137, 0]],
        [[28, 0], [314, 42], [253, 27], [8, 30], [68, 14], [126, 15], [245, 7], [97, 3], [192, 6], [45, 12], [109, 11], [321, 21], [105, 39], [137, 0]],
        [[28, 0], [314, 42], [253, 27], [6, 30], [71, 14], [125, 15], [245, 7], [96, 3], [193, 6], [47, 12], [107, 11], [321, 21], [104, 39], [138, 0]],
        [[28, 0], [314, 42], [254, 27], [3, 30], [74, 14], [125, 15], [244, 7], [94, 3], [194, 6], [50, 12], [104, 11], [322, 21], [104, 39], [138, 0]],
        [[29, 0], [314, 42], [253, 27], [1, 30], [76, 14], [126, 15], [243, 7], [95, 3], [192, 6], [53, 12], [102, 11], [322, 21], [104, 39], [138, 0]],
        [[29, 0], [314, 42], [252, 27], [79, 14], [126, 15], [242, 7], [95, 3], [192, 6], [54, 12], [100, 11], [322, 21], [105, 39], [138, 0]],
        [[29, 0], [314, 42], [250, 27], [81, 14], [127, 15], [242, 7], [95, 3], [190, 6], [57, 12], [98, 11], [322, 21], [105, 39], [138, 0]],
        [[29, 0], [315, 42], [247, 27], [84, 14], [127, 15], [241, 7], [96, 3], [188, 6], [60, 12], [95, 11], [323, 21], [104, 39], [139, 0]],
        [[29, 0], [315, 42], [245, 27], [87, 14], [127, 15], [240, 7], [96, 3], [188, 6], [62, 12], [93, 11], [322, 21], [105, 39], [139, 0]],
        [[30, 0], [314, 42], [242, 27], [90, 14], [128, 15], [239, 7], [97, 3], [186, 6], [65, 12], [90, 11], [323, 21], [105, 39], [139, 0]],
        [[30, 0], [314, 42], [241, 27], [92, 14], [128, 15], [238, 7], [97, 3], [185, 6], [67, 12], [89, 11], [323, 21], [104, 39], [140, 0]],
        [[30, 0], [315, 42], [238, 27], [94, 14], [129, 15], [237, 7], [98, 3], [184, 6], [69, 12], [86, 11], [324, 21], [104, 39], [140, 0]],
        [[30, 0], [315, 42], [236, 27], [97, 14], [129, 15], [236, 7], [98, 3], [183, 6], [71, 12], [85, 11], [323, 21], [105, 39], [140, 0]],
        [[30, 0], [315, 42], [234, 27], [100, 14], [129, 15], [235, 7], [99, 3], [181, 6], [74, 12], [83, 11], [323, 21], [105, 39], [140, 0]],
        [[31, 0], [315, 42], [231, 27], [102, 14], [130, 15], [234, 7], [100, 3], [179, 6], [77, 12], [80, 11], [324, 21], [104, 39], [141, 0]],
        [[31, 0], [315, 42], [228, 27], [106, 14], [130, 15], [233, 7], [100, 3], [179, 6], [79, 12], [78, 11], [323, 21], [105, 39], [141, 0]],
        [[31, 0], [315, 42], [226, 27], [109, 14], [130, 15], [232, 7], [101, 3], [177, 6], [81, 12], [76, 11], [324, 21], [105, 39], [141, 0]],
        [[31, 0], [316, 42], [223, 27], [111, 14], [131, 15], [232, 7], [100, 3], [176, 6], [84, 12], [74, 11], [324, 21], [105, 39], [141, 0]],
        [[32, 0], [315, 42], [221, 27], [114, 14], [132, 15], [230, 7], [101, 3], [174, 6], [87, 12], [71, 11], [324, 21], [105, 39], [142, 0]],
        [[32, 0], [315, 42], [219, 27], [117, 14], [132, 15], [229, 7], [101, 3], [174, 6], [89, 12], [69, 11], [324, 21], [105, 39], [142, 0]],
        [[32, 0], [316, 42], [216, 27], [119, 14], [133, 15], [228, 7], [102, 3], [172, 6], [92, 12], [66, 11], [325, 21], [105, 39], [142, 0]],
        [[32, 0], [316, 42], [214, 27], [122, 14], [132, 15], [228, 7], [102, 3], [171, 6], [94, 12], [65, 11], [325, 21], [105, 39], [142, 0]],
        [[33, 0], [315, 42], [212, 27], [125, 14], [133, 15], [226, 7], [103, 3], [170, 6], [96, 12], [62, 11], [325, 21], [106, 39], [142, 0]],
        [[33, 0], [316, 42], [209, 27], [127, 14], [134, 15], [225, 7], [103, 3], [169, 6], [98, 12], [61, 11], [325, 21], [105, 39], [143, 0]],
        [[33, 0], [316, 42], [207, 27], [130, 14], [134, 15], [224, 7], [104, 3], [167, 6], [101, 12], [58, 11], [326, 21], [105, 39], [143, 0]],
        [[33, 0], [316, 42], [205, 27], [133, 14], [134, 15], [223, 7], [104, 3], [166, 6], [104, 12], [56, 11], [326, 21], [105, 39], [143, 0]],
        [[34, 0], [316, 42], [202, 27], [135, 14], [135, 15], [222, 7], [32, 3], [1, 7], [72, 3], [164, 6], [107, 12], [53, 11], [326, 21], [106, 39], [143, 0]],
        [[34, 0], [316, 42], [200, 27], [138, 14], [135, 15], [222, 7], [27, 3], [5, 7], [73, 3], [163, 6], [109, 12], [51, 11], [326, 21], [105, 39], [144, 0]],
        [[34, 0], [316, 42], [198, 27], [141, 14], [136, 15], [220, 7], [22, 3], [10, 7], [73, 3], [162, 6], [111, 12], [49, 11], [327, 21], [105, 39], [144, 0]],
        [[34, 0], [317, 42], [195, 27], [143, 14], [137, 15], [219, 7], [16, 3], [17, 7], [73, 3], [160, 6], [114, 12], [46, 11], [327, 21], [106, 39], [144, 0]],
        [[35, 0], [316, 42], [193, 27], [146, 14], [137, 15], [218, 7], [10, 3], [23, 7], [73, 3], [159, 6], [117, 12], [44, 11], [327, 21], [105, 39], [145, 0]],
        [[35, 0], [316, 42], [191, 27], [149, 14], [137, 15], [217, 7], [4, 3], [29, 7], [74, 3], [157, 6], [119, 12], [43, 11], [327, 21], [105, 39], [145, 0]],
        [[35, 0], [317, 42], [188, 27], [151, 14], [138, 15], [249, 7], [74, 3], [157, 6], [121, 12], [40, 11], [327, 21], [106, 39], [145, 0]],
        [[35, 0], [317, 42], [186, 27], [154, 14], [138, 15], [249, 7], [72, 3], [157, 6], [124, 12], [38, 11], [327, 21], [106, 39], [145, 0]],
        [[35, 0], [318, 42], [183, 27], [157, 14], [139, 15], [247, 7], [71, 3], [157, 6], [127, 12], [35, 11], [328, 21], [105, 39], [146, 0]],
        [[36, 0], [317, 42], [181, 27], [160, 14], [139, 15], [246, 7], [69, 3], [158, 6], [129, 12], [33, 11], [39, 21], [2, 22], [288, 21], [105, 39], [146, 0]],
        [[36, 0], [317, 42], [179, 27], [163, 14], [139, 15], [245, 7], [67, 3], [159, 6], [132, 12], [31, 11], [38, 21], [5, 22], [285, 21], [106, 39], [146, 0]],
        [[36, 0], [318, 42], [176, 27], [165, 14], [141, 15], [243, 7], [65, 3], [160, 6], [135, 12], [28, 11], [39, 21], [7, 22], [283, 21], [106, 39], [146, 0]],
        [[36, 0], [318, 42], [173, 27], [169, 14], [141, 15], [243, 7], [62, 3], [162, 6], [137, 12], [26, 11], [38, 21], [10, 22], [281, 21], [105, 39], [147, 0]],
        [[37, 0], [317, 42], [171, 27], [172, 14], [141, 15], [242, 7], [60, 3], [163, 6], [139, 12], [24, 11], [39, 21], [12, 22], [278, 21], [106, 39], [147, 0]],
        [[37, 0], [318, 42], [168, 27], [175, 14], [142, 15], [240, 7], [57, 3], [165, 6], [142, 12], [22, 11], [38, 21], [15, 22], [276, 21], [106, 39], [147, 0]],
        [[37, 0], [318, 42], [166, 27], [177, 14], [143, 15], [239, 7], [55, 3], [166, 6], [145, 12], [19, 11], [38, 21], [18, 22], [274, 21], [106, 39], [147, 0]],
        [[37, 0], [318, 42], [165, 27], [179, 14], [143, 15], [239, 7], [53, 3], [166, 6], [147, 12], [18, 11], [38, 21], [20, 22], [271, 21], [106, 39], [148, 0]],
        [[38, 0], [318, 42], [162, 27], [182, 14], [144, 15], [237, 7], [51, 3], [167, 6], [150, 12], [15, 11], [38, 21], [23, 22], [269, 21], [106, 39], [148, 0]],
        [[38, 0], [318, 42], [160, 27], [184, 14], [145, 15], [236, 7], [48, 3], [169, 6], [153, 12], [13, 11], [38, 21], [25, 22], [267, 21], [106, 39], [148, 0]],
        [[38, 0], [319, 42], [156, 27], [188, 14], [145, 15], [235, 7], [46, 3], [170, 6], [156, 12], [10, 11], [38, 21], [28, 22], [264, 21], [106, 39], [149, 0]],
        [[38, 0], [319, 42], [154, 27], [191, 14], [146, 15], [234, 7], [42, 3], [172, 6], [158, 12], [9, 11], [38, 21], [30, 22], [262, 21], [106, 39], [149, 0]],
        [[39, 0], [318, 42], [152, 27], [194, 14], [146, 15], [233, 7], [40, 3], [173, 6], [161, 12], [6, 11], [38, 21], [33, 22], [260, 21], [106, 39], [149, 0]],
        [[39, 0], [319, 42], [149, 27], [197, 14], [147, 15], [231, 7], [37, 3], [176, 6], [163, 12], [3, 11], [39, 21], [35, 22], [258, 21], [105, 39], [150, 0]],
        [[39, 0], [319, 42], [147, 27], [200, 14], [147, 15], [230, 7], [34, 3], [178, 6], [166, 12], [1, 11], [38, 21], [38, 22], [255, 21], [106, 39], [150, 0]],
        [[39, 0], [319, 42], [145, 27], [202, 14], [149, 15], [228, 7], [32, 3], [179, 6], [169, 12], [37, 21], [41, 22], [252, 21], [106, 39], [150, 0]],
        [[40, 0], [319, 42], [142, 27], [205, 14], [150, 15], [227, 7], [28, 3], [181, 6], [172, 12], [34, 21], [44, 22], [249, 21], [107, 39], [150, 0]],
        [[40, 0], [319, 42], [140, 27], [208, 14], [150, 15], [226, 7], [25, 3], [183, 6], [174, 12], [33, 21], [46, 22], [247, 21], [106, 39], [151, 0]],
        [[40, 0], [319, 42], [138, 27], [211, 14], [93, 15], [1, 13], [56, 15], [225, 7], [23, 3], [184, 6], [177, 12], [30, 21], [48, 22], [246, 21], [106, 39], [151, 0]],
        [[40, 0], [320, 42], [135, 27], [213, 14], [92, 15], [3, 13], [57, 15], [223, 7], [19, 3], [187, 6], [179, 12], [29, 21], [50, 22], [243, 21], [107, 39], [151, 0]],
        [[41, 0], [319, 42], [133, 27], [216, 14], [90, 15], [5, 13], [58, 15], [222, 7], [15, 3], [189, 6], [182, 12], [26, 21], [53, 22], [241, 21], [106, 39], [152, 0]],
        [[41, 0], [320, 42], [130, 27], [219, 14], [88, 15], [7, 13], [58, 15], [221, 7], [11, 3], [192, 6], [185, 12], [24, 21], [55, 22], [239, 21], [106, 39], [152, 0]],
        [[41, 0], [320, 42], [128, 27], [222, 14], [86, 15], [10, 13], [58, 15], [219, 7], [8, 3], [194, 6], [188, 12], [21, 21], [59, 22], [235, 21], [107, 39], [152, 0]],
        [[41, 0], [320, 42], [126, 27], [225, 14], [84, 15], [12, 13], [59, 15], [217, 7], [4, 3], [197, 6], [191, 12], [19, 21], [61, 22], [233, 21], [107, 39], [152, 0]],
        [[42, 0], [320, 42], [123, 27], [228, 14], [82, 15], [14, 13], [59, 15], [216, 7], [1, 13], [199, 6], [193, 12], [17, 21], [64, 22], [231, 21], [106, 39], [153, 0]],
        [[42, 0], [320, 42], [121, 27], [231, 14], [80, 15], [16, 13], [60, 15], [209, 7], [6, 13], [198, 6], [196, 12], [14, 21], [67, 22], [228, 21], [107, 39], [153, 0]],
        [[42, 0], [321, 42], [118, 27], [233, 14], [46, 15], [1, 14], [33, 15], [18, 13], [60, 15], [202, 7], [11, 13], [197, 6], [199, 12], [12, 21], [69, 22], [226, 21], [107, 39], [153, 0]],
        [[42, 0], [321, 42], [115, 27], [238, 14], [43, 15], [3, 14], [31, 15], [20, 13], [60, 15], [1, 13], [195, 7], [16, 13], [196, 6], [202, 12], [9, 21], [72, 22], [224, 21], [106, 39], [154, 0]],
        [[43, 0], [321, 42], [113, 27], [239, 14], [43, 15], [4, 14], [29, 15], [22, 13], [59, 15], [2, 13], [101, 7], [2, 13], [86, 7], [21, 13], [195, 6], [204, 12], [8, 21], [73, 22], [222, 21], [107, 39], [154, 0]],
        [[43, 0], [321, 42], [111, 27], [242, 14], [41, 15], [6, 14], [27, 15], [24, 13], [57, 15], [5, 13], [99, 7], [9, 13], [73, 7], [28, 13], [193, 6], [207, 12], [5, 21], [77, 22], [219, 21], [107, 39], [154, 0]],
        [[43, 0], [321, 42], [1, 26], [108, 27], [245, 14], [39, 15], [8, 14], [25, 15], [27, 13], [55, 15], [7, 13], [96, 7], [18, 13], [57, 7], [36, 13], [192, 6], [210, 12], [2, 21], [80, 22], [217, 21], [106, 39], [155, 0]],
        [[44, 0], [317, 42], [4, 26], [106, 27], [248, 14], [37, 15], [10, 14], [24, 15], [28, 13], [53, 15], [10, 13], [94, 7], [33, 13], [27, 7], [51, 13], [191, 6], [212, 12], [1, 21], [82, 22], [214, 21], [107, 39], [155, 0]],
        [[44, 0], [315, 42], [7, 26], [102, 27], [252, 14], [35, 15], [12, 14], [21, 15], [31, 13], [52, 15], [12, 13], [92, 7], [111, 13], [190, 6], [213, 12], [85, 22], [212, 21], [107, 39], [155, 0]],
        [[44, 0], [312, 42], [10, 26], [100, 27], [255, 14], [33, 15], [14, 14], [20, 15], [33, 13], [49, 15], [15, 13], [90, 7], [112, 13], [188, 6], [214, 12], [87, 22], [210, 21], [107, 39], [155, 0]],
        [[45, 0], [309, 42], [12, 26], [98, 27], [258, 14], [31, 15], [16, 14], [18, 15], [35, 13], [48, 15], [17, 13], [88, 7], [112, 13], [187, 6], [214, 12], [90, 22], [207, 21], [107, 39], [156, 0]],
        [[45, 0], [306, 42], [16, 26], [95, 27], [260, 14], [30, 15], [18, 14], [16, 15], [38, 13], [45, 15], [20, 13], [86, 7], [112, 13], [186, 6], [215, 12], [92, 22], [205, 21], [107, 39], [156, 0]],
        [[45, 0], [304, 42], [18, 26], [93, 27], [263, 14], [28, 15], [21, 14], [13, 15], [40, 13], [44, 15], [22, 13], [83, 7], [113, 13], [184, 6], [216, 12], [95, 22], [202, 21], [108, 39], [156, 0]],
        [[45, 0], [301, 42], [22, 26], [90, 27], [266, 14], [26, 15], [23, 14], [11, 15], [42, 13], [42, 15], [25, 13], [81, 7], [114, 13], [182, 6], [216, 12], [98, 22], [200, 21], [107, 39], [157, 0]],
        [[46, 0], [298, 42], [24, 26], [88, 27], [269, 14], [24, 15], [25, 14], [9, 15], [45, 13], [39, 15], [29, 13], [78, 7], [114, 13], [181, 6], [217, 12], [100, 22], [198, 21], [107, 39], [157, 0]],
        [[46, 0], [296, 42], [26, 26], [86, 27], [272, 14], [22, 15], [27, 14], [8, 15], [46, 13], [38, 15], [31, 13], [76, 7], [114, 13], [180, 6], [217, 12], [103, 22], [195, 21], [72, 39], [3, 0], [33, 39], [157, 0]],
        [[46, 0], [293, 42], [30, 26], [83, 27], [275, 14], [20, 15], [29, 14], [6, 15], [48, 13], [37, 15], [33, 13], [74, 7], [115, 13], [178, 6], [218, 12], [105, 22], [193, 21], [72, 39], [6, 0], [29, 39], [158, 0]],
        [[46, 0], [291, 42], [32, 26], [81, 27], [278, 14], [18, 15], [31, 14], [4, 15], [51, 13], [34, 15], [36, 13], [72, 7], [115, 13], [177, 6], [218, 12], [108, 22], [191, 21], [71, 39], [10, 0], [26, 39], [158, 0]],
        [[47, 0], [287, 42], [36, 26], [78, 27], [281, 14], [16, 15], [33, 14], [2, 15], [54, 13], [31, 15], [40, 13], [68, 7], [116, 13], [176, 6], [218, 12], [111, 22], [188, 21], [72, 39], [13, 0], [23, 39], [158, 0]],
        [[47, 0], [285, 42], [38, 26], [76, 27], [284, 14], [14, 15], [35, 14], [56, 13], [30, 15], [42, 13], [66, 7], [116, 13], [175, 6], [219, 12], [113, 22], [186, 21], [72, 39], [16, 0], [19, 39], [159, 0]],
        [[47, 0], [282, 42], [41, 26], [74, 27], [287, 14], [12, 15], [35, 14], [59, 13], [27, 15], [46, 13], [63, 7], [117, 13], [172, 6], [220, 12], [116, 22], [184, 21], [71, 39], [20, 0], [16, 39], [159, 0]],
        [[48, 0], [279, 42], [44, 26], [71, 27], [290, 14], [10, 15], [35, 14], [61, 13], [25, 15], [50, 13], [60, 7], [117, 13], [171, 6], [220, 12], [120, 22], [180, 21], [72, 39], [23, 0], [13, 39], [159, 0]],
        [[48, 0], [276, 42], [47, 26], [69, 27], [293, 14], [8, 15], [35, 14], [64, 13], [23, 15], [52, 13], [58, 7], [117, 13], [170, 6], [221, 12], [122, 22], [178, 21], [72, 39], [26, 0], [9, 39], [160, 0]],
        [[48, 0], [274, 42], [50, 26], [66, 27], [296, 14], [6, 15], [35, 14], [66, 13], [21, 15], [56, 13], [55, 7], [117, 13], [169, 6], [221, 12], [125, 22], [175, 21], [72, 39], [30, 0], [6, 39], [160, 0]],
        [[49, 0], [270, 42], [53, 26], [64, 27], [299, 14], [4, 15], [36, 14], [68, 13], [19, 15], [59, 13], [51, 7], [118, 13], [167, 6], [223, 12], [127, 22], [173, 21], [72, 39], [33, 0], [3, 39], [160, 0]],
        [[49, 0], [268, 42], [56, 26], [61, 27], [302, 14], [2, 15], [36, 14], [71, 13], [16, 15], [63, 13], [48, 7], [119, 13], [165, 6], [223, 12], [130, 22], [170, 21], [73, 39], [196, 0]],
        [[49, 0], [266, 42], [58, 26], [59, 27], [341, 14], [73, 13], [15, 15], [65, 13], [46, 7], [119, 13], [164, 6], [223, 12], [132, 22], [169, 21], [72, 39], [197, 0]],
        [[49, 0], [263, 42], [62, 26], [56, 27], [342, 14], [76, 13], [12, 15], [69, 13], [43, 7], [119, 13], [163, 6], [224, 12], [135, 22], [166, 21], [72, 39], [197, 0]],
        [[50, 0], [260, 42], [64, 26], [54, 27], [343, 14], [78, 13], [11, 15], [73, 13], [39, 7], [119, 13], [162, 6], [224, 12], [138, 22], [163, 21], [73, 39], [197, 0]],
        [[50, 0], [257, 42], [68, 26], [51, 27], [344, 14], [81, 13], [8, 15], [77, 13], [36, 7], [120, 13], [159, 6], [226, 12], [140, 22], [161, 21], [72, 39], [198, 0]],
        [[50, 0], [255, 42], [70, 26], [49, 27], [346, 14], [83, 13], [6, 15], [81, 13], [31, 7], [121, 13], [158, 6], [226, 12], [143, 22], [159, 21], [72, 39], [198, 0]],
        [[51, 0], [251, 42], [73, 26], [47, 27], [347, 14], [86, 13], [3, 15], [85, 13], [28, 7], [121, 13], [157, 6], [226, 12], [146, 22], [156, 21], [73, 39], [198, 0]],
        [[51, 0], [249, 42], [76, 26], [43, 27], [349, 14], [89, 13], [1, 15], [89, 13], [24, 7], [121, 13], [155, 6], [228, 12], [148, 22], [118, 21], [1, 22], [35, 21], [72, 39], [199, 0]],
        [[51, 0], [246, 42], [79, 26], [41, 27], [350, 14], [184, 13], [20, 7], [122, 13], [153, 6], [228, 12], [151, 22], [115, 21], [5, 22], [31, 21], [73, 39], [199, 0]],
        [[52, 0], [243, 42], [82, 26], [38, 27], [351, 14], [190, 13], [15, 7], [122, 13], [152, 6], [228, 12], [154, 22], [113, 21], [7, 22], [29, 21], [72, 39], [200, 0]],
        [[52, 0], [240, 42], [85, 26], [36, 27], [2, 26], [350, 14], [196, 13], [9, 7], [123, 13], [150, 6], [230, 12], [156, 22], [110, 21], [11, 22], [26, 21], [72, 39], [200, 0]],
        [[52, 0], [239, 42], [87, 26], [33, 27], [4, 26], [349, 14], [201, 13], [5, 7], [123, 13], [149, 6], [230, 12], [159, 22], [108, 21], [13, 22], [23, 21], [73, 39], [200, 0]],
        [[52, 0], [236, 42], [90, 26], [31, 27], [6, 26], [349, 14], [329, 13], [148, 6], [230, 12], [162, 22], [105, 21], [16, 22], [21, 21], [72, 39], [201, 0]],
        [[53, 0], [232, 42], [94, 26], [28, 27], [9, 26], [347, 14], [331, 13], [146, 6], [231, 12], [164, 22], [103, 21], [18, 22], [19, 21], [72, 39], [201, 0]],
        [[53, 0], [230, 42], [96, 26], [26, 27], [12, 26], [345, 14], [332, 13], [144, 6], [232, 12], [167, 22], [101, 21], [21, 22], [15, 21], [73, 39], [201, 0]],
        [[54, 0], [226, 42], [99, 26], [24, 27], [14, 26], [344, 14], [333, 13], [143, 6], [232, 12], [170, 22], [98, 21], [25, 22], [12, 21], [72, 39], [202, 0]],
        [[54, 0], [224, 42], [102, 26], [21, 27], [17, 26], [342, 14], [334, 13], [141, 6], [234, 12], [172, 22], [96, 21], [27, 22], [9, 21], [73, 39], [202, 0]],
        [[54, 0], [221, 42], [105, 26], [19, 27], [19, 26], [341, 14], [336, 13], [139, 6], [234, 12], [175, 22], [93, 21], [30, 22], [7, 21], [73, 39], [202, 0]],
        [[55, 0], [218, 42], [108, 26], [16, 27], [22, 26], [339, 14], [337, 13], [137, 6], [235, 12], [178, 22], [91, 21], [33, 22], [4, 21], [72, 39], [203, 0]],
        [[55, 0], [215, 42], [111, 26], [14, 27], [24, 26], [339, 14], [337, 13], [136, 6], [236, 12], [181, 22], [87, 21], [37, 22], [73, 39], [203, 0]],
        [[55, 0], [213, 42], [114, 26], [11, 27], [27, 26], [336, 14], [339, 13], [134, 6], [237, 12], [184, 22], [85, 21], [40, 22], [69, 39], [204, 0]],
        [[56, 0], [209, 42], [117, 26], [9, 27], [29, 26], [336, 14], [340, 13], [132, 6], [237, 12], [187, 22], [83, 21], [42, 22], [67, 39], [204, 0]],
        [[56, 0], [207, 42], [120, 26], [6, 27], [32, 26], [334, 14], [341, 13], [131, 6], [238, 12], [188, 22], [81, 21], [45, 22], [65, 39], [204, 0]],
        [[56, 0], [205, 42], [122, 26], [4, 27], [34, 26], [333, 14], [342, 13], [129, 6], [239, 12], [191, 22], [79, 21], [48, 22], [61, 39], [205, 0]],
        [[56, 0], [203, 42], [125, 26], [1, 27], [37, 26], [331, 14], [343, 13], [128, 6], [239, 12], [194, 22], [76, 21], [51, 22], [59, 39], [205, 0]],
        [[57, 0], [199, 42], [166, 26], [330, 14], [345, 13], [125, 6], [240, 12], [197, 22], [74, 21], [53, 22], [56, 39], [206, 0]],
        [[57, 0], [196, 42], [170, 26], [329, 14], [345, 13], [123, 6], [242, 12], [200, 22], [70, 21], [57, 22], [53, 39], [206, 0]],
        [[57, 0], [194, 42], [172, 26], [328, 14], [346, 13], [122, 6], [242, 12], [203, 22], [68, 21], [59, 22], [51, 39], [206, 0]],
        [[58, 0], [191, 42], [175, 26], [326, 14], [347, 13], [120, 6], [243, 12], [206, 22], [66, 21], [62, 22], [47, 39], [207, 0]],
        [[58, 0], [188, 42], [178, 26], [325, 14], [349, 13], [117, 6], [244, 12], [209, 22], [63, 21], [65, 22], [45, 39], [207, 0]],
        [[58, 0], [185, 42], [182, 26], [323, 14], [350, 13], [116, 6], [245, 12], [211, 22], [61, 21], [68, 22], [42, 39], [207, 0]],
        [[59, 0], [182, 42], [184, 26], [322, 14], [351, 13], [114, 6], [246, 12], [214, 22], [58, 21], [71, 22], [39, 39], [208, 0]],
        [[59, 0], [180, 42], [187, 26], [320, 14], [352, 13], [112, 6], [247, 12], [217, 22], [56, 21], [74, 22], [36, 39], [208, 0]],
        [[59, 0], [181, 42], [186, 26], [319, 14], [353, 13], [111, 6], [248, 12], [219, 22], [53, 21], [77, 22], [33, 39], [209, 0]],
        [[60, 0], [180, 42], [187, 26], [37, 14], [2, 26], [279, 14], [354, 13], [108, 6], [249, 12], [222, 22], [51, 21], [79, 22], [31, 39], [209, 0]],
        [[60, 0], [180, 42], [187, 26], [35, 14], [4, 26], [278, 14], [355, 13], [107, 6], [249, 12], [225, 22], [49, 21], [82, 22], [28, 39], [209, 0]],
        [[60, 0], [181, 42], [187, 26], [32, 14], [7, 26], [276, 14], [356, 13], [105, 6], [250, 12], [228, 22], [46, 21], [85, 22], [25, 39], [210, 0]],
        [[61, 0], [180, 42], [188, 26], [29, 14], [9, 26], [275, 14], [358, 13], [102, 6], [252, 12], [230, 22], [43, 21], [89, 22], [22, 39], [210, 0]],
        [[61, 0], [181, 42], [187, 26], [27, 14], [12, 26], [273, 14], [359, 13], [100, 6], [253, 12], [233, 22], [41, 21], [91, 22], [19, 39], [211, 0]],
        [[61, 0], [181, 42], [188, 26], [25, 14], [13, 26], [272, 14], [360, 13], [98, 6], [254, 12], [236, 22], [38, 21], [95, 22], [16, 39], [211, 0]],
        [[62, 0], [180, 42], [188, 26], [23, 14], [16, 26], [270, 14], [361, 13], [96, 6], [255, 12], [239, 22], [36, 21], [97, 22], [14, 39], [211, 0]],
        [[62, 0], [181, 42], [188, 26], [20, 14], [19, 26], [269, 14], [362, 13], [93, 6], [256, 12], [242, 22], [34, 21], [100, 22], [10, 39], [212, 0]],
        [[62, 0], [181, 42], [188, 26], [18, 14], [21, 26], [268, 14], [363, 13], [91, 6], [257, 12], [245, 22], [31, 21], [103, 22], [8, 39], [212, 0]],
        [[63, 0], [181, 42], [188, 26], [16, 14], [23, 26], [266, 14], [364, 13], [90, 6], [258, 12], [247, 22], [29, 21], [105, 22], [6, 39], [212, 0]],
        [[63, 0], [181, 42], [188, 26], [14, 14], [25, 26], [265, 14], [365, 13], [88, 6], [259, 12], [250, 22], [26, 21], [108, 22], [3, 39], [213, 0]],
        [[63, 0], [182, 42], [188, 26], [11, 14], [28, 26], [263, 14], [367, 13], [85, 6], [260, 12], [253, 22], [24, 21], [111, 22], [213, 0]],
        [[64, 0], [181, 42], [188, 26], [10, 14], [30, 26], [261, 14], [368, 13], [83, 6], [262, 12], [255, 22], [21, 21], [115, 22], [210, 0]],
        [[64, 0], [182, 42], [188, 26], [7, 14], [32, 26], [260, 14], [369, 13], [81, 6], [263, 12], [258, 22], [19, 21], [117, 22], [208, 0]],
        [[65, 0], [181, 42], [189, 26], [4, 14], [35, 26], [259, 14], [369, 13], [78, 6], [265, 12], [261, 22], [16, 21], [120, 22], [206, 0]],
        [[65, 0], [181, 42], [189, 26], [2, 14], [38, 26], [257, 14], [371, 13], [75, 6], [266, 12], [265, 22], [13, 21], [123, 22], [203, 0]],
        [[65, 0], [182, 42], [228, 26], [256, 14], [372, 13], [73, 6], [267, 12], [268, 22], [10, 21], [127, 22], [200, 0]],
        [[66, 0], [181, 42], [229, 26], [254, 14], [373, 13], [71, 6], [269, 12], [270, 22], [8, 21], [129, 22], [198, 0]],
        [[66, 0], [182, 42], [228, 26], [253, 14], [374, 13], [68, 6], [271, 12], [273, 22], [5, 21], [133, 22], [195, 0]],
        [[66, 0], [182, 42], [229, 26], [251, 14], [375, 13], [66, 6], [272, 12], [276, 22], [3, 21], [135, 22], [193, 0]],
        [[67, 0], [182, 42], [229, 26], [250, 14], [376, 13], [63, 6], [273, 12], [279, 22], [1, 21], [137, 22], [191, 0]],
        [[67, 0], [182, 42], [229, 26], [249, 14], [377, 13], [61, 6], [274, 12], [420, 22], [189, 0]],
        [[67, 0], [182, 42], [230, 26], [247, 14], [378, 13], [58, 6], [276, 12], [424, 22], [186, 0]],
        [[68, 0], [182, 42], [229, 26], [246, 14], [379, 13], [56, 6], [278, 12], [426, 22], [184, 0]],
        [[68, 0], [182, 42], [230, 26], [244, 14], [381, 13], [52, 6], [280, 12], [430, 22], [181, 0]],
        [[68, 0], [183, 42], [230, 26], [242, 14], [382, 13], [50, 6], [281, 12], [434, 22], [178, 0]],
        [[69, 0], [182, 42], [231, 26], [240, 14], [383, 13], [47, 6], [283, 12], [437, 22], [176, 0]],
        [[69, 0], [183, 42], [230, 26], [239, 14], [384, 13], [44, 6], [285, 12], [440, 22], [174, 0]],
        [[69, 0], [183, 42], [231, 26], [237, 14], [386, 13], [41, 6], [286, 12], [444, 22], [171, 0]],
        [[70, 0], [183, 42], [231, 26], [236, 14], [386, 13], [38, 6], [289, 12], [447, 22], [168, 0]],
        [[70, 0], [183, 42], [231, 26], [235, 14], [387, 13], [34, 6], [292, 12], [450, 22], [166, 0]],
        [[71, 0], [182, 42], [232, 26], [233, 14], [388, 13], [32, 6], [293, 12], [453, 22], [164, 0]],
        [[71, 0], [183, 42], [231, 26], [232, 14], [389, 13], [29, 6], [295, 12], [456, 22], [162, 0]],
        [[71, 0], [183, 42], [232, 26], [230, 14], [391, 13], [25, 6], [297, 12], [460, 22], [159, 0]],
        [[72, 0], [183, 42], [232, 26], [229, 14], [391, 13], [22, 6], [299, 12], [463, 22], [157, 0]],
        [[72, 0], [183, 42], [232, 26], [227, 14], [393, 13], [18, 6], [302, 12], [467, 22], [154, 0]],
        [[72, 0], [184, 42], [232, 26], [226, 14], [393, 13], [15, 6], [304, 12], [470, 22], [152, 0]],
        [[73, 0], [183, 42], [233, 26], [224, 14], [395, 13], [10, 6], [308, 12], [471, 22], [151, 0]],
        [[73, 0], [184, 42], [232, 26], [223, 14], [396, 13], [6, 6], [311, 12], [471, 22], [152, 0]],
        [[74, 0], [183, 42], [233, 26], [221, 14], [397, 13], [2, 6], [314, 12], [472, 22], [152, 0]],
        [[74, 0], [184, 42], [233, 26], [219, 14], [394, 13], [319, 12], [472, 22], [153, 0]],
        [[74, 0], [184, 42], [234, 26], [218, 14], [391, 13], [321, 12], [473, 22], [153, 0]],
        [[75, 0], [184, 42], [233, 26], [217, 14], [387, 13], [325, 12], [474, 22], [153, 0]],
        [[75, 0], [184, 42], [234, 26], [215, 14], [383, 13], [329, 12], [474, 22], [154, 0]],
        [[76, 0], [184, 42], [234, 26], [213, 14], [378, 13], [334, 12], [475, 22], [154, 0]],
        [[76, 0], [184, 42], [234, 26], [212, 14], [373, 13], [339, 12], [476, 22], [154, 0]],
        [[76, 0], [185, 42], [234, 26], [210, 14], [367, 13], [345, 12], [476, 22], [155, 0]],
        [[77, 0], [184, 42], [235, 26], [208, 14], [360, 13], [352, 12], [477, 22], [155, 0]],
        [[77, 0], [185, 42], [234, 26], [207, 14], [356, 13], [357, 12], [476, 22], [156, 0]],
        [[78, 0], [184, 42], [235, 26], [205, 14], [357, 13], [356, 12], [477, 22], [156, 0]],
        [[78, 0], [184, 42], [236, 26], [204, 14], [357, 13], [355, 12], [477, 22], [157, 0]],
        [[78, 0], [182, 42], [239, 26], [202, 14], [358, 13], [354, 12], [478, 22], [157, 0]],
        [[79, 0], [180, 42], [240, 26], [201, 14], [359, 13], [353, 12], [479, 22], [157, 0]],
        [[79, 0], [178, 42], [243, 26], [199, 14], [360, 13], [352, 12], [479, 22], [158, 0]],
        [[80, 0], [175, 42], [245, 26], [198, 14], [362, 13], [350, 12], [480, 22], [158, 0]],
        [[80, 0], [172, 42], [249, 26], [196, 14], [363, 13], [349, 12], [480, 22], [159, 0]],
        [[80, 0], [170, 42], [252, 26], [195, 14], [363, 13], [348, 12], [481, 22], [159, 0]],
        [[81, 0], [167, 42], [255, 26], [193, 14], [364, 13], [347, 12], [481, 22], [160, 0]],
        [[81, 0], [165, 42], [258, 26], [191, 14], [365, 13], [346, 12], [482, 22], [160, 0]],
        [[82, 0], [162, 42], [260, 26], [190, 14], [366, 13], [345, 12], [482, 22], [161, 0]],
        [[82, 0], [160, 42], [263, 26], [188, 14], [367, 13], [344, 12], [483, 22], [161, 0]],
        [[82, 0], [158, 42], [266, 26], [186, 14], [368, 13], [343, 12], [483, 22], [162, 0]],
        [[83, 0], [155, 42], [269, 26], [184, 14], [369, 13], [342, 12], [484, 22], [162, 0]],
        [[83, 0], [153, 42], [271, 26], [184, 14], [369, 13], [341, 12], [485, 22], [162, 0]],
        [[83, 0], [151, 42], [274, 26], [134, 14], [1, 25], [47, 14], [371, 13], [340, 12], [484, 22], [163, 0]],
        [[84, 0], [148, 42], [277, 26], [132, 14], [3, 25], [45, 14], [372, 13], [341, 12], [483, 22], [163, 0]],
        [[84, 0], [146, 42], [280, 26], [130, 14], [5, 25], [43, 14], [373, 13], [342, 12], [481, 22], [164, 0]],
        [[85, 0], [143, 42], [282, 26], [129, 14], [7, 25], [41, 14], [374, 13], [343, 12], [480, 22], [164, 0]],
        [[85, 0], [141, 42], [285, 26], [127, 14], [9, 25], [39, 14], [375, 13], [344, 12], [478, 22], [165, 0]],
        [[86, 0], [138, 42], [288, 26], [125, 14], [11, 25], [37, 14], [376, 13], [345, 12], [477, 22], [165, 0]],
        [[86, 0], [136, 42], [291, 26], [123, 14], [13, 25], [36, 14], [376, 13], [346, 12], [476, 22], [165, 0]],
        [[87, 0], [133, 42], [294, 26], [121, 14], [15, 25], [34, 14], [377, 13], [347, 12], [474, 22], [166, 0]],
        [[87, 0], [131, 42], [296, 26], [120, 14], [17, 25], [32, 14], [378, 13], [348, 12], [473, 22], [166, 0]],
        [[87, 0], [129, 42], [299, 26], [118, 14], [19, 25], [30, 14], [379, 13], [349, 12], [471, 22], [167, 0]],
        [[88, 0], [126, 42], [302, 26], [116, 14], [21, 25], [28, 14], [381, 13], [349, 12], [470, 22], [167, 0]],
        [[88, 0], [124, 42], [305, 26], [114, 14], [23, 25], [26, 14], [382, 13], [350, 12], [468, 22], [168, 0]],
        [[89, 0], [121, 42], [307, 26], [113, 14], [25, 25], [24, 14], [383, 13], [145, 12], [1, 24], [205, 12], [467, 22], [168, 0]],
        [[89, 0], [119, 42], [310, 26], [111, 14], [27, 25], [22, 14], [384, 13], [143, 12], [4, 24], [205, 12], [465, 22], [169, 0]],
        [[89, 0], [117, 42], [313, 26], [109, 14], [29, 25], [21, 14], [384, 13], [141, 12], [6, 24], [206, 12], [464, 22], [169, 0]],
        [[90, 0], [114, 42], [316, 26], [107, 14], [31, 25], [19, 14], [385, 13], [139, 12], [9, 24], [206, 12], [462, 22], [170, 0]],
        [[90, 0], [111, 42], [319, 26], [106, 14], [34, 25], [16, 14], [386, 13], [136, 12], [12, 24], [207, 12], [461, 22], [170, 0]],
        [[91, 0], [108, 42], [322, 26], [104, 14], [36, 25], [14, 14], [387, 13], [134, 12], [15, 24], [207, 12], [460, 22], [170, 0]],
        [[91, 0], [106, 42], [325, 26], [102, 14], [38, 25], [12, 14], [388, 13], [131, 12], [18, 24], [208, 12], [458, 22], [171, 0]],
        [[92, 0], [103, 42], [328, 26], [100, 14], [40, 25], [10, 14], [389, 13], [129, 12], [21, 24], [208, 12], [456, 22], [172, 0]],
        [[92, 0], [102, 42], [330, 26], [98, 14], [42, 25], [9, 14], [390, 13], [126, 12], [23, 24], [209, 12], [455, 22], [172, 0]],
        [[92, 0], [99, 42], [334, 26], [96, 14], [44, 25], [7, 14], [391, 13], [124, 12], [25, 24], [210, 12], [454, 22], [172, 0]],
        [[93, 0], [96, 42], [336, 26], [95, 14], [46, 25], [5, 14], [392, 13], [121, 12], [29, 24], [210, 12], [452, 22], [173, 0]],
        [[93, 0], [94, 42], [339, 26], [93, 14], [49, 25], [2, 14], [393, 13], [118, 12], [32, 24], [211, 12], [451, 22], [173, 0]],
        [[94, 0], [91, 42], [342, 26], [91, 14], [51, 25], [193, 13], [1, 24], [200, 13], [116, 12], [35, 24], [210, 12], [450, 22], [174, 0]],
        [[94, 0], [89, 42], [345, 26], [89, 14], [53, 25], [191, 13], [5, 24], [197, 13], [113, 12], [38, 24], [209, 12], [451, 22], [174, 0]],
        [[95, 0], [86, 42], [348, 26], [87, 14], [55, 25], [190, 13], [8, 24], [194, 13], [111, 12], [41, 24], [207, 12], [451, 22], [175, 0]],
        [[95, 0], [84, 42], [351, 26], [85, 14], [58, 25], [187, 13], [12, 24], [191, 13], [108, 12], [44, 24], [206, 12], [452, 22], [175, 0]],
        [[95, 0], [82, 42], [354, 26], [83, 14], [60, 25], [186, 13], [14, 24], [189, 13], [105, 12], [48, 24], [204, 12], [452, 22], [176, 0]],
        [[96, 0], [79, 42], [356, 26], [82, 14], [62, 25], [185, 13], [17, 24], [186, 13], [102, 12], [51, 24], [202, 12], [454, 22], [176, 0]],
        [[97, 0], [76, 42], [359, 26], [80, 14], [64, 25], [183, 13], [21, 24], [184, 13], [98, 12], [55, 24], [200, 12], [454, 22], [177, 0]],
        [[97, 0], [74, 42], [362, 26], [78, 14], [66, 25], [182, 13], [23, 24], [182, 13], [96, 12], [57, 24], [200, 12], [454, 22], [177, 0]],
        [[97, 0], [72, 42], [365, 26], [76, 14], [68, 25], [181, 13], [27, 24], [178, 13], [93, 12], [61, 24], [198, 12], [454, 22], [178, 0]],
        [[98, 0], [69, 42], [368, 26], [74, 14], [70, 25], [179, 13], [31, 24], [175, 13], [90, 12], [64, 24], [197, 12], [455, 22], [178, 0]],
        [[98, 0], [67, 42], [371, 26], [72, 14], [73, 25], [177, 13], [34, 24], [172, 13], [86, 12], [69, 24], [194, 12], [456, 22], [179, 0]],
        [[99, 0], [64, 42], [374, 26], [70, 14], [75, 25], [175, 13], [38, 24], [169, 13], [83, 12], [72, 24], [193, 12], [457, 22], [179, 0]],
        [[99, 0], [62, 42], [376, 26], [69, 14], [77, 25], [174, 13], [42, 24], [165, 13], [79, 12], [77, 24], [191, 12], [457, 22], [180, 0]],
        [[100, 0], [58, 42], [380, 26], [67, 14], [80, 25], [172, 13], [45, 24], [162, 13], [76, 12], [80, 24], [190, 12], [458, 22], [180, 0]],
        [[100, 0], [56, 42], [383, 26], [65, 14], [82, 25], [170, 13], [50, 24], [158, 13], [72, 12], [85, 24], [188, 12], [458, 22], [181, 0]],
        [[101, 0], [53, 42], [386, 26], [63, 14], [84, 25], [169, 13], [54, 24], [154, 13], [68, 12], [89, 24], [187, 12], [459, 22], [181, 0]],
        [[101, 0], [51, 42], [389, 26], [61, 14], [86, 25], [167, 13], [59, 24], [151, 13], [63, 12], [93, 24], [186, 12], [459, 22], [182, 0]],
        [[101, 0], [50, 42], [391, 26], [60, 14], [87, 25], [166, 13], [62, 24], [148, 13], [60, 12], [97, 24], [184, 12], [460, 22], [182, 0]],
        [[102, 0], [46, 42], [395, 26], [58, 14], [90, 25], [164, 13], [66, 24], [144, 13], [56, 12], [101, 24], [183, 12], [460, 22], [183, 0]],
        [[102, 0], [44, 42], [397, 26], [57, 14], [92, 25], [162, 13], [72, 24], [139, 13], [51, 12], [107, 24], [181, 12], [461, 22], [183, 0]],
        [[103, 0], [41, 42], [401, 26], [54, 14], [95, 25], [160, 13], [77, 24], [134, 13], [46, 12], [112, 24], [179, 12], [462, 22], [184, 0]],
        [[103, 0], [39, 42], [404, 26], [52, 14], [97, 25], [159, 13], [82, 24], [129, 13], [41, 12], [118, 24], [177, 12], [463, 22], [184, 0]],
        [[104, 0], [36, 42], [406, 26], [50, 14], [100, 25], [157, 13], [89, 24], [123, 13], [36, 12], [123, 24], [176, 12], [463, 22], [185, 0]],
        [[104, 0], [34, 42], [409, 26], [48, 14], [102, 25], [156, 13], [95, 24], [117, 13], [30, 12], [130, 24], [174, 12], [464, 22], [185, 0]],
        [[105, 0], [31, 42], [412, 26], [46, 14], [105, 25], [153, 13], [102, 24], [111, 13], [24, 12], [136, 24], [173, 12], [464, 22], [186, 0]],
        [[105, 0], [29, 42], [415, 26], [44, 14], [107, 25], [152, 13], [109, 24], [104, 13], [17, 12], [144, 24], [170, 12], [466, 22], [186, 0]],
        [[106, 0], [26, 42], [418, 26], [42, 14], [109, 25], [150, 13], [117, 24], [98, 13], [7, 12], [153, 24], [169, 12], [1, 23], [465, 22], [187, 0]],
        [[106, 0], [24, 42], [421, 26], [40, 14], [112, 25], [148, 13], [127, 24], [86, 13], [163, 24], [167, 12], [3, 23], [464, 22], [187, 0]],
        [[106, 0], [22, 42], [424, 26], [39, 14], [113, 25], [147, 13], [137, 24], [67, 13], [172, 24], [166, 12], [4, 23], [463, 22], [188, 0]],
        [[107, 0], [19, 42], [427, 26], [37, 14], [115, 25], [145, 13], [156, 24], [30, 13], [192, 24], [164, 12], [6, 23], [462, 22], [188, 0]],
        [[108, 0], [16, 42], [430, 26], [35, 14], [118, 25], [143, 13], [378, 24], [163, 12], [8, 23], [460, 22], [189, 0]],
        [[108, 0], [14, 42], [432, 26], [34, 14], [120, 25], [142, 13], [379, 24], [161, 12], [10, 23], [459, 22], [189, 0]],
        [[109, 0], [11, 42], [436, 26], [30, 14], [124, 25], [139, 13], [380, 24], [160, 12], [12, 23], [457, 22], [190, 0]],
        [[109, 0], [9, 42], [439, 26], [29, 14], [125, 25], [138, 13], [380, 24], [158, 12], [15, 23], [456, 22], [190, 0]],
        [[110, 0], [6, 42], [442, 26], [27, 14], [127, 25], [136, 13], [382, 24], [156, 12], [17, 23], [454, 22], [191, 0]],
        [[110, 0], [4, 42], [445, 26], [25, 14], [130, 25], [134, 13], [382, 24], [155, 12], [18, 23], [454, 22], [191, 0]],
        [[111, 0], [1, 42], [448, 26], [23, 14], [133, 25], [132, 13], [383, 24], [152, 12], [21, 23], [452, 22], [192, 0]],
        [[111, 0], [449, 26], [22, 14], [135, 25], [130, 13], [384, 24], [151, 12], [23, 23], [450, 22], [193, 0]],
        [[112, 0], [449, 26], [20, 14], [138, 25], [128, 13], [385, 24], [149, 12], [25, 23], [449, 22], [193, 0]],
        [[112, 0], [450, 26], [18, 14], [140, 25], [127, 13], [385, 24], [148, 12], [27, 23], [447, 22], [194, 0]],
        [[112, 0], [451, 26], [16, 14], [142, 25], [125, 13], [387, 24], [146, 12], [29, 23], [446, 22], [194, 0]],
        [[113, 0], [451, 26], [14, 14], [145, 25], [123, 13], [387, 24], [145, 12], [31, 23], [444, 22], [195, 0]],
        [[113, 0], [452, 26], [12, 14], [147, 25], [121, 13], [389, 24], [142, 12], [34, 23], [443, 22], [195, 0]],
        [[114, 0], [452, 26], [10, 14], [150, 25], [119, 13], [389, 24], [141, 12], [35, 23], [442, 22], [196, 0]],
        [[114, 0], [453, 26], [8, 14], [153, 25], [117, 13], [390, 24], [138, 12], [38, 23], [440, 22], [197, 0]],
        [[115, 0], [453, 26], [6, 14], [155, 25], [115, 13], [391, 24], [137, 12], [40, 23], [439, 22], [197, 0]],
        [[115, 0], [455, 26], [3, 14], [158, 25], [113, 13], [391, 24], [136, 12], [42, 23], [437, 22], [198, 0]],
        [[116, 0], [455, 26], [1, 14], [160, 25], [111, 13], [393, 24], [134, 12], [44, 23], [436, 22], [198, 0]],
        [[116, 0], [455, 26], [163, 25], [109, 13], [393, 24], [132, 12], [47, 23], [434, 22], [199, 0]],
        [[117, 0], [455, 26], [163, 25], [107, 13], [395, 24], [130, 12], [48, 23], [434, 22], [199, 0]],
        [[117, 0], [456, 26], [164, 25], [105, 13], [395, 24], [129, 12], [50, 23], [432, 22], [200, 0]],
        [[118, 0], [456, 26], [165, 25], [103, 13], [396, 24], [126, 12], [53, 23], [431, 22], [200, 0]],
        [[119, 0], [456, 26], [165, 25], [101, 13], [397, 24], [125, 12], [55, 23], [429, 22], [201, 0]],
        [[119, 0], [457, 26], [166, 25], [99, 13], [398, 24], [123, 12], [57, 23], [428, 22], [201, 0]],
        [[120, 0], [458, 26], [165, 25], [98, 13], [398, 24], [121, 12], [60, 23], [426, 22], [202, 0]],
        [[120, 0], [459, 26], [166, 25], [95, 13], [400, 24], [119, 12], [62, 23], [425, 22], [202, 0]],
        [[121, 0], [459, 26], [167, 25], [93, 13], [400, 24], [118, 12], [64, 23], [423, 22], [203, 0]],
        [[121, 0], [460, 26], [168, 25], [90, 13], [402, 24], [115, 12], [66, 23], [422, 22], [204, 0]],
        [[122, 0], [460, 26], [169, 25], [88, 13], [402, 24], [113, 12], [69, 23], [421, 22], [204, 0]],
        [[122, 0], [461, 26], [169, 25], [87, 13], [403, 24], [111, 12], [71, 23], [419, 22], [205, 0]],
        [[123, 0], [461, 26], [170, 25], [84, 13], [404, 24], [110, 12], [73, 23], [418, 22], [205, 0]],
        [[123, 0], [462, 26], [170, 25], [83, 13], [405, 24], [108, 12], [75, 23], [416, 22], [206, 0]],
        [[124, 0], [462, 26], [171, 25], [81, 13], [405, 24], [106, 12], [78, 23], [415, 22], [206, 0]],
        [[124, 0], [463, 26], [172, 25], [78, 13], [406, 24], [105, 12], [79, 23], [414, 22], [207, 0]],
        [[125, 0], [463, 26], [173, 25], [76, 13], [407, 24], [102, 12], [82, 23], [414, 22], [206, 0]],
        [[125, 0], [464, 26], [174, 25], [73, 13], [408, 24], [101, 12], [84, 23], [415, 22], [204, 0]],
        [[126, 0], [464, 26], [175, 25], [71, 13], [409, 24], [98, 12], [87, 23], [416, 22], [202, 0]],
        [[126, 0], [465, 26], [175, 25], [70, 13], [409, 24], [97, 12], [89, 23], [417, 22], [200, 0]],
        [[127, 0], [466, 26], [176, 25], [66, 13], [411, 24], [94, 12], [92, 23], [418, 22], [198, 0]],
        [[127, 0], [467, 26], [176, 25], [65, 13], [411, 24], [92, 12], [95, 23], [418, 22], [197, 0]],
        [[128, 0], [467, 26], [177, 25], [62, 13], [413, 24], [90, 12], [97, 23], [419, 22], [195, 0]],
        [[128, 0], [468, 26], [178, 25], [60, 13], [413, 24], [89, 12], [98, 23], [420, 22], [194, 0]],
        [[129, 0], [468, 26], [179, 25], [58, 13], [414, 24], [86, 12], [101, 23], [421, 22], [192, 0]],
        [[130, 0], [468, 26], [180, 25], [55, 13], [415, 24], [84, 12], [104, 23], [58, 22], [2, 23], [362, 22], [190, 0]],
        [[130, 0], [469, 26], [181, 25], [53, 13], [416, 24], [82, 12], [106, 23], [56, 22], [4, 23], [363, 22], [188, 0]],
        [[131, 0], [470, 26], [181, 25], [51, 13], [416, 24], [80, 12], [109, 23], [54, 22], [6, 23], [364, 22], [186, 0]],
        [[131, 0], [471, 26], [182, 25], [48, 13], [418, 24], [78, 12], [111, 23], [52, 22], [8, 23], [364, 22], [185, 0]],
        [[132, 0], [471, 26], [183, 25], [46, 13], [418, 24], [76, 12], [113, 23], [51, 22], [10, 23], [365, 22], [183, 0]],
        [[132, 0], [470, 26], [187, 25], [42, 13], [420, 24], [74, 12], [116, 23], [48, 22], [12, 23], [366, 22], [181, 0]],
        [[133, 0], [468, 26], [190, 25], [40, 13], [420, 24], [72, 12], [118, 23], [47, 22], [14, 23], [367, 22], [179, 0]],
        [[133, 0], [467, 26], [193, 25], [37, 13], [422, 24], [69, 12], [121, 23], [45, 22], [16, 23], [367, 22], [178, 0]],
        [[134, 0], [466, 26], [195, 25], [35, 13], [422, 24], [68, 12], [123, 23], [43, 22], [18, 23], [366, 22], [178, 0]],
        [[134, 0], [465, 26], [198, 25], [33, 13], [422, 24], [66, 12], [126, 23], [41, 22], [20, 23], [364, 22], [179, 0]],
        [[135, 0], [463, 26], [201, 25], [30, 13], [424, 24], [64, 12], [128, 23], [39, 22], [22, 23], [363, 22], [179, 0]],
        [[135, 0], [462, 26], [204, 25], [28, 13], [424, 24], [62, 12], [130, 23], [37, 22], [25, 23], [361, 22], [180, 0]],
        [[136, 0], [460, 26], [208, 25], [24, 13], [426, 24], [59, 12], [133, 23], [35, 22], [27, 23], [359, 22], [181, 0]],
        [[137, 0], [458, 26], [211, 25], [22, 13], [426, 24], [57, 12], [136, 23], [33, 22], [29, 23], [358, 22], [181, 0]],
        [[137, 0], [457, 26], [214, 25], [20, 13], [427, 24], [55, 12], [138, 23], [31, 22], [31, 23], [356, 22], [182, 0]],
        [[138, 0], [455, 26], [218, 25], [16, 13], [428, 24], [53, 12], [141, 23], [29, 22], [33, 23], [354, 22], [183, 0]],
        [[138, 0], [455, 26], [220, 25], [14, 13], [429, 24], [50, 12], [144, 23], [27, 22], [35, 23], [353, 22], [183, 0]],
        [[139, 0], [453, 26], [224, 25], [11, 13], [429, 24], [48, 12], [147, 23], [25, 22], [37, 23], [351, 22], [184, 0]],
        [[140, 0], [451, 26], [227, 25], [8, 13], [431, 24], [46, 12], [149, 23], [23, 22], [39, 23], [350, 22], [184, 0]],
        [[140, 0], [450, 26], [230, 25], [6, 13], [431, 24], [44, 12], [151, 23], [22, 22], [41, 23], [348, 22], [185, 0]],
        [[141, 0], [448, 26], [234, 25], [2, 13], [432, 24], [42, 12], [154, 23], [20, 22], [43, 23], [347, 22], [185, 0]],
        [[141, 0], [447, 26], [237, 25], [433, 24], [39, 12], [157, 23], [18, 22], [45, 23], [345, 22], [186, 0]],
        [[142, 0], [446, 26], [236, 25], [434, 24], [37, 12], [160, 23], [15, 22], [48, 23], [343, 22], [187, 0]],
        [[142, 0], [444, 26], [238, 25], [435, 24], [35, 12], [162, 23], [13, 22], [50, 23], [342, 22], [187, 0]],
        [[143, 0], [443, 26], [238, 25], [436, 24], [32, 12], [165, 23], [11, 22], [52, 23], [340, 22], [188, 0]],
        [[144, 0], [441, 26], [238, 25], [437, 24], [30, 12], [168, 23], [9, 22], [54, 23], [339, 22], [188, 0]],
        [[144, 0], [440, 26], [239, 25], [438, 24], [27, 12], [170, 23], [8, 22], [56, 23], [337, 22], [189, 0]],
        [[145, 0], [438, 26], [240, 25], [438, 24], [25, 12], [173, 23], [6, 22], [58, 23], [335, 22], [190, 0]],
        [[145, 0], [437, 26], [240, 25], [440, 24], [22, 12], [176, 23], [4, 22], [60, 23], [334, 22], [190, 0]],
        [[146, 0], [435, 26], [241, 25], [440, 24], [20, 12], [179, 23], [1, 22], [63, 23], [332, 22], [191, 0]],
        [[146, 0], [435, 26], [240, 25], [441, 24], [18, 12], [246, 23], [331, 22], [191, 0]],
        [[147, 0], [433, 26], [241, 25], [442, 24], [15, 12], [249, 23], [329, 22], [192, 0]],
        [[147, 0], [432, 26], [241, 25], [443, 24], [13, 12], [252, 23], [327, 22], [193, 0]],
        [[148, 0], [430, 26], [242, 25], [444, 24], [10, 12], [255, 23], [326, 22], [193, 0]],
        [[149, 0], [428, 26], [243, 25], [444, 24], [8, 12], [258, 23], [324, 22], [194, 0]],
        [[150, 0], [426, 26], [243, 25], [446, 24], [5, 12], [261, 23], [322, 22], [195, 0]],
        [[150, 0], [425, 26], [244, 25], [446, 24], [3, 12], [264, 23], [321, 22], [195, 0]],
        [[151, 0], [423, 26], [244, 25], [448, 24], [267, 23], [319, 22], [196, 0]],
        [[151, 0], [423, 26], [244, 25], [448, 24], [268, 23], [317, 22], [197, 0]],
        [[152, 0], [421, 26], [245, 25], [448, 24], [269, 23], [316, 22], [197, 0]],
        [[152, 0], [420, 26], [245, 25], [450, 24], [268, 23], [315, 22], [198, 0]],
        [[153, 0], [418, 26], [246, 25], [450, 24], [270, 23], [313, 22], [198, 0]],
        [[154, 0], [416, 26], [247, 25], [451, 24], [270, 23], [311, 22], [199, 0]],
        [[154, 0], [416, 26], [246, 25], [452, 24], [271, 23], [309, 22], [200, 0]],
        [[155, 0], [414, 26], [247, 25], [453, 24], [271, 23], [308, 22], [200, 0]],
        [[155, 0], [413, 26], [247, 25], [454, 24], [272, 23], [306, 22], [201, 0]],
        [[156, 0], [411, 26], [248, 25], [455, 24], [272, 23], [305, 22], [201, 0]],
        [[157, 0], [409, 26], [249, 25], [455, 24], [273, 23], [303, 22], [202, 0]],
        [[157, 0], [408, 26], [249, 25], [457, 24], [273, 23], [301, 22], [203, 0]],
        [[158, 0], [406, 26], [250, 25], [457, 24], [273, 23], [300, 22], [204, 0]],
        [[158, 0], [405, 26], [251, 25], [458, 24], [273, 23], [299, 22], [204, 0]],
        [[159, 0], [404, 26], [250, 25], [459, 24], [274, 23], [297, 22], [205, 0]],
        [[160, 0], [402, 26], [251, 25], [460, 24], [274, 23], [296, 22], [205, 0]],
        [[160, 0], [401, 26], [251, 25], [461, 24], [275, 23], [294, 22], [206, 0]],
        [[161, 0], [399, 26], [252, 25], [462, 24], [275, 23], [292, 22], [207, 0]],
        [[162, 0], [397, 26], [253, 25], [462, 24], [276, 23], [291, 22], [207, 0]],
        [[162, 0], [398, 26], [251, 25], [463, 24], [277, 23], [289, 22], [208, 0]],
        [[163, 0], [398, 26], [250, 25], [464, 24], [277, 23], [287, 22], [209, 0]],
        [[164, 0], [398, 26], [248, 25], [465, 24], [278, 23], [286, 22], [209, 0]],
        [[164, 0], [399, 26], [247, 25], [466, 24], [278, 23], [284, 22], [210, 0]],
        [[165, 0], [399, 26], [245, 25], [467, 24], [279, 23], [282, 22], [211, 0]],
        [[165, 0], [401, 26], [243, 25], [468, 24], [279, 23], [281, 22], [211, 0]],
        [[166, 0], [401, 26], [242, 25], [468, 24], [280, 23], [279, 22], [212, 0]],
        [[167, 0], [401, 26], [240, 25], [470, 24], [280, 23], [278, 22], [212, 0]],
        [[167, 0], [402, 26], [239, 25], [470, 24], [281, 23], [276, 22], [213, 0]],
        [[168, 0], [402, 26], [238, 25], [471, 24], [281, 23], [274, 22], [214, 0]],
        [[168, 0], [403, 26], [236, 25], [472, 24], [282, 23], [272, 22], [215, 0]],
        [[169, 0], [404, 26], [234, 25], [473, 24], [282, 23], [271, 22], [215, 0]],
        [[170, 0], [404, 26], [232, 25], [473, 24], [284, 23], [269, 22], [216, 0]],
        [[170, 0], [405, 26], [231, 25], [470, 24], [288, 23], [267, 22], [217, 0]],
        [[171, 0], [406, 26], [229, 25], [468, 24], [291, 23], [266, 22], [217, 0]],
        [[172, 0], [406, 26], [227, 25], [467, 24], [294, 23], [264, 22], [218, 0]],
        [[172, 0], [407, 26], [226, 25], [465, 24], [297, 23], [262, 22], [219, 0]],
        [[173, 0], [407, 26], [225, 25], [463, 24], [300, 23], [261, 22], [219, 0]],
        [[174, 0], [407, 26], [223, 25], [461, 24], [304, 23], [259, 22], [220, 0]],
        [[174, 0], [409, 26], [221, 25], [459, 24], [307, 23], [257, 22], [221, 0]],
        [[175, 0], [409, 26], [219, 25], [458, 24], [310, 23], [256, 22], [221, 0]],
        [[176, 0], [409, 26], [218, 25], [455, 24], [314, 23], [254, 22], [222, 0]],
        [[176, 0], [410, 26], [217, 25], [453, 24], [317, 23], [252, 22], [223, 0]],
        [[177, 0], [411, 26], [214, 25], [451, 24], [321, 23], [250, 22], [224, 0]],
        [[178, 0], [411, 26], [213, 25], [449, 24], [324, 23], [248, 22], [225, 0]],
        [[178, 0], [413, 26], [210, 25], [447, 24], [328, 23], [247, 22], [225, 0]],
        [[179, 0], [413, 26], [209, 25], [445, 24], [331, 23], [245, 22], [226, 0]],
        [[180, 0], [413, 26], [208, 25], [443, 24], [334, 23], [244, 22], [226, 0]],
        [[180, 0], [414, 26], [206, 25], [441, 24], [338, 23], [242, 22], [227, 0]],
        [[181, 0], [415, 26], [204, 25], [439, 24], [341, 23], [240, 22], [228, 0]],
        [[182, 0], [414, 26], [203, 25], [437, 24], [345, 23], [238, 22], [229, 0]],
        [[183, 0], [412, 26], [204, 25], [434, 24], [349, 23], [237, 22], [229, 0]],
        [[183, 0], [411, 26], [205, 25], [431, 24], [353, 23], [235, 22], [230, 0]],
        [[184, 0], [409, 26], [205, 25], [430, 24], [356, 23], [233, 22], [231, 0]],
        [[185, 0], [408, 26], [205, 25], [427, 24], [360, 23], [232, 22], [231, 0]],
        [[185, 0], [407, 26], [205, 25], [425, 24], [364, 23], [230, 22], [232, 0]],
        [[186, 0], [405, 26], [206, 25], [422, 24], [368, 23], [228, 22], [233, 0]],
        [[187, 0], [403, 26], [207, 25], [419, 24], [372, 23], [226, 22], [234, 0]],
        [[187, 0], [403, 26], [206, 25], [418, 24], [375, 23], [225, 22], [234, 0]],
        [[188, 0], [401, 26], [207, 25], [415, 24], [379, 23], [223, 22], [235, 0]],
        [[189, 0], [399, 26], [208, 25], [411, 24], [384, 23], [221, 22], [236, 0]],
        [[189, 0], [399, 26], [207, 25], [409, 24], [388, 23], [219, 22], [237, 0]],
        [[190, 0], [397, 26], [208, 25], [406, 24], [392, 23], [218, 22], [237, 0]],
        [[191, 0], [395, 26], [208, 25], [404, 24], [396, 23], [216, 22], [238, 0]],
        [[191, 0], [394, 26], [209, 25], [400, 24], [401, 23], [214, 22], [239, 0]],
        [[192, 0], [392, 26], [210, 25], [397, 24], [405, 23], [212, 22], [240, 0]],
        [[193, 0], [391, 26], [209, 25], [394, 24], [410, 23], [211, 22], [240, 0]],
        [[194, 0], [389, 26], [210, 25], [391, 24], [414, 23], [209, 22], [241, 0]],
        [[194, 0], [388, 26], [211, 25], [388, 24], [417, 23], [208, 22], [242, 0]],
        [[195, 0], [387, 26], [210, 25], [385, 24], [422, 23], [207, 22], [242, 0]],
        [[196, 0], [385, 26], [211, 25], [381, 24], [428, 23], [204, 22], [243, 0]],
        [[196, 0], [384, 26], [211, 25], [378, 24], [433, 23], [202, 22], [244, 0]],
        [[197, 0], [382, 26], [212, 25], [374, 24], [438, 23], [200, 22], [245, 0]],
        [[198, 0], [381, 26], [212, 25], [373, 24], [440, 23], [198, 22], [246, 0]],
        [[199, 0], [379, 26], [212, 25], [374, 24], [441, 23], [197, 22], [246, 0]],
        [[199, 0], [378, 26], [213, 25], [374, 24], [442, 23], [195, 22], [247, 0]],
        [[200, 0], [376, 26], [213, 25], [376, 24], [441, 23], [194, 22], [248, 0]],
        [[201, 0], [374, 26], [214, 25], [376, 24], [442, 23], [192, 22], [249, 0]],
        [[202, 0], [373, 26], [213, 25], [377, 24], [443, 23], [191, 22], [249, 0]],
        [[202, 0], [372, 26], [214, 25], [377, 24], [444, 23], [189, 22], [250, 0]],
        [[203, 0], [370, 26], [217, 25], [376, 24], [444, 23], [187, 22], [251, 0]],
        [[204, 0], [369, 26], [219, 25], [374, 24], [445, 23], [185, 22], [252, 0]],
        [[205, 0], [40, 26], [2, 0], [325, 26], [223, 25], [371, 24], [446, 23], [184, 22], [252, 0]],
        [[205, 0], [38, 26], [5, 0], [323, 26], [226, 25], [369, 24], [447, 23], [182, 22], [253, 0]],
        [[206, 0], [36, 26], [7, 0], [321, 26], [230, 25], [367, 24], [447, 23], [180, 22], [254, 0]],
        [[207, 0], [34, 26], [8, 0], [321, 26], [233, 25], [364, 24], [448, 23], [178, 22], [255, 0]],
        [[208, 0], [31, 26], [11, 0], [319, 26], [237, 25], [361, 24], [449, 23], [176, 22], [256, 0]],
        [[208, 0], [30, 26], [13, 0], [317, 26], [241, 25], [358, 24], [450, 23], [174, 22], [257, 0]],
        [[209, 0], [28, 26], [15, 0], [315, 26], [245, 25], [356, 24], [450, 23], [173, 22], [257, 0]],
        [[210, 0], [26, 26], [17, 0], [314, 26], [248, 25], [353, 24], [451, 23], [171, 22], [258, 0]],
        [[210, 0], [24, 26], [19, 0], [313, 26], [251, 25], [351, 24], [452, 23], [169, 22], [259, 0]],
        [[211, 0], [22, 26], [21, 0], [311, 26], [255, 25], [348, 24], [453, 23], [167, 22], [260, 0]],
        [[212, 0], [20, 26], [23, 0], [309, 26], [260, 25], [344, 24], [454, 23], [166, 22], [260, 0]],
        [[213, 0], [18, 26], [24, 0], [309, 26], [263, 25], [342, 24], [454, 23], [164, 22], [261, 0]],
        [[214, 0], [15, 26], [27, 0], [307, 26], [266, 25], [340, 24], [455, 23], [162, 22], [262, 0]],
        [[214, 0], [14, 26], [29, 0], [305, 26], [266, 25], [341, 24], [456, 23], [160, 22], [263, 0]],
        [[215, 0], [12, 26], [31, 0], [303, 26], [267, 25], [341, 24], [457, 23], [159, 22], [263, 0]],
        [[216, 0], [9, 26], [34, 0], [302, 26], [267, 25], [342, 24], [457, 23], [157, 22], [264, 0]],
        [[217, 0], [7, 26], [36, 0], [300, 26], [267, 25], [343, 24], [458, 23], [155, 22], [265, 0]],
        [[218, 0], [5, 26], [38, 0], [298, 26], [268, 25], [343, 24], [459, 23], [153, 22], [266, 0]],
        [[218, 0], [4, 26], [39, 0], [297, 26], [269, 25], [343, 24], [460, 23], [151, 22], [267, 0]],
        [[219, 0], [1, 26], [42, 0], [296, 26], [269, 25], [344, 24], [460, 23], [149, 22], [268, 0]],
        [[263, 0], [294, 26], [269, 25], [345, 24], [461, 23], [148, 22], [268, 0]],
        [[264, 0], [292, 26], [270, 25], [345, 24], [462, 23], [146, 22], [269, 0]],
        [[264, 0], [291, 26], [271, 25], [345, 24], [463, 23], [144, 22], [270, 0]],
        [[265, 0], [289, 26], [271, 25], [347, 24], [463, 23], [142, 22], [271, 0]],
        [[266, 0], [288, 26], [271, 25], [343, 24], [468, 23], [140, 22], [272, 0]],
        [[267, 0], [286, 26], [272, 25], [338, 24], [474, 23], [138, 22], [273, 0]],
        [[268, 0], [284, 26], [272, 25], [335, 24], [479, 23], [137, 22], [273, 0]],
        [[269, 0], [283, 26], [272, 25], [330, 24], [485, 23], [135, 22], [274, 0]],
        [[270, 0], [281, 26], [273, 25], [325, 24], [491, 23], [133, 22], [275, 0]],
        [[270, 0], [280, 26], [274, 25], [321, 24], [496, 23], [131, 22], [276, 0]],
        [[271, 0], [278, 26], [274, 25], [317, 24], [502, 23], [129, 22], [277, 0]],
        [[272, 0], [277, 26], [274, 25], [311, 24], [509, 23], [127, 22], [278, 0]],
        [[273, 0], [275, 26], [275, 25], [305, 24], [516, 23], [125, 22], [279, 0]],
        [[274, 0], [273, 26], [275, 25], [301, 24], [6, 40], [516, 23], [124, 22], [279, 0]],
        [[275, 0], [271, 26], [276, 25], [294, 24], [13, 40], [517, 23], [122, 22], [280, 0]],
        [[275, 0], [271, 26], [276, 25], [287, 24], [21, 40], [517, 23], [120, 22], [281, 0]],
        [[276, 0], [269, 26], [276, 25], [280, 24], [29, 40], [518, 23], [118, 22], [282, 0]],
        [[277, 0], [267, 26], [277, 25], [271, 24], [38, 40], [519, 23], [116, 22], [283, 0]],
        [[278, 0], [265, 26], [277, 25], [262, 24], [48, 40], [520, 23], [114, 22], [284, 0]],
        [[279, 0], [263, 26], [278, 25], [250, 24], [60, 40], [521, 23], [112, 22], [285, 0]],
        [[280, 0], [262, 26], [278, 25], [238, 24], [72, 40], [522, 23], [111, 22], [285, 0]],
        [[281, 0], [260, 26], [279, 25], [180, 24], [131, 40], [521, 23], [110, 22], [286, 0]],
        [[281, 0], [259, 26], [279, 25], [181, 24], [131, 40], [523, 23], [107, 22], [287, 0]],
        [[282, 0], [258, 26], [279, 25], [181, 24], [131, 40], [524, 23], [105, 22], [288, 0]],
        [[283, 0], [256, 26], [280, 25], [181, 24], [131, 40], [525, 23], [103, 22], [289, 0]],
        [[284, 0], [254, 26], [280, 25], [182, 24], [132, 40], [525, 23], [101, 22], [290, 0]],
        [[285, 0], [252, 26], [281, 25], [182, 24], [132, 40], [526, 23], [99, 22], [291, 0]],
        [[286, 0], [251, 26], [281, 25], [181, 24], [133, 40], [527, 23], [97, 22], [292, 0]],
        [[287, 0], [249, 26], [281, 25], [182, 24], [133, 40], [528, 23], [96, 22], [292, 0]],
        [[288, 0], [248, 26], [281, 25], [182, 24], [133, 40], [529, 23], [94, 22], [293, 0]],
        [[289, 0], [248, 26], [280, 25], [182, 24], [133, 40], [529, 23], [93, 22], [294, 0]],
        [[290, 0], [249, 26], [278, 25], [182, 24], [134, 40], [529, 23], [91, 22], [295, 0]],
        [[290, 0], [250, 26], [276, 25], [183, 24], [134, 40], [530, 23], [89, 22], [296, 0]],
        [[291, 0], [250, 26], [275, 25], [183, 24], [134, 40], [532, 23], [86, 22], [297, 0]],
        [[292, 0], [251, 26], [273, 25], [183, 24], [134, 40], [533, 23], [84, 22], [298, 0]],
        [[293, 0], [251, 26], [271, 25], [184, 24], [134, 40], [534, 23], [83, 22], [298, 0]],
        [[294, 0], [252, 26], [269, 25], [184, 24], [134, 40], [535, 23], [80, 22], [300, 0]],
        [[295, 0], [252, 26], [268, 25], [184, 24], [135, 40], [534, 23], [79, 22], [301, 0]],
        [[296, 0], [252, 26], [266, 25], [185, 24], [135, 40], [535, 23], [78, 22], [301, 0]],
        [[297, 0], [253, 26], [264, 25], [185, 24], [135, 40], [536, 23], [76, 22], [302, 0]],
        [[298, 0], [253, 26], [263, 25], [185, 24], [135, 40], [537, 23], [74, 22], [303, 0]],
        [[298, 0], [254, 26], [261, 25], [186, 24], [135, 40], [538, 23], [72, 22], [304, 0]],
        [[299, 0], [255, 26], [259, 25], [186, 24], [135, 40], [539, 23], [70, 22], [305, 0]],
        [[300, 0], [255, 26], [258, 25], [186, 24], [136, 40], [539, 23], [68, 22], [306, 0]],
        [[301, 0], [256, 26], [256, 25], [186, 24], [136, 40], [540, 23], [66, 22], [307, 0]],
        [[302, 0], [256, 26], [254, 25], [187, 24], [136, 40], [541, 23], [64, 22], [308, 0]],
        [[303, 0], [257, 26], [252, 25], [187, 24], [136, 40], [542, 23], [62, 22], [309, 0]],
        [[304, 0], [257, 26], [251, 25], [187, 24], [136, 40], [543, 23], [60, 22], [310, 0]],
        [[305, 0], [258, 26], [248, 25], [188, 24], [136, 40], [544, 23], [58, 22], [311, 0]],
        [[306, 0], [258, 26], [247, 25], [188, 24], [137, 40], [544, 23], [56, 22], [312, 0]],
        [[307, 0], [259, 26], [244, 25], [189, 24], [137, 40], [545, 23], [54, 22], [313, 0]],
        [[308, 0], [259, 26], [243, 25], [189, 24], [137, 40], [546, 23], [52, 22], [314, 0]],
        [[309, 0], [259, 26], [242, 25], [143, 24], [7, 40], [39, 24], [137, 40], [547, 23], [51, 22], [314, 0]],
        [[310, 0], [260, 26], [240, 25], [143, 24], [19, 40], [27, 24], [137, 40], [548, 23], [49, 22], [315, 0]],
        [[311, 0], [260, 26], [238, 25], [144, 24], [37, 40], [9, 24], [137, 40], [549, 23], [47, 22], [316, 0]],
        [[312, 0], [261, 26], [236, 25], [144, 24], [184, 40], [549, 23], [45, 22], [317, 0]],
        [[313, 0], [261, 26], [235, 25], [144, 24], [184, 40], [550, 23], [43, 22], [318, 0]],
        [[314, 0], [262, 26], [232, 25], [145, 24], [184, 40], [551, 23], [41, 22], [319, 0]],
        [[315, 0], [263, 26], [230, 25], [144, 24], [185, 40], [552, 23], [39, 22], [320, 0]],
        [[316, 0], [263, 26], [229, 25], [144, 24], [185, 40], [553, 23], [37, 22], [321, 0]],
        [[316, 0], [265, 26], [226, 25], [145, 24], [185, 40], [554, 23], [35, 22], [322, 0]],
        [[317, 0], [265, 26], [225, 25], [145, 24], [186, 40], [554, 23], [33, 22], [323, 0]],
        [[318, 0], [265, 26], [224, 25], [145, 24], [186, 40], [555, 23], [31, 22], [324, 0]],
        [[319, 0], [266, 26], [221, 25], [146, 24], [186, 40], [556, 23], [29, 22], [325, 0]],
        [[320, 0], [266, 26], [220, 25], [146, 24], [186, 40], [557, 23], [27, 22], [326, 0]],
        [[321, 0], [267, 26], [218, 25], [146, 24], [186, 40], [558, 23], [25, 22], [327, 0]],
        [[322, 0], [268, 26], [216, 25], [146, 24], [186, 40], [559, 23], [23, 22], [328, 0]],
        [[323, 0], [268, 26], [214, 25], [147, 24], [187, 40], [559, 23], [21, 22], [329, 0]],
        [[324, 0], [269, 26], [212, 25], [146, 24], [188, 40], [560, 23], [19, 22], [330, 0]],
        [[325, 0], [270, 26], [210, 25], [146, 24], [188, 40], [561, 23], [17, 22], [331, 0]],
        [[326, 0], [270, 26], [208, 25], [147, 24], [188, 40], [562, 23], [15, 22], [332, 0]],
        [[327, 0], [271, 26], [206, 25], [147, 24], [188, 40], [563, 23], [13, 22], [333, 0]],
        [[328, 0], [272, 26], [204, 25], [147, 24], [188, 40], [564, 23], [11, 22], [334, 0]],
        [[329, 0], [272, 26], [202, 25], [148, 24], [189, 40], [564, 23], [9, 22], [335, 0]],
        [[330, 0], [273, 26], [200, 25], [148, 24], [189, 40], [565, 23], [7, 22], [336, 0]],
        [[331, 0], [273, 26], [199, 25], [148, 24], [189, 40], [566, 23], [5, 22], [337, 0]],
        [[332, 0], [274, 26], [196, 25], [149, 24], [189, 40], [567, 23], [3, 22], [338, 0]],
        [[333, 0], [275, 26], [194, 25], [149, 24], [189, 40], [568, 23], [1, 22], [339, 0]],
        [[334, 0], [276, 26], [192, 25], [148, 24], [190, 40], [569, 23], [339, 0]],
        [[335, 0], [276, 26], [191, 25], [148, 24], [191, 40], [569, 23], [338, 0]],
        [[336, 0], [277, 26], [188, 25], [149, 24], [191, 40], [570, 23], [337, 0]],
        [[337, 0], [278, 26], [186, 25], [149, 24], [191, 40], [571, 23], [336, 0]],
        [[338, 0], [279, 26], [184, 25], [149, 24], [191, 40], [572, 23], [335, 0]],
        [[339, 0], [279, 26], [182, 25], [150, 24], [191, 40], [573, 23], [334, 0]],
        [[340, 0], [280, 26], [180, 25], [150, 24], [192, 40], [573, 23], [333, 0]],
        [[341, 0], [281, 26], [177, 25], [151, 24], [192, 40], [574, 23], [332, 0]],
        [[343, 0], [281, 26], [175, 25], [151, 24], [192, 40], [575, 23], [331, 0]],
        [[344, 0], [281, 26], [174, 25], [151, 24], [192, 40], [576, 23], [330, 0]],
        [[345, 0], [282, 26], [172, 25], [150, 24], [193, 40], [577, 23], [329, 0]],
        [[346, 0], [283, 26], [169, 25], [3, 40], [148, 24], [193, 40], [578, 23], [328, 0]],
        [[347, 0], [284, 26], [167, 25], [6, 40], [145, 24], [194, 40], [578, 23], [327, 0]],
        [[348, 0], [285, 26], [165, 25], [9, 40], [142, 24], [194, 40], [579, 23], [326, 0]],
        [[349, 0], [286, 26], [162, 25], [13, 40], [139, 24], [194, 40], [580, 23], [325, 0]],
        [[350, 0], [286, 26], [161, 25], [17, 40], [135, 24], [194, 40], [581, 23], [324, 0]],
        [[351, 0], [287, 26], [159, 25], [20, 40], [132, 24], [194, 40], [581, 23], [324, 0]],
        [[352, 0], [288, 26], [157, 25], [23, 40], [128, 24], [195, 40], [582, 23], [323, 0]],
        [[353, 0], [289, 26], [154, 25], [28, 40], [124, 24], [196, 40], [582, 23], [322, 0]],
        [[354, 0], [290, 26], [152, 25], [32, 40], [120, 24], [196, 40], [583, 23], [321, 0]],
        [[355, 0], [291, 26], [150, 25], [35, 40], [117, 24], [196, 40], [585, 23], [319, 0]],
        [[356, 0], [292, 26], [147, 25], [40, 40], [113, 24], [196, 40], [586, 23], [318, 0]],
        [[357, 0], [292, 26], [146, 25], [45, 40], [108, 24], [196, 40], [587, 23], [317, 0]],
        [[358, 0], [294, 26], [143, 25], [49, 40], [104, 24], [196, 40], [587, 23], [317, 0]],
        [[360, 0], [294, 26], [140, 25], [54, 40], [100, 24], [197, 40], [49, 23], [2, 40], [536, 23], [316, 0]],
        [[361, 0], [295, 26], [138, 25], [58, 40], [96, 24], [197, 40], [45, 23], [6, 40], [535, 23], [317, 0]],
        [[362, 0], [296, 26], [136, 25], [63, 40], [91, 24], [197, 40], [41, 23], [10, 40], [534, 23], [318, 0]],
        [[363, 0], [296, 26], [135, 25], [66, 40], [87, 24], [198, 40], [38, 23], [13, 40], [533, 23], [319, 0]],
        [[364, 0], [297, 26], [132, 25], [72, 40], [82, 24], [198, 40], [33, 23], [18, 40], [532, 23], [320, 0]],
        [[365, 0], [298, 26], [130, 25], [77, 40], [77, 24], [198, 40], [28, 23], [24, 40], [530, 23], [321, 0]],
        [[366, 0], [299, 26], [128, 25], [82, 40], [72, 24], [199, 40], [22, 23], [29, 40], [529, 23], [322, 0]],
        [[367, 0], [300, 26], [125, 25], [88, 40], [67, 24], [199, 40], [17, 23], [34, 40], [528, 23], [323, 0]],
        [[368, 0], [301, 26], [123, 25], [94, 40], [61, 24], [199, 40], [11, 23], [40, 40], [527, 23], [324, 0]],
        [[369, 0], [303, 26], [120, 25], [99, 40], [56, 24], [199, 40], [5, 23], [47, 40], [525, 23], [325, 0]],
        [[371, 0], [303, 26], [117, 25], [106, 40], [50, 24], [251, 40], [524, 23], [326, 0]],
        [[372, 0], [304, 26], [115, 25], [112, 40], [44, 24], [251, 40], [522, 23], [328, 0]],
        [[373, 0], [305, 26], [113, 25], [119, 40], [37, 24], [251, 40], [521, 23], [329, 0]],
        [[374, 0], [307, 26], [109, 25], [127, 40], [29, 24], [253, 40], [519, 23], [330, 0]],
        [[375, 0], [307, 26], [108, 25], [133, 40], [23, 24], [253, 40], [519, 23], [330, 0]],
        [[376, 0], [309, 26], [105, 25], [141, 40], [15, 24], [253, 40], [517, 23], [332, 0]],
        [[378, 0], [309, 26], [103, 25], [151, 40], [5, 24], [253, 40], [516, 23], [333, 0]],
        [[379, 0], [310, 26], [100, 25], [411, 40], [514, 23], [334, 0]],
        [[380, 0], [311, 26], [98, 25], [411, 40], [513, 23], [335, 0]],
        [[381, 0], [313, 26], [94, 25], [412, 40], [512, 23], [336, 0]],
        [[382, 0], [314, 26], [92, 25], [412, 40], [511, 23], [337, 0]],
        [[383, 0], [315, 26], [90, 25], [412, 40], [510, 23], [338, 0]],
        [[385, 0], [316, 26], [86, 25], [414, 40], [508, 23], [339, 0]],
        [[386, 0], [317, 26], [84, 25], [414, 40], [507, 23], [340, 0]],
        [[387, 0], [318, 26], [82, 25], [414, 40], [506, 23], [341, 0]],
        [[388, 0], [319, 26], [80, 25], [414, 40], [505, 23], [342, 0]],
        [[389, 0], [321, 26], [76, 25], [416, 40], [502, 23], [344, 0]],
        [[390, 0], [322, 26], [74, 25], [416, 40], [501, 23], [345, 0]],
        [[391, 0], [323, 26], [72, 25], [416, 40], [500, 23], [346, 0]],
        [[393, 0], [324, 26], [68, 25], [417, 40], [499, 23], [347, 0]],
        [[394, 0], [326, 26], [65, 25], [418, 40], [497, 23], [348, 0]],
        [[395, 0], [327, 26], [63, 25], [418, 40], [496, 23], [349, 0]],
        [[396, 0], [329, 26], [59, 25], [419, 40], [495, 23], [350, 0]],
        [[398, 0], [329, 26], [1, 40], [56, 25], [419, 40], [494, 23], [351, 0]],
        [[399, 0], [327, 26], [4, 40], [54, 25], [420, 40], [491, 23], [353, 0]],
        [[400, 0], [326, 26], [6, 40], [52, 25], [420, 40], [491, 23], [353, 0]],
        [[401, 0], [53, 26], [2, 0], [270, 26], [9, 40], [48, 25], [421, 40], [489, 23], [355, 0]],
        [[402, 0], [51, 26], [4, 0], [268, 26], [13, 40], [45, 25], [421, 40], [488, 23], [356, 0]],
        [[403, 0], [50, 26], [6, 0], [266, 26], [15, 40], [43, 25], [421, 40], [487, 23], [357, 0]],
        [[405, 0], [47, 26], [8, 0], [264, 26], [19, 40], [39, 25], [423, 40], [485, 23], [358, 0]],
        [[406, 0], [45, 26], [10, 0], [263, 26], [22, 40], [36, 25], [423, 40], [484, 23], [359, 0]],
        [[407, 0], [43, 26], [13, 0], [261, 26], [25, 40], [33, 25], [423, 40], [483, 23], [360, 0]],
        [[409, 0], [41, 26], [14, 0], [259, 26], [29, 40], [29, 25], [425, 40], [481, 23], [361, 0]],
        [[410, 0], [39, 26], [16, 0], [258, 26], [31, 40], [27, 25], [425, 40], [479, 23], [363, 0]],
        [[411, 0], [37, 26], [19, 0], [255, 26], [36, 40], [23, 25], [425, 40], [478, 23], [364, 0]],
        [[412, 0], [35, 26], [21, 0], [254, 26], [38, 40], [20, 25], [426, 40], [477, 23], [365, 0]],
        [[413, 0], [34, 26], [23, 0], [252, 26], [41, 40], [17, 25], [427, 40], [475, 23], [366, 0]],
        [[415, 0], [31, 26], [25, 0], [250, 26], [44, 40], [15, 25], [427, 40], [474, 23], [367, 0]],
        [[416, 0], [29, 26], [27, 0], [249, 26], [48, 40], [10, 25], [428, 40], [473, 23], [368, 0]],
        [[417, 0], [27, 26], [30, 0], [247, 26], [51, 40], [7, 25], [428, 40], [472, 23], [369, 0]],
        [[419, 0], [25, 26], [31, 0], [245, 26], [55, 40], [4, 25], [429, 40], [469, 23], [371, 0]],
        [[420, 0], [23, 26], [34, 0], [243, 26], [488, 40], [468, 23], [372, 0]],
        [[421, 0], [21, 26], [36, 0], [241, 26], [489, 40], [467, 23], [373, 0]],
        [[422, 0], [19, 26], [38, 0], [240, 26], [489, 40], [466, 23], [374, 0]],
        [[424, 0], [17, 26], [40, 0], [238, 26], [490, 40], [463, 23], [376, 0]],
        [[425, 0], [15, 26], [43, 0], [235, 26], [491, 40], [462, 23], [377, 0]],
        [[426, 0], [13, 26], [45, 0], [234, 26], [491, 40], [461, 23], [378, 0]],
        [[428, 0], [11, 26], [46, 0], [232, 26], [492, 40], [460, 23], [379, 0]],
        [[429, 0], [9, 26], [49, 0], [230, 26], [492, 40], [459, 23], [380, 0]],
        [[430, 0], [7, 26], [51, 0], [229, 26], [493, 40], [457, 23], [381, 0]],
        [[432, 0], [4, 26], [53, 0], [227, 26], [494, 40], [455, 23], [383, 0]],
        [[433, 0], [2, 26], [56, 0], [225, 26], [494, 40], [454, 23], [384, 0]],
        [[493, 0], [223, 26], [494, 40], [453, 23], [385, 0]],
        [[494, 0], [221, 26], [496, 40], [451, 23], [386, 0]],
        [[496, 0], [218, 26], [497, 40], [449, 23], [388, 0]],
        [[497, 0], [217, 26], [497, 40], [448, 23], [389, 0]],
        [[499, 0], [215, 26], [497, 40], [447, 23], [390, 0]],
        [[500, 0], [213, 26], [499, 40], [445, 23], [391, 0]],
        [[502, 0], [211, 26], [499, 40], [444, 23], [392, 0]],
        [[503, 0], [210, 26], [499, 40], [443, 23], [393, 0]],
        [[505, 0], [207, 26], [500, 40], [441, 23], [395, 0]],
        [[506, 0], [206, 26], [501, 40], [439, 23], [396, 0]],
        [[508, 0], [203, 26], [502, 40], [438, 23], [397, 0]],
        [[509, 0], [202, 26], [502, 40], [436, 23], [399, 0]],
        [[511, 0], [200, 26], [502, 40], [435, 23], [400, 0]],
        [[513, 0], [65, 26], [1, 0], [131, 26], [503, 40], [434, 23], [401, 0]],
        [[514, 0], [64, 26], [3, 0], [129, 26], [504, 40], [431, 23], [403, 0]],
        [[516, 0], [61, 26], [5, 0], [128, 26], [504, 40], [430, 23], [404, 0]],
        [[517, 0], [60, 26], [7, 0], [125, 26], [505, 40], [429, 23], [405, 0]],
        [[519, 0], [57, 26], [10, 0], [123, 26], [505, 40], [428, 23], [406, 0]],
        [[520, 0], [56, 26], [12, 0], [120, 26], [507, 40], [425, 23], [408, 0]],
        [[522, 0], [53, 26], [14, 0], [119, 26], [507, 40], [424, 23], [409, 0]],
        [[524, 0], [50, 26], [17, 0], [117, 26], [507, 40], [423, 23], [410, 0]],
        [[525, 0], [49, 26], [19, 0], [114, 26], [508, 40], [421, 23], [412, 0]],
        [[527, 0], [46, 26], [22, 0], [112, 26], [509, 40], [56, 23], [3, 40], [360, 23], [413, 0]],
        [[529, 0], [44, 26], [24, 0], [109, 26], [510, 40], [52, 23], [7, 40], [359, 23], [414, 0]],
        [[530, 0], [42, 26], [27, 0], [107, 26], [510, 40], [49, 23], [10, 40], [357, 23], [416, 0]],
        [[532, 0], [40, 26], [29, 0], [105, 26], [511, 40], [45, 23], [13, 40], [356, 23], [417, 0]],
        [[533, 0], [38, 26], [32, 0], [102, 26], [512, 40], [42, 23], [17, 40], [354, 23], [418, 0]],
        [[535, 0], [36, 26], [34, 0], [100, 26], [512, 40], [38, 23], [21, 40], [353, 23], [419, 0]],
        [[537, 0], [33, 26], [36, 0], [99, 26], [512, 40], [35, 23], [24, 40], [351, 23], [421, 0]],
        [[538, 0], [32, 26], [39, 0], [95, 26], [513, 40], [31, 23], [29, 40], [349, 23], [422, 0]],
        [[540, 0], [29, 26], [42, 0], [93, 26], [514, 40], [27, 23], [32, 40], [348, 23], [423, 0]],
        [[542, 0], [26, 26], [45, 0], [90, 26], [515, 40], [23, 23], [36, 40], [346, 23], [425, 0]],
        [[543, 0], [25, 26], [47, 0], [88, 26], [515, 40], [19, 23], [41, 40], [344, 23], [426, 0]],
        [[545, 0], [22, 26], [50, 0], [85, 26], [516, 40], [15, 23], [45, 40], [342, 23], [428, 0]],
        [[547, 0], [20, 26], [52, 0], [83, 26], [517, 40], [10, 23], [49, 40], [341, 23], [429, 0]],
        [[549, 0], [17, 26], [55, 0], [81, 26], [517, 40], [6, 23], [54, 40], [339, 23], [430, 0]],
        [[551, 0], [15, 26], [57, 0], [78, 26], [518, 40], [2, 23], [58, 40], [337, 23], [432, 0]],
        [[552, 0], [13, 26], [60, 0], [76, 26], [578, 40], [336, 23], [433, 0]],
        [[554, 0], [10, 26], [63, 0], [74, 26], [578, 40], [335, 23], [434, 0]],
        [[556, 0], [8, 26], [65, 0], [71, 26], [580, 40], [272, 23], [2, 0], [58, 23], [436, 0]],
        [[558, 0], [5, 26], [68, 0], [69, 26], [580, 40], [271, 23], [4, 0], [56, 23], [437, 0]],
        [[559, 0], [4, 26], [70, 0], [66, 26], [582, 40], [268, 23], [7, 0], [53, 23], [439, 0]],
        [[561, 0], [1, 26], [74, 0], [63, 26], [582, 40], [266, 23], [9, 0], [52, 23], [440, 0]],
        [[638, 0], [61, 26], [582, 40], [198, 23], [2, 0], [65, 23], [11, 0], [50, 23], [441, 0]],
        [[640, 0], [58, 26], [584, 40], [196, 23], [3, 0], [63, 23], [14, 0], [47, 23], [443, 0]],
        [[642, 0], [56, 26], [584, 40], [194, 23], [6, 0], [60, 23], [17, 0], [45, 23], [444, 0]],
        [[644, 0], [53, 26], [585, 40], [192, 23], [9, 0], [58, 23], [18, 0], [43, 23], [446, 0]],
        [[647, 0], [50, 26], [585, 40], [190, 23], [11, 0], [56, 23], [21, 0], [41, 23], [447, 0]],
        [[648, 0], [49, 26], [586, 40], [187, 23], [14, 0], [54, 23], [22, 0], [39, 23], [449, 0]],
        [[651, 0], [45, 26], [587, 40], [186, 23], [15, 0], [53, 23], [24, 0], [37, 23], [450, 0]],
        [[653, 0], [43, 26], [587, 40], [184, 23], [18, 0], [50, 23], [27, 0], [35, 23], [451, 0]],
        [[655, 0], [41, 26], [588, 40], [181, 23], [20, 0], [48, 23], [29, 0], [33, 23], [453, 0]],
        [[658, 0], [37, 26], [589, 40], [179, 23], [23, 0], [45, 23], [32, 0], [31, 23], [454, 0]],
        [[660, 0], [35, 26], [589, 40], [177, 23], [26, 0], [43, 23], [34, 0], [28, 23], [456, 0]],
        [[663, 0], [31, 26], [591, 40], [174, 23], [28, 0], [41, 23], [36, 0], [27, 23], [457, 0]],
        [[665, 0], [29, 26], [591, 40], [172, 23], [31, 0], [38, 23], [39, 0], [24, 23], [459, 0]],
        [[667, 0], [27, 26], [591, 40], [170, 23], [33, 0], [36, 23], [41, 0], [23, 23], [460, 0]],
        [[670, 0], [23, 26], [593, 40], [167, 23], [36, 0], [34, 23], [43, 0], [20, 23], [462, 0]],
        [[672, 0], [21, 26], [593, 40], [166, 23], [37, 0], [33, 23], [45, 0], [18, 23], [463, 0]],
        [[674, 0], [18, 26], [594, 40], [164, 23], [40, 0], [30, 23], [47, 0], [16, 23], [465, 0]],
        [[677, 0], [15, 26], [594, 40], [162, 23], [42, 0], [28, 23], [50, 0], [14, 23], [466, 0]],
        [[679, 0], [13, 26], [595, 40], [159, 23], [45, 0], [25, 23], [53, 0], [11, 23], [468, 0]],
        [[682, 0], [9, 26], [596, 40], [157, 23], [47, 0], [24, 23], [54, 0], [10, 23], [469, 0]],
        [[684, 0], [7, 26], [596, 40], [155, 23], [50, 0], [21, 23], [57, 0], [7, 23], [471, 0]],
        [[687, 0], [3, 26], [598, 40], [151, 23], [54, 0], [18, 23], [60, 0], [5, 23], [472, 0]],
        [[689, 0], [1, 26], [598, 40], [149, 23], [56, 0], [16, 23], [62, 0], [3, 23], [474, 0]],
        [[692, 0], [596, 40], [62, 23], [3, 0], [82, 23], [59, 0], [14, 23], [64, 0], [1, 23], [475, 0]],
        [[695, 0], [594, 40], [59, 23], [5, 0], [80, 23], [61, 0], [12, 23], [542, 0]],
        [[697, 0], [592, 40], [56, 23], [9, 0], [77, 23], [64, 0], [9, 23], [544, 0]],
        [[699, 0], [590, 40], [54, 23], [11, 0], [75, 23], [66, 0], [7, 23], [546, 0]],
        [[702, 0], [587, 40], [51, 23], [14, 0], [73, 23], [69, 0], [5, 23], [547, 0]],
        [[705, 0], [585, 40], [47, 23], [18, 0], [70, 23], [72, 0], [2, 23], [549, 0]],
        [[708, 0], [582, 40], [45, 23], [20, 0], [68, 23], [625, 0]],
        [[711, 0], [579, 40], [42, 23], [24, 0], [64, 23], [628, 0]],
        [[713, 0], [578, 40], [38, 23], [27, 0], [62, 23], [630, 0]],
        [[716, 0], [575, 40], [35, 23], [31, 0], [59, 23], [632, 0]],
        [[719, 0], [573, 40], [32, 23], [33, 0], [57, 23], [634, 0]],
        [[722, 0], [570, 40], [28, 23], [37, 0], [54, 23], [637, 0]],
        [[725, 0], [567, 40], [25, 23], [41, 0], [51, 23], [639, 0]],
        [[728, 0], [565, 40], [22, 23], [43, 0], [49, 23], [641, 0]],
        [[730, 0], [563, 40], [19, 23], [46, 0], [47, 23], [643, 0]],
        [[733, 0], [560, 40], [16, 23], [50, 0], [44, 23], [645, 0]],
        [[737, 0], [556, 40], [13, 23], [53, 0], [41, 23], [648, 0]],
        [[740, 0], [554, 40], [9, 23], [57, 0], [38, 23], [650, 0]],
        [[743, 0], [551, 40], [6, 23], [60, 0], [36, 23], [652, 0]],
        [[746, 0], [548, 40], [1, 0], [1, 23], [64, 0], [33, 23], [655, 0]],
        [[749, 0], [544, 40], [68, 0], [30, 23], [657, 0]],
        [[753, 0], [537, 40], [71, 0], [28, 23], [659, 0]],
        [[756, 0], [531, 40], [75, 0], [24, 23], [662, 0]],
        [[759, 0], [524, 40], [79, 0], [21, 23], [665, 0]],
        [[762, 0], [519, 40], [81, 0], [20, 23], [666, 0]],
        [[765, 0], [512, 40], [86, 0], [16, 23], [669, 0]],
        [[769, 0], [505, 40], [89, 0], [14, 23], [671, 0]],
        [[772, 0], [498, 40], [93, 0], [11, 23], [674, 0]],
        [[776, 0], [491, 40], [97, 0], [8, 23], [676, 0]],
        [[780, 0], [483, 40], [101, 0], [5, 23], [679, 0]],
        [[783, 0], [476, 40], [106, 0], [2, 23], [681, 0]],
        [[787, 0], [468, 40], [793, 0]],
        [[791, 0], [461, 40], [796, 0]],
        [[795, 0], [452, 40], [801, 0]],
        [[799, 0], [444, 40], [805, 0]],
        [[802, 0], [438, 40], [808, 0]],
        [[807, 0], [429, 40], [812, 0]],
        [[807, 0], [425, 40], [816, 0]],
        [[807, 0], [420, 40], [821, 0]],
        [[807, 0], [416, 40], [825, 0]],
        [[806, 0], [413, 40], [829, 0]],
        [[806, 0], [408, 40], [834, 0]],
        [[806, 0], [403, 40], [839, 0]],
        [[806, 0], [398, 40], [844, 0]],
        [[805, 0], [394, 40], [849, 0]],
        [[805, 0], [388, 40], [855, 0]],
        [[805, 0], [384, 40], [859, 0]],
        [[805, 0], [378, 40], [865, 0]],
        [[805, 0], [373, 40], [870, 0]],
        [[804, 0], [368, 40], [876, 0]],
        [[804, 0], [361, 40], [883, 0]],
        [[804, 0], [355, 40], [889, 0]],
        [[804, 0], [348, 40], [896, 0]],
        [[803, 0], [342, 40], [903, 0]],
        [[803, 0], [333, 40], [912, 0]],
        [[803, 0], [325, 40], [920, 0]],
        [[803, 0], [318, 40], [927, 0]],
        [[802, 0], [312, 40], [934, 0]],
        [[802, 0], [312, 40], [934, 0]],
        [[802, 0], [312, 40], [934, 0]],
        [[802, 0], [312, 40], [934, 0]],
        [[801, 0], [313, 40], [934, 0]],
        [[801, 0], [313, 40], [934, 0]],
        [[801, 0], [313, 40], [934, 0]],
        [[801, 0], [313, 40], [934, 0]],
        [[801, 0], [314, 40], [933, 0]],
        [[800, 0], [315, 40], [933, 0]],
        [[800, 0], [315, 40], [933, 0]],
        [[800, 0], [315, 40], [933, 0]],
        [[799, 0], [316, 40], [933, 0]],
        [[804, 0], [311, 40], [933, 0]],
        [[808, 0], [307, 40], [933, 0]],
        [[813, 0], [302, 40], [933, 0]],
        [[817, 0], [298, 40], [933, 0]],
        [[822, 0], [293, 40], [933, 0]],
        [[827, 0], [289, 40], [932, 0]],
        [[831, 0], [285, 40], [932, 0]],
        [[837, 0], [279, 40], [932, 0]],
        [[841, 0], [275, 40], [932, 0]],
        [[846, 0], [270, 40], [932, 0]],
        [[852, 0], [264, 40], [932, 0]],
        [[858, 0], [258, 40], [932, 0]],
        [[863, 0], [253, 40], [932, 0]],
        [[870, 0], [246, 40], [932, 0]],
        [[876, 0], [240, 40], [932, 0]],
        [[883, 0], [234, 40], [931, 0]],
        [[891, 0], [226, 40], [931, 0]],
        [[898, 0], [219, 40], [931, 0]],
        [[904, 0], [213, 40], [931, 0]],
        [[913, 0], [204, 40], [931, 0]],
        [[923, 0], [194, 40], [931, 0]],
        [[933, 0], [177, 40], [938, 0]],
        [[944, 0], [155, 40], [949, 0]],
        [[958, 0], [126, 40], [964, 0]],
        [[979, 0], [85, 40], [984, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]],
        [[2048, 0]]
	);
}

sub load_mappings {
    $atmo_map{""}{"AmmoniaOxygen"} = "Ammonia and Oxygen";
    $atmo_map{""}{"EarthLike"} = "Suitable for water-based life";
    $atmo_map{""}{"None"} = "No atmosphere";
    $atmo_map{""}{"SulphurDioxide"} = "Sulphur dioxide";
    $atmo_map{"ammonia atmosphere"}{"Ammonia"} = "Ammonia";
    $atmo_map{"ammonia rich atmosphere"}{"AmmoniaRich"} = "Ammonia-rich";
    $atmo_map{"argon atmosphere"}{"Argon"} = "Argon";
    $atmo_map{"argon rich atmosphere"}{"ArgonRich"} = "Argon-rich";
    $atmo_map{"carbon dioxide atmosphere"}{"CarbonDioxide"} = "Carbon dioxide";
    $atmo_map{"carbon dioxide rich atmosphere"}{"CarbonDioxideRich"} = "Carbon dioxide-rich";
    $atmo_map{"helium atmosphere"}{"Helium"} = "Helium";
    $atmo_map{"hot carbon dioxide atmosphere"}{"CarbonDioxide"} = "Hot Carbon dioxide";
    $atmo_map{"hot silicate vapour atmosphere"}{"SilicateVapour"} = "Hot Silicate vapour";
    $atmo_map{"hot sulfur dioxide atmosphere"}{"SulphurDioxide"} = "Hot Sulphur dioxide";
    $atmo_map{"hot thick ammonia atmosphere"}{"Ammonia"} = "Hot thick Ammonia";
    $atmo_map{"hot thick ammonia rich atmosphere"}{"AmmoniaRich"} = "Hot thick Ammonia-rich";
    $atmo_map{"hot thick argon atmosphere"}{"Argon"} = "Hot thick Argon";
    $atmo_map{"hot thick argon rich atmosphere"}{"ArgonRich"} = "Hot thick Argon-rich";
    $atmo_map{"hot thick carbon dioxide atmosphere"}{"CarbonDioxide"} = "Hot thick Carbon dioxide";
    $atmo_map{"hot thick carbon dioxide rich atmosphere"}{"CarbonDioxideRich"} = "Hot thick Carbon dioxide-rich";
    $atmo_map{"hot thick metallic vapour atmosphere"}{"MetallicVapour"} = "Hot thick Metallic vapour";
    $atmo_map{"hot thick methane atmosphere"}{"Methane"} = "Hot thick Methane";
    $atmo_map{"hot thick methane rich atmosphere"}{"MethaneRich"} = "Hot thick Methane-rich";
    $atmo_map{"hot thick silicate vapour atmosphere"}{"SilicateVapour"} = "Hot thick Silicate vapour";
    $atmo_map{"hot thick sulfur dioxide atmosphere"}{"SulphurDioxide"} = "Hot thick Sulphur dioxide";
    $atmo_map{"hot thick water atmosphere"}{"Water"} = "Hot thick Water";
    $atmo_map{"hot thick water rich atmosphere"}{"WaterRich"} = "Hot thick Water-rich";
    $atmo_map{"hot thin carbon dioxide atmosphere"}{"CarbonDioxide"} = "Hot thin Carbon dioxide";
    $atmo_map{"hot thin silicate vapour atmosphere"}{"SilicateVapour"} = "Hot thin Silicate vapour";
    $atmo_map{"hot thin sulfur dioxide atmosphere"}{"SulphurDioxide"} = "Hot thin Sulphur dioxide";
    $atmo_map{"hot water atmosphere"}{"Water"} = "Hot Water";
    $atmo_map{"methane atmosphere"}{"Methane"} = "Methane";
    $atmo_map{"methane rich atmosphere"}{"MethaneRich"} = "Methane-rich";
    $atmo_map{"neon rich atmosphere"}{"NeonRich"} = "Neon-rich";
    $atmo_map{"nitrogen atmosphere"}{"Nitrogen"} = "Nitrogen";
    $atmo_map{"oxygen atmosphere"}{"Oxygen"} = "Oxygen";
    $atmo_map{"sulfur dioxide atmosphere"}{"SulphurDioxide"} = "Sulphur dioxide";
    $atmo_map{"thick  atmosphere"}{"AmmoniaOxygen"} = "Thick Ammonia and Oxygen";
    $atmo_map{"thick ammonia atmosphere"}{"Ammonia"} = "Thick Ammonia";
    $atmo_map{"thick ammonia rich atmosphere"}{"AmmoniaRich"} = "Thick Ammonia-rich";
    $atmo_map{"thick argon atmosphere"}{"Argon"} = "Thick Argon";
    $atmo_map{"thick argon rich atmosphere"}{"ArgonRich"} = "Thick Argon-rich";
    $atmo_map{"thick carbon dioxide atmosphere"}{"CarbonDioxide"} = "Thick Carbon dioxide";
    $atmo_map{"thick carbon dioxide rich atmosphere"}{"CarbonDioxideRich"} = "Thick Carbon dioxide-rich";
    $atmo_map{"thick helium atmosphere"}{"Helium"} = "Thick Helium";
    $atmo_map{"thick methane atmosphere"}{"Methane"} = "Thick Methane";
    $atmo_map{"thick methane rich atmosphere"}{"MethaneRich"} = "Thick Methane-rich";
    $atmo_map{"thick nitrogen atmosphere"}{"Nitrogen"} = "Thick Nitrogen";
    $atmo_map{"thick sulfur dioxide atmosphere"}{"SulphurDioxide"} = "Thick Sulphur dioxide";
    $atmo_map{"thick water rich atmosphere"}{"WaterRich"} = "Thick Water-rich";
    $atmo_map{"thin  atmosphere"}{"AmmoniaOxygen"} = "Thin Ammonia and Oxygen";
    $atmo_map{"thin ammonia atmosphere"}{"Ammonia"} = "Thin Ammonia";
    $atmo_map{"thin argon atmosphere"}{"Argon"} = "Thin Argon";
    $atmo_map{"thin argon rich atmosphere"}{"ArgonRich"} = "Thin Argon-rich";
    $atmo_map{"thin carbon dioxide atmosphere"}{"CarbonDioxide"} = "Thin Carbon dioxide";
    $atmo_map{"thin carbon dioxide rich atmosphere"}{"CarbonDioxideRich"} = "Thin Carbon dioxide-rich";
    $atmo_map{"thin helium atmosphere"}{"Helium"} = "Thin Helium";
    $atmo_map{"thin methane atmosphere"}{"Methane"} = "Thin Methane";
    $atmo_map{"thin methane rich atmosphere"}{"MethaneRich"} = "Thin Methane-rich";
    $atmo_map{"thin neon atmosphere"}{"Neon"} = "Thin Neon";
    $atmo_map{"thin neon rich atmosphere"}{"NeonRich"} = "Thin Neon-rich";
    $atmo_map{"thin nitrogen atmosphere"}{"Nitrogen"} = "Thin Nitrogen";
    $atmo_map{"thin oxygen atmosphere"}{"Oxygen"} = "Thin Oxygen";
    $atmo_map{"thin sulfur dioxide atmosphere"}{"SulphurDioxide"} = "Thin Sulphur dioxide";
    $atmo_map{"thin water atmosphere"}{"Water"} = "Thin Water";
    $atmo_map{"thin water rich atmosphere"}{"WaterRich"} = "Thin Water-rich";
    $atmo_map{"water atmosphere"}{"Water"} = "Water";
    $atmo_map{"water rich atmosphere"}{"WaterRich"} = "Water-rich";

    $volc_map{""} = "No volcanism";
    $volc_map{"carbon dioxide geysers volcanism"} = "Carbon Dioxide Geysers";
    $volc_map{"major metallic magma volcanism"} = "Major Metallic Magma";
    $volc_map{"major rocky magma volcanism"} = "Major Rocky Magma";
    $volc_map{"major silicate vapour geysers volcanism"} = "Major Silicate Vapour Geysers";
    $volc_map{"major water geysers volcanism"} = "Major Water Geysers";
    $volc_map{"major water magma volcanism"} = "Major Water Magma";
    $volc_map{"metallic magma volcanism"} = "Metallic Magma";
    $volc_map{"minor ammonia magma volcanism"} = "Minor Ammonia Magma";
    $volc_map{"minor carbon dioxide geysers volcanism"} = "Minor Carbon Dioxide Geysers";
    $volc_map{"minor metallic magma volcanism"} = "Minor Metallic Magma";
    $volc_map{"minor methane magma volcanism"} = "Minor Methane Magma";
    $volc_map{"minor nitrogen magma volcanism"} = "Minor Nitrogen Magma";
    $volc_map{"minor rocky magma volcanism"} = "Minor Rocky Magma";
    $volc_map{"minor silicate vapour geysers volcanism"} = "Minor Silicate Vapour Geysers";
    $volc_map{"minor water geysers volcanism"} = "Minor Water Geysers";
    $volc_map{"minor water magma volcanism"} = "Minor Water Magma";
    $volc_map{"rocky magma volcanism"} = "Rocky Magma";
    $volc_map{"silicate vapour geysers volcanism"} = "Silicate Vapour Geysers";
    $volc_map{"water geysers volcanism"} = "Water Geysers";
    $volc_map{"water magma volcanism"} = "Water Magma";

    $planet_map{"Ammonia world"} = "Ammonia world";
    $planet_map{"Earthlike body"} = "Earth-like world";
    $planet_map{"Gas giant with ammonia based life"} = "Gas giant with ammonia-based life";
    $planet_map{"Gas giant with water based life"} = "Gas giant with water-based life";
    $planet_map{"Helium rich gas giant"} = "Helium-rich gas giant";
    $planet_map{"High metal content body"} = "High metal content world";
    $planet_map{"Icy body"} = "Icy body";
    $planet_map{"Metal rich body"} = "Metal-rich body";
    $planet_map{"Rocky body"} = "Rocky body";
    $planet_map{"Rocky ice body"} = "Rocky Ice world";
    $planet_map{"Sudarsky class I gas giant"} = "Class I gas giant";
    $planet_map{"Sudarsky class II gas giant"} = "Class II gas giant";
    $planet_map{"Sudarsky class III gas giant"} = "Class III gas giant";
    $planet_map{"Sudarsky class IV gas giant"} = "Class IV gas giant";
    $planet_map{"Sudarsky class V gas giant"} = "Class V gas giant";
    $planet_map{"Water giant"} = "Water giant";
    $planet_map{"Water world"} = "Water world";

    $star_map{"A"} = "A (Blue-White) Star";
    $star_map{"A_BlueWhiteSuperGiant"} = "B (Blue-White super giant) Star";
    $star_map{"AeBe"} = "Herbig Ae/Be Star";
    $star_map{"B"} = "B (Blue-White) Star";
    $star_map{"B_BlueWhiteSuperGiant"} = "B (Blue-White super giant) Star";
    $star_map{"C"} = "C Star";
    $star_map{"CJ"} = "CJ Star";
    $star_map{"CN"} = "CN Star";
    $star_map{"D"} = "White Dwarf (D) Star";
    $star_map{"DA"} = "White Dwarf (DA) Star";
    $star_map{"DAB"} = "White Dwarf (DAB) Star";
    $star_map{"DAV"} = "White Dwarf (DAV) Star";
    $star_map{"DB"} = "White Dwarf (DB) Star";
    $star_map{"DBV"} = "White Dwarf (DBV) Star";
    $star_map{"DC"} = "White Dwarf (DC) Star";
    $star_map{"DCV"} = "White Dwarf (DCV) Star";
    $star_map{"DQ"} = "White Dwarf (DQ) Star";
    $star_map{"F"} = "F (White) Star";
    $star_map{"F_WhiteSuperGiant"} = "G (White-Yellow super giant) Star";
    $star_map{"G"} = "G (White-Yellow) Star";
    $star_map{"G_WhiteSuperGiant"} = "G (White-Yellow super giant) Star";
    $star_map{"H"} = "Black Hole";
    $star_map{"K"} = "K (Yellow-Orange) Star";
    $star_map{"K_OrangeGiant"} = "K (Yellow-Orange giant) Star";
    $star_map{"L"} = "L (Brown dwarf) Star";
    $star_map{"M"} = "M (Red dwarf) Star";
    $star_map{"MS"} = "MS-type Star";
    $star_map{"M_RedGiant"} = "M (Red giant) Star";
    $star_map{"M_RedSuperGiant"} = "M (Red super giant) Star";
    $star_map{"N"} = "Neutron Star";
    $star_map{"O"} = "O (Blue-White) Star";
    $star_map{"S"} = "S-type Star";
    $star_map{"SupermassiveBlackHole"} = "Supermassive Black Hole";
    $star_map{"T"} = "T (Brown dwarf) Star";
    $star_map{"TTS"} = "T Tauri Star";
    $star_map{"W"} = "Wolf-Rayet Star";
    $star_map{"WC"} = "Wolf-Rayet C Star";
    $star_map{"WN"} = "Wolf-Rayet N Star";
    $star_map{"WNC"} = "Wolf-Rayet NC Star";
    $star_map{"WO"} = "Wolf-Rayet O Star";
    $star_map{"Y"} = "Y (Brown dwarf) Star";
    $star_map{"RoguePlanet"} = "RoguePlanet";
    $star_map{"Nebula"} = "Nebula";
    $star_map{"StellarRemnantNebula"} = "StellarRemnantNebula";

    my $und = undef;
    $terr_map{""} = "Not terraformable";
    $terr_map{$und} = "Not terraformable";
    $terr_map{"Terraformable"} = "Candidate for terraforming";
    $terr_map{"Terraformed"} = "Terraformed";
    $terr_map{"Terraforming"} = "Terraforming";

}

sub set_logname {
	$logname = shift;
}

sub logger {
	my @t = localtime;
	my $ts = sprintf("%04u-%02u-%02u %02u:%02u:%02u",$t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0]);
	my $fn = sprintf("edastro-%04u%02u.log",$t[5]+1900,$t[4]+1);

	open LOGFILE, ">>/home/bones/elite/log/$fn";
	foreach (@_) {
		chomp;
		print LOGFILE "[$ts] $logname: $_\n";
	}
	close LOGFILE;
}

sub log_mysql {
	my ($db,$sql,$param) = @_;
	my $add = $param && ref($param) eq 'ARRAY' ? ' ['.join(',',@$param).']' : '';

	logger("$db: $sql$add");
	db_mysql(@_);
}

sub compress_send {
	my $fn = shift;
	my $wc = shift;
	my $se = shift;

	my %settings = ('debug'=>0, 'upload_only'=>0, 'allow_scp'=>1);

	if ($se && ref($se) eq 'HASH') {
		foreach my $k (keys %$se) {
			$settings{$k} = $$se{$k};
		}
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

	if (!$settings{upload_only}) {
		unlink $zipf;

		my $exec = "/usr/bin/zip temp-$$-$zipf $fn ; /bin/mv temp-$$-$zipf $zipf";
		print "\n# $exec\n";
		system($exec);
	}

	my_system("$scp $zipf $meta $remote_server/") if (!$settings{debug} && $settings{allow_scp});

	#my_system("./push2mediafire.pl $zipf") if (!$settings{debug} && $settings{allow_scp});
	#my_system("./push2mediafire.pl $stat") if (!$settings{debug} && $settings{allow_scp});
}

sub my_system {
        my $string  = shift;
	my $verbose = shift;

        print "# $string\n" if ($verbose);
        system($string);
}

sub ssh_options {
	my $fn = '/etc/ssh.opts';
	
	if (-e $fn) {
		open SSHOPTS, "<$fn";
		my $opts = <SSHOPTS>;
		chomp $opts;
		close SSHOPTS;
		return ' '.$opts;
	} else {
		return '';
	}
}

sub scp_options {
	my $fn = '/etc/scp.opts';
	
	if (-e $fn) {
		open SCPOPTS, "<$fn";
		my $opts = <SCPOPTS>;
		chomp $opts;
		close SCPOPTS;
		return ' '.$opts;
	} else {
		return '';
	}
}

1;


############################################################################

