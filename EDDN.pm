package EDDN;

# Copyright (C) 2020-2021, Ed Toton (CMDR Orvidius), All Rights Reserved.

use strict;

use JSON;
use Data::Dumper;
use Time::HiRes qw( gettimeofday );
use File::Path qw(make_path);
use POSIX qw/floor/;
use LWP 5.64;
use IO::Socket::SSL;

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch btrim my_syslog);

use lib "/home/bones/elite";
use EDSM qw(codex_entry import_field import_directly update_object $allow_updates $edsm_verbose key_findcreate_local
		load_mappings %atmo_map %volc_map %planet_map %star_map %terr_map logger log_mysql id64_sectorID id64_subsector);

############################################################################

my $db;
our $json_testing;
our $logging_override;
my $eddn_debug;
my $eddn_verbose;
my %updated_system;
my $updating_systems;
my $queue_path;
my $use_queue;
my $statusURL;

BEGIN { # Export functions first because of possible circular dependancies
   use Exporter;
   use vars qw(@ISA $VERSION @EXPORT_OK);

   $VERSION = 2.01;
   @ISA = qw(Exporter);
   @EXPORT_OK = qw(eddn_json process_queue process_event_file process_event_json check_db_connection $json_testing $eddn_debug $eddn_verbose track_carrier track_exploration
		game_OK);

	$db			= 'elite';
	$updating_systems	= 1;
	$json_testing		= undef; #'scandata';	# Can be 'scandata' or 'carriers'
	$logging_override	= undef; # Set this to undef for normal operation
	$eddn_debug		= 0;
	$eddn_verbose		= 0;
	%updated_system		= ();
	$use_queue		= 1;
	$queue_path		= '/DATA/eddn/queue'; #'/home/bones/elite/eddn-data/queue';
	$statusURL		= 'https://ed-server-status.orerve.net/';

	$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;
	$ENV{HTTPS_DEBUG} = 1;

	IO::Socket::SSL::set_ctx_defaults(
	     SSL_verifycn_scheme => 'www',
	     SSL_verify_mode => 0,
	);

}


############################################################################

sub eddn_json {
	my $json = shift;
	my $logging = shift;
	my $event = '';

	$logging = $logging_override if (defined($logging_override));
	$edsm_verbose = 1 if ($eddn_debug || $eddn_verbose);
	show_queries(1) if ($eddn_debug || $eddn_verbose);

	if ($json =~ /"event"\s*:\s*"([\s\w\d\_]+)"/) {
		$event = btrim($1);
	}

	if ($json =~ /"\$schemaRef"\s*:\s*"https?:\/\/[\w\d\-\_\/\.]+\/test"/i) {
		log_jsonl('test',$json);
		return;
	}
	if (!$event && $json =~ /"\$schemaRef"\s*:\s*"https?:\/\/[\w\d\-\_\/\.]+carrier"/i) {
		log_jsonl('carrierschema',$json);
		return;
	}

	return if (!$event);

	if ($event =~ /FSDJump|Location/i) {
		#log_jsonl('locations',$json) if ($logging);
	} elsif ($event =~ /SAASignalsFound/i || $event eq 'Scan') {
		#log_jsonl('scans',$json) if ($logging);
	} elsif ($event =~ /Docked/i) {
		log_jsonl('docked',$json) if ($logging);
	} elsif ($event =~ /Carrier/i) {
		log_jsonl('carriers',$json) if ($logging);
	} elsif ($event =~ /FSSAllBodiesFound|FSSDiscoveryScan/i) {
		log_jsonl('FSS',$json) if ($logging);
	} elsif ($event =~ /ScanBaryCentre/i) {
		log_jsonl('barycenters',$json) if ($logging);
	} elsif ($event =~ /NavRoute/i) {
		log_jsonl('navroute',$json);
	} else {
		log_jsonl('other',$json) if ($logging);
	}

	return if ($event !~ /NavRoute|Docked|Location|Jump|Carrier|SAASignalsFound|Scan|FSSSignalDiscovered|ScanOrganic|CodexEntry|ScanBaryCentre|FSSAllBodiesFound|FSSDiscoveryScan/i);


	my ($seconds, $microseconds) = gettimeofday;
	my @t = gmtime($seconds);
	my $id = sprintf("%04u%02u%02u-%02u%02u%02u-%06u-%06u",$t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0],$microseconds,$$);

	my $path = sprintf("%s/%02u%02u%02u-%02u%02u",$queue_path,$t[5]+1900,$t[4]+1,$t[3],$t[2],floor($t[1]/10)*10);
	my $fn = "$path/$id-$event";

	if ($use_queue) { 
		print "QUEUING: $fn\n";
		make_path($path) if (!-d $path);
	
		open EVENTFILE, ">$fn";
		print EVENTFILE "$json\n";
		close EVENTFILE;
	} else {
		process_event_json($event,$json);
	}

	return;

}

sub process_event_file {
	my $fn = shift;
	my $event = undef;

	if (!-e $fn) {
		warn "File no longer exists: $fn\n";
		return 0;
	}

	if ($fn =~ /[\.-]([\w\d\_]+)$/) {
		$event = $1;
	}

	if (!$event) {
		warn "Could not determine event type from '$fn'\n";
		return 0;
	}

	open EVENTFILE, "<$fn";
	my @lines = <EVENTFILE>;
	my $json = join('',@lines);
	close EVENTFILE;

	if (!$json) {
		warn "No data recovered from '$fn'\n";
		return 0;
	}

	return process_event_json($event,$json,$fn);
}

