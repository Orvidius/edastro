#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10 ssh_options scp_options);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

use Image::Magick;
use POSIX qw(floor);
#use File::Basename;

############################################################################

show_queries(0);
$0 =~ s/^.*\///s;
my $progname = $0;

my $hostname = `/usr/bin/hostname -s`; chomp $hostname;

my $debug		= 0;
my $debug_full		= 0;
my $skip_all		= 0;
my $skip_alternates	= 0;
my $verbose		= 0;
my $allow_scp		= 1;

my $maxChildren		= 4;
my $fork_verbose	= 0;

my $id_add		= 10**12;

my $override_PNG	= 'tga'; #'';
$override_PNG = '' if ($hostname =~ /ghoul/);

my $FSSdate		= '2018-12-11 00:00:00';
my $FSSepoch		= date2epoch($FSSdate);

my $chunk_size		= 100000;
my $debug_stars		= 100000;
my $debug_and		= " and edsm_date>='$FSSdate'" if ($debug);
my $debug_limit		= '';
#   $debug_limit		= "order by coord_z limit $debug_stars" if ($debug);
#   $debug_limit		= " and (name like 'Eol Prou %' or name like 'Oevasy %' or name like 'Eos Chrea %')" if ($debug);
#   $debug_limit		= " and abs(coord_x)<1000 and abs(coord_y)<1000 and abs(coord_z)<1000 order by id64 limit $debug_stars" if ($debug);
#   $debug_limit		= " and abs(coord_x)<1000 and abs(coord_y)<1000 and abs(coord_z)<1000 order by id64" if ($debug);
   $debug_limit		= "limit $debug_stars" if ($debug);

if ($debug && $debug_full) {
	$debug_limit = '';
	$debug_and = '';
}

my $remote_server	= 'www@services:/www/edastro.com/mapcharts/';
my $filepath		= "/home/bones/www/elite";
my $img_path		= "/home/bones/elite/images";
my $scripts_path	= "/home/bones/elite/scripts";

$filepath .= '/test'	if ($0 =~ /\.pl\.\S+/);
$allow_scp = 0		if ($0 =~ /\.pl\.\S+/);

my $author		= "By CMDR Orvidius (edastro.com) - CC BY-NC-SA 3.0 - Data from EDDN & EDSM.net";

my $outputgroup		= 0;
$outputgroup = $ARGV[0] if ($ARGV[0]);

$maxChildren = $ARGV[1]+0 if ($ARGV[1] =~ /^\d+$/ && $ARGV[1] > 0);

my %file = ();


#$file{"classmassG-C-6750"}	= "$filepath/class-G-mass-C-age_6750.png" if (!$outputgroup || $outputgroup==1);
#$file{"classmassK-C-6750"}	= "$filepath/class-K-mass-C-age_6750.png" if (!$outputgroup || $outputgroup==1);
#$file{"classmassG-C-12700"}	= "$filepath/class-G-mass-C-age_12700.png" if (!$outputgroup || $outputgroup==1);
#$file{"classmassK-C-12700"}	= "$filepath/class-K-mass-C-age_12700.png" if (!$outputgroup || $outputgroup==1);
#$file{"classmassG-C-old"}	= "$filepath/class-G-mass-C-age_old.png" if (!$outputgroup || $outputgroup==1);
#$file{"classmassK-C-old"}	= "$filepath/class-K-mass-C-age_old.png" if (!$outputgroup || $outputgroup==1);


$file{systems_heatmin2}	= "$filepath/visited-systems-heatmap-minimum2.png" if (!$outputgroup || $outputgroup==1);

#if (!$debug && !$skip_all) {
$file{systems_recent}	= "$filepath/systems_recent.png" if (!$outputgroup || $outputgroup==2);
$file{averagebodies}	= "$filepath/averagebodies.png" if (!$outputgroup || $outputgroup==1);
$file{systems_heat}	= "$filepath/visited-systems-heatmap.png" if (!$outputgroup || $outputgroup==1);
$file{systems_heatmin}	= "$filepath/visited-systems-heatmap-minimum.png" if (!$outputgroup || $outputgroup==1);
$file{systems_mono}	= "$filepath/visited-systems.png" if (!$outputgroup || $outputgroup==1);
$file{systems_indexed}	= "$filepath/visited-systems-indexedheatmap.png" if (!$outputgroup || $outputgroup==1);
$file{"classmassF"}	= "$filepath/class-F-mass-distribution.png"   if (!$outputgroup || $outputgroup==1);
$file{"classmassF-D"}	= "$filepath/class-F-mass-D-distribution.png" if (!$outputgroup || $outputgroup==1);
$file{"classmassF-E"}	= "$filepath/class-F-mass-E-distribution.png" if (!$outputgroup || $outputgroup==1);
$file{"classmassG"}	= "$filepath/class-G-mass-distribution.png"   if (!$outputgroup || $outputgroup==1);
$file{"classmassG-C"}	= "$filepath/class-G-mass-C-distribution.png" if (!$outputgroup || $outputgroup==1);
$file{"classmassG-D"}	= "$filepath/class-G-mass-D-distribution.png" if (!$outputgroup || $outputgroup==1);
$file{"classmassK"}	= "$filepath/class-K-mass-distribution.png"   if (!$outputgroup || $outputgroup==1);
$file{"classmassK-C"}	= "$filepath/class-K-mass-C-distribution.png" if (!$outputgroup || $outputgroup==1);
$file{"classmassK-D"}	= "$filepath/class-K-mass-D-distribution.png" if (!$outputgroup || $outputgroup==1);
$file{sector_overlay}	= "$filepath/sector-overlay.png" if (!$outputgroup || $outputgroup==1);

$file{starclass_large}	= "$filepath/galaxy-heatmap.png" if (!$outputgroup || $outputgroup==1);
$file{starclass}	= "$filepath/star-heatmap.png" if (!$outputgroup || $outputgroup==1);
$file{masscode}		= "$filepath/masscode.png" if (!$outputgroup || $outputgroup==1);
$file{agestars}		= "$filepath/age-stars.png" if (!$outputgroup || $outputgroup==1);

$file{averagestars}	= "$filepath/averagestars.png" if (!$outputgroup || $outputgroup==2);
$file{giantstars}	= "$filepath/giantstars.png" if (!$outputgroup || $outputgroup==2);
$file{hugestars}	= "$filepath/hugestars.png" if (!$outputgroup || $outputgroup==2);
$file{dwarfs}		= "$filepath/dwarfs.png" if (!$outputgroup || $outputgroup==2);
$file{worlds}		= "$filepath/valuable-worlds.png" if (!$outputgroup || $outputgroup==2);
$file{planets}		= "$filepath/planets.png" if (!$outputgroup || $outputgroup==2);
$file{earthlikes}	= "$filepath/earthlikes.png" if (!$outputgroup || $outputgroup==2);
$file{lifeworlds}	= "$filepath/lifeworlds.png" if (!$outputgroup || $outputgroup==2);
$file{terraformables}	= "$filepath/terraformables.png" if (!$outputgroup || $outputgroup==2);
$file{oddballs}		= "$filepath/oddballs.png" if (!$outputgroup || $outputgroup==2);
$file{protostars}	= "$filepath/protostars.png" if (!$outputgroup || $outputgroup==2);
$file{neutrons}		= "$filepath/neutrons.png" if (!$outputgroup || $outputgroup==2);
$file{wolfrayet}	= "$filepath/wolfrayet.png" if (!$outputgroup || $outputgroup==2);
$file{wolfrayet1}	= "$filepath/wolfrayet1.png" if (!$outputgroup || $outputgroup==2);
$file{wolfrayet2}	= "$filepath/wolfrayet2.png" if (!$outputgroup || $outputgroup==2);
$file{wolfrayet3}	= "$filepath/wolfrayet3.png" if (!$outputgroup || $outputgroup==2);
$file{wolfrayet4}	= "$filepath/wolfrayet4.png" if (!$outputgroup || $outputgroup==2);
$file{whitedwarfs}	= "$filepath/whitedwarfs.png" if (!$outputgroup || $outputgroup==2);
$file{remnants}		= "$filepath/star-remnants.png" if (!$outputgroup || $outputgroup==2);
$file{heliumrich}	= "$filepath/heliumrich.png" if (!$outputgroup || $outputgroup==2);
$file{boostables}	= "$filepath/boostables.png" if (!$outputgroup || $outputgroup==2);
$file{bluestars}	= "$filepath/bluestars.png" if (!$outputgroup || $outputgroup==2);
$file{blackholes}	= "$filepath/black-holes.png" if (!$outputgroup || $outputgroup==2);
$file{wolfrayet}	= "$filepath/wolfrayet.png" if (!$outputgroup || $outputgroup==2);
$file{wolfrayet1}	= "$filepath/wolfrayet1.png" if (!$outputgroup || $outputgroup==2);
$file{wolfrayet2}	= "$filepath/wolfrayet2.png" if (!$outputgroup || $outputgroup==2);
$file{wolfrayet3}	= "$filepath/wolfrayet3.png" if (!$outputgroup || $outputgroup==2);
$file{wolfrayet4}	= "$filepath/wolfrayet4.png" if (!$outputgroup || $outputgroup==2);
#}

my %mapstyle = ();
$mapstyle{systems_mono} = 'mono';
$mapstyle{systems_heat} = 'heatmap';
$mapstyle{systems_heatmin} = 'heatmap';
$mapstyle{systems_heatmin2} = 'heatmap';
$mapstyle{systems_indexed} = 'indexedheatmap';
$mapstyle{averagebodies} = 'averagebodies';
$mapstyle{averagestars} = 'averagestars';
$mapstyle{systems_recent} = 'indexedheatmap2';

my %halfsize = ();
$halfsize{systems_recent} = 1;

my $heatmin_minstars = 20;
my $heatmin_minstars_2 = 10;

if (!$outputgroup || $outputgroup==2) {
	foreach my $l ('A'..'H') {
		$file{"mass$l"} = "$filepath/mass$l.png" if (!$debug && !$skip_all);
	}
	foreach my $l (0..4) {
		$file{"age$l"} = "$filepath/age$l.png" if (!$debug && !$skip_all);
	}
}

my $pi			= 3.1415926535;

my $ssh			= '/usr/bin/ssh'.ssh_options();
my $scp			= '/usr/bin/scp'.scp_options();
my $convert		= '/usr/bin/convert';

#print "SSH: $ssh\n";
#print "SCP: $scp\n";
#exit;

my $logarithm_scale	= 0.2;	# Fraction to add to logarithms based on the largest (hottest) pixel element

my $pixellightyears	= 50;
my $bigpixellightyears	= 20;
my $hugepixellightyears	= 10;

my $galaxy_radius	= 45000;
my $galaxy_height	= 6000;

my $sector_radius	= 35;
my $sector_height	= 4;

my $galcenter_x		= 0;
my $galcenter_y		= -25;
my $galcenter_z		= 25000;

my $sectorcenter_x	= -65;
my $sectorcenter_y	= -25;
my $sectorcenter_z	= 25815;

my %chart = ();
my %agelimit = ();

my $separator		= int(1500/$pixellightyears);

my $magnitude_boost	= 25;
my $magnitude_scale	= 55;
my $temperature_scale	= 35000;
my $hr_scale		= 1.6;

my @colorkey = ("O|O Star","B|B Star","A|A Star","F|F Star","G|G Star","K|K Star","M|M Star","BD|Brown Dwarf","TT|T Tauri Star","HE|Herbig Ae/Be",
		"C|Carbon Star","WR|Wolf-Rayet","WD|White Dwarf","NS|Neutron Star","BH|Black Hole","U|Misc",
		"GG1|Class I Gas Giant","GG2|Class II Gas Giant","GG3|Class III Gas Giant","GG4|Class IV Gas Giant","GG5|Class V Gas Giant",
		"WW|Water World","ELW|Earth-Like World","AW|Ammonia World","GGAL|Gas Giant, Ammonia Life","GGWL|Gas Giant, Water Life",
		"GGHE|Helium Gas Giant","GGHR|Helium-rich Gas Giant","WG|Water Giant","HMC|High Metal Content World","ROCKY|Rocky Body","ICY|Icy Body",
		"ROCKICE|Rocky Icy Body","MR|Metal-Rich Body",'S_B|B (Blue-White super giant) Star', 'S_A|A (Blue-White super giant) Star', 
		'S_F|F (White super giant) Star', 'S_G|G (White-Yellow super giant) Star', 'G_K|K (Yellow-Orange giant) Star', 'S_M|M (Red super giant) Star', 
		'G_M|M (Red giant) Star');

my @masskey = ("A|A-Mass System","B|B-Mass System","C|C-Mass System","D|D-Mass System","E|E-Mass System","F|F-Mass System","G|G-Mass System","H|H-Mass System");

my @agekey = ("a0|0-9 Million Years","a1|10-99 Million Years","a2|100-999 Million Years","a3|1-9 Billion Years","a4|10-99 Billion Years","a5|100-999 Billion Years");

my %giantstarcodes = ('S_B'=>1, 'S_A'=>1, 'S_F'=>1, 'S_G'=>1, 'G_K'=>1, 'S_M'=>1, 'G_M'=>1);
my %starcodes = ('O'=>1, 'B'=>1, 'A'=>1, 'F'=>1, 'G'=>1, 'K'=>1, 'M'=>1, 'BD'=>1, 'TT'=>1, 'HE'=>1, 'C'=>1, 'WR'=>1, 'WD'=>1, 'NS'=>1, 'BH'=>1, 'U'=>1);
my %planetcodes = ('GG1'=>1, 'GG2'=>1, 'GG3'=>1, 'GG4'=>1, 'GG5'=>1, 'ELW'=>1, 'AW'=>1, 'WW'=>1, 'GGAL'=>1, 'GGWL'=>1, 'GGHE'=>1, 'GGHR'=>1, 
			'WG'=>1,'HMC'=>1,'MR'=>1,'ICY'=>1,'ROCKY'=>1,'ROCKICE'=>1);

my %starTypeKey = {};
$starTypeKey{''} = 'Main Sequence';
$starTypeKey{'D'} = 'Dwarf';
$starTypeKey{'G'} = 'Giant';
$starTypeKey{'S'} = 'Supergiant';


my %mapviews		= ();
@{$mapviews{starclass}}	= qw(main front side beagle beag2 sagA colonia bubble hrdiagram);
@{$mapviews{starclass_large}}	= qw(main3 front3 side3);
@{$mapviews{remnants}}	= qw(main front side);
$mapviews{oddballs}	= $mapviews{remnants};
$mapviews{protostars}	= $mapviews{remnants};
$mapviews{dwarfs}	= $mapviews{remnants};
$mapviews{giantstars}	= $mapviews{remnants};
$mapviews{hugestars}	= $mapviews{remnants};
$mapviews{worlds}	= $mapviews{remnants};
$mapviews{earthlikes}	= $mapviews{remnants};
$mapviews{lifeworlds}	= $mapviews{remnants};
$mapviews{terraformables}	= $mapviews{remnants};
$mapviews{planets}	= $mapviews{remnants};
$mapviews{heliumrich}	= $mapviews{remnants};
$mapviews{bluestars}	= $mapviews{remnants};
$mapviews{agestars}	= $mapviews{remnants};
$mapviews{neutrons}	= $mapviews{remnants};
$mapviews{wolfrayet}	= $mapviews{remnants};
$mapviews{wolfrayet1}	= $mapviews{remnants};
$mapviews{wolfrayet2}	= $mapviews{remnants};
$mapviews{wolfrayet3}	= $mapviews{remnants};
$mapviews{wolfrayet4}	= $mapviews{remnants};
$mapviews{whitedwarfs}	= $mapviews{remnants};
$mapviews{blackholes}	= $mapviews{remnants};
$mapviews{boostables}	= $mapviews{remnants};
@{$mapviews{systems}}	= qw(main3 front3 side3);
@{$mapviews{averagebodies}}	= qw(main3 front3 side3);
@{$mapviews{averagestars}}	= qw(main3 front3 side3);

