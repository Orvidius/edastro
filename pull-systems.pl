#!/usr/bin/perl
use strict;

#############################################################################

use File::Basename;

use lib "/home/bones/perl";
use ATOMS qw(btrim epoch2date date2epoch);

# Some archived dumps are here: https://edgalaxydata.space/

#############################################################################

my $edsm_down		= 0;

my $path		= '/home/bones/elite';
my @t			= localtime;
my $date		= sprintf("%04u%02u%02u",$t[5]+1900,$t[4]+1,$t[3]);

my $mail		= '/usr/bin/mail';
my $echo		= '/usr/bin/echo';
my $gunzip		= '/usr/bin/gunzip';
my $wget		= '/usr/bin/wget';
my $mv			= '/usr/bin/mv';
my $ps			= '/usr/bin/ps';
my $grep		= '/usr/bin/grep';
my $touch		= '/usr/bin/touch';
my $scp			= '/usr/bin/scp';

my $runfile		= '/home/bones/pull-systems.pl.running';

my $day_interval	= 2;

my $epochDay		= int(time / 86400);

my %planets		= ();
my %stars		= ();
my %moons		= ();

my %action		= ();
my $cron		= 0;

foreach my $arg (@ARGV) {
	if ($arg =~ /^cron$/i) {
		$cron = 1;
	} else {
		$action{$arg} = 1;
	}
}

my $runfile = '/home/bones/elite/pull-systems.pl.run';

my @fstat = stat($runfile);

my @t1 = localtime($fstat[9]);
my @t2 = localtime;
my $fdate = sprintf("%04u-%02u-%02u",$t1[5]+1900,$t1[4]+1,$t1[3]);
my $cdate = sprintf("%04u-%02u-%02u",$t2[5]+1900,$t2[4]+1,$t2[3]);

if ($cron && $fdate eq $cdate) {
	die "Already ran today ($fdate).\n";
}


@{$moons{'moons-of-ELWs.csv'}} = ('Earth-like world');