sub process_event_json {
	my $event = shift;
	my $json  = shift;
	my $fn    = shift;	# optional, informational only
	my $jref  = undef;

	eval {
		$jref = JSON->new->utf8->decode($json);
	};
	print "ERROR: $@" if ($@);

	if (!$jref) {
		warn "Could not decode JSON '$fn'\n" if ($fn);
		warn "Could not decode JSON\n" if (!$fn);
		return 0;
	}

	my $ok = 0;

	eval {
		my %jhash1 = %$jref; # make a copy, just because
		my %jhash2 = %$jref; # make another copy!
	
		load_mappings() if (!keys %atmo_map);
	
		# This should never happen, but let's use the JSON decoded event name if it differs from the regex version for some reason:
		$event = $$jref{message}{event} if ($$jref{message}{event} && $$jref{message}{event} ne $event);
	
		track_carrier($event, \%jhash1) if (!$json_testing || $json_testing eq 'carriers');
		track_exploration($event, \%jhash2) if (!$json_testing || $json_testing eq 'scandata');
		track_station($event, \%jhash2) if (!$json_testing || $json_testing eq 'stations');
		$ok = 1;
	};
	print "ERROR: $@" if ($@);

	return $ok;
}

############################################################################

sub process_queue {
	my $verbose = shift;
	my $delete_finished = shift;
	my @dirs = ();

	opendir QUEUEDIR, $queue_path;
	while (my $d = readdir QUEUEDIR) {
		if ($d !~ /^\./ && -d "$queue_path/$d" && $d =~ /^\d/) {
			push @dirs, $d;
		}
	}
	closedir QUEUEDIR;

	foreach my $d (sort @dirs) {
		my $failures = 0;

		opendir QUEUEDIR, "$queue_path/$d";
		while (my $f = readdir QUEUEDIR) {
			my $fn = "$queue_path/$d/$f";

			if ($f !~ /^\./ && -f $fn && -e $fn) {
				my $ok = 0;
				print "QUEUE: $fn\n";

				if (!(stat($fn))[7]) {
					unlink $fn;
				} else {

					eval {
						$ok = process_event_file($fn);
					};
					print "ERROR: $@" if ($@);
					print ($ok ? "OK\n\n" : "FAIL\n\n") if ($verbose);
	
					unlink $fn if ($ok && $delete_finished);
					$failures++ if (!$ok);
				}
			}
		}
		closedir QUEUEDIR;

		eval {
			rmdir "$queue_path/$d" if (!$failures);		# Silently fail here if directory isn't empty.
		};
	}
}

############################################################################

sub track_station {
	my ($eventType, $jref) = @_;
	return if (!$jref || ref($jref) ne 'HASH' || !keys(%$jref));

	return if (!ok_gameversion($jref));

	my %hash  = ();
	my %event = %{$$jref{message}};

	$edsm_verbose = 1 if ($json_testing);
	#$allow_updates = 0; # insert only
	$allow_updates = 1; # date-checks for updates below

	if ($eventType =~ /Docked/ && $event{StationType}) { # && $event{StationType} ne 'FleetCarrier') {
		import_field(\%hash,'eddnDate',\%event,'timestamp');
		$hash{eddnDate} =~ s/\+\d\d//s;
		$hash{eddnDate} =~ s/Z//s;
		$hash{eddnDate} =~ s/T/ /s;
	
		import_field(\%hash,'systemName',\%event,'StarSystem');
		import_field(\%hash,'systemId64',\%event,'SystemAddress');
		import_field(\%hash,'marketID',\%event,'MarketID');
		import_field(\%hash,'name',\%event,'StationName');
		import_field(\%hash,'distanceToArrival',\%event,'DistFromStarLS');

		import_field(\%hash,'type',\%event,'StationType');
		import_field(\%hash,'padsL',\%event,'LandingPads/Large');
		import_field(\%hash,'padsM',\%event,'LandingPads/Medium');
		import_field(\%hash,'padsS',\%event,'LandingPads/Small');

		$hash{type} = 'Odyssey Settlement' if ($hash{type} eq 'OnFootSettlement');
		$hash{type} = 'Planetary Outpost' if ($hash{type} eq 'CraterOutpost');
		$hash{type} = 'Planetary Port' if ($hash{type} eq 'CraterPort');
		$hash{type} = 'Coriolis Starport' if ($hash{type} eq 'Coriolis');
		$hash{type} = 'Orbis Starport' if ($hash{type} eq 'Orbis');
		$hash{type} = 'Ocellus Starport' if ($hash{type} eq 'Ocellus');
		$hash{type} = 'Asteroid base' if ($hash{type} =~ /Asteroid/i);
		$hash{type} = 'Fleet Carrier' if ($hash{type} eq 'FleetCarrier');
		$hash{type} = 'Mega ship' if ($hash{type} eq 'MegaShip');

		my $event_services = '';
		$event_services = join(',',@{$event{StationServices}}) if (ref($event{StationServices}) eq 'ARRAY');
	
		$hash{haveOutfitting} = 1 if ($event_services =~ /outfitting/);
		$hash{haveShipyard} = 1 if ($event_services =~ /shipyard/);
		$hash{haveMarket} = 1 if ($event_services =~ /shipyard/);
	
		update_object('station',\%hash,\%event,'eddnDate',$hash{eddnDate});
	}
}

############################################################################