my %galaxy_chart	= ();
$galaxy_chart{starclass}= 'main';
$galaxy_chart{starclass_large}	= 'main3';
$galaxy_chart{remnants}	= 'main';
$galaxy_chart{oddballs}	= 'main';
$galaxy_chart{protostars}= 'main';
$galaxy_chart{dwarfs}	= 'main';
$galaxy_chart{giantstars}	= 'main';
$galaxy_chart{hugestars}	= 'main';
$galaxy_chart{worlds}	= 'main';
$galaxy_chart{earthlikes}	= 'main';
$galaxy_chart{lifeworlds}	= 'main';
$galaxy_chart{terraformables}	= 'main';
$galaxy_chart{planets}	= 'main';
$galaxy_chart{heliumrich}= 'main';
$galaxy_chart{bluestars}= 'main';
$galaxy_chart{agestars}= 'main';
$galaxy_chart{neutrons}= 'main';
$galaxy_chart{wolfrayet}= 'main';
$galaxy_chart{wolfrayet1}= 'main';
$galaxy_chart{wolfrayet2}= 'main';
$galaxy_chart{wolfrayet3}= 'main';
$galaxy_chart{wolfrayet4}= 'main';
$galaxy_chart{whitedwarfs}= 'main';
$galaxy_chart{boostables}= 'main';
$galaxy_chart{blackholes}= 'main';
$galaxy_chart{systems}= 'main3';
$galaxy_chart{averagebodies}= 'main3';
$galaxy_chart{averagestars}= 'main3';

my %mapdata		= ();
$mapdata{starclass}{label}	= 'Milky Way scanned stars';
$mapdata{starclass_large}{label}= 'Milky Way scanned stars';
$mapdata{remnants}{label}	= 'Milky Way scanned supernova remnants';
$mapdata{oddballs}{label}	= 'Milky Way scanned Wolf-Rayet, Carbon, and rare stars';
$mapdata{protostars}{label}	= 'Milky Way scanned proto-stars';
$mapdata{dwarfs}{label}		= 'Milky Way scanned dwarf stars';
$mapdata{giantstars}{label}	= 'Milky Way scanned Giant & Super-Giant stars (ED Type)';
$mapdata{hugestars}{label}	= 'Milky Way scanned Huge Radius stars';
$mapdata{worlds}{label}		= 'Milky Way scanned Valuable Worlds';
$mapdata{earthlikes}{label}	= 'Milky Way scanned Earth-like Worlds';
$mapdata{lifeworlds}{label}	= 'Milky Way scanned Life-Capable Worlds';
$mapdata{terraformables}{label}	= 'Milky Way scanned Terraformable Worlds';
$mapdata{planets}{label}	= 'Milky Way scanned planets & moons';
$mapdata{heliumrich}{label}	= 'Milky Way scanned Helium Rich Gas Giants';
$mapdata{bluestars}{label}	= 'Milky Way scanned blue stars';
$mapdata{agestars}{label}	= 'Milky Way scanned stars by age, 1 MY to 14 BY';
$mapdata{neutrons}{label}	= 'Milky Way scanned neutron stars';
$mapdata{wolfrayet}{label}	= 'Milky Way scanned Wolf-Rayet stars';
$mapdata{wolfrayet1}{label}	= 'Milky Way scanned Wolf-Rayet stars';
$mapdata{wolfrayet2}{label}	= 'Milky Way scanned Wolf-Rayet stars';
$mapdata{wolfrayet3}{label}	= 'Milky Way scanned Wolf-Rayet stars';
$mapdata{wolfrayet4}{label}	= 'Milky Way scanned Wolf-Rayet stars';
$mapdata{whitedwarfs}{label}	= 'Milky Way scanned white dwarfs';
$mapdata{boostables}{label}	= 'Milky Way scanned neutron stars and white dwarfs';
$mapdata{systems}{label}	= 'Milky Way discovered/submitted systems';
$mapdata{averagebodies}{label}	= 'Milky Way average bodies scanned per system';
$mapdata{blackholes}{label}	= 'Milky Way scanned black holes';
$mapdata{averagestars}{label}	= 'Milky Way Average Stars per System, Post-FSS Era';

%{$mapdata{starclass}{bodies}}	= %starcodes;
$mapdata{starclass_large}{bodies}	= $mapdata{starclass}{bodies};
%{$mapdata{remnants}{bodies}}	= ('NS'=>1, 'BH'=>1);
%{$mapdata{oddballs}{bodies}}	= ('WR'=>1, 'U'=>1, 'C'=>1);
%{$mapdata{protostars}{bodies}}	= ('TT'=>1, 'HE'=>1);
%{$mapdata{dwarfs}{bodies}}	= ('WD'=>1, 'BD'=>1);
%{$mapdata{giantstars}{bodies}}	= %giantstarcodes;
%{$mapdata{worlds}{bodies}}	= ('WW'=>1, 'ELW'=>1, 'AW'=>1);
%{$mapdata{earthlikes}{bodies}}	= ('ELW'=>1);
%{$mapdata{lifeworlds}{bodies}}	= ('WW'=>1, 'ELW'=>1, 'AW'=>1, 'GGWL'=>1, 'GGAL'=>1, 'WG'=>1);
%{$mapdata{terraformables}{bodies}}	= ();
%{$mapdata{planets}{bodies}}	= %planetcodes;
%{$mapdata{heliumrich}{bodies}}	= ('GGHE'=>1,'GGHR'=>1);
%{$mapdata{bluestars}{bodies}}	= ('O'=>1, 'B'=>1);
%{$mapdata{agestars}{bodies}}	= %starcodes;
%{$mapdata{neutrons}{bodies}}	= ('NS'=>1);
%{$mapdata{wolfrayet}{bodies}}	= ('WR'=>1);
%{$mapdata{wolfrayet1}{bodies}}	= ('WR'=>1);
%{$mapdata{wolfrayet2}{bodies}}	= ('WR'=>1);
%{$mapdata{wolfrayet3}{bodies}}	= ('WR'=>1);
%{$mapdata{wolfrayet4}{bodies}}	= ('WR'=>1);
%{$mapdata{whitedwarfs}{bodies}}= ('WD'=>1);
%{$mapdata{blackholes}{bodies}}	= ('BH'=>1);
%{$mapdata{boostables}{bodies}}	= ('NS'=>1, 'WD'=>1);
%{$mapdata{systems}{bodies}}	= ();
%{$mapdata{averagebodies}{bodies}}	= ();
%{$mapdata{averagestars}{bodies}}	= ();

$mapdata{starclass}{bodytype}	= 'stars';
$mapdata{starclass_large}{bodytype}	= 'stars';
$mapdata{remnants}{bodytype}	= 'stars';
$mapdata{oddballs}{bodytype}	= 'stars';
$mapdata{protostars}{bodytype}	= 'stars';
$mapdata{dwarfs}{bodytype}	= 'stars';
$mapdata{giantstars}{bodytype}	= 'stars';
$mapdata{hugestars}{bodytype}	= 'stars';
$mapdata{worlds}{bodytype}	= 'planets';
$mapdata{earthlikes}{bodytype}	= 'planets';
$mapdata{lifeworlds}{bodytype}	= 'planets';
$mapdata{terraformables}{bodytype}	= 'planets';
$mapdata{planets}{bodytype}	= 'planets';
$mapdata{heliumrich}{bodytype}	= 'planets';
$mapdata{bluestars}{bodytype}	= 'stars';
$mapdata{agestars}{bodytype}	= 'stars';
$mapdata{neutrons}{bodytype}	= 'stars';
$mapdata{wolfrayet}{bodytype}	= 'stars';
$mapdata{wolfrayet1}{bodytype}	= 'stars';
$mapdata{wolfrayet2}{bodytype}	= 'stars';
$mapdata{wolfrayet3}{bodytype}	= 'stars';
$mapdata{wolfrayet4}{bodytype}	= 'stars';
$mapdata{whitedwarfs}{bodytype}	= 'stars';
$mapdata{blackholes}{bodytype}	= 'stars';
$mapdata{boostables}{bodytype}	= 'stars';
$mapdata{systems}{bodytype}	= 'systems';
$mapdata{averagebodies}{bodytype}	= 'systems';
$mapdata{averagestars}{bodytype}= 'systems';

$mapdata{starclass_large}{gamma}	= '1.2';
$mapdata{remnants}{gamma}	= '1.2';
$mapdata{oddballs}{gamma}	= '1.2';
$mapdata{protostars}{gamma}	= '1.2';
$mapdata{dwarfs}{gamma}		= '1.2';
$mapdata{giantstars}{gamma}	= '1.2';
$mapdata{hugestars}{gamma}	= '1.2';
$mapdata{worlds}{gamma}		= '1.2';
$mapdata{earthlikes}{gamma}	= '1.2';
$mapdata{lifeworlds}{gamma}	= '1.2';
$mapdata{terraformables}{gamma}		= '1.2';
$mapdata{neutrons}{gamma}	= '1.2';
$mapdata{wolfrayet}{gamma}	= '1.2';
$mapdata{wolfrayet1}{gamma}	= '1.2';
$mapdata{wolfrayet2}{gamma}	= '1.2';
$mapdata{wolfrayet3}{gamma}	= '1.2';
$mapdata{wolfrayet4}{gamma}	= '1.2';
$mapdata{whitedwarfs}{gamma}	= '1.2';
$mapdata{blackholes}{gamma}	= '1.2';
$mapdata{boostalbes}{gamma}	= '1.2';
$mapdata{bluestars}{gamma}	= '1.2';
$mapdata{averagestars}{gamma}	= '1.2';

$chart{main}{size_x}	= int($galaxy_radius/$pixellightyears);
$chart{main}{size_y}	= int($galaxy_radius/$pixellightyears);
$chart{main}{center_x}	= $chart{main}{size_x};
$chart{main}{center_y}	= $chart{main}{size_y};
$chart{main}{zoom}	= 1;
$chart{main}{x}		= $galcenter_x;
$chart{main}{y}		= $galcenter_y;
$chart{main}{z}		= $galcenter_z;
$chart{main}{label}	= 'Milky Way scanned stars';

$chart{front}{size_x}	= int($galaxy_radius/$pixellightyears);
$chart{front}{size_y}	= int($galaxy_height/$pixellightyears);
$chart{front}{center_x}	= $chart{front}{size_x};
$chart{front}{center_y}	= $chart{front}{size_y} + $chart{main}{size_y} + $chart{main}{center_y};
$chart{front}{zoom}	= 1;
$chart{front}{x}	= $galcenter_x;
$chart{front}{y}	= $galcenter_y;
$chart{front}{z}	= $galcenter_z;

$chart{side}{size_x}	= int($galaxy_height/$pixellightyears);
$chart{side}{size_y}	= int($galaxy_radius/$pixellightyears);
$chart{side}{center_x}	= $chart{side}{size_x} + $chart{main}{size_x} + $chart{main}{center_x};
$chart{side}{center_y}	= $chart{side}{size_y};
$chart{side}{zoom}	= 1;
$chart{side}{x}		= $galcenter_x;
$chart{side}{y}		= $galcenter_y;
$chart{side}{z}		= $galcenter_z;

my $edge		= 2*($chart{main}{size_x}+$chart{side}{size_x}) + $separator;
my %bottom = ();
$bottom{starclass}	= 2*($chart{main}{size_y}+$chart{front}{size_y}) + $separator;

$chart{beagle}{size_x}	= int($bottom{starclass}/6);
$chart{beagle}{size_y}	= $chart{beagle}{size_x};
$chart{beagle}{center_x}= $edge + $chart{beagle}{size_x};
$chart{beagle}{center_y}= $chart{beagle}{size_y}+1;
$chart{beagle}{zoom}	= 5;
$chart{beagle}{x}	= -1111.56;
$chart{beagle}{y}	= -134.219;
$chart{beagle}{z}	= 65269.8 - 1000;
$chart{beagle}{label}	= 'Beagle Point';

$chart{sagA}{size_x}	= int($bottom{starclass}/6);
$chart{sagA}{size_y}	= $chart{sagA}{size_x};
$chart{sagA}{center_x}	= $edge + $chart{sagA}{size_x};
$chart{sagA}{center_y}	= $chart{sagA}{size_y}*3+1;
$chart{sagA}{zoom}	= 5;
$chart{sagA}{x}		= 25.2188;
$chart{sagA}{y}		= -20.9062;
$chart{sagA}{z}		= 25900;
$chart{sagA}{label}	= 'Sagittarius A*';

$chart{colonia}{size_x}	= int($bottom{starclass}/6);
$chart{colonia}{size_y}	= $chart{colonia}{size_x};
$chart{colonia}{center_x}= $edge + $chart{colonia}{size_x};
$chart{colonia}{center_y}= $chart{colonia}{size_y}*5+1;
$chart{colonia}{zoom}	= 5;
$chart{colonia}{x}	= -9530.5;
$chart{colonia}{y}	= -910.281;
$chart{colonia}{z}	= 19808.1;
$chart{colonia}{label}	= 'Colonia';

$edge += 2*$chart{beagle}{size_x};

$chart{bubble}{size_x}	= int($bottom{starclass}/3);
$chart{bubble}{size_y}	= $chart{bubble}{size_x};
$chart{bubble}{center_x}= $edge + $chart{bubble}{size_x};
$chart{bubble}{center_y}= $bottom{starclass} - $chart{bubble}{size_y} - 1;
$chart{bubble}{zoom}	= 5;
$chart{bubble}{x}	= 0;
$chart{bubble}{y}	= 0;
$chart{bubble}{z}	= 0;
$chart{bubble}{label}	= 'The Bubble';

$chart{beag2}{size_x}	= int($bottom{starclass}/6);
$chart{beag2}{size_y}	= $chart{beag2}{size_x};
$chart{beag2}{center_x}	= $edge + $chart{beag2}{size_x};
$chart{beag2}{center_y}	= $chart{beag2}{size_y}+1;
$chart{beag2}{zoom}	= 10;
$chart{beag2}{x}	= -1111.56;
$chart{beag2}{y}	= -134.219;
$chart{beag2}{z}	= 65269.8 - 500;
$chart{beag2}{label}	= 'Beagle Point, Side';

$chart{hrdiagram}{size_x}	= int($bottom{starclass}/6);
$chart{hrdiagram}{size_y}	= $chart{hrdiagram}{size_x};
$chart{hrdiagram}{center_x}	= $edge + $chart{beag2}{size_x}*3;
$chart{hrdiagram}{center_y}	= $chart{hrdiagram}{size_y}+1;
$chart{hrdiagram}{zoom}		= 1;
$chart{hrdiagram}{x}		= 0;
$chart{hrdiagram}{y}		= 0;
$chart{hrdiagram}{z}		= 0;
$chart{hrdiagram}{label}	= 'Hertzsprung-Russell Diagram';

$edge += 2*$chart{bubble}{size_x};

my $mapimagesize_x	= $edge;
my $mapimagesize_y	= $bottom{starclass};
my %imagesize;
$imagesize{starclass}	= $mapimagesize_x.'x'.$mapimagesize_y;

$chart{main2}{size_x}	= int($galaxy_radius/$bigpixellightyears);
$chart{main2}{size_y}	= int($galaxy_radius/$bigpixellightyears);
$chart{main2}{center_x}	= $chart{main2}{size_x};
$chart{main2}{center_y}	= $chart{main2}{size_y};
$chart{main2}{zoom}	= 1;
$chart{main2}{x}	= $galcenter_x;
$chart{main2}{y}	= $galcenter_y;
$chart{main2}{z}	= $galcenter_z;
$chart{main2}{label}	= 'Milky Way scanned stars';

$chart{front2}{size_x}	= int($galaxy_radius/$bigpixellightyears);
$chart{front2}{size_y}	= int($galaxy_height/$bigpixellightyears);
$chart{front2}{center_x}= $chart{front2}{size_x};
$chart{front2}{center_y}= $chart{front2}{size_y} + $chart{main2}{size_y} + $chart{main2}{center_y};
$chart{front2}{zoom}	= 1;
$chart{front2}{x}	= $galcenter_x;
$chart{front2}{y}	= $galcenter_y;
$chart{front2}{z}	= $galcenter_z;