@{$planets{'Earth-like-worlds.csv'}} = ('Earth-like world');
@{$planets{'Ammonia-worlds.csv'}} = ('Ammonia world');
@{$planets{'Life-giants.csv'}} = ('Gas giant with ammonia-based life','Gas giant with water-based life');
@{$planets{'Helium-rich-giants.csv'}} = ('Helium-rich gas giant');
@{$planets{'Helium-gas-giants.csv'}} = ('Helium gas giant');
@{$planets{'Water-giants.csv'}} = ('Water giant');
@{$planets{'eccentric-orbits.csv'}} = ('and:orbitalEccentricity\>=0.999');
@{$planets{'eccentric-orbits-landable.csv'}} = ('and:orbitalEccentricity\>=0.9','and:isLandable=1');
@{$planets{'metal-rich-terraformables.csv'}} = ('Metal-rich body',"and:terraformingState=\\'Candidate\\ for\\ terraforming\\'");
@{$planets{'gas-giants-as-moons.csv'}} = (q(rlike:name=\'\ \[\0-9\]+\\(\ \[a-z\]\\)+$\'),'Class I gas giant','Class II gas giant','Class III gas giant','Class IV gas giant','Class V gas giant','Gas giant with ammonia-based life','Gas giant with water-based life','Helium gas giant','Helium-rich gas giant','Water giant');
@{$planets{'shortest-rotation-planets.csv'}} = ('notnull:rotationalPeriodDec','and:rotationalPeriodDec\>0','order=abs(rotationalPeriodDec)','limit=10000');
@{$planets{'smallest-planets.csv'}} = ('and:radiusDec\>=0','and:radiusDec\<190','order=radiusDec');

#@{$planets{'odyssey-landables.csv'}} = ('High metal content world','Icy body','Metal-rich body','Rocky body','Rocky Ice world','and:surfacePressure\>=0.001','and:surfacePressure\<=0.1','and:isLandable=1');

@{$planets{'zero-distance-planets.csv'}} = ('and:distanceToArrival\=0');
@{$planets{'distant-planets.csv'}} = ('and:distanceToArrival\>700000', q(binlike:name=\'\ \[A-Z\]\[A-Z\]-\[A-Z\]\ \[a-z\]\'));
@{$stars{'distant-stars.csv'}} = ('and:distanceToArrival\>700000', q(binlike:name=\'\ \[A-Z\]\[A-Z\]-\[A-Z\]\ \[a-z\]\'));

@{$stars{'Black-Holes.csv'}} = ('Black Hole','Supermassive Black Hole');
@{$stars{'Carbon-stars.csv'}} = ('C Star','CJ Star','CN Star','S-type Star','MS-type Star');
@{$stars{'Carbon-C-stars.csv'}} = ('C Star');
@{$stars{'Red-SuperGiants.csv'}} = ('M (Red super giant) Star');
@{$stars{'WhiteDwarf-Rare-Subtypes.csv'}} = ('White Dwarf (DAZ) Star','White Dwarf (DBV) Star','White Dwarf (DBZ) Star','White Dwarf (DQ) Star');
@{$stars{'O-class-stars.csv'}} = ('O (Blue-White) Star');
@{$stars{'B-class-supergiants.csv'}} = ('B (Blue-White super giant) Star');
@{$stars{'A-class-supergiants.csv'}} = ('A (Blue-White super giant) Star');
@{$stars{'K-class-giants.csv'}} = ('K (Yellow-Orange giant) Star');
@{$stars{'Wolf-Rayet-stars.csv'}} = ('Wolf-Rayet C Star','Wolf-Rayet N Star','Wolf-Rayet NC Star','Wolf-Rayet O Star','Wolf-Rayet Star');
@{$stars{'herbig-stars.csv'}} = ('Herbig Ae/Be Star');

#############################################################################

date_print("Epoch Day: $epochDay");
print "\t$day_interval-Day: ".($epochDay % $day_interval)."\n";

system("$touch $runfile");

if (!keys(%action) && ($t[3] == 1 || $t[3] == 15)) {
	get_file(1,'-u','https://www.edsm.net/dump','systemsWithoutCoordinates.json') if (!$edsm_down);
}

if ((!keys(%action) && $epochDay % 4 == 0) || $action{bodies}) {	# Every 4 days despite normal schedule
	my_system("cd ~bones/elite ; ./spansh-sync.sh > spansh-sync.sh.out 2>\&1");
}

if ((!keys(%action) && $epochDay % 4 == 2) || $action{bodies}) {	# Every 4 days despite normal schedule
	#my_system("cd ~bones/elite ; ./eddb-sync.sh > eddb-sync.sh.out 2>\&1");
}
if ((!keys(%action) && ($epochDay % 4 == 1 || $epochDay % 4 == 3)) || $action{bodies}) {	# Every 4 days despite normal schedule
	get_file(1,'-u','https://www.edsm.net/dump','systemsWithCoordinates7days.json') if (!$edsm_down);
	get_file(1,'-u','https://www.edsm.net/dump','bodies7days.json') if (!$edsm_down);
}
if ((!keys(%action) && $t[6] == 1) || $action{data}) {
	get_file(1,'-u4','https://www.edsm.net/dump','codex.json',1) if (!$edsm_down);
}

my_system("cd ~bones/elite ; ./update-boxels.pl ");
my_system("cd ~bones/elite ; ./systems-fixups.pl ");
my_system("cd ~bones/elite ; ./purge-navsystems-duplicates.pl");

#my_system(1,"cd ~bones/elite/scripts ; ./colony-candidates.pl > colony-candidates.pl.out 2>\&1 ");

#my_system("cd ~bones/elite ; ./carrier-maps.pl ");

#my_system("cd ~bones/elite ; ./get-GGGs.sh ; ./DSSA-pull.pl");
#my_system("cd ~bones/elite ; ( $wget -O POIlist.json https://www.edsm.net/en/galactic-mapping/json-edd ; ".
#	"./json-to-jsonl.pl POIlist.json > POIlist.jsonl ; ./parse-data.pl POIlist.jsonl ) 2>\&1 > parse-POIlist.out ");
##	"; ./edsmPOI.pl > edsmPOI.data ; scp edsmPOI.data www\@services:/www/edastro.com/galmap/ ");

if ($t[3] == 1) {
	#my_system("cd ~bones/elite/csv-maps ; ./get-hullseals.pl ; ./csv-maps.pl hullseals.conf");
	my_system("cd ~bones/elite/csv-maps ; ./get-fuelrats.pl ; ./csv-maps.pl fuelrats.conf");
}

if ((!keys(%action) && $epochDay % $day_interval == 0) || $action{bodies}) {
	get_file(1,'-u','https://www.edsm.net/dump','stations.json') if (!$edsm_down);
	my_system(1,"cd ~bones/elite ; ./adjusted-dates.pl > adjusted-dates.pl.out 2>\&1");
}
if (!keys(%action) || $action{bodies}) {
	my_system(1,"cd ~bones/elite ; ./find-primaries.pl ");
	my_system(1,"cd ~bones/elite ; ./orbit-types-update.pl ");
	waitfor('find-primaries.pl','orbit-types-update.pl');
	my_system(1,"cd ~bones/elite ; ./update-regioncodes.pl > update-regioncodes.pl.out 2>\&1");
	my_system(1,"cd ~bones/elite ; ./update-parents.pl > update-parents.pl.out 2>\&1");
	#my_system(1,"cd ~bones/elite ; ./update-completion.pl > update-completion.pl.out 2>\&1");
	my_system(1,"cd ~bones/elite ; ./update-main-startypes.pl > update-main-startypes.pl.out 2>\&1");
	waitfor('update-regioncodes.pl','update-parents.pl','update-completion.pl');
}

if (!keys(%action) && ($t[3] == 1 || $t[3] == 15)) {
	#my_system(1,"cd ~bones/elite/scripts ; ./dump-bodies.pl > dump-bodies.pl.out 2>\&1 ; ssh -p222 www\@services 'cd /www/edastro.com/mapcharts ; ./update-spreadsheets.pl'");
	my_system(1,"cd ~bones/elite/scripts ; ./rings-atmos-etc.pl > rings-atmos-etc.out 2>\&1");
}

#if (!keys(%action) && $t[6] == 0) {
#	my_system("cd ~bones/elite ; ./draw-graphs.pl > draw-graphs.pl.out 2>\&1");
#}

if ((!keys(%action) && $epochDay % $day_interval == 0) || $action{maps}) {
	#my_system("cd ~bones/elite ; ./projections.pl > projections.pl.out 2>\&1");
	#my_system("cd ~bones/elite ; ./make-starmaps.pl > make-starmaps.pl.out 2>\&1");
	#my_system("ssh -p222 www\@services 'cd /www/EDtravelhistory ; nohup nice ./tiles.pl >tiles.pl.out 2>\&1 \&'");
}

if ((!keys(%action) && $t[6] == 6) || $action{maps}) {
	#my_system("cd ~bones/elite ; $wget -O nebulae.xlsx https://docs.google.com/spreadsheets/d/1uU01bSvv5SpScuOnsaUK56R2ylVAU4rFtVkcGUA7VZg/export?format=xlsx");
	#my_system("cd ~bones/elite ; $wget -O lagrangeclouds.xlsx https://docs.google.com/spreadsheets/d/1Bq5RmU9zfK2Hu409BpoyHQZa-mUgAtONWTySqKT7Df8/export?format=xlsx");
	#my_system("cd ~bones/elite ; ./lagrangecloud-maps.pl");

	#my_system("cd ~bones/elite ; ./get-nebulae.sh ; ./nebula-maps.pl ; ./IGAUcodex-maps.pl ");
	#my_system("cd ~bones/elite ; ./get-nebulae.sh ; ./nebula-maps.pl");
	#my_system("cd ~bones/elite ; ./IGAU_Codex-import.pl > IGAU_Codex-import.pl.out 2>\&1 ");
	my_system(1,"cd ~bones/elite ; ./codex-maps.pl > codex-maps.pl.out 2>\&1 ");
	my_system("cd ~bones/elite ; ./missing-coordinates-map.pl > missing-coordinates-map.pl.out 2>\&1");
	my_system("cd ~bones/elite ; ./codex-tweaks.pl > codex-tweaks.pl.out 2>\&1 ") if (!$edsm_down);
	my_system("cd ~bones/elite ; ./organic-maps.pl > organic-maps.pl.out 2>\&1 ");
}

#if (!keys(%action) && $t[3] == 28) {
if (!keys(%action) && $t[6] == 6) {
	my_system(1,"cd ~bones/elite ; ./update-main-startypes.pl 1 > update-main-startypes.pl.out2 2>\&1");	# Fix missing occasionally
}

if ((!keys(%action) && $epochDay % $day_interval == 0) || $action{files}) {

	my_system("$path/carrier-video.pl > $path/carrier-video.pl.out >\&1");
	my_system("$path/thargoid-video.pl > $path/thargoid-video.pl.out >\&1");
	my_system("$path/inhabited-video.pl > $path/inhabited-video.pl.out >\&1");

	#my_system(1,"cd ~bones/elite/scripts ; ./lagrange-capable-stars.pl > lagrange-capable-stars.csv ; [ -s lagrange-capable-stars.csv ] \&\& scp lagrange-capable-stars.csv www\@services:/www/edastro.com/mapcharts/files/  ");

	#redirect_script("near-entry-systems.pl.pl","near-entry-systems.pl.csv");

	foreach my $csv (sort keys %planets) { eval {

		my @list = ();
		foreach my $n (sort @{$planets{$csv}}) {
			push @list, "'$n'" if ($n !~ /^(and|rlike|binlike):/);
			push @list, $n if ($n =~ /^(and|rlike|binlike):/);
		}

		my $cmd = "cd ~bones/elite/scripts ; ./planet-list.pl ".join(' ',@list)." > $csv ; [ -s $csv ] \&\& scp -P222 $csv www\@services:/www/edastro.com/mapcharts/files/";
		my_system(1,$cmd);
	}};

	foreach my $csv (sort keys %stars) { eval {

		my @list = ();
		foreach my $n (sort @{$stars{$csv}}) {
			push @list, "'$n'" if ($n !~ /^(and|rlike|binlike):/);
			push @list, $n if ($n =~ /^(and|rlike|binlike):/);
		}

		my $cmd = "cd ~bones/elite/scripts ; ./star-list.pl ".join(' ',@list)." > $csv ; [ -s $csv ] \&\& scp -P222 $csv www\@services:/www/edastro.com/mapcharts/files/";
		my_system($cmd);
	}};

	foreach my $csv (sort keys %moons) { eval {

		my @list = ();
		foreach my $n (sort @{$moons{$csv}}) {
			push @list, "'$n'" if ($n !~ /^(and|rlike|binlike):/);
			push @list, $n if ($n =~ /^(and|rlike|binlike):/);
		}

		my $cmd = "cd ~bones/elite/scripts ; ./moons-of-planets.pl ".join(' ',@list)." > $csv ; [ -s $csv ] \&\& scp -P222 $csv www\@services:/www/edastro.com/mapcharts/files/";
		my_system($cmd);
	}};

	my_system(1,"cd ~bones/elite/scripts ; ./nearest-sol-discoveries.pl > nearest-sol-discoveries.csv ; [ -s nearest-sol-discoveries.csv ] \&\& scp nearest-sol-discoveries.csv www\@services:/www/edastro.com/mapcharts/files/ ");
	my_system(1,"cd ~bones/elite/scripts ; ./sector-list.pl > sector-list.pl.out ; cp sector-list.csv sector-list-stable.csv ; ".
		"[ -s sector-list.csv ] \&\& scp -P222 sector-list.csv www\@services:/www/edastro.com/mapcharts/files/ ; ".
		"[ -s sector-discovery.csv ] \&\& scp -P222 sector-discovery.csv www\@services:/www/edastro.com/mapcharts/files/ ");

	my_system(1,"cd ~bones/elite/scripts ; ./database-stats.pl > database-stats.csv ; [ -s database-stats.csv ] \&\& scp -P222 database-stats.csv www\@services:/www/edastro.com/mapcharts/files/ ");
	my_system(1,"cd ~bones/elite/scripts ; ./inclined-moons-near-rings.pl > inclined-moons-near-rings.csv ; [ -s inclined-moons-near-rings.csv ] \&\& scp inclined-moons-near-rings.csv www\@services:/www/edastro.com/mapcharts/files/ ");
	update_spreadsheets();

	my_system("cd ~bones/elite/scripts ; ./planet-multiples.pl 2 'Earth-like world' > ELW-multiples.csv ; [ -s ELW-multiples.csv ] \&\& scp -P222 ELW-multiples.csv www\@services:/www/edastro.com/mapcharts/files/ ");
	background_script("close-landables.pl","close-landables.csv");
	my_system("cd ~bones/elite/scripts ; ./nested-moons.pl > Nested-Moons.csv ; [ -s Nested-Moons.csv ] \&\& scp -P222 Nested-Moons.csv www\@services:/www/edastro.com/mapcharts/files/ ");
	my_system("cd ~bones/elite/scripts ; ./edge-systems.pl > edge-systems.csv ; [ -s edge-systems.csv ] \&\& scp -P222 edge-systems.csv www\@services:/www/edastro.com/mapcharts/files/ ");
	my_system(1,"cd ~bones/elite/scripts ; ./hot-gasgiants.pl > hot-gasgiants.csv ; [ -s hot-gasgiants.csv ] \&\& scp -P222 hot-gasgiants.csv www\@services:/www/edastro.com/mapcharts/files/ ");
	my_system(1,"cd ~bones/elite/scripts ; ./hot-jupiters.pl > hot-jupiters.csv ; [ -s hot-jupiters.csv ] \&\& scp -P222 hot-jupiters.csv www\@services:/www/edastro.com/mapcharts/files/ ");
	my_system("cd ~bones/elite/scripts ; ./unknown-stars.pl > unknown-stars.csv ; [ -s unknown-stars.csv ] \&\& scp -P222 unknown-stars.csv www\@services:/www/edastro.com/mapcharts/files/ ");
	#my_system("cd ~bones/elite/scripts ; ./body-counts.pl > body-counts.csv ; [ -s body-counts.csv ] \&\& scp -P222 body-counts.csv www\@services:/www/edastro.com/mapcharts/files/ ");
	my_system("cd ~bones/elite/scripts ; ./binary-planets.pl > binary-ELW.csv ; [ -s binary-ELW.csv ] \&\& scp -P222 binary-ELW.csv www\@services:/www/edastro.com/mapcharts/files/ ");
	my_system("cd ~bones/elite/scripts ; ./neutron-stars.pl > neutron-stars.csv ; [ -s neutron-stars.csv ] \&\& scp -P222 neutron-stars.csv www\@services:/www/edastro.com/mapcharts/files/ ");
	my_system(1,"cd ~bones/elite/scripts ; ./icy-ring-systems.pl ");

	bg_execute_script("discovery-dates.pl","discovery-dates.csv","discovery-months.csv");
	execute_script("boxel-stats.pl","boxel-stats.csv");
	update_spreadsheets();

	redirect_script("popular-carrier-names.pl","popular-carrier-names.csv");
	redirect_script("date-erosion.pl","date-erosion.csv");
	redirect_script("multiple-star-planets.pl","multiple-star-planets.csv");
	redirect_script("water-worlds.pl","water-worlds-g-class.csv");
	#redirect_script("herbig-planets.pl 'Ammonia world'","herbig-AW.csv");
	#redirect_script("herbig-planets.pl","herbig-ELW.csv");
	redirect_script("short-period-planets.pl","short-period-planets.csv");
	background_script("ringed-stars.pl","ringed-stars.csv");
	background_script("valuable-planet-systems.pl","valuable-planet-systems.csv");
	bg_execute_script("tightest-binary-stars.pl","tightest-binary-stars.csv");
	bg_execute_script("tightest-binary-stars.pl 1","tightest-binary-stars-surface.csv");
	redirect_script("ELW-moons.pl","ELW-moons.csv");
	redirect_script("terraformable-systems.pl","terraformable-systems.csv");
	redirect_script("systems-without-coordinates.pl","systems-without-coordinates.csv");
	redirect_script("stations.pl","stations.csv");
	redirect_script("tidally-locked-unequal.pl","tidally-locked-unequal.csv");
	redirect_script("landables-closest-approach.pl","landables-closest-approach.csv");
	redirect_script("sol-like-systems.pl","sol-like-systems.csv");
	redirect_script("codex-data.pl","codex-data.csv");
	#redirect_script("planet-list.pl -notype 'Water world'","water-worlds.csv");

	update_spreadsheets();
}

#my_system("cd ~bones/elite/scripts ; ./additional-carriers.sh ; ./yank-inara-carriers.pl");
redirect_script("fleetcarriers.pl","fleetcarriers.csv");

if ((!keys(%action) && $epochDay % $day_interval == 1) || $action{files}) {
	if (!$action{files}) {	# 2 hours
		#date_print("Sleeping, to allow maps to complete if they're still running.");
		#sleep 2*3600;
	}
	my_system(1,"cd ~bones/elite/scripts ; ./json7days.pl > json7days.pl.out 2>\&1");
	#my_system(1,"cd ~bones/elite/scripts ; ./galactic-records.pl > galactic-records.pl.out 2>\&1") if ($t[6] == 0 || $t[6] == 6); # Saturday or Sunday, on the quieter of the two
	background_script("moon-rich-HMCs.pl","moon-rich-HMCs.csv");
	bg_execute_script("moon-rich-planets.pl","moon-rich-planets.csv");
	bg_execute_script("moon-rich-stars.pl","moon-rich-stars.csv");
	#my_system(1,"cd ~bones/elite/scripts ; ./trojan-planets.pl > trojan-planets.csv ; [ -s trojan-planets.csv ] \&\& scp trojan-planets.csv www\@services:/www/edastro.com/mapcharts/files/  ");
	background_script("suspicious-data.pl","suspicious-data.csv");
	bg_execute_script("odyssey-landable-rare-candidates.sh","odyssey-landable-rare-candidates.csv");
	redirect_script("sol-like-systems.pl","sol-like-systems.csv");
	redirect_script("moons-smallest-ring-gaps.pl","moons-smallest-ring-gaps.csv");
	redirect_script("area-largest.pl","area-largest.csv");
	redirect_script("tidally-locked-to-stars.pl","tidally-locked-to-stars.csv");
	my_system("cd ~bones/elite/scripts ; ./sphereradius-systembodies.pl 'Hen 2-333' 350 graea-hypue.csv > sphereradius-graea-hypue.out 2>\&1 ");
	#redirect_script("navsystems.pl","navsystems.csv");
	background_script("masscode-classes.pl","masscode-classes.csv");

	update_spreadsheets();

	background_script("high-body-count-systems.pl","high-body-count-systems.csv");
	background_script("close-moons-landable.pl 'Earth-like world'","close-moons-landable-ELW.csv");
	my_system("cd ~bones/elite/scripts ; ./catalog-systems.pl > catalog-systems.pl.out 2>\&1");

	#waitfor('trojan-planets.pl');

	#my_system("cd ~bones/elite/scripts ; ./shepherd-moons.pl > shepherd-moons.csv 2>shepherd-moons.out ; [ -s shepherd-moons.csv ] \&\& scp shepherd-moons.csv www\@services:/www/edastro.com/mapcharts/files/  ");

	my_system("cd ~bones/elite/scripts ; ./sector-list-H-mass.pl > sector-list-H-mass.csv ; [ -s sector-list-H-mass.csv ] \&\& scp -P222 sector-list-H-mass.csv www\@services:/www/edastro.com/mapcharts/files/ ");

	my_system("scp -P222 ~bones/elite/images/region-lines.png www\@services:/www/edastro.com/galmap/");
	bg_execute_script("rings-statistics.pl","rings-statistics.csv");

	update_spreadsheets();
}

#if ($t[6] == 2 || $t[6] == 5) {	# Tuesday and Friday
if ($t[6] == 4) {			# Thursdays
	#my_system(1,"cd ~bones/elite/scripts ; ./galactic-records.pl > galactic-records.pl.out 2>\&1");
}

if (!keys(%action) && $t[6] == 0) {
	#redirect_script("metallicity.pl","metallicity.csv");
	#my_system('cd ~bones/elite/scripts ; cp metallicity.csv metallicity-stable.csv');
	my_system("cd ~bones/elite/scripts ; ./systems-without-main-stars.pl > systems-without-main-stars.pl.out 2>\&1 ");
	update_spreadsheets();
}

#if ((!keys(%action) && $t[6] == 6) || $action{video}) {
#	my_system(1,"$path/history-video.pl > $path/history-video.pl.out 2>\&1");
#	my_system(1,"$path/history-video.pl 1 > $path/history-video.pl.decay.out 2>\&1");
#	#my_system("$path/carrier-video.pl > $path/carrier-video.pl .out >\&1");
#}

#get_file(0,'-u','https://eddb.io/archive/v5','bodies_recently.jsonl');


unlink $runfile;

date_print("Done.");

exit;

#############################################################################

sub update_spreadsheets {
	my_system("ssh -p222 www\@services 'cd /www/edastro.com/mapcharts ; ./update-spreadsheets.pl'");
}

sub background_script {
	my ($script,$outfile) = @_;
	$script = btrim($script);
	my $logname = log_name($script);
	my_system(1,"cd ~bones/elite/scripts ; ./$script > $outfile 2>$logname ; [ -s $outfile ] \&\& scp $outfile www\@services:/www/edastro.com/mapcharts/files/");
}

sub redirect_script {
	my ($script,$outfile) = @_;
	$script = btrim($script);
	if ($script =~ /^\d+$/) {
		(my $ignore,$script,$outfile) = @_;
	}
	my $logname = log_name($script);
	my_system("cd ~bones/elite/scripts ; ./$script > $outfile 2>$logname ; [ -s $outfile ] \&\& scp $outfile www\@services:/www/edastro.com/mapcharts/files/");
}

sub execute_script {
	my $script = btrim(shift);
	my $datafiles = join(' ',@_);
	my $logname = log_name($script);
	my_system("cd ~bones/elite/scripts ; ./$script > $logname 2>\&1 ; scp $datafiles www\@services:/www/edastro.com/mapcharts/files/");
}

sub bg_execute_script {
	my $script = btrim(shift);
	my $datafiles = join(' ',@_);
	my $logname = log_name($script);
	my_system(1,"cd ~bones/elite/scripts ; ./$script > $logname 2>\&1 ; scp $datafiles www\@services:/www/edastro.com/mapcharts/files/");
}

sub log_name {
	my $script = btrim(shift);
	my $logname = $script;
	$logname =~ s/\s+.*$//s;
	$logname .= ".out";

	return "outfile.out" if (!$logname || $logname eq $script || $logname =~ /\s/);
	return $logname;
}

sub get_file {
	my ($parse_now, $param, $url, $file, $do_bg) = @_;

	my $bg = $do_bg ? 1 : 0;

	my $bg_task = $bg ? "; $path/parse-data.pl $param $path/$file > $path/$file.out 2>\&1 ; mv $path/$file $path/$file.used" : '';

	#my_system("cd $path ; rm -f $file ; $wget $url/$file");

	#if (!-e $file) {
		#my_system("cd $path ; rm -f $file ; rm -f $file.gz ; $wget --no-check-certificate $url/$file.gz"); # Use if cert lookup is failing
		#my_system("cd $path ; $gunzip $file.gz ; sync");
		my_system($bg,"cd $path ; rm -f $file ; rm -f $file.gz ; $wget $url/$file.gz ; $gunzip $file.gz ; sync $bg_task");
	#}

	return if ($bg_task);

	if (!-e "$path/$file") {
		my_system($bg,"$echo \"Could not retrieve $file\" | $mail -s \"EDastro Pull Failure: $file\" ed\@toton.org");
	}

	if (!$parse_now) {
		date_print("MV $file -> $date-$file");
		my_system($bg,"$mv $path/$file $path/$date-$file");
		#my_system("$path/parse-data.pl $param $path/$date-$file > $path/$date-$file.out 2>\&1") if ($parse_now);
	} else {
		my_system($bg,"$path/parse-data.pl $param $path/$file > $path/$file.out 2>\&1");
		my_system($bg,"mv $path/$file $path/$file.used");
	}
}

sub my_system {
	my $do_fork = 0;

	if ($_[0] =~ /^\d+$/) {
		$do_fork = shift @_;
	}

	my @list = @_;

	my $s = join(' ',@list);
	my $d = epoch2date(time,-5,1);
	print "[$d] $s\n";

	my $pid = undef;

	if (!$do_fork) {
		system(@list);
	} else {
		if ($pid = fork) {
			#parent
			return;
		} elsif (defined $pid) {
			#child
			exec(@list);
		} else {
			system(@list);
		}
		
	}
}

sub date_print {
	my $d = epoch2date(time,-5,1);
	foreach my $s (@_) {
		my $ss = $s;
		chomp $ss;
		print "[$d] $ss\n";
	}
}

sub waitfor {
	my @scripts = @_;
	my %running = ();
	my $done = 0;

	return if (!@scripts);

	my $d = epoch2date(time,-5,1);
	print "[$d] Waiting for: '".join("','",@scripts)."':";

	while (!$done) {

		#/usr/bin/perl ./trojan-planets.pl
		#/usr/bin/perl ./update-POI.pl
		my %running = ();

		open PS, "$ps awx | $grep perl |";
		while (<PS>) {
			#10164 pts/5    S+     0:00 /usr/bin/perl ./orbit-types-update.pl
			if (/[\/\w]+perl\s+([\.\/\w\-]+?)\s*(\s+.+)?$/) {
				$running{basename($1)} = 1;
				#print "found: ".basename($1)."\n";
			}
		}
		close PS;

		$done = 1;
		foreach my $script (@scripts) {
			$done = 0 if ($running{$script});
		}

		if (!$done) {
			sleep 5;
			print ';';
		}
	}
	print "\n";

	my $d = epoch2date(time,-5,1);
	print "[$d] DONE Waiting for: '".join("','",@scripts)."'\n";
}

#############################################################################