sub track_exploration {
	my ($eventType, $jref) = @_;
	return if (!$jref || ref($jref) ne 'HASH' || !keys(%$jref));

	my %hash  = ();
	my %event = %{$$jref{message}};

	$edsm_verbose = 1 if ($json_testing);
	#$allow_updates = 0; # insert only
	$allow_updates = 1; # date-checks for updates below

	load_mappings() if (!keys %atmo_map);

	if (lc($eventType) eq 'navroute' && ref($event{Route}) eq 'ARRAY') {
		#print "NAV: ".int(@{$event{Route}})."\n";
		foreach my $sys (@{$event{Route}}) {
			eval {
				print "NAV: $$sys{SystemAddress} / $$sys{StarSystem}: ".join(',',@{$$sys{StarPos}})."\n";
			};
			if (ref($$sys{StarPos}) eq 'ARRAY' && $$sys{SystemAddress}) {

				my @checknav = db_mysql('elite',"select name,coord_x,coord_y,coord_z from navsystems where id64=?",[($$sys{SystemAddress})]);
				my @checksys = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where id64=?",[($$sys{SystemAddress})]);
				
				if (@checknav && @checksys) {
					# In both, remove from nav:
					log_mysql('elite',"delete from navsystems where id64=?",[($$sys{SystemAddress})]);
				} elsif (@checksys) {
					# Already in systems table, do nothing for now
				} elsif (!@checknav && !@checksys) {
					# Not in either

					my $sectorID = id64_sectorID($$sys{SystemAddress});
					my ($massID,$boxID,$boxnum) = id64_subsector($$sys{SystemAddress},1);

					log_mysql('elite',"insert into navsystems (id64,id64sectorID,id64mass,id64boxelID,id64boxelnum,name,starclass,coord_x,coord_y,coord_z,created) ".
						"values (?,?,?,?,?,?,?,?,?,?,NOW())", [($$sys{SystemAddress},$sectorID,$massID,$boxID,$boxnum,
						$$sys{StarSystem},$$sys{StarClass},${$$sys{StarPos}}[0],${$$sys{StarPos}}[1],${$$sys{StarPos}}[2])]);
				}
			}
		}

		return;
	} 

	if ($updating_systems && $eventType =~ /Jump|Location|SAASignalsFound|Scan/) {
		# System

		import_field(\%hash,'id64',\%event,'SystemAddress') if ($event{SystemAddress} =~ /\d+/);

		my $scandate = $event{timestamp} if ($event{timestamp});
		$scandate =~ s/T/ /s;
		$scandate =~ s/Z//s;
		$hash{eddn_date} = $scandate;
	
		if (!$updated_system{$hash{id64}} || time - $updated_system{$hash{id64}} > 3600) {
			import_field(\%hash,'name',\%event,'StarSystem');
			import_field(\%hash,'coord_x',\%event,'StarPos',0);
			import_field(\%hash,'coord_y',\%event,'StarPos',1);
			import_field(\%hash,'coord_z',\%event,'StarPos',2);

			if (ok_gameversion($jref)) {
				import_field(\%hash,'SystemGovernment',\%event,'SystemGovernment');
				import_field(\%hash,'SystemSecurity',\%event,'SystemSecurity');
				import_field(\%hash,'SystemEconomy',\%event,'SystemEconomy');
				import_field(\%hash,'SystemSecondEconomy',\%event,'SystemSecondEconomy');
				import_field(\%hash,'SystemAllegiance',\%event,'SystemAllegiance');
			}

			$updated_system{$hash{id64}} = time;
	
			$hash{sol_dist} = sqrt($hash{coord_x}**2 + $hash{coord_y}**2 + $hash{coord_z}**2);
	
			if ($hash{id64} && $hash{name} && defined($hash{coord_x}) && defined($hash{coord_y}) && defined($hash{coord_z})) {
				check_db_connection();
				if (!$eddn_debug) {
					update_object('system',\%hash,\%event,'eddn_date',$scandate);
				} else {
					#print "EVENT($scandate): ".Dumper(\%event)."\n";
					print 'SYSTEM: '.Dumper(\%hash)."\n";
				}
			}
		} elsif ($hash{id64}) {
			log_mysql('elite',"update systems set eddn_date=?,eddn_updated=NOW() where id64=? and deletionState=0 and eddn_date<?",
				[($hash{eddn_date},$hash{id64},$hash{eddn_date})]);
			
		}
		if ($hash{id64}) {
			# Do this regardless of conditions above.
			log_mysql('elite',"update systems set eddn_updated=NOW() where id64=?",[($hash{id64})]);
		}
	} 

	if ($eventType =~ /SAASignalsFound|Scan|ScanBaryCentre/) {
		my $scandate = undef;
		my $bodyType = undef;

		$bodyType = 'planet' if ($event{PlanetClass});
		$bodyType = 'star' if ($event{StarType});
		$bodyType = 'barycenter' if ($eventType eq 'ScanBaryCentre');

		$scandate = $event{timestamp} if ($event{timestamp});
		$scandate =~ s/T/ /s;
		$scandate =~ s/Z//s;

		$hash{eddn_date} = $scandate;


		$hash{distanceToArrival} = $event{DistanceFromArrivalLS} if (exists($event{DistanceFromArrivalLS}));
		delete($hash{distanceToArrival}) if ($hash{distanceToArrival} !~ /\d/);
		$hash{systemId64} = $event{SystemAddress};
		$hash{name} = $event{BodyName} if (defined($event{BodyName}));
		$hash{bodyId} = $event{BodyID};
		$hash{bodyId64} = $event{SystemAddress} | ($event{BodyID} << 55) if (defined($event{BodyID}));

		if (!$hash{bodyId64} && $hash{bodyId} && $hash{systemId64}) {
			$hash{bodyId64} = ($hash{bodyId} << 55) | $hash{systemId64};
		}

		delete($hash{bodyId64}) if (!defined($hash{bodyId64}));

		$hash{axialTilt} = $event{AxialTilt};
		$hash{rotationalPeriod} = $event{RotationPeriod}/86400;		# seconds to days
		$hash{orbitalPeriod} = $event{OrbitalPeriod}/86400;		# seconds to days
		$hash{orbitalEccentricity} = $event{Eccentricity};
		$hash{semiMajorAxis} = $event{SemiMajorAxis}/149597870700;	# meters to AU
		$hash{argOfPeriapsis} = $event{Periapsis};
		$hash{orbitalInclination} = $event{OrbitalInclination};
		$hash{meanAnomaly} = $event{MeanAnomaly};
		$hash{meanAnomalyDate} = $scandate if ($event{MeanAnomaly} && $scandate);
		$hash{ascendingNode} = $event{AscendingNode};
		$hash{rotationalPeriodTidallyLocked} = $event{TidalLock} ? 1 : 0;
		$hash{parents} = $event{Parents};

		#print uc($bodyType)."($scandate): ".Dumper(\%hash)."\n";

		if ($bodyType eq 'star') {
			load_mappings() if (!keys %star_map);

			$hash{subType} = $star_map{$event{StarType}};
			$hash{subType} = 'White Dwarf ('.$event{StarType}.') Star' if ($event{StarType} =~ /^D/);
			$hash{subType} = $event{StarType} if ($event{StarType} && !$hash{subType});

			$hash{solarRadius} = $event{Radius}/696340000;		# meters to solar radius
			$hash{solarMasses} = $event{StellarMass};
			$hash{surfaceTemperature} = $event{SurfaceTemperature};
			$hash{luminosity} = $event{Luminosity};
			$hash{absoluteMagnitude} = $event{AbsoluteMagnitude};
			$hash{age} = $event{Age_MY};

			$hash{isScoopable} = 0;
			$hash{isScoopable} = 1 if ($event{StarType} =~ /^[OBAFGKM]$/ || $event{StarType} =~ /^[OBAFGKM]_/);

			if (defined($event{Subclass})) {
				if ($hash{subType} eq 'T Tauri Star') {
					$hash{spectralClass} = 'TTS'.$event{Subclass};
				} elsif ($hash{subType} eq 'Herbig Ae/Be Star') {
					$hash{spectralClass} = 'AeBe'.$event{Subclass};
				} elsif ($hash{subType} =~ /^\s*([OBAFGKMLTY])\s+\(.+\)\s+Star/) {
					$hash{spectralClass} = $1.$event{Subclass};
				}
			}
		}

		if ($bodyType eq 'planet') {
			load_mappings() if (!keys %planet_map);
	
			$hash{subType} = $planet_map{$event{PlanetClass}};
			$hash{subType} = 'Helium gas giant' if ($event{PlanetClass} =~ /helium/i && !$hash{subType});
			$hash{subType} = $event{PlanetClass} if ($event{PlanetClass} && !$hash{subType});
	
			$hash{volcanismType} = $volc_map{$event{Volcanism}};
			$hash{volcanismType} = $event{Volcanism} if (!$hash{volcanismType});
			$hash{atmosphereType} = $atmo_map{$event{Atmosphere}}{$event{AtmosphereType}};
			$hash{atmosphereType} = $event{AtmosphereType} if (!$hash{atmosphereType});
	
			$hash{terraformingState} = $terr_map{$event{TerraformState}};
	
			$hash{gravity} = $event{SurfaceGravity}/9.80665;		# convert to earth gravity
			$hash{surfacePressure} = $event{SurfacePressure}/101325;	# pascals to earth atmospheres
			$hash{surfaceTemperature} = $event{SurfaceTemperature};
			$hash{earthMasses} = $event{MassEM};
			$hash{radius} = $event{Radius}/1000;
	
			$hash{isLandable} = $event{Landable} ? 1 : 0;
	
			$hash{composition} = $event{Composition} if ($event{Composition});
			$hash{composition} = $event{solidComposition} if ($event{solidComposition});
	
			if (ref($event{Materials}) eq 'ARRAY') {
				foreach my $r (@{$event{Materials}}) { # each row
					$hash{materials}{$$r{Name}} = $$r{Percent};
				}
			}
	
			if (ref($event{AtmosphereComposition}) eq 'ARRAY') {
				foreach my $r (@{$event{AtmosphereComposition}}) { # each row
					$hash{atmospheres}{$$r{Name}} = $$r{Percent};
				}
			}
		}

		if (ref($event{Rings}) eq 'ARRAY') {

			foreach my $r (@{$event{Rings}}) { # each row
				my $n = {};
				$$n{name} = $$r{Name};
				$$n{type} = 'Metallic' if ($$r{RingClass} =~ /Metal/i);
				$$n{type} = 'Metal Rich' if ($$r{RingClass} =~ /MetalRich/i);
				$$n{type} = 'Rocky' if ($$r{RingClass} =~ /Rock/i);
				$$n{type} = 'Icy' if ($$r{RingClass} =~ /Ice|Icy/i);
				$$n{innerRadius} = $$r{InnerRad}/1000;
				$$n{outerRadius} = $$r{OuterRad}/1000;

				if ($$r{Name} =~ /(Belt|Ring)\s*$/) {
					my $thing = lc($1);
					$thing = "ring" if ($bodyType eq 'planet');
					$thing .= 's';
					@{$hash{$thing}} = () if (ref($hash{$thing}) ne 'ARRAY');
					push @{$hash{$thing}}, $n;
				}
			}
		}

		if ($bodyType && ($hash{name} || $eventType eq 'ScanBaryCentre') && defined($hash{bodyId64}) && $hash{systemId64}) {
			check_db_connection();
			if (!$eddn_debug) {
				update_object($bodyType,\%hash,\%event,'eddn_date',$scandate);
			} else {
				#print "EVENT($scandate): ".Dumper(\%event)."\n";
				print uc($bodyType)."($scandate): ".Dumper(\%hash)."\n";
			}
		}


		if (exists($event{Genuses}) && ref($event{Genuses}) eq 'ARRAY') {
			foreach my $r (@{$event{Genuses}}) {
				my $genusID = key_findcreate_local('genus',$$r{Genus},$$r{Genus_Localised});

#warn "!! $event{SystemAddress}.$event{BodyID}: $$r{Genus} ($$r{Genus_Localised}) = $genusID\n";

				if ($genusID) {
					my @rows = db_mysql('elite',"select * from organicsignals where systemId64=? and bodyId=? and genusID=?",
						[($event{SystemAddress},$event{BodyID},$genusID)]);

					if (@rows) {
						foreach my $r (@rows) {
							my $first = $$r{firstReported};
							$first = $scandate if ($scandate && $scandate gt '2021-04-01 00:00:00' && (!$$r{firstReported} || $scandate lt $$r{firstReported}));
							my $last = $$r{lastSeen};
							$last = $scandate if ($scandate && $scandate gt '2021-04-01 00:00:00' && (!$$r{lastSeen} || $scandate gt $$r{lastSeen}));
		
							next if ($first eq $$r{firstReported} && $last eq $$r{lastSeen});
		
							log_mysql('elite',"update organicsignals set firstReported=?,lastSeen=? where id=?",[($first,$last,$$r{id})]);
						}
					} else {
						log_mysql('elite',"insert into organicsignals (systemId64,bodyId,genusID,firstReported,lastSeen,date_added) values (?,?,?,?,?,NOW())",
								[($event{SystemAddress},$event{BodyID},$genusID,$scandate,$scandate)]);
					}
					
				}
			}
		} else {
#warn "!! $event{SystemAddress}.$event{BodyID}: NO GENUS\n";
		}
	}


	if ($eventType eq "ScanOrganic") {
		my $speciesID = key_findcreate_local('species',$event{Species},$event{Species_Localised});
		my $genusID = key_findcreate_local('genus',$event{Genus},$event{Genus_Localised});
		my $date = $event{timestamp};
		$date =~ s/T|Z/ /gs;
		$date =~ s/\.\d+\s*$//s;

		if ($speciesID && $genusID) {
			my @rows = db_mysql('elite',"select * from organic where systemId64=? and bodyId=? and genusID=? and speciesID=?",
				[($event{SystemAddress},$event{Body},$genusID,$speciesID)]);

			if (@rows) {
				foreach my $r (@rows) {
					my $first = $$r{firstReported};
					$first = $date if ($date && $date gt '2021-04-01 00:00:00' && (!$$r{firstReported} || $date lt $$r{firstReported}));
					my $last = $$r{lastSeen};
					$last = $date if ($date && $date gt '2021-04-01 00:00:00' && (!$$r{lastSeen} || $date gt $$r{lastSeen}));

					next if ($first eq $$r{firstReported} && $last eq $$r{lastSeen});

					log_mysql('elite',"update organic set firstReported=?,lastSeen=? where id=?",[($first,$last,$$r{id})]);
				}
			} else {
				log_mysql('elite',"insert into organic (systemId64,bodyId,genusID,speciesID,firstReported,lastSeen,date_added) values (?,?,?,?,?,?,NOW())",
						[($event{SystemAddress},$event{Body},$genusID,$speciesID,$date,$date)]);
			}
		}
	}

	if ($eventType eq "FSSSignalDiscovered" && $event{IsStation} && $event{SignalName} =~ /(.*\S+)\s+([A-Z0-9]{3}\-[A-Z0-9]{3})\s*$/) {
		my $name = btrim($1);
		my $callsign = btrim($2);
		my $timestamp = undef;
		my $id64 = undef;

		if ($event{SystemAddress} =~ /\s*(\d+)\D*/) {
			$id64 = $1+0;
		}

		if ($event{timestamp} =~ /(\d{4}-\d{2}-\d{2})[T\s]?(\d{2}:\d{2}:\d{2})(\.\d+)?Z?/) {
			$timestamp = "$1 $2";
		}

		if ($timestamp) {
			my @rows = db_mysql('elite',"select ID,name,systemId64,FSSdate,lastMoved from carriers where callsign=?",[($callsign)]);
	
			if (@rows && (!${$rows[0]}{FSSdate} || $timestamp gt ${$rows[0]}{FSSdate})) {
				# Update only if the new FSS event date is newer than on record, or don't have one on record.

				my $r = $rows[0];

				if (uc($name) ne uc($$r{name})) {
					print "FSSSignalDiscovered: $name ($$r{name}) $callsign [$timestamp]\n";
					log_mysql('elite',"update carriers set FSSdate=?,name=? where ID=?",[($timestamp,$name,$$r{ID})]);
				} else {
					print "FSSSignalDiscovered: $name $callsign [$timestamp]\n";
					log_mysql('elite',"update carriers set FSSdate=? where ID=?",[($timestamp,$$r{ID})]);
				}
	
				if ($id64 && $id64 != $$r{systemId64} && (!$$r{lastMoved} || $timestamp gt $$r{lastMoved})) {
					my @lookup = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where id64=? and deletionState=0",[($id64)]);
					my ($sysname,$x,$y,$z) = (undef,undef,undef,undef);
	
					if (@lookup) {
						my $s = shift @lookup;
						$sysname = $$s{name};
						$x = $$s{coord_x};
						$y = $$s{coord_y};
						$z = $$s{coord_z};
					}

					print "FSSSignalDiscovered: $name $callsign [$timestamp] $sysname, ($id64) $x, $y, $z\n";
					log_mysql('elite',"update carriers set systemId64=?,systemName=?,coord_x=?,coord_y=?,coord_z=? where ID=? and systemId64!=?",
						[($id64,$sysname,$x,$y,$z,$$r{ID},$id64)]);
				}
			}
		}
	}

	if ($eventType =~ /FSSAllBodiesFound|FSSDiscoveryScan/) {
		#{ "timestamp":"2021-06-24T21:06:52Z", "event":"FSSDiscoveryScan", "Progress":0.257542, "BodyCount":31, "NonBodyCount":4, "SystemName":"NGC 2244 Sector MI-Q c6-30", "SystemAddress":8333813616490 }
		#{ "timestamp":"2021-06-24T21:09:11Z", "event":"FSSAllBodiesFound", "SystemName":"NGC 2244 Sector MI-Q c6-30", "SystemAddress":8333813616490, "Count":31 }

		my $bodies = $event{BodyCount};
		$bodies = $event{Count} if ($event{Count} && !$event{BodyCount});

		my $nonbodies = undef;
		$nonbodies = $event{NonBodyCount} if ($event{NonBodyCount});

		my $id64 = $event{SystemAddress};
		my $progress = $event{Progress};
		$progress = 1 if ($eventType eq 'FSSAllBodiesFound');

		my $timestamp = $event{timestamp};
		$timestamp =~ s/T/ /s;
		$timestamp =~ s/Z//s;

		if ($id64) {
			my @rows = db_mysql('elite',"select ID from systems where id64=?",[($id64)]);

			if (@rows) {
				my @params = ($timestamp,$progress,$bodies);
				my $nonbodyUpdate = '';

				if (defined($nonbodies) || $eventType eq 'FSSDiscoveryScan') {
					$nonbodies = 0 if (!$nonbodies);
					$nonbodyUpdate = ',nonbodyCount=?';
					push @params, $nonbodies;
				}

				push @params, $id64;
				push @params, $progress;

				log_mysql('elite',"update systems set FSSdate=?,FSSprogress=?,bodyCount=?$nonbodyUpdate where id64=? and ".
					"(FSSprogress is null or FSSprogress<?)",\@params);
			} else {

				log_mysql('elite',"insert into systems (id64,name,FSSdate,FSSprogress,bodyCount,nonbodyCount) values (?,?,?,?,?,?)",
					[($id64,$event{StarSystem},$timestamp,$progress,$bodies,$nonbodies)]);
			}
		}
	}

	if ($eventType eq "CodexEntry") {
		print "CodexEntry: $event{Name_Localised}\n";
		codex_entry(\%event);
	}

}