$chart{side2}{size_x}	= int($galaxy_height/$bigpixellightyears);
$chart{side2}{size_y}	= int($galaxy_radius/$bigpixellightyears);
$chart{side2}{center_x}	= $chart{side2}{size_x} + $chart{main2}{size_x} + $chart{main2}{center_x};
$chart{side2}{center_y}	= $chart{side2}{size_y};
$chart{side2}{zoom}	= 1;
$chart{side2}{x}	= $galcenter_x;
$chart{side2}{y}	= $galcenter_y;
$chart{side2}{z}	= $galcenter_z;

$chart{main3}{size_x}	= int($galaxy_radius/$hugepixellightyears);
$chart{main3}{size_y}	= int($galaxy_radius/$hugepixellightyears);
$chart{main3}{center_x}	= $chart{main3}{size_x};
$chart{main3}{center_y}	= $chart{main3}{size_y};
$chart{main3}{zoom}	= 1;
$chart{main3}{x}	= $galcenter_x;
$chart{main3}{y}	= $galcenter_y;
$chart{main3}{z}	= $galcenter_z;
$chart{main3}{label}	= 'Milky Way visited systems';

$chart{front3}{size_x}	= int($galaxy_radius/$hugepixellightyears);
$chart{front3}{size_y}	= int($galaxy_height/$hugepixellightyears);
$chart{front3}{center_x}= $chart{front3}{size_x};
$chart{front3}{center_y}= $chart{front3}{size_y} + $chart{main3}{size_y} + $chart{main3}{center_y};
$chart{front3}{zoom}	= 1;
$chart{front3}{x}	= $galcenter_x;
$chart{front3}{y}	= $galcenter_y;
$chart{front3}{z}	= $galcenter_z;

$chart{side3}{size_x}	= int($galaxy_height/$hugepixellightyears);
$chart{side3}{size_y}	= int($galaxy_radius/$hugepixellightyears);
$chart{side3}{center_x}	= $chart{side3}{size_x} + $chart{main3}{size_x} + $chart{main3}{center_x};
$chart{side3}{center_y}	= $chart{side3}{size_y};
$chart{side3}{zoom}	= 1;
$chart{side3}{x}	= $galcenter_x;
$chart{side3}{y}	= $galcenter_y;
$chart{side3}{z}	= $galcenter_z;

$bottom{systems}	= 2*($chart{main3}{size_y}+$chart{front3}{size_y}) + $separator;
$imagesize{systems}	= $bottom{systems}.'x'.$bottom{systems};

$bottom{averagebodies}	= 2*($chart{main3}{size_y}+$chart{front3}{size_y}) + $separator;
$imagesize{averagebodies}	= $bottom{averagebodies}.'x'.$bottom{averagebodies};

$bottom{starclass_large}	= 2*($chart{main3}{size_y}+$chart{front3}{size_y}) + $separator;
$imagesize{starclass_large}	= $bottom{starclass_large}.'x'.$bottom{starclass_large};

$bottom{remnants}	= 2*($chart{main}{size_y}+$chart{front}{size_y}) + 50;
$imagesize{remnants}	= $bottom{remnants}.'x'.$bottom{remnants};

$bottom{oddballs}	= $bottom{remnants};
$imagesize{oddballs}	= $imagesize{remnants};

$bottom{protostars}	= $bottom{remnants};
$imagesize{protostars}	= $imagesize{remnants};

$bottom{dwarfs}		= $bottom{remnants};
$imagesize{dwarfs}	= $imagesize{remnants};

$bottom{giantstars}	= $bottom{remnants};
$imagesize{giantstars}	= $imagesize{remnants};

$bottom{hugestars}	= $bottom{remnants};
$imagesize{hugestars}	= $imagesize{remnants};

$bottom{worlds}		= $bottom{remnants};
$imagesize{worlds}	= $imagesize{remnants};

$bottom{earthlikes}	= $bottom{remnants};
$imagesize{earthlikes}	= $imagesize{remnants};

$bottom{lifeworlds}	= $bottom{remnants};
$imagesize{lifeworlds}	= $imagesize{remnants};

$bottom{terraformables}	= $bottom{remnants};
$imagesize{terraformables}= $imagesize{remnants};

$bottom{planets}	= $bottom{remnants};
$imagesize{planets}	= $imagesize{remnants};

$bottom{heliumrich}	= $bottom{remnants};
$imagesize{heliumrich}	= $imagesize{remnants};

$bottom{bluestars}	= $bottom{remnants};
$imagesize{bluestars}	= $imagesize{remnants};

$bottom{agestars}	= $bottom{remnants};
$imagesize{agestars}	= $imagesize{remnants};

$bottom{neutrons}	= $bottom{remnants};
$imagesize{neutrons}	= $imagesize{remnants};

$bottom{wolfrayet}	= $bottom{remnants};
$imagesize{wolfrayet}	= $imagesize{remnants};
$bottom{wolfrayet1}	= $bottom{remnants};
$imagesize{wolfrayet1}	= $imagesize{remnants};
$bottom{wolfrayet2}	= $bottom{remnants};
$imagesize{wolfrayet2}	= $imagesize{remnants};
$bottom{wolfrayet3}	= $bottom{remnants};
$imagesize{wolfrayet3}	= $imagesize{remnants};
$bottom{wolfrayet4}	= $bottom{remnants};
$imagesize{wolfrayet4}	= $imagesize{remnants};

$bottom{whitedwarfs}	= $bottom{remnants};
$imagesize{whitedwarfs}	= $imagesize{remnants};

$bottom{blackholes}	= $bottom{remnants};
$imagesize{blackholes}	= $imagesize{remnants};

$bottom{boostables}	= $bottom{remnants};
$imagesize{boostables}	= $imagesize{remnants};

$bottom{averagestars}	= $bottom{systems};
$imagesize{averagestars}	= $imagesize{systems};

foreach my $maptype (keys %file) {
	if ($maptype =~ /^systems_/ || $maptype eq 'sector_overlay') {
		@{$mapviews{$maptype}} = @{$mapviews{systems}};
		$galaxy_chart{$maptype} = $galaxy_chart{systems};
		%{$mapdata{$maptype}} = %{$mapdata{systems}};
		$bottom{$maptype} = $bottom{systems};
		$imagesize{$maptype} = $imagesize{systems};
	}
}

$agelimit{'classmassG-C-6750'}{min} = 0;
$agelimit{'classmassG-C-6750'}{max} = 6750;
$agelimit{'classmassK-C-6750'}{min} = 0;
$agelimit{'classmassK-C-6750'}{max} = 6750;
$agelimit{'classmassG-C-12700'}{min} = 6750;
$agelimit{'classmassG-C-12700'}{max} = 12700;
$agelimit{'classmassK-C-12700'}{min} = 6750;
$agelimit{'classmassK-C-12700'}{max} = 12700;
$agelimit{'classmassG-C-old'}{min} = 12700;
$agelimit{'classmassG-C-old'}{max} = 99999999999;
$agelimit{'classmassK-C-old'}{min} = 12700;
$agelimit{'classmassK-C-old'}{max} = 99999999999;

my %classmassFound = ();
foreach my $l ('K','G','F') {
  foreach my $k ('','A'..'H') {
	my $add = '';
	$add = "-$k" if ($k);
	my $m = "classmass$l$add";
	next if (!$file{$m});

	$classmassFound{$m} = 1;

	$mapviews{$m}		= $mapviews{remnants};
	$galaxy_chart{$m}	= 'main';
	$mapdata{$m}{label}	= "Milky Way $l-class Main Stars by Mass Code$k";
	$mapdata{$m}{bodytype}	= 'systems';
	$mapdata{$m}{gamma}	= '1.2';
	$bottom{$m}		= $bottom{remnants};
	$imagesize{$m}		= $imagesize{remnants};
  }
}

foreach my $f (keys %file) {
	if ($f =~ /^(classmass([A-Z])-([A-Z]))(.+)$/) {
		my $basemap  = $1;
		my $class    = $2;
		my $masscode = $3;
		my $append   = $4;

		next if ($classmassFound{$f});

		$mapviews{$f}		= $mapviews{remnants};
		$galaxy_chart{$f}	= 'main';
		$mapdata{$f}{label}	= "Milky Way $class-class Main Stars by Mass Code-$masscode (Age $agelimit{$f}{min}-$agelimit{$f}{max})";
		$mapdata{$f}{bodytype}	= 'systems';
		$mapdata{$f}{gamma}	= '1.2';
		$bottom{$f}		= $bottom{remnants};
		$imagesize{$f}		= $imagesize{remnants};
	}
}


foreach my $l ('A'..'H') {
	my $m = "mass$l";
	$mapviews{$m}		= $mapviews{remnants};
	$galaxy_chart{$m}	= 'main';
	$mapdata{$m}{label}	= "Milky Way visited systems with Mass Code '$l'";
	$mapdata{$m}{bodytype}	= 'systems';
	$mapdata{$m}{gamma}	= '1.2';
	$bottom{$m}		= $bottom{remnants};
	$imagesize{$m}		= $imagesize{remnants};
}
$mapviews{masscode}		= $mapviews{remnants};
$galaxy_chart{masscode}		= 'main';
$mapdata{masscode}{label}	= 'Milky Way visited systems by Mass Code';
$mapdata{masscode}{bodytype}	= 'systems';
$bottom{masscode}		= $bottom{remnants};
$imagesize{masscode}		= $imagesize{remnants};

foreach my $l (0..4) {
	my $m = "age$l";
	my $start = commify(10**$l);
	my $end = commify((10**($l+1))-1);

	$mapviews{$m}		= $mapviews{remnants};
	$galaxy_chart{$m}	= 'main';
	$mapdata{$m}{label}	= "Milky Way scanned stars of ages $start to $end Million Years";
	$mapdata{$m}{bodytype}	= 'systems';
	$mapdata{$m}{gamma}	= '1.2';
	$bottom{$m}		= $bottom{remnants};
	$imagesize{$m}		= $imagesize{remnants};
}

my %radiuscolor = ();
@{$radiuscolor{0}}= (0,0,0);
@{$radiuscolor{10}}= (64,96,255);
@{$radiuscolor{20}}= (0,255,255);
@{$radiuscolor{50}}= (0,255,0);
@{$radiuscolor{100}}= (255,255,0);
@{$radiuscolor{500}}= (255,0,0);
@{$radiuscolor{1500}}= (255,0,255);

my %agecolor = ();
@{$agecolor{a0}} = (127,127,255);
@{$agecolor{a1}} = (0,255,255);
@{$agecolor{a2}} = (0,255,0);
@{$agecolor{a3}} = (255,255,0);
@{$agecolor{a4}} = (255,0,0);
@{$agecolor{a5}} = (255,0,255);

my %masscolor	= ();
@{$masscolor{A}}  = (255,0,0);
@{$masscolor{B}}  = (255,127,0);
@{$masscolor{C}}  = (255,255,0);
@{$masscolor{D}}  = (0,255,0);
@{$masscolor{E}}  = (0,255,255);
@{$masscolor{F}}  = (64,128,255);
@{$masscolor{G}}  = (255,0,255);
@{$masscolor{H}}  = (255,255,255);

my @TFCcolor = (200,224,224);

my %colorclass	= ();
@{$colorclass{O}}  = (0,50,255);
@{$colorclass{B}}  = (20,80,245);
@{$colorclass{A}}  = (50,100,235);
@{$colorclass{F}}  = (150,150,235);
@{$colorclass{G}}  = (210,215,195);
@{$colorclass{K}}  = (200,125,50);
@{$colorclass{M}}  = (200,0,0);
@{$colorclass{BD}} = (100,0,0);
@{$colorclass{NS}} = (0,200,255);
@{$colorclass{WD}} = (0,160,160);
@{$colorclass{TT}} = (150,50,0);
@{$colorclass{HE}} = (150,0,200);
@{$colorclass{BH}} = (0,255,0);
@{$colorclass{WR}} = (80,0,255);
@{$colorclass{C}}  = (255,255,0);
@{$colorclass{U}}  = (100,100,100);

# A (Blue-White super giant) Star   |
# B (Blue-White super giant) Star   |
# F (White super giant) Star        |
# G (White-Yellow super giant) Star |
# K (Yellow-Orange giant) Star      |
# M (Red giant) Star                |
# M (Red super giant) Star          |

@{$colorclass{S_B}}  = (64,96,255);
@{$colorclass{S_A}}  = (0,255,255);
@{$colorclass{S_F}}  = (255,255,255);
@{$colorclass{S_G}}  = (255,255,0);
@{$colorclass{G_K}}  = (255,160,0);
@{$colorclass{S_M}}  = (255,96,0);
@{$colorclass{G_M}}  = (255,0,0);

@{$colorclass{AW}}	= (255,0,0);
@{$colorclass{WW}}	= (80,80,255);
@{$colorclass{ELW}}	= (0,255,0);
@{$colorclass{WG}}	= (0,255,255);
@{$colorclass{GGAL}}	= (255,255,0);
@{$colorclass{GGWL}}	= (255,0,255);
@{$colorclass{GGHE}}	= (220,64,255);
@{$colorclass{GGHR}}	= (220,255,220);
@{$colorclass{ICY}}	= (100,100,200);
@{$colorclass{ROCKY}}	= (200,100,50);
@{$colorclass{ROCKICE}}	= (200,100,200);
@{$colorclass{HMC}}	= (150,100,100);
@{$colorclass{MR}}	= (200,50,100);
@{$colorclass{GG1}}	= (50,160,220);
@{$colorclass{GG2}}	= (200,200,200);
@{$colorclass{GG3}}	= (210,160,100);
@{$colorclass{GG4}}	= (220,160,80);
@{$colorclass{GG5}}	= (225,150,50);

my %colorclassoverride	= ();

@{$colorclassoverride{remnants}{NS}} = (0,255,255);
@{$colorclassoverride{remnants}{BH}} = (255,0,255);

@{$colorclassoverride{boostables}{NS}} = (0,255,255);
@{$colorclassoverride{boostables}{WD}} = (255,63,63);

@{$colorclassoverride{oddballs}{WR}} = (200,0,255);

@{$colorclassoverride{protostars}{TT}} = (255,0,0);
@{$colorclassoverride{protostars}{HE}} = (255,0,255);

@{$colorclassoverride{bluestars}{B}} = (111,95,255);
@{$colorclassoverride{bluestars}{O}} = (0,200,200);

@{$colorclassoverride{blackholes}{BH}} = (200,200,200);

@{$colorclassoverride{wolfrayet}{WR}}  = (255,128,255);
@{$colorclassoverride{wolfrayet1}{WR}} = (255,128,255);
@{$colorclassoverride{wolfrayet2}{WR}} = (255,128,255);
@{$colorclassoverride{wolfrayet3}{WR}} = (255,128,255);
@{$colorclassoverride{wolfrayet4}{WR}} = (255,128,255);

my %coord_limit = ();

$coord_limit{wolfrayet1}{y}{min}	= -2585;
$coord_limit{wolfrayet1}{y}{max}	= -1305;
$coord_limit{wolfrayet2}{y}{min}	= -1305;
$coord_limit{wolfrayet2}{y}{max}	= -25;
$coord_limit{wolfrayet3}{y}{min}	= -25;
$coord_limit{wolfrayet3}{y}{max}	= 1255;
$coord_limit{wolfrayet4}{y}{min}	= 1255;
$coord_limit{wolfrayet4}{y}{max}	= 2535;


my $max_heat            = 9;
my @heatcolor           = ();
@{$heatcolor[0]}        = (0,0,200);
#@{$heatcolor[1]}        = (63,63,255);
@{$heatcolor[1]}        = (0,0,255);
@{$heatcolor[2]}        = (63,127,255);
@{$heatcolor[3]}        = (0,255,255);
@{$heatcolor[4]}        = (0,255,0);
@{$heatcolor[5]}        = (255,255,0);
@{$heatcolor[6]}        = (255,255,255);
@{$heatcolor[7]}        = (255,0,0);
@{$heatcolor[8]}        = (255,0,127);
@{$heatcolor[9]}        = (255,0,255);
@{$heatcolor[10]}       = (127,127,127);	# Out of range
@{$heatcolor[11]}       = (0,0,0);		# Out of range

my %heatindex = ();
@{$heatindex{0}}	= (0,0,0);
@{$heatindex{1}}	= (0,0,128);
@{$heatindex{2}}	= (0,0,255);
@{$heatindex{5}}	= (63,63,255);
@{$heatindex{10}}	= (63,127,255);
@{$heatindex{20}}	= (0,255,255);
@{$heatindex{40}}	= (0,255,0);
@{$heatindex{60}}	= (255,255,0);
@{$heatindex{80}}	= (255,255,255);
@{$heatindex{100}}	= (255,0,0);
@{$heatindex{200}}	= (255,0,127);
@{$heatindex{500}}	= (255,0,255);
@{$heatindex{1000}}	= (128,0,255);
@{$heatindex{5000}}	= (128,0,0);
@{$heatindex{999999999}}= (128,0,255);

my %heatindex2 = ();
@{$heatindex2{0}}	= (0,0,0);
@{$heatindex2{1}}	= (0,96,255);
@{$heatindex2{2}}	= (0,160,255);
@{$heatindex2{3}}	= (0,255,255);
@{$heatindex2{4}}	= (0,255,0);
@{$heatindex2{5}}	= (255,255,0);
@{$heatindex2{10}}	= (255,255,255);
@{$heatindex2{20}}	= (255,0,0);
@{$heatindex2{30}}	= (255,0,127);
@{$heatindex2{40}}	= (255,0,255);
@{$heatindex2{50}}	= (128,0,255);
@{$heatindex2{100}}	= (128,0,0);
@{$heatindex2{999999999}}= (128,0,255);

my %averagestars_index = ();
@{$averagestars_index{0}}	= (0,0,0);
@{$averagestars_index{1}}	= (0,0,255);
@{$averagestars_index{2}}	= (0,255,255);
@{$averagestars_index{3}}	= (0,255,0);
@{$averagestars_index{4}}	= (255,255,0);
@{$averagestars_index{5}}	= (255,0,0);
@{$averagestars_index{6}}	= (255,0,255);
@{$averagestars_index{7}}	= (255,255,255);
@{$averagestars_index{8}}	= (128,0,255);
@{$averagestars_index{999999999}}= (128,0,255);

my %averagebodies_index = ();
@{$averagebodies_index{0}}	= (0,0,0);
@{$averagebodies_index{1}}	= (0,0,255);
@{$averagebodies_index{2}}	= (0,255,255);
@{$averagebodies_index{3}}	= (0,255,0);
@{$averagebodies_index{5}}	= (255,255,0);
@{$averagebodies_index{10}}	= (255,0,0);
@{$averagebodies_index{25}}	= (255,0,255);
@{$averagebodies_index{100}}	= (255,255,255);
@{$averagebodies_index{999999999}}	= (255,255,255);

my %brightest = ();
my %map = ();
my %image;
my %starsplotted = ();
my %classplotted = ();
my %systemsplotted = ();
my %heightgraph = ();
my %heightgraphP = ();
my %heightgraphA = ();
my %habitable = ();
my %hrdata = ();
my @sectorname = ();

my %bolometric_table = ();
my $boloclass = 'V';
open TXT, "<bolometrics.txt";
while (<TXT>) {
	chomp;
	if (/^\s*#/) {
		# do nothing, comment
	} elsif (/(\d+)\t([\d\-\.]+)/) {
		$bolometric_table{$boloclass}{$1} = $2;
	} elsif (/^:(\S+)/) {
		$boloclass = uc($1);
	}
}
close TXT;

my $name_ext = '';
$name_ext = '-skip' if ($0 =~ /\.skip/);
$name_ext = '-debug' if ($debug);
$name_ext = '-new' if ($0 =~ /\.new/);

my $tri_up = Image::Magick->new;
show_result($tri_up->Read("images/triangle-up.bmp"));
$tri_up->Resize(geometry=>'10x8');

my $tri_dn = Image::Magick->new;
show_result($tri_dn->Read("images/triangle-dn.bmp"));
$tri_dn->Resize(geometry=>'10x8');

my $shellscript = "$filepath/conversions$name_ext.sh";

print "Making: ".join(', ',keys %file)."\n";

print "Writing to $shellscript\n";

open TXT, ">$shellscript";

print TXT "#!/bin/bash\n";

print "START: ".epoch2date(time)."\n";
create_maps();
merge_exploration_maps();
print "FINISH: ".epoch2date(time)."\n";

close TXT;
print "EXEC $shellscript\n";
exec "/bin/bash $shellscript";
exit;

############################################################################
# $image->SetPixel( x => $x, y => $y, color => [($r,$g,$b)] );

sub no_kids {
	my $ref = shift;

	foreach my $kid (@$ref) {
		return 0 if (defined($kid));
	}

	return 1;
}