############################################################################

sub track_carrier {
	my ($eventType, $jref) = @_;
	return if (!$jref || ref($jref) ne 'HASH');

	my $table = 'carriers';
	my $logtable = 'carrierlog';

	if (!ok_gameversion($jref,undef,'carrier')) {
		$table = 'legacycarriers';
		$logtable = 'legacycarrierlog';
	}

	$allow_updates = 1;

	#return if ($$jref{message}{'$schemaRef'} !~ /schemas\/journal\/1$/);	# Don't process anything outside of the journal schema, or in test, etc

	my %carrier = ();
	my %event = %{$$jref{message}};
	$eventType = $event{event} if ($event{event} && $event{event} ne $eventType);

#	if ($eventType eq 'FSSSignalDiscovered' && $event{IsStation} && $event{SignalName} =~ /\s+([\w\d]{3}\-[\w\d]{3})\s*$/) {
#		$carrier{callsign} = $1;
#		$carrier{name} = $event{SignalName};
#		$carrier{systemId64} = $event{SystemAddress};
#	}

	if ($event{StationName} &&
		( $eventType eq 'CarrierJump' || 
		  ($eventType eq 'Location' && $event{Docked} && 
			($event{StationType} eq 'FleetCarrier' || $event{StationName} =~ /^\s*[\w\d]{3,5}\-[\w\d]{3,5}\s*$/)) ||
		  ($eventType eq 'Docked' && $event{StationType} eq 'FleetCarrier')
		)
	   ) {
		$carrier{callsign} = $event{StationName};
		$carrier{name} = $event{CarrierName} if ($event{CarrierName}); # Not part of actual events, shoehorning in for my scripts
		$carrier{marketID} = $event{MarketID};
		$carrier{marketID} = $event{CarrierID} if ($event{CarrierID});
		$carrier{systemName} = $event{StarSystem};
		$carrier{systemId64} = $event{SystemAddress};
		$carrier{distanceToArrival} = $event{DistFromStarLS} if ($event{DistFromStarLS});

		$carrier{lastEvent} = $event{timestamp};
		$carrier{lastEvent} =~ s/T/ /gs;
		$carrier{lastEvent} =~ s/(\.\d+)?Z.*$//gs;

		if ($event{StarPos}) {
			($carrier{coord_x},$carrier{coord_y},$carrier{coord_z}) = @{$event{StarPos}};
		}

		$carrier{services} = join(',',sort keys %{$event{StationServices}}) if (exists($event{StationServices}) && ref($event{StationServices}) eq 'HASH');
		$carrier{services} = join(',',sort @{$event{StationServices}}) if (exists($event{StationServices}) && ref($event{StationServices}) eq 'ARRAY');

		print "CARRIER: $carrier{callsign}($carrier{marketID}) in $carrier{systemName} ($carrier{systemId64}) $carrier{services}\n";

	} elsif ($eventType eq 'CarrierStats') {
		$carrier{callsign} = $event{Callsign};
		$carrier{name} = $event{Name};
		$carrier{marketID} = $event{CarrierID} if ($event{CarrierID});

		foreach my $key (qw(AllowNotorious PendingDecommission)) {
			$carrier{$key} = $event{$key} ? 1 : 0;
		}
		foreach my $key (qw(DockingAccess FuelLevel)) {
			$carrier{$key} = $event{$key};
		}
		$carrier{TaxRate} = $event{Finance}{TaxRate};
		$carrier{CarrierBalance} = $event{Finance}{CarrierBalance};

		$carrier{lastEvent} = $event{timestamp};
		$carrier{lastEvent} =~ s/T/ /gs;
		$carrier{lastEvent} =~ s/(\.\d+)?Z.*$//gs;

	} elsif ($eventType eq "FSSSignalDiscovered" && $event{IsStation} && $event{SignalName} =~ /(.*\S+)\s+([A-Z0-9]{3}\-[A-Z0-9]{3})\s*$/) {

		($carrier{name}, $carrier{callsign}) = ($1, $2);

		$carrier{lastEvent} = $event{timestamp};
		$carrier{lastEvent} =~ s/T/ /gs;
		$carrier{lastEvent} =~ s/(\.\d+)?Z.*$//gs;
		
		$carrier{systemId64} = $event{SystemAddress};

	} elsif ($eventType eq 'CarrierJumpRequest') {
		my @rows = db_mysql('elite',"select * from $table where marketID=?",[($event{CarrierID})]);
		if (@rows) {
			my $r = shift @rows;
			%carrier = %$r;

			$carrier{lastEvent} = $event{timestamp};
			$carrier{lastEvent} =~ s/T/ /gs;
			$carrier{lastEvent} =~ s/(\.\d+)?Z.*$//gs;

			$carrier{systemName} = $event{StarSystem};
			$carrier{systemId64} = $event{SystemAddress};

			my @sys = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where id64=? and deletionState=0",[($event{SystemAddress})]);

			if (@sys) {
				my $s = shift @sys;

				if (defined($$s{coord_x}) && defined($$s{coord_x}) && defined($$s{coord_x})) {
					foreach my $v (qw(coord_x coord_y coord_z)) {
						$carrier{$v} = $$s{$v};
					}
				}
			}
		}	
	}

	if (keys %carrier && $carrier{callsign}) {
		# Update the carrier here.

		check_db_connection();

#		if ($carrier{marketID}) {
#			eval {
#				my @check = db_mysql('elite',"select ID,callsign from $table where marketID=? and callsign!=? and (converted is null or converted=0)",[($carrier{marketID},$carrier{callsign})]);
#	
#				if (@check>1 || (@check==1 && ${$check[0]}{callsign} ne $carrier{callsign})) {
#					system('/home/bones/elite/reassign-carrier.pl',${$check[0]}{callsign},$carrier{callsign},1);
#				}
#			};
#			print "ERROR: $@" if ($@);
#		}


		if ($carrier{services}) {
			$carrier{services} =~ s/(carrierfuel|carriermanagement|docking|flightcontroller|stationMenu|stationoperations|autodock)\,/\,/gs;
			$carrier{services} =~ s/\,\,+/\,/gs;
		}

		if ($carrier{systemId64} && (!$carrier{systemName} || !$carrier{coord_x} || !$carrier{coord_y} ||!$carrier{coord_z})) {
			my @rows = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where id64=?",[($carrier{systemId64})]);
			foreach my $s (@rows) {
				$carrier{systemName} = $$s{name};
				$carrier{coord_x} = $$s{coord_x};
				$carrier{coord_y} = $$s{coord_y};
				$carrier{coord_z} = $$s{coord_z};
			}
		}

		my @rows = db_mysql('elite',"select * from $table where callsign=?",[($carrier{callsign})]);

		if (!@rows) {
			# Carrier is new

			log_mysql('elite',"insert into $table (name,marketID,callsign,created,lastEvent,lastMoved,systemId64,systemName,services,coord_x,coord_y,coord_z,".
				"CarrierBalance,TaxRate,DockingAccess,FuelLevel,AllowNotorious,PendingDecommission) ".
				"values (?,?,?,NOW(),?,NOW(),?,?,?,?,?,?,?,?,?,?,?,?)",
				[($carrier{name},$carrier{marketID},$carrier{callsign},$carrier{lastEvent},$carrier{systemId64},
				$carrier{systemName},$carrier{services},$carrier{coord_x},$carrier{coord_y},$carrier{coord_z},
				$carrier{CarrierBalance},$carrier{TaxRate},$carrier{DockingAccess},$carrier{FuelLevel},$carrier{AllowNotorious},$carrier{PendingDecommission})]);

			log_mysql('elite',"insert into $logtable (callsign,logdate,systemId64,systemName,coord_x,coord_y,coord_z) values (?,?,?,?,?,?,?)",
				[($carrier{callsign},$carrier{lastEvent},$carrier{systemId64},$carrier{systemName},
				$carrier{coord_x},$carrier{coord_y},$carrier{coord_z})]) if ($carrier{systemId64});
		} else {
			# Carrier exists, check for changes.

			my $old = shift @rows;

			eval {
				my $and = '';
				my @andparams = ();

				if ($carrier{systemName}) {
					$and .= " and systemName=?";
					push @andparams, $carrier{systemName};
				}
				if ($carrier{systemId64}) {
					$and .= " and systemId64=?";
					push @andparams, $carrier{systemId64};
				}

				my @thisrow = db_mysql('elite',"select * from $logtable where callsign=? and logdate=? $and",[($carrier{callsign},$carrier{lastEvent},@andparams)]);

				if (!@thisrow) {

				my @prevrow = db_mysql('elite',"select * from $logtable where callsign=? and logdate<? order by logdate desc limit 1",
							[($carrier{callsign},$carrier{lastEvent})]);
	
				my @nextrow = db_mysql('elite',"select * from $logtable where callsign=? and logdate>? order by logdate limit 1",
							[($carrier{callsign},$carrier{lastEvent})]);
	
				my %prev = ();
				my %next = ();
	
				if (@prevrow) {	
					%prev = %{$prevrow[0]};
				}
	
				if (@nextrow) {	
					%next = %{$nextrow[0]};
				}
	
				if ( (!@nextrow && !@prevrow) || (@nextrow && $carrier{systemId64} != $next{systemId64} && $carrier{systemId64} != $prev{systemId64}) ) {
					# Log entry is between others, with a move, add it.
					# Or, there are no log entries at all. Add it.
	
					log_mysql('elite',"insert into $logtable (callsign,logdate,systemId64,systemName,coord_x,coord_y,coord_z) values (?,?,?,?,?,?,?)",
						[($carrier{callsign},$carrier{lastEvent},$carrier{systemId64},$carrier{systemName},
						$carrier{coord_x},$carrier{coord_y},$carrier{coord_z})]) if ($carrier{systemId64});
	
				} elsif (@nextrow && $carrier{systemId64} == $next{systemId64} && $carrier{systemId64} != $prev{systemId64}) {
					# Log entry is between others, with a move from prev, same as next, so back-date next.
	
					db_mysql('elite',"update $logtable set logdate=? where ID=?",[($carrier{lastEvent},$next{ID})]);
	
				} elsif (@nextrow && $carrier{systemId64} == $prev{systemId64}) {
					# Log entry is between others, same as prev, Ignore.
	
				} elsif (!@nextrow && $carrier{systemId64} != $prev{systemId64}) {
					# Log entry comes after existing logs, and has a move, add it.
	
					log_mysql('elite',"insert into $logtable (callsign,logdate,systemId64,systemName,coord_x,coord_y,coord_z) values (?,?,?,?,?,?,?)",
						[($carrier{callsign},$carrier{lastEvent},$carrier{systemId64},$carrier{systemName},
						$carrier{coord_x},$carrier{coord_y},$carrier{coord_z})]) if ($carrier{systemId64});
	
				} elsif (!@nextrow) {
					# Log entry is after existing logs, no move, so ignore.
				} else {
					# shouldn't get here. But trap this unknown condition anyway.
				}

				} # endif (!@thisrow)
			};
			print "ERROR: $@" if ($@);

			eval {
				my @lastrow = db_mysql('elite',"select * from $logtable where callsign=? order by logdate desc limit 1",[($carrier{callsign})]);
	
				if (@lastrow) {
					$carrier{lastMoved}  = ${$lastrow[0]}{logdate};
					$carrier{systemName} = ${$lastrow[0]}{systemName};
					$carrier{systemId64} = ${$lastrow[0]}{systemId64};
				}
	
				#if ($carrier{lastEvent} >= $$old{lastEvent}) {
				if ($carrier{lastEvent} ge $$old{lastEvent}) {
					my $changes = '';
					my @params = ();
		
					foreach my $k (sort keys %carrier) {
						next if ($k =~ /^(updated|created|ID|FSS)$/);
						next if (!exists($$old{$k}));
		
						if (defined($carrier{$k}) && $carrier{$k} ne '' && $carrier{$k} ne $$old{$k}) {
							$changes .= ",$k=?";
							push @params, $carrier{$k};
							#print "CHANGE [$carrier{callsign}] $k = $carrier{$k}\n";
						}
					}
		
					if ($changes && @params) {
						$changes = "updated=NOW()".$changes;
						log_mysql('elite',"update $table set $changes where callsign=?",[(@params,$carrier{callsign})]);
					}
				} elsif ($carrier{lastMoved} ne $$old{lastMoved}) {
					# We get here if the "new" event is actually older than a previous update. But if our recalculation
					# of the "lastMoved" date has changed somehow, we can just update that.

					log_mysql('elite',"update $table set lastMoved=? where callsign=?",[($carrier{lastMoved},$carrier{callsign})]);
				}

				if (@lastrow && ($$old{systemName} ne ${$lastrow[0]}{systemName} || $$old{systemId64} ne ${$lastrow[0]}{systemId64})) {
					# This is a sanity check. Latest log entry should always be matched in the carrier table:

					log_mysql('elite',"update $table set lastMoved=?,systemName=?,systemId64=? where callsign=?",
						[($carrier{lastMoved},${$lastrow[0]}{systemName},${$lastrow[0]}{systemId64},$carrier{callsign})]);
				}
			};
			print "ERROR: $@" if ($@);
		}

		if (($eventType =~ /Docked/i || $event{event} eq 'Docked') && $carrier{lastEvent} && $carrier{callsign}) {
			check_db_connection();
			eval {
				my @rows = db_mysql('elite',"select * from carrierdockings where callsign=? and docked=?",[($carrier{callsign},$carrier{lastEvent})]);
				log_mysql('elite',"insert into carrierdockings (callsign,docked) values (?,?)",[($carrier{callsign},$carrier{lastEvent})]) if (!@rows);
			};
			print "ERROR: $@" if ($@);

			eval {
				log_mysql('elite',"update $table set lastEvent=? where callsign=? and lastEvent<?",[($carrier{lastEvent},$carrier{callsign},$carrier{lastEvent})]);
			};
			print "ERROR: $@" if ($@);
		}
	}
}