sub create_maps {

	print "Initializing...\n";

	my $compass = Image::Magick->new;
	show_result($compass->Read("images/thargoid-rose-hydra.bmp"));

	my $logo1 = Image::Magick->new;
	show_result($logo1->Read("images/edastro-550px.bmp"));

	my $logo2 = Image::Magick->new;
	show_result($logo2->Read("images/edastro-greyscale-550px.bmp"));

	foreach my $maptype (keys %file) {
		@{$map{$maptype}} = ();
	}

	my $map_string = '';
	foreach my $f (sort keys %file) {
		$map_string .= ", $f";
	}
	$map_string =~ s/^[\s,]+//;
	print "Creating maps: $map_string\n";

	my $chunk = 0;
	my $no_more_data = 0;

	my $sql_select = "select edsm_id,id64,name,coord_x,coord_y,coord_z,edsm_date date,eddn_updated from systems";

	my $chunk_seconds = 0;
	my $body_seconds = 0;

	print "\nPulling system ID list.\n";

	my $cols = columns_mysql('elite',"select ID from systems where coord_x is not null and coord_y is not null and coord_z is not null and boxelID is not null ".
				"$debug_and order by boxelID $debug_limit");

	print "READY: ".epoch2date(time)."\n";
	print "\nScanning star systems.\n";

	my $recentDate = epoch2date(time - (7*86400));

	my @kids = ();
	my @childpid = ();
	while (!$no_more_data || !no_kids(\@kids)) {

		last if ($no_more_data && no_kids(\@kids));

		foreach my $childNum (0..$maxChildren-1) {

			last if ($no_more_data && no_kids(\@kids));

			if ($kids[$childNum] && $childpid[$childNum]) {
				my $fh = $kids[$childNum];
				my @lines = <$fh>;
	
			        foreach my $line (@lines) {
			                chomp $line;
	
					print "$line\n" if ($fork_verbose);
	
					my ($action,$data) = split /\|/, $line, 2;
	
					if ($action eq 'map') {		# Multi-channel
						eval {
							my ($maptype,$chartmap,$x,$y,$n,$c) = split /,/, $data;
							${$map{$maptype}}[$x][$y][$n] += $c;
	
							$brightest{$maptype}{$chartmap} = ${$map{$maptype}}[$x][$y][$n] 
								if (${$map{$maptype}}[$x][$y][$n] > $brightest{$maptype}{$chartmap});
						};
	
					} elsif ($action eq 'map1') {	# Single channel
						eval {
							my ($maptype,$chartmap,$x,$y,$c) = split /,/, $data;
							${$map{$maptype}}[$x][$y] += $c;
	
							$brightest{$maptype}{$chartmap} = ${$map{$maptype}}[$x][$y] 
								if (${$map{$maptype}}[$x][$y] > $brightest{$maptype}{$chartmap});
						};
	
					} elsif ($action eq 'systemsplotted') {
						my ($maptype,$n) = split /,/, $data;
						$systemsplotted{$maptype} += $n;
	
					} elsif ($action eq 'starsplotted') {
						my ($maptype,$n) = split /,/, $data;
						$starsplotted{$maptype} += $n;
	
					} elsif ($action eq 'classplotted') {
						my ($maptype,$starClass,$n) = split /,/, $data;
						$classplotted{$maptype}{$starClass} += $n;
	
					} elsif ($action eq 'sectorname') {
						my ($x,$z,$n,$coord_y) = split /,/, $data;
						if (ref($sectorname[$x][$z]) ne 'HASH' or (!exists(${$sectorname[$x][$z]}{$n}) || $coord_y>${$sectorname[$x][$z]}{$n})) {
							${$sectorname[$x][$z]}{$n} = $coord_y;
						}
	
					} elsif ($action eq 'no_more_data') {
						$no_more_data = 1;
	
					} else {
						print "CHILD: $line\n";
					}
			        }

				waitpid $childpid[$childNum], 0;

				$kids[$childNum]	= undef;
				$childpid[$childNum]	= undef;
				
			}

			if (!$no_more_data) {
				if ($chunk && $chunk % 1000000 == 0) {
					print "(".commify($chunk).' - '.epoch2date(time).")\n";
					$chunk_seconds = 0;
					$body_seconds = 0;
				} elsif ($chunk && $chunk % 10000 == 0) {
					print ".";
				}
				$chunk += $chunk_size;
		
				my @ids = splice @{$$cols{ID}},0,$chunk_size;
				if (!@ids) {
					$no_more_data = 1;
					last;
				}
				my $chunk_select = "$sql_select where ID in (".join(',',@ids).")";
	
				# FORK START SETUP
	
				my $pid = open $kids[$childNum] => "-|";
				die "Failed to fork: $!" unless defined $pid;
	
				if ($pid) {
					# Parent.
	
					$childpid[$childNum] = $pid;
	
					#$0 =~ s/\s+\[(child|parent)\]\s+[\d,]+\s*$//is;
					$0 = $progname.' [parent] '.commify($chunk);
				} else {
					# Child.
	
					disconnect_all();	# Important to make our own DB connections as a child process.
					my %out = ();
	
					#$0 =~ s/\s+\[(child|parent)\]\s+[\d,]+\s*$//is;
					$0 = $progname.' [child] '.commify($chunk);
	
					sleep floor($childNum/3)+1 if ($childNum);
			
					# FORK END SETUP
	
					my $starttime = time;
					my $rows = rows_mysql('elite',$chunk_select);
					$chunk_seconds += time-$starttime;
			
					if (ref($rows) eq 'ARRAY') { 
						if (!@$rows) {
							$no_more_data = 1;
							last;
						}
						#$no_more_data = 1 if ($debug && $chunk+$chunk_size >= $debug_stars);
			
			
						my @id_list = ();
						foreach my $r (@$rows) {
							push @id_list, $$r{id64} if ($$r{id64});
						}
			
						my %systemBodies = ();
						my $starttime = time;
						get_bodies(\%systemBodies,@id_list);
						$body_seconds += time-$starttime;
			
						while (@$rows) {
				
							my $r = shift @$rows;
				
							if (!defined($$r{coord_x}) && !defined($$r{coord_y}) && !defined($$r{coord_z})) {
								print "$$r{id64} missing coordinates.\n" if ($debug);
								next;
							}
			
							if (0) {
								if ($$r{name} =~ /^\s*(([\w\-\.]+\s+)+)\w\w\-\w\s+\w/) {
									my $n = $1; 
									$n =~ s/\s+$//s;
				
									my $x = floor(($$r{coord_x}-$sectorcenter_x)/1280)+$sector_radius;
									my $z = floor(($$r{coord_z}-$sectorcenter_z)/1280)+$sector_radius;
				
									if ($x>=0 && $z>=0) {
										$n =~ s/\s+$//s;
										if (ref($sectorname[$x][$z]) ne 'HASH' or (!exists(${$sectorname[$x][$z]}{$n}) || $$r{coord_y}>${$sectorname[$x][$z]}{$n})) {
											${$sectorname[$x][$z]}{$n} = $$r{coord_y};
											$out{sectorname}{$x}{$z}{$n} = $$r{coord_y};
										}
									}
								}
							}
			
							eval {
								my @views = ();
								my $maptype = 'systems';
								if (ref($mapviews{$maptype}) eq 'ARRAY') { @views = @{$mapviews{$maptype}}; }
								
								my $ok = 0;
								my $ok_recent = 0;
				
								foreach my $chartmap (@views) {
									my $pixelscale = get_pixelscale($maptype,$chart{$chartmap}{zoom});
									my ($x,$y,$in_range) = get_image_coords($maptype,$chartmap,$r,$pixelscale,1,undef,$systemBodies{$$r{id64}});
			
									if ($in_range) {
										#${$map{$maptype}}[$x][$y] += $in_range;
										#$brightest{$maptype}{$chartmap} = ${$map{$maptype}}[$x][$y] if (${$map{$maptype}}[$x][$y] > $brightest{$maptype}{$chartmap});
										$out{map1}{$maptype}{$chartmap}{$x}{$y} += $in_range;
										$out{map1}{bodies}{$chartmap}{$x}{$y} += int((keys %{$systemBodies{$$r{id64}}}));
										$ok = 1;
	
										if (($$r{date} && $$r{date} gt $recentDate) || ($$r{eddn_updated} && $$r{eddn_updated} gt $recentDate)) {
											$out{map1}{recent}{$chartmap}{$x}{$y} += $in_range;
											$ok_recent = 1;
										}
	
										if (date2epoch($$r{date}) >= $FSSepoch) {
											my $stars = 0;
											foreach my $bodyID (keys %{$systemBodies{$$r{id64}}}) {
												my $bodyhash = $systemBodies{$$r{id64}}{$bodyID};
												$stars++ if ($$bodyhash{star});
											}
		
											$out{map1}{stars}{$chartmap}{$x}{$y} += $stars;
											$out{map1}{starssystems}{$chartmap}{$x}{$y} += 1;
	#print "$$r{edsm_date}, $stars\n";
										}
									}
								}
								#$systemsplotted{$maptype}++ if ($ok);
								$out{systemsplotted}{$maptype}++ if ($ok);
								$out{systemsplotted}{recent}++ if ($ok_recent);
	
							};
			
							if ($$r{name} =~ /\w+\s+[a-zA-Z]{2}\-[a-zA-Z]\s+([a-hA-H])/) {
								my $masscode = uc($1);
								
								foreach my $maptype ('masscode',"mass$masscode") {
									next if (!$file{$maptype} || $maptype =~ /^systems/ || $maptype eq 'averagestars');
									#$systemsplotted{$maptype}++;
									$out{systemsplotted}{$maptype}++;
			
									my @views = ();
									if (ref($mapviews{$maptype}) eq 'ARRAY') { @views = @{$mapviews{$maptype}}; }
						
									foreach my $chartmap (@views) {
										my $pixelscale = get_pixelscale($maptype,$chart{$chartmap}{zoom});
				
										my ($x,$y,$in_range) = get_image_coords($maptype,$chartmap,$r,$pixelscale,1);
					
										next if (!$in_range);
			
										for (my $n=0; $n<3; $n++) {
											eval {
												#${$map{$maptype}}[$x][$y][$n] += ${$masscolor{$masscode}}[$n];
												#$brightest{$maptype}{$chartmap} = ${$map{$maptype}}[$x][$y][$n]
												#	if (${$map{$maptype}}[$x][$y][$n]  > $brightest{$maptype}{$chartmap});
												$out{map}{$maptype}{$chartmap}{$x}{$y}{$n} += ${$masscolor{$masscode}}[$n];
											};
										}
									}
								}
			
								# See if this system qualifies for the class-mass-distribution maps
			
								my $primaryclass = '';
								my $primaryage = 0;
	
								foreach my $bodyID (keys %{$systemBodies{$$r{id64}}}) {
									if ($systemBodies{$$r{id64}}{$bodyID}{isPrimary}) {
										$primaryclass = $systemBodies{$$r{id64}}{$bodyID}{subType};
										$primaryage = $systemBodies{$$r{id64}}{$bodyID}{real_age};
									}
								}
			
								my @maplist = ('',"-$masscode");
	
								foreach my $age_submap (keys %agelimit) {
									if ($age_submap =~ /^classmass$primaryclass-$masscode(.+)/ && $primaryage>0 && $masscode && 
										$primaryage>=$agelimit{$age_submap}{min} && $primaryage<$agelimit{$age_submap}{max}) {
									
										push @maplist, "-$masscode$1";
									}
								}
			
								foreach my $subMap (@maplist) {
									my $maptype = "classmass$primaryclass$subMap";
			
									if ($file{"$maptype"}) {
										#$systemsplotted{$maptype}++;
										$out{systemsplotted}{$maptype}++;
				
										my @views = ();
										if (ref($mapviews{$maptype}) eq 'ARRAY') { @views = @{$mapviews{$maptype}}; }
							
										foreach my $chartmap (@views) {
											my $pixelscale = get_pixelscale($maptype,$chart{$chartmap}{zoom});
					
											my ($x,$y,$in_range) = get_image_coords($maptype,$chartmap,$r,$pixelscale,1);
						
											next if (!$in_range);
				
											for (my $n=0; $n<3; $n++) {
												eval {
													#${$map{$maptype}}[$x][$y][$n] += ${$masscolor{$masscode}}[$n];
													#$brightest{$maptype}{$chartmap} = ${$map{$maptype}}[$x][$y][$n]
													#	if (${$map{$maptype}}[$x][$y][$n]  > $brightest{$maptype}{$chartmap});
													$out{map}{$maptype}{$chartmap}{$x}{$y}{$n} += ${$masscolor{$masscode}}[$n];
												};
											}
										}
									}
								}
							}
			
			
							#my $loop = 0;
							my %loop = ();
			
							foreach my $bodyID (keys %{$systemBodies{$$r{id64}}}) {
			
								my $bodyhash = $systemBodies{$$r{id64}}{$bodyID};
	
								if ($$bodyhash{subType} && $colorclass{$$bodyhash{subType}}) {
									my $starAge = $$bodyhash{age};
			
									foreach my $maptype (keys %file) {
										my $starClass = $$bodyhash{subType};
	
										$starClass = $$bodyhash{starType} . '_' . $$bodyhash{subType} if ($maptype eq 'giantstars' && $$bodyhash{starType});
										next if ($maptype eq 'giantstars' && $$bodyhash{starType} !~ /^(G|S)$/);
			
										next if (!$file{$maptype} || $maptype =~ /^systems/ || $maptype =~ /^averagebodies/);
										next if ($maptype eq 'masscode' || $maptype =~ /^mass[A-Z]$/ || $maptype =~ /^classmass/ || $maptype eq 'averagestars');
										next if ($maptype =~ /^age/ && !defined($starAge));
										next if ($maptype eq 'hugestars' and $$bodyhash{rad}<10);
	
										if ($maptype =~ /terraformables/i) {
											next if ($$bodyhash{terraformingState} !~ /candidate/i);
										}
										
										if ($maptype =~ /^age(\d+)/) {
											next if ("a$1" ne $starAge);
										}
			
										if (ref($mapdata{$maptype}{bodies}) eq 'HASH' && $maptype !~ /terraformables/i) {
											next if (!$mapdata{$maptype}{bodies}{$starClass});
										}
						
										#$systemsplotted{$maptype}++ if (!$loop);
										#$starsplotted{$maptype}++;
										#$classplotted{$maptype}{$starClass}++;
	
										$out{systemsplotted}{$maptype}++ if (!$loop{$maptype});
										$out{starsplotted}{$maptype}++;
										$out{classplotted}{$maptype}{$starClass}++;
										$loop{$maptype}++;
					
										my @calc_colors = ();
										@calc_colors = star_radius_colors($$bodyhash{rad}) if ($maptype =~ /^hugestars$/);
										#warn "Radius=$$bodyhash{rad}: $calc_colors[0],$calc_colors[1],$calc_colors[2]\n";
	
										my @views = ();
										if (ref($mapviews{$maptype}) eq 'ARRAY') { @views = @{$mapviews{$maptype}}; }
							
										foreach my $chartmap (@views) {
			
											my $pixelscale = get_pixelscale($maptype,$chart{$chartmap}{zoom});
											#print "$starClass in $maptype.$chartmap\n" if ($maptype eq 'worlds');
						
											my ($x,$y,$in_range) = get_image_coords($maptype,$chartmap,$r,$pixelscale,0,$bodyhash);
			
											next if (!$in_range);
	
											for (my $n=0; $n<3; $n++) {
												my $ok = 0;
												eval {
													if ($maptype =~ /^hugestars$/) {
														$out{map}{$maptype}{$chartmap}{$x}{$y}{$n} += $calc_colors[$n];
													} elsif ($maptype =~ /terraformables/) {
														$out{map}{$maptype}{$chartmap}{$x}{$y}{$n} += $TFCcolor[$n];
													} elsif ($maptype =~ /^age/) {
														#${$map{$maptype}}[$x][$y][$n] += ${$agecolor{$starAge}}[$n];
														$out{map}{$maptype}{$chartmap}{$x}{$y}{$n} += ${$agecolor{$starAge}}[$n];
													} elsif (exists($colorclassoverride{$maptype}{$starClass}) && 
															ref($colorclassoverride{$maptype}{$starClass}) eq 'ARRAY') {
														#${$map{$maptype}}[$x][$y][$n] += ${$colorclassoverride{$maptype}{$starClass}}[$n];
														$out{map}{$maptype}{$chartmap}{$x}{$y}{$n} += ${$colorclassoverride{$maptype}{$starClass}}[$n];
													} else {
														#${$map{$maptype}}[$x][$y][$n] += ${$colorclass{$starClass}}[$n];
														$out{map}{$maptype}{$chartmap}{$x}{$y}{$n} += ${$colorclass{$starClass}}[$n];
													}
													$ok = 1;
												};
												if (!$ok && ($verbose || $debug)) {
													if (ref($colorclass{$starClass}) eq 'ARRAY') {
														print "$chartmap: $x,$y,$n -- id64=$$r{id64}, bodyID=$bodyID, ".
															"subType=$$bodyhash{subType}, colorclass=".join(',',@{$colorclass{$starClass}})."\n";
													} else {
														print "$chartmap: $x,$y,$n -- id64=$$r{id64}, bodyID=$bodyID, ".
															"subType=$$bodyhash{subType}, colorclass=$colorclass{$starClass}\n";
													}
												}
											}
										}
									}
								}
								#$loop++;
							}
						}
		
						# Sector names:
		
						if (0) {
							foreach my $x (keys %{$out{sectorname}}) {
								foreach my $z (keys %{$out{sectorname}{$x}}) {
									foreach my $n (keys %{$out{sectorname}{$x}{$z}}) {
										print "sectorname|$x,$z,$n,$out{sectorname}{$x}{$z}{$n}\n";
									}
								}
							}
						}
		
						# Maps:
		
						foreach my $maptype (keys %{$out{map}}) {
							foreach my $chartmap (keys %{$out{map}{$maptype}}) {
								foreach my $x (keys %{$out{map}{$maptype}{$chartmap}}) {
									foreach my $y (keys %{$out{map}{$maptype}{$chartmap}{$x}}) {
										foreach my $n (keys %{$out{map}{$maptype}{$chartmap}{$x}{$y}}) {
											print "map|$maptype,$chartmap,$x,$y,$n,$out{map}{$maptype}{$chartmap}{$x}{$y}{$n}\n";
										}
									}
								}
							}
						}
						foreach my $maptype (keys %{$out{map1}}) {
							foreach my $chartmap (keys %{$out{map1}{$maptype}}) {
								foreach my $x (keys %{$out{map1}{$maptype}{$chartmap}}) {
									foreach my $y (keys %{$out{map1}{$maptype}{$chartmap}{$x}}) {
										print "map1|$maptype,$chartmap,$x,$y,$out{map1}{$maptype}{$chartmap}{$x}{$y}\n";
									}
								}
							}
						}
	
						# Running totals:
	
						foreach my $maptype (keys %{$out{systemsplotted}}) {
							print "systemsplotted|$maptype,$out{systemsplotted}{$maptype}\n";
						}
						foreach my $maptype (keys %{$out{starsplotted}}) {
							print "starsplotted|$maptype,$out{starsplotted}{$maptype}\n";
						}
						foreach my $maptype (keys %{$out{classplotted}}) {
							foreach my $starClass (keys %{$out{classplotted}{$maptype}}) {
								print "classplotted|$maptype,$starClass,$out{classplotted}{$maptype}{$starClass}\n";
							}
						}
						
					} else {
						print "no_more_data\n";
					}
	
					exit if defined $pid;
				}
			}
		}


	}
	print "\n";


	print "Getting sector list...\n";
	open CSV, "<$scripts_path/sector-list-stable.csv";

	while (<CSV>) {
		chomp;
		my ($s,$c,$x,$y,$z,$x1,$y1,$z1,$x2,$y2,$z2,$bx,$bz,@extra) = parse_csv($_);
		# format: ${$sectorname[$x][$z]}{$n} = $$r{coord_y};
		#my $bx = floor(($x-$sectorcenter_x)/1280)+$sector_radius;
		#my $bz = floor(($z-$sectorcenter_z)/1280)+$sector_radius;
		${$sectorname[$bx][$bz]}{$s} = $y;
	}

	close CSV;




	print "Drawing...\n";
	

	####################
	# Heatmaps

	foreach my $maptype (sort { $bottom{$a} <=> $bottom{$b} || $a cmp $b } keys %file) {

		my $datatype = $maptype;
		$datatype = 'systems' if ($maptype =~ /^systems/ || $maptype eq 'averagestars' || $maptype eq 'averagebodies');
		$datatype = 'recent' if ($maptype eq 'systems_recent');

		my $v = 'False';
		$v = 'True' ;#if ($verbose);

		my $size = $imagesize{$maptype};

		my $depth = 8;
		my $colorspace = 'RGB';
		my $imagetype = 'TrueColor';

		if ($mapstyle{$maptype} eq 'mono') {
			$depth = 1;
			$colorspace = 'Gray';
			$imagetype = 'Bilevel';
		}

		$image{$maptype} = Image::Magick->new(
			size  => $size,
			type  => $imagetype,
			depth => $depth,
			verbose => $v
		);
		show_result($image{$maptype}->ReadImage('canvas:black')) if ($maptype ne 'sector_overlay');
		show_result($image{$maptype}->ReadImage('canvas:graya(1%, 0)')) if ($maptype eq 'sector_overlay');
		show_result($image{$maptype}->Quantize(colorspace=>$colorspace)) if ($depth != 1);
		show_result($image{$maptype}->Set(monochrome=>'True')) if ($depth == 1) ;

		#Draw pixels

		my @views = ();
		if (ref($mapviews{$maptype}) eq 'ARRAY') { @views = @{$mapviews{$maptype}}; }

		my $pixelscale = get_pixelscale($maptype);

		foreach my $chartmap (@views) {
			#my $pixelscale = get_pixelscale($maptype,$chart{$chartmap}{zoom});

			print "\nDRAWING $maptype/$chartmap ".sprintf("%u,%u - %u,%u",
				$chart{$chartmap}{center_x}-$chart{$chartmap}{size_x},$chart{$chartmap}{center_y}-$chart{$chartmap}{size_y},
				$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}-1,$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}-1)."\n";

			if (!$brightest{$datatype}{$chartmap}) {
				print "\t\tNo pixels found.\n";
				next;
			}

			my $brightestlog = 0;

			$brightestlog = scaled_log($brightest{$datatype}{$chartmap});
			print "Brightest overall pixel element: $brightest{$datatype}{$chartmap} ($brightestlog)\n";

			my @whitepixel = (1,1,1);
		
			for (my $x=$chart{$chartmap}{center_x}-$chart{$chartmap}{size_x}; $x<$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}-1; $x++) {
				print "." if ($x % 100 == 0);
	
				for (my $y=$chart{$chartmap}{center_y}-$chart{$chartmap}{size_y}; $y<$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}-1; $y++) {
		
					if ($maptype eq 'averagestars') {

						eval {
							if (${$map{stars}}[$x][$y] && ${$map{starssystems}}[$x][$y]) {

								my @pixels = indexed_heat_pixels('averagestars',$chartmap,${$map{stars}}[$x][$y]/${$map{starssystems}}[$x][$y]);

								$image{$maptype}->SetPixel( x => $x, y => $y, color => float_colors(@pixels) );
							}
						};

					} elsif ($maptype eq 'averagebodies') {

						eval {
							if (${$map{bodies}}[$x][$y] && ${$map{starssystems}}[$x][$y]) {

								my @pixels = indexed_heat_pixels('averagebodies',$chartmap,${$map{bodies}}[$x][$y]/${$map{starssystems}}[$x][$y]);

								$image{$maptype}->SetPixel( x => $x, y => $y, color => float_colors(@pixels) );
							}
						};

					} elsif ($maptype =~ /^systems/) {
						eval {
							if (${$map{$datatype}}[$x][$y]) {

								if ($mapstyle{$maptype} eq 'heatmap') {
									# Logarithmic Heat map:

									my @pixels = (0,0,0);
									if ($maptype =~ /heatmin/) {
										my $heatmin = $heatmin_minstars;
										$heatmin = $heatmin_minstars_2 if ($maptype =~ /heatmin2/);
										@pixels = heat_pixels($datatype,$chartmap,${$map{$datatype}}[$x][$y]-$heatmin)
											if (${$map{$datatype}}[$x][$y]>$heatmin);
									} else {
										@pixels = heat_pixels($datatype,$chartmap,${$map{$datatype}}[$x][$y]);
									}

									$image{$maptype}->SetPixel( x => $x, y => $y, color => float_colors(@pixels) );

								} elsif ($mapstyle{$maptype} eq "indexedheatmap") {

									# Indexed Heat map:

									my @pixels = indexed_heat_pixels($datatype,$chartmap,${$map{$datatype}}[$x][$y],$mapstyle{$maptype});
									$image{$maptype}->SetPixel( x => $x, y => $y, color => float_colors(@pixels) );

								} elsif ($mapstyle{$maptype} eq "indexedheatmap2") {

									# Indexed Heat map:

									my @pixels = indexed_heat_pixels($datatype,$chartmap,${$map{$datatype}}[$x][$y],$mapstyle{$maptype});
									$image{$maptype}->SetPixel( x => $x, y => $y, color => float_colors(@pixels) );

								} else {

									# Monochrome:

									$image{$maptype}->SetPixel( x => $x, y => $y, color=>\@whitepixel);
								}
							}
						};
					} else {
						my @pixel = ();
						my $brightest_element = 0;
			
						for (my $n=0; $n<3; $n++) {
							$brightest_element = ${$map{$datatype}}[$x][$y][$n] if (${$map{$datatype}}[$x][$y][$n] > $brightest_element);
						}
			
						if ($brightest_element) {
							my $local_brightestlog = scaled_log($brightest_element,$brightest{$datatype}{$chartmap});
							for (my $n=0; $n<3; $n++) {
			
								# Yes, we want floats from 0..1:
								$pixel[$n] = ($local_brightestlog / $brightestlog) * (${$map{$datatype}}[$x][$y][$n] / $brightest_element);
							}
							$image{$maptype}->SetPixel( x => $x, y => $y, color => \@pixel );
						}
						@{${$map{$datatype}}[$x][$y]} = ();
					}
				}
			}

			print "\n";
		}

		delete($map{$maptype});	# Not datatype, since we may need that in another pass

		# Gamma correction

		if ($mapdata{$maptype}{gamma}) {
			$image{$maptype}->Gamma( gamma=>$mapdata{$maptype}{gamma}, channel=>"all" );
		}

		foreach my $chartmap (@views) {
			#my $pixelscale = get_pixelscale($maptype);
	
			# Chart labels

			if ($chart{$chartmap}{label} || ($chartmap =~ /main/ && $mapdata{$maptype}{label})) {
				my $label = $chart{$chartmap}{label};
				$label = $mapdata{$maptype}{label} if ($chartmap =~ /main/ && $mapdata{$maptype}{label});
				$label .= " - Visited within 7 days" if ($maptype eq 'systems_recent');

				if ($chartmap ne 'hrdiagram') {
					$label .= " - 1px = ".($pixelscale/$chart{$chartmap}{zoom})." ly" if (!$halfsize{$maptype});
					$label .= " - 1px = ".(2*$pixelscale/$chart{$chartmap}{zoom})." ly" if ($halfsize{$maptype});
				}

				$label .= " (logarithmic heat map)" if ($maptype eq 'systems_heat');
				$label .= " (logarithmic heat map of highly explored areas, $heatmin_minstars+)" if ($maptype eq 'systems_heatmin');
				$label .= " (logarithmic heat map of highly explored areas, $heatmin_minstars_2+)" if ($maptype eq 'systems_heatmin2');
				$label .= " (indexed heat map)" if ($maptype eq 'systems_indexed' || $maptype eq 'systems_recent');

				if (exists($coord_limit{$maptype})) {
					$label .= " (Coordinate range: ";

					foreach my $c (qw(x y z)) {
						if (defined($coord_limit{$maptype}{$c}{min}) && defined($coord_limit{$maptype}{$c}{max})) {
							$label .= uc($c)."=[$coord_limit{$maptype}{$c}{min} to $coord_limit{$maptype}{$c}{max}]";
						}
					}

					$label .= ")";
				}

				my $pointsize = int(1000/$pixelscale);
				$image{$maptype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>$label,
					x=>($chart{$chartmap}{center_x}-$chart{$chartmap}{size_x}+$pointsize),
					y=>($chart{$chartmap}{center_y}-$chart{$chartmap}{size_y}+2*$pointsize));
			}

			# Chart borders

			if ($chartmap !~ /^(bubble)$/ && $chartmap !~ /^(main|front|side)\d*$/) {
				my $linewidth = int(125/$pixelscale);
				$linewidth = 1 if ($linewidth<1);

				my_rectangle($maptype,$chart{$chartmap}{center_x}-$chart{$chartmap}{size_x},$chart{$chartmap}{center_y}-$chart{$chartmap}{size_y},
					$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}-1,$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}-1,$linewidth,'#777');
			}

			# Chart scales

			if ($chartmap !~ /^(hrdiagram)$/ && $chartmap !~ /^(main|front|side)\d*$/) {
				
				my $pointsize = int(750/$pixelscale);
				$image{$maptype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>"1000 ly",
					x=>($chart{$chartmap}{center_x}-$chart{$chartmap}{size_x}+$pointsize),
					y=>($chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}-$pointsize*2));

				my $x = $chart{$chartmap}{center_x}-$chart{$chartmap}{size_x}+$pointsize;
				my $y = $chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}-$pointsize;

				my $x2 = $x + int(1000/($pixelscale/$chart{$chartmap}{zoom}));

				$image{$maptype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>1,
					points=>sprintf("%u,%u %u,%u",$x,$y,$x2,$y));
				$image{$maptype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>1,
					points=>sprintf("%u,%u %u,%u",$x,$y-$pointsize/3,$x,$y+$pointsize/3));
				$image{$maptype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>1,
					points=>sprintf("%u,%u %u,%u",$x2,$y-$pointsize/3,$x2,$y+$pointsize/3));
			}
		}

		$pixelscale = get_pixelscale($maptype);

		my $pointsize = int(1000/$pixelscale);

		my $additional = commify(int($starsplotted{$maptype}))." $mapdata{$maptype}{bodytype} in ".commify(int($systemsplotted{$datatype}))." systems";
		$additional = commify(int($systemsplotted{$datatype}))." systems" if ($mapdata{$maptype}{bodytype} eq 'systems');

		if ($maptype =~ /starclass|systems/) {
			$additional .= ' (approximately '.sprintf("%f",$systemsplotted{$datatype}*100/400000000000).'%% of galaxy)';
		}

		$image{$maptype}->Annotate(pointsize=>$pointsize,fill=>'white',x=>$pointsize,y=>$bottom{$maptype}-$pointsize*0.75,
				text=>"$author - ".epoch2date(time)." - $additional");

		if ($maptype !~ /heightgraph|sector_overlay/) {
			#my $pixelscale = get_pixelscale($maptype);

			# Galaxy rulers

			my $galradius = 43000/$pixelscale;
			my $galheight = 4000/$pixelscale;
			my $gal1k = 1000/$pixelscale;
			my $sideoffset = $galaxy_height/$pixelscale;
			my $chartmap  = $galaxy_chart{$maptype};

			my $thickness = int($pixellightyears/$pixelscale);
			$thickness = 1 if ($thickness < 1);

			my $fontPointSize = int(12*$pixellightyears/$pixelscale);

			my @typelist = ($maptype);
			#push @typelist, 'hugeview2' if ($maptype eq 'hugeview');
			#push @typelist, 'indexedheatmap' if ($maptype eq 'hugeview');

			foreach my $mtype (@typelist) {

				# Main ruler primary lines:
		
				$image{$mtype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>$thickness,
						 points=>sprintf("%u,%u %u,%u",
								$chart{$chartmap}{center_x}-$galradius,$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y},
								$chart{$chartmap}{center_x}+$galradius,$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}));
		
				$image{$mtype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>$thickness,
						 points=>sprintf("%u,%u %u,%u",
								$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x},$chart{$chartmap}{center_y}-$galradius,
								$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x},$chart{$chartmap}{center_y}+$galradius));

				# Side-view ruler primary lines:

				$image{$mtype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>$thickness,
						 points=>sprintf("%u,%u %u,%u",
								$chart{$chartmap}{center_x}-$galradius,$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}+$sideoffset-$galheight,
								$chart{$chartmap}{center_x}-$galradius,$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}+$sideoffset+$galheight));
		
				$image{$mtype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>$thickness,
						 points=>sprintf("%u,%u %u,%u",
								$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}+$sideoffset-$galheight,$chart{$chartmap}{center_y}-$galradius,
								$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}+$sideoffset+$galheight,$chart{$chartmap}{center_y}-$galradius));

		
				foreach my $i (0..43) {
					my $length = 150/$pixelscale;
					if ($i % 10 == 0) {
						$length = 300/$pixelscale;
					}
		
					my $rad = ($i*1000)/$pixelscale;


					# Main ruler cross-lines:
		
					$image{$mtype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>$thickness,
						points=>sprintf("%u,%u %u,%u",
								$chart{$chartmap}{center_x}-$rad,$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}-$length,
								$chart{$chartmap}{center_x}-$rad,$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}+$length));
	
					$image{$mtype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>$thickness,
						points=>sprintf("%u,%u %u,%u",
								$chart{$chartmap}{center_x}+$rad,$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}-$length,
								$chart{$chartmap}{center_x}+$rad,$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}+$length));
		
					$image{$mtype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>$thickness,
						points=>sprintf("%u,%u %u,%u",
								$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}-$length,$chart{$chartmap}{center_y}-$rad,
								$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}+$length,$chart{$chartmap}{center_y}-$rad));
		
					$image{$mtype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>$thickness,
						points=>sprintf("%u,%u %u,%u",
								$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}-$length,$chart{$chartmap}{center_y}+$rad,
								$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}+$length,$chart{$chartmap}{center_y}+$rad));

					# Side-view ruler cross-lines:

					if ($i<=4) {
						my $line_x = $chart{$chartmap}{center_x}-$galradius;
						my $line_y = $chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}+$sideoffset;

						$image{$mtype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>$thickness,
							points=>sprintf("%u,%u %u,%u",
								$line_x-$length,$line_y-$rad, 
								$line_x+$length,$line_y-$rad));
		
						$image{$mtype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>$thickness,
							points=>sprintf("%u,%u %u,%u",
								$line_x-$length,$line_y+$rad, 
								$line_x+$length,$line_y+$rad));
		
						my $line_x = $chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}+$sideoffset;
						my $line_y = $chart{$chartmap}{center_y}-$galradius;

						$image{$mtype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>$thickness,
							points=>sprintf("%u,%u %u,%u",
								$line_x-$rad,$line_y-$length, 
								$line_x-$rad,$line_y+$length));
		
						$image{$mtype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>$thickness,
							points=>sprintf("%u,%u %u,%u",
								$line_x+$rad,$line_y-$length, 
								$line_x+$rad,$line_y+$length));
		
					}

					# Main ruler labels:
		
					if ($i % 10 == 0) {
						my $adjust = 0-int($fontPointSize*0.85);
						my $yid = $i; $yid = "+$yid" if ($yid);
	
						$image{$mtype}->Annotate(pointsize=>$fontPointSize,fill=>'white',text=>"-$i",
							x=>$chart{$chartmap}{center_x}+$adjust-$rad,y=>$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}+$length*3.5) if ($i);
	
						$image{$mtype}->Annotate(pointsize=>$fontPointSize,fill=>'white',text=>$yid,
							x=>$chart{$chartmap}{center_x}+$adjust+$rad,y=>$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}+$length*3.5) if ($i);
		
						my $yi = $i+25;
						$adjust = int($fontPointSize/3)-1;
		
						$image{$mtype}->Annotate(pointsize=>$fontPointSize,fill=>'white',text=>"+$yi",
							x=>$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}+$length*2,y=>$chart{$chartmap}{center_y}+$adjust-$rad);
			
						$yi = 25-$i; $yid = $yi; $yid = "+$yid" if ($yid>0);
		
						$image{$mtype}->Annotate(pointsize=>$fontPointSize,fill=>'white',text=>$yid,
							x=>$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}+$length*2,y=>$chart{$chartmap}{center_y}+$adjust+$rad) 
								if ($yi != 25 || !$yi);
					}

				}
				my $length = 300/$pixelscale;
				my $rad = (25*1000)/$pixelscale;

				# Main ruler zeroes:
	
				$image{$mtype}->Annotate(pointsize=>$fontPointSize,fill=>'white',text=>'0',
					x=>$chart{$chartmap}{center_x}-$fontPointSize*0.25,
					y=>$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}+$length*3.5);
	
				$image{$mtype}->Annotate(pointsize=>$fontPointSize,fill=>'white',text=>'0',
					x=>$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}+$length*2,
					y=>$chart{$chartmap}{center_y}+$rad+$fontPointSize/3+1);


				# Side-view ruler zeroes, etc:

				# (left of lower edge view)

				$image{$mtype}->Annotate(pointsize=>$fontPointSize,fill=>'white',text=>'0',
					x=>$chart{$chartmap}{center_x}-$galradius-$length-$fontPointSize*1.2,
					y=>$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}+$sideoffset+$fontPointSize/3+1);
	
				$image{$mtype}->Annotate(pointsize=>$fontPointSize,fill=>'white',text=>'+4',
					x=>$chart{$chartmap}{center_x}-$galradius-$length-$fontPointSize*1.5,
					y=>$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}+$sideoffset+$fontPointSize/3+1-$gal1k*4);
	
				$image{$mtype}->Annotate(pointsize=>$fontPointSize,fill=>'white',text=>'-4',
					x=>$chart{$chartmap}{center_x}-$galradius-$length-$fontPointSize*1.4,
					y=>$chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}+$sideoffset+$fontPointSize/3+1+$gal1k*4);

	
				# (top of right edge view)

				$image{$mtype}->Annotate(pointsize=>$fontPointSize,fill=>'white',text=>'0',
					x=>$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}+$sideoffset-$fontPointSize*0.25,
					y=>$chart{$chartmap}{center_y}-$galradius-$length-$fontPointSize*0.5);
				
				$image{$mtype}->Annotate(pointsize=>$fontPointSize,fill=>'white',text=>'+4',
					x=>$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}+$sideoffset-$fontPointSize*0.85-$gal1k*4,
					y=>$chart{$chartmap}{center_y}-$galradius-$length-$fontPointSize*0.5);
				
				$image{$mtype}->Annotate(pointsize=>$fontPointSize,fill=>'white',text=>'-4',
					x=>$chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}+$sideoffset-$fontPointSize*0.75+$gal1k*4,
					y=>$chart{$chartmap}{center_y}-$galradius-$length-$fontPointSize*0.5);
				

				# Heat map scales:

				if ($mapstyle{$mtype} =~ /indexed|averagestars|averagebodies/) {
					my %index = %heatindex;
					%index = %averagestars_index if ($mapstyle{$mtype} eq 'averagestars');
					%index = %averagebodies_index if ($mapstyle{$mtype} eq 'averagebodies');
					%index = %heatindex2 if ($mapstyle{$mtype} eq 'indexedheatmap2');

					my $pointsize = int(550/$pixelscale);
					my $mainchart = $galaxy_chart{$maptype};
					my $x = $chart{$mainchart}{center_x}+$chart{$mainchart}{size_x};
					my $y = $chart{$mainchart}{center_y}+$chart{$mainchart}{size_y};
					my @list = sort {$a<=>$b} keys %index;

					#print "\tHeat index list: ".join(',',@list)."\n";

					$image{$mtype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Color Index:',x=>$x,y=>$y);
					for(my $i=0; $i<@list-1; $i++) {
						my $s = "$list[$i]";
						#$s .= "-".int($list[$i+1]-1) if ($list[$i+1]-1 > $list[$i] && $i+1<@list-1);
						$s .= "+" if ($i+1 >= @list-1);
		
						$y += int($pointsize*1.3);
						my $color = "rgb(".join(',',@{$index{$list[$i]}}).")";
						print "\t$list[$i] = $color\n";
		
						$image{$mtype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>$s,x=>$x+$pointsize*2,y=>$y+$pointsize-1);
		
						my_rectangle($mtype,$x+$pointsize*0.5,$y,$x+$pointsize*1.5-1,$y+$pointsize-1,1,'#777',$color);
					}
				}

				if ($mapstyle{$mtype} eq 'heatmap') {
					
					foreach my $chartmap (@views) {

						my ($x,$y);

						my $pixelscale = get_pixelscale($maptype,10);

						my $length = int(800/$pixelscale);
						my $width = int(40/$pixelscale);
						my $points = int(40/$pixelscale);

						my $scale_range = 0;
						my $n = 1;
						my @nums = (1);
						my $increment = 1;

						while ($n < $brightest{$datatype}{$chartmap} || $n<1000) {
							$scale_range ++;
							$n *= 10;
							push @nums, $n;
						}
						next if (!$scale_range);

						if ($scale_range<=8) {
							my @new = ();
							$increment = 0.5;
							$increment = 1/3 if ($scale_range<=5);

							foreach my $n (@nums) {
								push @new, $n/2 if ($n>1);
								push @new, $n/4 if ($n>1 && $scale_range<=5);
							}
							@nums = sort (@nums,@new);
						}

						@nums = sort {$a<=>$b} @nums;
						my $count = 0;

						while ($count<5 && $nums[int(@nums)-2] > $brightest{$datatype}{$chartmap}) {	# Remove highest if second highest is good enough.
							pop @nums;
							$scale_range = log10($nums[int(@nums)-1]);
							$count++;
						}

						if ($chartmap =~ /main/) {
							$x = $chart{$chartmap}{center_x}-$chart{$chartmap}{size_x}+$length/2;
							$y = $chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}-($length*1.5);
						}
						if ($chartmap =~ /front/) {
							$x = $chart{$chartmap}{center_x}+$chart{$chartmap}{size_x};
							$y = $chart{$chartmap}{center_y}-int($length/2);
						}
						if ($chartmap =~ /side/) {
							$x = $chart{$chartmap}{center_x}+$chart{$chartmap}{size_x}*2/3;
							$y = $chart{$chartmap}{center_y}+$chart{$chartmap}{size_y}-$length;
						}

						#print "Heat scale: $mtype/$chartmap $x,$y\n";

						my $penalty = 0;
						$penalty = $heatmin_minstars if ($mtype =~ /heatmin/);
						$penalty = $heatmin_minstars_2 if ($mtype =~ /heatmin2/);

						for (my $i=0;$i<$length;$i++) {
							my @pixels = heat_pixels($datatype,$chartmap,10**(($i/$length)*$scale_range), $brightest{$datatype}{$chartmap});
							my $color = colorFormatted(@pixels);

							$image{$mtype}->Draw( primitive=>'line', stroke=>$color, strokewidth=>1,
								points=>sprintf("%u,%u %u,%u",$x,$y+$length-$i,$x+$width,$y+$length-$i));
						}

						if ($penalty) {
							my $next = 0;
							my @new = ();
							foreach my $i (sort {$a<=>$b} @nums) {
								if ($i>=$penalty) {
									push @new, $i if ($i>$penalty);
									$next = $i if (!$next && $i>$penalty);
								}
							}

							push @nums, $penalty;
							push @nums, $penalty + 500 if ($penalty>=1000);
							push @nums, $penalty + 250 if ($penalty>=500);
							push @nums, $penalty + 100 if ($penalty>=200);
							push @nums, $penalty + 50 if ($penalty>=100);
							push @nums, $penalty + 25 if ($penalty>=50);
							push @nums, $penalty + 10 if ($penalty>=20);
							push @nums, $penalty + 5 if ($penalty>=10);
						}

						my $n = 0;
						foreach my $i (sort @nums) {
							last if (log10($i) > $scale_range);
							my $num = floor($i);

							if ($penalty) {
								if (!$n) {
									$num = $penalty;
								} elsif ($num <= $penalty) {
									next;
								}
							}

							#my $xx = $x + $n * ($length/$scale_range);
							#$n += $increment;
							$n++;

							my $yy = $y + $length - (log10($num-$penalty)*$length/$scale_range);


							my $s = $num;
							$s = sprintf("%.1fK",int($num*2/1000)/2) if ($num>=1000); 
							$s = sprintf("%.1fM",int($num*2/1000000)/2) if ($num>=1000000); 
							$s = sprintf("%.1fG",int($num*2/1000000000)/2) if ($num>=1000000000); 
							$s =~ s/\.0\d*//;

							$image{$mtype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>1,
								points=>sprintf("%u,%u %u,%u",$x+$width,$yy,$x+$width+$points/4,$yy));

							$image{$mtype}->Annotate(pointsize=>$points,fill=>'white',text=>$s,x=>$x+$width+$points/2,y=>$yy+$points/3);
						}
					}
				}
			}
	
			# Color Key:

			my $pointsize = int(550/$pixelscale);

			my $mainchart = $galaxy_chart{$maptype};

			my $x = $chart{$mainchart}{center_x}+$chart{$mainchart}{size_x};
			my $y = $chart{$mainchart}{center_y}+$chart{$mainchart}{size_y};

			$y -= int($pointsize*0.5);

			if ($maptype =~ /terraformables/) {
				# Skip it.

			} elsif ($maptype eq 'hugestars') {
				$y += int($pointsize*1.5);
				$pointsize *= 2;

				$image{$maptype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Solar Radius:',x=>$x,y=>$y);

				$x += $pointsize;

				my $width  = int($pointsize*1.5);
				my $height = $width;
				my @radii  = sort {$a<=>$b} keys %radiuscolor;

				for (my $n=1; $n<int(@radii); $n++) {

					$image{$maptype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>1,
							points=>sprintf("%u,%u %u,%u",$x+$pointsize*1.2,$y+($height*$n),$x+$pointsize*1.8,$y+($height*$n)));

					$image{$maptype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>$radii[$n],x=>$x+$pointsize*2,y=>$y+($height*$n)+$pointsize*0.3);

					if ($n+1 < @radii) { # not the last one

						for (my $i=0; $i<=$height; $i++) {

							my @pixels = star_radius_colors(($i/$height)*($radii[$n+1]-$radii[$n])+$radii[$n]);
							my $color = colorFormatted(@pixels);
					
							my_rectangle($maptype,$x,$y+$height*($n-0.25),$x+$width,$y+$height*$n,1,$color,$color) if ($n == 1 && !$i);
		
							$image{$maptype}->Draw( primitive=>'line', stroke=>$color, strokewidth=>1,
								points=>sprintf("%u,%u %u,%u",$x,$y+$height*$n+$i,$x+$width,$y+$height*$n+$i));
						}

					} elsif ($n == int(@radii)-1) {
						my $color = colorFormatted(star_radius_colors($radii[$n]));
						my_rectangle($maptype,$x,$y+$height*$n,$x+$width,$y+$height*($n+0.2),1,$color,$color);
					}
				}

			} elsif ($maptype eq 'masscode' || $maptype =~ /^mass[A-Z]$/ || $maptype =~ /^classmass[A-Z]+(\-[A-H])?/) {
				$image{$maptype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Color Influence:',x=>$x,y=>$y) if (@masskey);
				foreach my $ck (@masskey) {
					my ($code,$name) = split(/\|/,$ck);

					$y += int($pointsize*1.3);
					my $color = "rgb(".join(',',@{$masscolor{$code}}).")";
	
					$image{$maptype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>$name,x=>$x+$pointsize*2,y=>$y+$pointsize-1);
	
					my_rectangle($maptype,$x+$pointsize*0.5,$y,$x+$pointsize*1.5-1,$y+$pointsize-1,1,'#777',$color);
				}
			} elsif ($maptype =~ /^age/) {
				$image{$maptype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Color Influence:',x=>$x,y=>$y) if (@agekey);
				foreach my $ck (@agekey) {
					my ($code,$name) = split(/\|/,$ck);

					$y += int($pointsize*1.3);
					my $color = "rgb(".join(',',@{$agecolor{$code}}).")";
	
					$image{$maptype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>$name,x=>$x+$pointsize*2,y=>$y+$pointsize-1);
	
					my_rectangle($maptype,$x+$pointsize*0.5,$y,$x+$pointsize*1.5-1,$y+$pointsize-1,1,'#777',$color);
				}
			} elsif ($maptype !~ /systems|averagestars|averagebodies/) {
				$image{$maptype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Color Influence:',x=>$x,y=>$y) if (@colorkey);
				foreach my $ck (@colorkey) {
					my ($code,$name) = split(/\|/,$ck);
	
					next if (!$classplotted{$maptype}{$code});
	
					$y += int($pointsize*1.3);
					my $color = "rgb(".join(',',@{$colorclass{$code}}).")";
	
					if (exists($colorclassoverride{$maptype}{$code}) && ref($colorclassoverride{$maptype}{$code}) eq 'ARRAY') {
						$color = "rgb(".join(',',@{$colorclassoverride{$maptype}{$code}}).")";
					}
	
					$image{$maptype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>$name,x=>$x+$pointsize*2,y=>$y+$pointsize-1);
	
					my_rectangle($maptype,$x+$pointsize*0.5,$y,$x+$pointsize*1.5-1,$y+$pointsize-1,1,'#777',$color);
				}
			}
		}


		if ($maptype eq 'starclass') {
			#my $pixelscale = get_pixelscale($maptype);

			# HR labeling

			my $pointsize = int(600/$pixelscale);

			my ($x1,$x2,$y1,$y2);

			foreach my $i (0..$magnitude_scale) {
				if ($i % 5 == 0) {
					my $mag = $i-$magnitude_boost;
					my $y = $chart{hrdiagram}{center_y}+($hr_scale*$chart{hrdiagram}{size_y}*(($i/$magnitude_scale)-0.5));
					my $x = $chart{hrdiagram}{center_x}-(0.9*$chart{hrdiagram}{size_x});

					$image{$maptype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>1,
						points=>sprintf("%u,%u %u,%u",$x,$y,$x+$pointsize/2,$y));

					my $text = $mag; $text = "+$text" if ($mag > 0);
					$image{$maptype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>$text,x=>$x-$pointsize*2,y=>$y+$pointsize/2);

					if ($i == 0) { $x1 = $x; $y1 = $y }
					if ($i == $magnitude_scale) { $x2 = $x; $y2 = $y }
				}
			}
			
			$image{$maptype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>"Absolute Magnitude",x=>$x1,y=>$y1-$pointsize/2);

			$image{$maptype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>1,
				points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y2));
				

			my $end = int($temperature_scale/5000);
			foreach my $i (0..$end) {
				my $temp = $i*5000;

				my $x = $chart{hrdiagram}{center_x}+($hr_scale*$chart{hrdiagram}{size_x}*(0.5-($temp/$temperature_scale)));
				my $y = $chart{hrdiagram}{center_y}+(0.85*$chart{hrdiagram}{size_y});

				$image{$maptype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>1,
					points=>sprintf("%u,%u %u,%u",$x,$y,$x,$y-$pointsize/2));

				$image{$maptype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>$temp,x=>$x-$pointsize*0.5,y=>$y+$pointsize*1.2);

				if ($i == $end) { $x1 = $x; $y1 = $y }
				if ($i == 0) { $x2 = $x; $y2 = $y }
			}

			$image{$maptype}->Draw( primitive=>'line', stroke=>'white', strokewidth=>1,
				points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y2));

				
			$image{$maptype}->Annotate(pointsize=>$pointsize,fill=>'white',text=>"Surface Temperature (Kelvin)",x=>$x1,y=>$y1+$pointsize*2.5);
		};


		if ($maptype ne 'sector_overlay') {
			my $tmp_logo1 = undef;
			my $tmp_logo2 = undef;
	
			if ($mapstyle{$maptype} eq 'mono') {
				$tmp_logo1 = $logo2->Clone();
				$tmp_logo2 = $logo1->Clone();
			} else {
				$tmp_logo1 = $logo1->Clone();
			}
	
			my $logo_size = int(10000/$pixelscale);
			my $logo_x = int(1000/$pixelscale);
			my $logo_y = int(2000/$pixelscale);
	
			my $eval_ok = 0;
			eval {
				show_result($tmp_logo1->Resize(geometry=>$logo_size.'x'.$logo_size.'+0+0'));
				show_result($image{$maptype}->Composite(image=>$tmp_logo1, compose=>'over', gravity=>'northwest',x=>$logo_x,y=>$logo_y));
				$eval_ok = 1;
			};
			if (!$eval_ok) {
				print "$@\n";
				`/usr/bin/free -m`;
			}
	
			my $compass_x = $chart{$galaxy_chart{$maptype}}{center_x}+$chart{$galaxy_chart{$maptype}}{size_x}-int(11000/$pixelscale);
			my $compass_y = $chart{$galaxy_chart{$maptype}}{center_y}+$chart{$galaxy_chart{$maptype}}{size_y}-int(11000/$pixelscale);
			my $tmp_compass = $compass->Clone();
			show_result($tmp_compass->Resize(geometry=>$logo_size.'x'.$logo_size.'+0+0'));
			show_result($image{$maptype}->Composite(image=>$tmp_compass, compose=>'over', gravity=>'northwest',x=>$compass_x,y=>$compass_y));
		}

		my $fn = $file{$maptype};

		if ($override_PNG) {
			$fn =~ s/\.png$/\.$override_PNG/;
		}

		if ($maptype eq 'sector_overlay') {
			sector_overlay('sector_overlay','systems');
			#show_result($image{$maptype}->Transparent(color=>'rgb(0,0,2)'));
		}

		print "Writing $fn ($depth)\n";
		show_result($image{$maptype}->Set(depth => $depth));
		show_result($image{$maptype}->Set(gamma => 0.454545));
		show_result($image{$maptype}->Write( filename => $fn ));
		system('/home/bones/elite/half-size-image.pl',$fn) if ($halfsize{$maptype});
		push_images($fn);

		if (($maptype eq 'systems_heat' || $maptype eq 'systems_indexed') && (!$debug || !$skip_alternates)) {

			my $region_fn = $fn;
			$region_fn =~ s/heatmap/regions/;

			my_system("$convert -composite $fn $img_path/region-lines.bmp -gravity northwest $region_fn");
			push_images($region_fn);

			# Heatmap w/ sector overlay

			sector_overlay($maptype,'systems');

			#$fn = $file{$maptype};
			#$fn =~ s/(\.\S+)$/-sectors$1/;
			$fn =~ s/heatmap/sectors/;
	
			print "Writing $fn\n";
			show_result($image{$maptype}->Set(depth => 8));
			show_result($image{$maptype}->Set(gamma => 0.454545));
			show_result($image{$maptype}->Write( filename => $fn ));
			push_images($fn);
		}

		# Dump unneeded memory:
		delete($image{$maptype});
		delete($map{$maptype});
	}
}