############################################################################

sub log_jsonl {
	my ($type,$jsonl) = @_;
	my @t = localtime;
	my $date = sprintf("%04u%02u",$t[5]+1900,$t[4]+1_);
	open EDDNJSON, ">>/home/bones/elite/eddn-data/$date-$type.jsonl";
	print EDDNJSON "$jsonl\n";
	close EDDNJSON;
}

sub check_db_connection {

	my $ok = 0;

	while (!$ok) {
		eval {
			my @rows = db_mysql('elite',"show tables");
			$ok = 1 if (@rows);
		};
		print "ERROR: $@" if ($@);
	
		if (!$ok) {
			disconnect_all();
			print "DB went away. Sleeping 5,\n";
			sleep 5;
		}
	}
}

sub ok_gameversion {
	my $jref = shift;
	my $ver = shift;
	my $carrier = shift;
	#$carrier = undef; # for now, try again

	if (!$ver) {
		if ($carrier) {
			return 1 if (!$jref || ref($jref) ne 'HASH');
			return 1 if (!$$jref{header}{gameversion});
		} else {
			return 0 if (!$jref || ref($jref) ne 'HASH');
			return 0 if (!$$jref{header}{gameversion});
		}
		$ver = $$jref{header}{gameversion};
	}

	if ($carrier) {
		return 1 if (!$ver);
		return 1 if ($ver =~ /^CAPI-Live/i);
		return 1 if ($ver !~ /^\d+\.\d+\./);
	} else {
		return 0 if (!$ver);
		return 1 if ($ver =~ /^CAPI-Live/i);
		return 0 if ($ver !~ /^\d+\.\d+\./);
	}

	$ver =~ s/^(\d+\.\d+)\..+$/$1/;

	return 0 if ($ver < 4.0);
	return 1;
}

sub game_OK {
	my $verbose = shift;

	my $browser = LWP::UserAgent->new;
	my $response = $browser->get($statusURL);
	if ($response->is_success) {
		if ($response->content =~ /"code"\s*:\s*(\d+),/s) {
			my_syslog("EDDN: Game status: $1") if ($verbose);
			return 1 if ($1>0);
			return 0;
		}
	}

	my_syslog("EDDN: Game status not retrieved") if ($verbose);
	return 1; # Fail open
}



1;


############################################################################