sub sector_overlay {
	my $maptype = shift;
	my $mtype   = shift;
	my $ctype   = $galaxy_chart{$mtype};

	# Loop over sectors:

	print "Adding sector overlay ($maptype/$mtype/$ctype).\n";

	my $sectorpixellightyears = 1280/$hugepixellightyears;

	my %redsector = ();
	my $max_names = 9;

	my $black = '#010101';

	for (my $sz=0-$sector_radius; $sz<$sector_radius; $sz++) {
		for (my $sx=0-$sector_radius; $sx<$sector_radius; $sx++) {

			my @lines = ();
			my @extra = ();
			my %hash  = ();

			if (ref($sectorname[$sx+$sector_radius][$sz+$sector_radius]) eq 'HASH') {

				%hash = %{$sectorname[$sx+$sector_radius][$sz+$sector_radius]};

				foreach my $s (sort { $hash{$b} <=> $hash{$a} } keys %hash) {

					next if ($s =~ /^\s*\d+\s*$/);

					my $tmp = $s;
					$tmp = substr($s,0,17) if (length($s) > 17);

					if ($s =~ /NGC|sector|region|ghost|jupiter/i) {
						push @extra, $tmp;
					} else {
						push @lines, $tmp;
					}
				}
			}
if (0) { #(@lines || @extra) {
print "Lines: ".join(', ',@lines)."\n";
print "Extra: ".join(', ',@extra)."\n\n";
}

			push @lines, @extra;

			next if (!@lines);

			# Find rectangle corners:

			my $rx1 = int(($chart{$ctype}{center_x} + $sx*$sectorpixellightyears) - (($galcenter_x - $sectorcenter_x)/$hugepixellightyears));
			my $ry2 = int(($chart{$ctype}{center_y} - $sz*$sectorpixellightyears) + (($galcenter_z - $sectorcenter_z)/$hugepixellightyears));

			my $rx2 = int($rx1+$sectorpixellightyears);
			my $ry1 = int($ry2-$sectorpixellightyears);

			my_rectangle($maptype,$rx1,$ry1,$rx2,$ry2,1,'#777');
			#print "Sector: $rx1,$ry1 -> $rx2,$ry2\n";

			if (@lines > $max_names) {
				$redsector{$rx1}{$ry2} = 1;
			}

			my $psize = 13;

			my $i=0;
			foreach my $s (@lines) {
				$image{$maptype}->Annotate(pointsize=>$psize,fill=>$black,stroke=>$black,strokewidth=>3,text=>$s,x=>$rx1+15,y=>$ry1+($psize*1.5)+$psize*$i-3);
				$i++;
				last if ($i >= $max_names);
			}

			$i=0;
			foreach my $s (@lines) {
				if (defined($hash{$s})) {
				 show_result($image{$maptype}->Composite(image=>$tri_up, compose=>'over', x=>$rx1+4,y=>$ry1+($psize*0.5)+$psize*$i+1)) if ($hash{$s} > $sectorcenter_y);
				 show_result($image{$maptype}->Composite(image=>$tri_dn, compose=>'over', x=>$rx1+4,y=>$ry1+($psize*0.5)+$psize*$i+1)) if ($hash{$s} <= $sectorcenter_y);
				}

				$image{$maptype}->Annotate(pointsize=>$psize,fill=>'white',text=>$s,x=>$rx1+15,y=>$ry1+($psize*1.5)+$psize*$i-3);
				$i++;
				last if ($i >= $max_names);
			}
		}
	}

	foreach my $rx1 (sort keys %redsector) {
		foreach my $ry2 (sort keys %{$redsector{$rx1}}) {

			my $rx2 = int($rx1+$sectorpixellightyears);
			my $ry1 = int($ry2-$sectorpixellightyears);

			my_rectangle($maptype,$rx1,$ry1,$rx2,$ry2,1,'#f53');
		}
	}
}


sub push_images {
	my $fn = shift;

	my $png = $fn;
	$png =~ s/\.(png|gif|bmp|jpg|tga|tif)$/.png/;

	my $thumb = $fn;
	$thumb =~ s/\.(png|gif|bmp|jpg|tga|tif)$/-thumb.jpg/;

	my $jpg = $fn;
	$jpg =~ s/\.(png|gif|bmp|jpg|tga|tif)$/.jpg/;

	print "Copying $fn, $jpg, $thumb...\n";

	my $jpg_size = '1200x1200';
	$jpg_size = '600x600' if ($fn =~ /visited/);

	my_system("$convert $fn -verbose $png") if ($override_PNG || ($png ne $fn && $fn !~ /\.gif$/));
	my_system("$convert $fn -verbose -resize $jpg_size -gamma 1.3 $jpg");
	my_system("$convert $fn -verbose -resize 200x200 -gamma 1.3 $thumb");
	my_system("$scp $png $jpg $thumb $remote_server") if (!$debug && $allow_scp);
	print "\n";
}

sub scaled_log {
	my $n = shift;
	my $brightest = shift;
	return 0 if (!$n);

	if ($brightest) {
		return log10($n)+(log10($brightest)*$logarithm_scale);
	} else {
		return log10($n)*(1+$logarithm_scale);
	}
}

sub colorFormatted {
        return "rgb(".join(',',@_).")";
}
sub scaledColor {
        my ($r,$g,$b,$scale) = @_;

        $r = int((255-$r)*$scale+$r);
        $g = int((255-$g)*$scale+$g);
        $b = int((255-$b)*$scale+$b);

        return colorFormatted($r,$g,$b);
}
sub scaledColorRange {
        my ($r,$g,$b,$scale,$tr,$tg,$tb) = @_;

        $r = int(($tr-$r)*$scale+$r);
        $g = int(($tg-$g)*$scale+$g);
        $b = int(($tb-$b)*$scale+$b);

        return ($r,$g,$b);
}
sub float_colors {
        my $r = shift(@_)/255;
        my $g = shift(@_)/255;
        my $b = shift(@_)/255;
        return [($r,$g,$b)];
}

sub my_rectangle {
	my ($maptype,$x1,$y1,$x2,$y2,$strokewidth,$color,$fill) = @_;

	#print "Rectangle for $maptype: $x1,$y1,$x2,$y2,$strokewidth,$color\n";

	return if ($x1 < 0 || $y1 < 0 || $x2 < 0 || $y2 < 0);

	if ($fill) {

		$image{$maptype}->Draw( primitive=>'rectangle', stroke=>$color, fill=>$fill, strokewidth=>$strokewidth,
			points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y2));

	} else {

		$image{$maptype}->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
			points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y1));
	
		$image{$maptype}->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
			points=>sprintf("%u,%u %u,%u",$x1,$y2,$x2,$y2));
	
		$image{$maptype}->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
			points=>sprintf("%u,%u %u,%u",$x1,$y1,$x1,$y2));
	
		$image{$maptype}->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
			points=>sprintf("%u,%u %u,%u",$x2,$y1,$x2,$y2));
	}
}

sub get_pixelscale {
	my $maptype	= shift;
	my $zoom	= shift;
	my $pixelscale = $pixellightyears;
	#$pixelscale = $bigpixellightyears if ($maptype eq 'starclass_large');
	$pixelscale = $hugepixellightyears if ($maptype eq 'starclass_large');
	$pixelscale = $hugepixellightyears if ($maptype =~ /systems/ || $maptype eq 'averagestars' || $maptype eq 'averagebodies');

	$pixelscale /= $zoom if ($zoom);

	return $pixelscale;
}

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}

sub my_system {
	my $string = shift;
	print "# $string\n";
	print TXT "$string\n";
}

############################################################################


sub get_image_coords {
	my ($maptype,$chartmap,$r,$pixelscale,$system_data,$bodyhash,$sysbodyhash) = @_;

	my ($x,$y,$in_range) = (0,0,0);

	if ($system_data) {
		if ($chartmap =~ /front/) {
			$x = int( $chart{$chartmap}{center_x} + (($$r{coord_x} - $chart{$chartmap}{x}) / $pixelscale));
			$y = int( $chart{$chartmap}{center_y} - (($$r{coord_y} - $chart{$chartmap}{y}) / $pixelscale));
		} elsif ($chartmap =~ /side/) {
			$x = int( $chart{$chartmap}{center_x} - (($$r{coord_y} - $chart{$chartmap}{y}) / $pixelscale));
			$y = int( $chart{$chartmap}{center_y} - (($$r{coord_z} - $chart{$chartmap}{z}) / $pixelscale));
		} else {
			$x = int( $chart{$chartmap}{center_x} + (($$r{coord_x} - $chart{$chartmap}{x}) / $pixelscale));
			$y = int( $chart{$chartmap}{center_y} - (($$r{coord_z} - $chart{$chartmap}{z}) / $pixelscale));
		}
	} else {
		if ($chartmap eq 'hrdiagram') {

			my $x_percent = 1-($$bodyhash{surfaceTemperature}/$temperature_scale);
			my $y_percent = ($$bodyhash{absoluteMagnitude}+$magnitude_boost)/$magnitude_scale;

			if ($y_percent >= 0 && $y_percent <= 1 && $x_percent >= 0 && $x_percent <= 1) {

				$x = int( $chart{$chartmap}{center_x} + (($x_percent-0.5)*$chart{$chartmap}{size_x}*$hr_scale));
				$y = int( $chart{$chartmap}{center_y} + (($y_percent-0.5)*$chart{$chartmap}{size_y}*$hr_scale));
			}
		} elsif ($chartmap =~ /front/) {
			$x = int( $chart{$chartmap}{center_x} + (($$r{coord_x} - $chart{$chartmap}{x}) / $pixelscale));
			$y = int( $chart{$chartmap}{center_y} - (($$r{coord_y} - $chart{$chartmap}{y}) / $pixelscale));
		} elsif ($chartmap =~ /side/) {
			$x = int( $chart{$chartmap}{center_x} - (($$r{coord_y} - $chart{$chartmap}{y}) / $pixelscale));
			$y = int( $chart{$chartmap}{center_y} - (($$r{coord_z} - $chart{$chartmap}{z}) / $pixelscale));
		} elsif ($chartmap eq 'beag2') {
			$x = int( $chart{$chartmap}{center_x} + (($$r{coord_z} - $chart{$chartmap}{z}) / $pixelscale));
			$y = int( $chart{$chartmap}{center_y} + (($$r{coord_y} - $chart{$chartmap}{y}) / $pixelscale));
		} else {
			$x = int( $chart{$chartmap}{center_x} + (($$r{coord_x} - $chart{$chartmap}{x}) / $pixelscale));
			$y = int( $chart{$chartmap}{center_y} - (($$r{coord_z} - $chart{$chartmap}{z}) / $pixelscale));
		}
	}

	if (	   $x >= $chart{$chartmap}{center_x} - $chart{$chartmap}{size_x}
		&& $x <  $chart{$chartmap}{center_x} + $chart{$chartmap}{size_x}
		&& $y >= $chart{$chartmap}{center_y} - $chart{$chartmap}{size_y}
		&& $y <  $chart{$chartmap}{center_y} + $chart{$chartmap}{size_y} ) {
		$in_range = 1;
	}

	$in_range = 1 if ($in_range);

	if (exists($coord_limit{$maptype})) {
		foreach my $c (qw(x y z)) {
			if (exists($coord_limit{$maptype}{$c})) {
				$in_range = 0 if ($$r{"coord_$c"} < $coord_limit{$maptype}{$c}{min} || $$r{"coord_$c"} >= $coord_limit{$maptype}{$c}{max});
			}
		}
	}

	if ($in_range && $maptype eq 'hugeviewDW2') {
		my $DW2_start  = date2epoch("2019-01-13 00:00:00");
		my $DW2_finish = date2epoch("2019-06-14 00:00:00");
		my $epoch = date2epoch($$r{date});

		$in_range = 0 if ($epoch<$DW2_start or $epoch>=$DW2_finish);

		my $hasStars = 0;
		my $hasPlanets = 0;

		foreach my $bodyID (keys %$sysbodyhash) {
			my $body = $$sysbodyhash{$bodyID};
			my $updated = $$body{updateTime};
			my $discovered = $$body{discoveryDate};

			$hasStars = 1 if ($$body{star} && ( ($updated>=$DW2_start && $updated<$DW2_finish) || ($discovered>=$DW2_start && $discovered<$DW2_finish) ));
			$hasPlanets = 1 if (!$$body{star} && ( ($updated>=$DW2_start && $updated<$DW2_finish) || ($discovered>=$DW2_start && $discovered<$DW2_finish) ));
		}
		$in_range += ($hasStars*0.25) + ($hasPlanets*0.25);
	}

	return ($x,$y,$in_range);
}

sub bolometric_correction {
	my $luminosity_class = uc(shift);
	my $surface_temp = shift;

	$luminosity_class =~ s/[^IV]//g;

	$luminosity_class = 'III' if ($luminosity_class eq 'IV');
	$luminosity_class = 'V' if ($luminosity_class =~ /VI/);

	return undef if ($luminosity_class !~ /^(I|III|V)$/);

	my @list = sort keys %{$bolometric_table{$luminosity_class}};

	my $upper_index = 0;
	my $lower_index = int(@list)-1;

	for (my $i=0; $i<@list; $i++) {
		my $temp = $list[$i];

		$upper_index = $i if ($temp > $surface_temp && $i < $upper_index);
		$lower_index = $i if ($temp < $surface_temp && $i > $lower_index);
	}

	if ($upper_index == $lower_index) {
		return $bolometric_table{$luminosity_class}{$list[$upper_index]};
	} else {
		my $range = $list[$upper_index] - $list[$lower_index];
		if ($range) {
			my $scaled_temp = ($surface_temp - $list[$lower_index]) / $range;
			return ($bolometric_table{$luminosity_class}{$list[$upper_index]} - $bolometric_table{$luminosity_class}{$list[$lower_index]})*$scaled_temp 
				+ $bolometric_table{$luminosity_class}{$list[$lower_index]};
		} else {
			return $bolometric_table{$luminosity_class}{$list[$lower_index]};
		}
	}
}

############################################################################

sub get_bodies {
	my $body_ref = shift;
	return if (!@_);

	my $id_list = '('.join(',',@_).')';

	my @rows  = ();
	my $retry = 0;
	my $ok = undef;

	while (!$ok && $retry < 3) {
		$ok = eval {
			@rows = db_mysql('elite',"select starID as localID,isPrimary,systemId,systemId64,subType,solarRadius,absoluteMagnitude,luminosity,".
					"surfaceTemperature,age,updateTime,discoveryDate from stars where systemId64 in $id_list");
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
			$$r{real_age} = $$r{age};
			$$r{age} = 'a'.int(log10($$r{age}));
		} else {
			$$r{age} = undef;
		}

		print "! Unused star type: [".$$r{systemId64}."] $subType\n" if (!$class);

		$$r{subType} = $class;
		$$r{star} = 1;

		$$r{rad} = $$r{solarRadius};
		delete($$r{solarRadius});

		%{$$body_ref{$$r{systemId64}}{$$r{localID}}} = %$r;
	}


	@rows  = ();
	$retry = 0;
	$ok = undef;

	while (!$ok && $retry < 3) {
		$ok = eval {
			@rows = db_mysql('elite',"select planetID as localID,systemId64,subType,gravity,surfaceTemperature,earthMasses,updateTime,".
					"terraformingState,discoveryDate from planets where systemId64 in $id_list");
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

		%{$$body_ref{$$r{systemId64}}{$$r{localID}+$id_add}} = %$r;
	}
}

sub truncate_num {
	my $n = shift;
	$n =~ s/\..*$//;
	return int($n);
}

sub star_radius_colors {
	my ($radius) = @_;
	return index_colors('','',$radius,\%radiuscolor);
}

sub indexed_heat_pixels {
	my ($maptype,$chartmap,$heat,$indextype) = @_;
	my $index = \%heatindex;

	if ($maptype eq 'averagestars') {
		$index = \%averagestars_index;
	}
	if ($maptype eq 'averagebodies') {
		$index = \%averagebodies_index;
	}
	if ($maptype eq 'systems_recent' || $indextype eq 'indexedheatmap2') {
		return index_colors($maptype,$chartmap,$heat,\%heatindex2,1);
	}
	return index_colors($maptype,$chartmap,$heat,$index);
}

sub index_colors {
	my ($maptype,$chartmap,$heat,$index,$floor1) = @_;
	return (0,0,0) if (!$heat || !$index);

	my $bottomIndex = 0;
	my $topIndex = 0;

	my @list = sort {$a<=>$b} keys %$index;
	my $maxVal = $list[@list-1];

	my $i = 0;
	while ($i<@list-1 && !$topIndex) {
		$i++;
		if ($heat >= $list[$i] && $heat < $list[$i+1]) {
			$bottomIndex = $i; $topIndex = $i+1;
			last;
		}
	}
	return (@{$$index{$maxVal}}) if ($heat >= $maxVal);
	return (0,0,0) if (!$topIndex || $list[$topIndex]-$list[$bottomIndex] == 0);

	my $decimal = ($heat-$list[$bottomIndex]) / ($list[$topIndex]-$list[$bottomIndex]);

	$decimal = 0.99 if ($floor1 && $heat<1);

	my @bottomColor = @{$$index{$list[$bottomIndex]}};
	my @topColor    = @{$$index{$list[$topIndex]}};

	my @pixels = scaledColorRange($bottomColor[0],$bottomColor[1],$bottomColor[2],$decimal,$topColor[0],$topColor[1],$topColor[2]);

	return @pixels;
}

sub heat_pixels {
	my ($maptype,$chartmap,$heat,$brightest) = @_;

	return (0,0,0) if (!$heat || $heat < 0);

	my $brightestlog = scaled_log($brightest{$maptype}{$chartmap});
	$brightestlog = scaled_log($brightest) if ($brightest && !$brightestlog);

	#print "WARN: $maptype,$chartmap($heat) / brightest_log = $brightestlog ($brightest{$maptype}{$chartmap})\n" if (!$brightestlog);

	return (128,128,128) if (!$brightestlog);

	my $local_log = scaled_log($heat,$brightest{$maptype}{$chartmap});
	my $brightness = ($local_log/$brightestlog)*$max_heat;

	my $integer = int($brightness);
	my $decimal = 0;
	$decimal = $brightness - $integer if ($integer);

	if ($integer >= $max_heat) {
		$integer = $max_heat;
		$decimal = 0;
	}
	my $bottomset = $integer;
	my $topset = $integer+1;

	my @pixels = scaledColorRange($heatcolor[$bottomset][0],$heatcolor[$bottomset][1],$heatcolor[$bottomset][2],
		$decimal,$heatcolor[$topset][0],$heatcolor[$topset][1],$heatcolor[$topset][2]);

	return @pixels;
}

sub show_result {
	foreach (@_) {
		warn "WARN: $_\n" if ($_);
	}
}

sub merge_exploration_maps {
	return if (!$file{systems_heatmin2});

	my $fn = $file{systems_heatmin2};

	if ($override_PNG) {
		$fn =~ s/\.png$/\.$override_PNG/;
	}

	print "Making merged heavy-exploration map\n";

	my $image = Image::Magick->new;
	show_result($image->Read($fn));
	
	my $mask = Image::Magick->new;
	show_result($mask->Read("/home/bones/elite/images/blackout-mask.bmp"));

	show_result($image->Composite(image=>$mask, compose=>'multiply', x=>0,y=>0));
	
	my $map = Image::Magick->new;
	show_result($map->Read("/home/bones/www/elite/exploration-saturation-map.bmp"));
	
	$mask = Image::Magick->new;
	show_result($mask->Read("/home/bones/elite/images/blackout-mask2.bmp"));
	show_result($map->Composite(image=>$mask, compose=>'multiply', x=>0,y=>0));
	show_result($map->Composite(image=>$image, compose=>'screen', x=>0,y=>0));

	my $pointsize = int(1200/$hugepixellightyears);
	$map->Annotate(pointsize=>$pointsize,fill=>'white',x=>$pointsize,y=>$pointsize,gravity=>'southwest',text=>"$author - ".epoch2date(time));
	$map->Annotate(pointsize=>$pointsize,fill=>'white',x=>$pointsize,y=>$pointsize*1.5,gravity=>'northwest',text=>"Heavy Exploration Area Map");
	$map->Annotate(pointsize=>$pointsize,fill=>'white',x=>$pointsize,y=>$pointsize*3.5,gravity=>'northwest',text=>"Red/White = Significantly explored relative to star density");
	$map->Annotate(pointsize=>$pointsize,fill=>'white',x=>$pointsize,y=>$pointsize*4.8,gravity=>'northwest',text=>"Yellow/Green = Popular exploration paths, highly explored");

	my $outfile = "$filepath/heavily-explored-map.bmp";
	show_result($map->Write( filename => $outfile));
	push_images($outfile);
	print "Merged heavy-exploration map complete\n";
}

############################################################################





