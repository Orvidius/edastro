#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10 ssh_options scp_options);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch parse_csv make_csv);

use Image::Magick;
use POSIX qw(floor);

############################################################################

show_queries(0);
my $one = 1;

my $debug		= 0;
my $skip_all		= 0;
my $verbose		= 0;
my $allow_scp		= 1;

my $id_add		= 10**12;

my $chunk_size		= 5000;
my $debug_stars		= 20000;
my $debug_limit		= '';
my $debug_and		= '';
#   $debug_limit		= "order by coord_z limit $debug_stars" if ($debug);
#   $debug_limit		= " and (name like 'Eol Prou %' or name like 'Oevasy %' or name like 'Eos Chrea %')" if ($debug);
#   $debug_limit		= " and abs(coord_x)<1000 and abs(coord_y)<1000 and abs(coord_z)<1000 order by id64 limit $debug_stars" if ($debug);
#   $debug_limit		= " and abs(coord_x)<1000 and abs(coord_y)<1000 and abs(coord_z)<1000 order by id64" if ($debug);
   $debug_limit		= "and edsm_date>'2020-12-01 00:00:00' and edsm_date<'2021-03-01 00:00:00' limit $debug_stars" if ($debug);
#   $debug_and		= "and edsm_date>'2020-12-01 00:00:00'" if ($debug);

my $current_absolute_day = floor(time/86400);

my $remote_server	= 'www@services:/www/edastro.com/mapcharts/';
my $filepath		= "/home/bones/www/elite";
my $img_path		= "/home/bones/elite/images";

$filepath .= '/test'    if ($0 =~ /\.pl\.\S+/);
$allow_scp = 0          if ($0 =~ /\.pl\.\S+/);

my $author		= "By CMDR Orvidius (edastro.com) - CC BY-NC-SA 3.0 - Data from EDDN & EDSM";

my $outputgroup		= 0;
$outputgroup = $ARGV[0] if ($ARGV[0]);

my %gfile = ();

my @hrtypes		= qw(hrdiag hrlog hrlog2);
my @perdaytypes		= qw(bodiespersystem newfinds);
#my @zonetypes		= qw(habitablezone terraformable);
my @zonetypes		= qw();


$gfile{gasgiant_helium}= "$filepath/gasgiant_helium.png";

if (!$skip_all) {

$gfile{bodymetals}= "$filepath/bodymetals.png";
$gfile{sectormassmetals}= "$filepath/sectormassmetals.png";
$gfile{bodiespersystem}	= "$filepath/bodiespersystem.png";
$gfile{newfinds}	= "$filepath/newfinds.png";
$gfile{heightgraph2W}	= "$filepath/heightgraph2W.png";
$gfile{radialdistance}	= "$filepath/radialdistance.png";
$gfile{systemmassplanets}	= "$filepath/systemmassplanets.png";
$gfile{systemstarplanets}	= "$filepath/systemstarplanets.png";
$gfile{heightgraph2}	= "$filepath/heightgraph2.png";
$gfile{hrdiag}		= "$filepath/hr-diag.png";
$gfile{hrlog}		= "$filepath/hr-log.png";
$gfile{hrlog2}		= "$filepath/hr-log2.png";
$gfile{heightgraph}	= "$filepath/heightgraph.png";
$gfile{heightgraphP}	= "$filepath/heightgraph-planets.png";
$gfile{heightgraphA}	= "$filepath/heightgraph-age.png";
$gfile{sectormassplanets}	= "$filepath/sectormassplanets.png";
$gfile{sectorstarplanets}	= "$filepath/sectorstarplanets.png";
$gfile{habitablezone}	= "$filepath/habitablezone.png";
#$gfile{terraformable}	= "$filepath/terraformable.png";
}

my $radialdistance_granularity	= 500;
my $heightgraph_granularity	= 50;

my $heightgraph2_scale		= 10;
my $heightgraph2_nodes		= 101;
my $heightgraph2_widenodes	= 301;

my $heightgraph_maxheight	= 5000;

my $pi			= 3.1415926535;

#my $ssh			= '/usr/bin/ssh';
#my $scp			= '/usr/bin/scp -P222';
my $ssh                 = '/usr/bin/ssh'.ssh_options();
my $scp                 = '/usr/bin/scp'.scp_options();
my $convert		= '/usr/bin/convert';

my $logarithm_scale	= 0.2;	# Fraction to add to logarithms based on the largest (hottest) pixel element

my $galaxy_radius	= 45000;
my $galaxy_height	= 6000;

my $sector_radius	= 35;
my $sector_height	= 4;

my $galcenter_x		= 0;
my $galcenter_y		= -25;
my $galcenter_z		= 25000;

my $sgrA_x		= 25.2188;
my $sgrA_y		= -20.9062;
my $sgrA_z		= 25900;

my $sectorcenter_x	= -65;
my $sectorcenter_y	= -25;
my $sectorcenter_z	= 25815;

my %chart = ();

my $magnitude_boost	= 25;
my $magnitude_scale	= 55;
my $temperature_scale	= 35000;
my $hr_scale		= 1.6;

my $gg_he_steps		= 10;

my @colorkey = ("O|O Star","B|B Star","A|A Star","F|F Star","G|G Star","K|K Star","M|M Star","BD|Brown Dwarf","TT|T Tauri Star","HE|Herbig Ae/Be",
		"C|Carbon Star","WR|Wolf-Rayet","WD|White Dwarf","NS|Neutron Star","BH|Black Hole","U|Unidentified",
		"GG1|Class I Gas Giant","GG2|Class II Gas Giant","GG3|Class III Gas Giant","GG4|Class IV Gas Giant","GG5|Class V Gas Giant",
		"WW|Water World","ELW|Earth-Like World","AW|Ammonia World","GGAL|Gas Giant, Ammonia Life","GGWL|Gas Giant, Water Life",
		"GGHE|Helium Gas Giant","GGHR|Helium-rich Gas Giant","WG|Water Giant","HMC|High Metal Content World","ROCKY|Rocky Body","ICY|Icy Body",
		"ROCKICE|Rocky Icy Body","MR|Metal-Rich Body");

my @masskey = ("A|A-Mass System","B|B-Mass System","C|C-Mass System","D|D-Mass System","E|E-Mass System","F|F-Mass System","G|G-Mass System","H|H-Mass System");

my @agekey = ("a0|0-9 Million Years","a1|10-99 Million Years","a2|100-999 Million Years","a3|1-9 Billion Years","a4|10-99 Billion Years","a5|100-999 Billion Years");

my %starcodes = ('O'=>1, 'B'=>1, 'A'=>1, 'F'=>1, 'G'=>1, 'K'=>1, 'M'=>1, 'BD'=>1, 'TT'=>1, 'HE'=>1, 'C'=>1, 'WR'=>1, 'WD'=>1, 'NS'=>1, 'BH'=>1, 'U'=>1);
my %planetcodes = ('GG1'=>1, 'GG2'=>1, 'GG3'=>1, 'GG4'=>1, 'GG5'=>1, 'ELW'=>1, 'AW'=>1, 'WW'=>1, 'GGAL'=>1, 'GGWL'=>1, 'GGHE'=>1, 'GGHR'=>1, 
			'WG'=>1,'HMC'=>1,'MR'=>1,'ICY'=>1,'ROCKY'=>1,'ROCKICE'=>1);

my @planetcodelist = (qw(ICY ROCKICE ROCKY HMC MR WW AW ELW WG GG1 GG2 GG3 GG4 GG5 GGAL GGWL GGHE GGHR));
my @starcodelist = (qw(O B A F G K M BD TT HE C WR WD NS BH));


my %colorkeynames = ();
foreach my $type (@colorkey) {
	my ($key, $name) = split /\|/, $type, 2;
	$colorkeynames{$key} = $name;
}

my %mapdata = ();
%{$mapdata{starclass}{bodies}}	= %starcodes;
%{$mapdata{planets}{bodies}}	= %planetcodes;

my %starTypeKey = {};
$starTypeKey{''} = 'Main Sequence';
$starTypeKey{'D'} = 'Dwarf';
$starTypeKey{'G'} = 'Giant';
$starTypeKey{'S'} = 'Supergiant';

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
@{$masscolor{F}}  = (10,50,255);
@{$masscolor{G}}  = (255,0,255);
@{$masscolor{H}}  = (255,255,255);

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
@{$colorclass{BH}} = (255,0,255);
@{$colorclass{WR}} = (0,255,0);
@{$colorclass{C}}  = (255,255,0);
@{$colorclass{U}}  = (100,100,100);

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

my %gasgiantscolor	 = ();
@{$gasgiantscolor{GG1}}  = (255,0,0);
@{$gasgiantscolor{GG2}}  = (192,64,0);
@{$gasgiantscolor{GG3}}  = (128,128,0);
@{$gasgiantscolor{GG4}}  = (64,192,0);
@{$gasgiantscolor{GG5}}  = (0,255,0);
@{$gasgiantscolor{WG}}   = (0,0,255);
@{$gasgiantscolor{GGWL}} = (0,255,255);
@{$gasgiantscolor{GGAL}} = (255,255,0);
@{$gasgiantscolor{GGHE}} = (128,0,240);
@{$gasgiantscolor{GGHR}} = (255,0,255);
my @gasgiantstypes = qw(GG1 GG2 GG3 GG4 GG5 WG GGWL GGAL GGHE GGHR);

my %gasgiantskey = ();
$gasgiantskey{GG1}	= 'Class 1 Gas Giant';
$gasgiantskey{GG2}	= 'Class 2 Gas Giant';
$gasgiantskey{GG3}	= 'Class 3 Gas Giant';
$gasgiantskey{GG4}	= 'Class 4 Gas Giant';
$gasgiantskey{GG5}	= 'Class 5 Gas Giant';
$gasgiantskey{WG}	= 'Water Giant';
$gasgiantskey{GGWL}	= 'Gas Giant w/ Water Life';
$gasgiantskey{GGAL}	= 'Gas Giant w/ Ammonia Life';
$gasgiantskey{GGHE}	= 'Helium Gas Giant';
$gasgiantskey{GGHR}	= 'Helium-Rich Gas Giant';

my %sectormassplanetscolor	= ();
@{$sectormassplanetscolor{AW}}	= (255,255,0);
@{$sectormassplanetscolor{WW}}	= (80,80,255);
@{$sectormassplanetscolor{TWW}}	= (0,255,255);
@{$sectormassplanetscolor{ELW}}	= (0,255,0);
@{$sectormassplanetscolor{TFC}}	= (255,0,255);
my @sectormassplanetstypes = qw(WW TWW TFC ELW AW);

my %sectormassplanetskey = ();
$sectormassplanetskey{AW} = 'Ammonia world';
$sectormassplanetskey{WW} = 'Water world (non terraformable)';
$sectormassplanetskey{TWW} = 'Terraformable Water world';
$sectormassplanetskey{ELW} = 'Earth-like world';
$sectormassplanetskey{TFC} = 'Terraformable (other)';

my %sectormassmetalscolor      = ();
@{$sectormassmetalscolor{H}}   = (255,255,0);
@{$sectormassmetalscolor{He}}   = (0,255,255);
@{$sectormassmetalscolor{Metals}} = (255,0,0);
my @sectormassmetalstypes = qw(H He Metals);

my %sectormassmetalskey = ();
$sectormassmetalskey{H} = 'Hydrogen';
$sectormassmetalskey{He} = 'Helium';
$sectormassmetalskey{Metals} = 'Metals';

my %bodymetalscolor = %sectormassmetalscolor;
my @bodymetalstypes = qw(H He Metals);
my %bodymetalskey   = %sectormassmetalskey;

my @gg_he_planets	= qw(GG1 GG2 GG3 GG4 GG5 WG GGWL GGAL GGHE GGHR);

my @gasgiant_percentages = ();
foreach (0..$gg_he_steps) {
	push @gasgiant_percentages, $_*(100/$gg_he_steps);
}

my $max_heat            = 9;
my @heatcolor           = ();
@{$heatcolor[0]}        = (0,0,200);
@{$heatcolor[1]}        = (63,63,255);
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


my %image;
my %radialdistance = ();
my %heightgraph = ();
my %heightgraph2 = ();
my %heightgraph2W = ();
my %heightgraphP = ();
my %heightgraphA = ();
my %habitable = ();
my %hrdata = ();
my %highest_value = ();
my %sectormetals = ();
my %sectorplanets = ();
my %systemplanets = ();
my %system_vector = ();
my %system_seen = ();
my %chunk_seen = ();
my %datedata = ();
my %bodymetals = ();
my %gg_he = ();

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

open TXT, ">$filepath/graph-conversions.sh";
print TXT "#!/bin/bash\n";

my $logo1 = Image::Magick->new;
$logo1->Read("images/edastro-550px.png");

print "START: ".epoch2date(time)."\n";
scan_systems();
get_daily_numbers();
draw_graphs();
print "FINISH: ".epoch2date(time)."\n";

close TXT;
exec "/bin/bash $filepath/graph-conversions.sh";
exit;

############################################################################
# $image->SetPixel( x => $x, y => $y, color => [($r,$g,$b)] );


sub scan_systems {

	return if ($skip_all && ($gfile{bodiespersystem} || $gfile{newfinds}) && int(keys(%gfile))<=2);

	print "Initializing...\n";

	my $chunk = 0;
	my $no_more_data = 0;

	my $sql_select = "select edsm_id,id64,name,coord_x,coord_y,coord_z,edsm_date date,mainStarType type from systems";

	my $chunk_seconds = 0;
	my $body_seconds = 0;

	print "\nPulling system ID list.\n";


#	my $cols = columns_mysql('elite',"select ID from systems where coord_x is not null and coord_y is not null and coord_z is not null and deletionState=0 ".
#				"$debug_and order by edsm_date $debug_limit");

	my $cols = columns_mysql('elite',"select ID from systems where deletionState=0 $debug_limit");

	die "Could not retrieve ID list.\n" if (ref($$cols{ID}) ne 'ARRAY');

	print "READY: ".epoch2date(time)."\n";
	print "\nScanning star systems (".int(@{$$cols{ID}}).").\n";

	my $last_date = '';

	while (!$no_more_data) {

		if ($chunk && $chunk % 1000000 == 0) {
			print "(".commify($chunk).' - '.epoch2date(time).", $chunk_seconds chunk sec, $body_seconds body sec)\n";
			$chunk_seconds = 0;
			$body_seconds = 0;
		} elsif ($chunk && $chunk % 10000 == 0) {
			print ".";
		}

		my @ids = splice @{$$cols{ID}},0,$chunk_size;
		last if (!@ids);
		#my $chunk_select = "$sql_select where ID in (".join(',',@ids).") order by edsm_date";
		my $chunk_select = "$sql_select where ID in (".join(',',@ids).")";

		my $starttime = time;
		my $rows = rows_mysql('elite',$chunk_select);
		$chunk_seconds += time-$starttime;

		%chunk_seen = ();

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

				graph_system($r);

				$$r{date} =~ /(\d{4}-\d{2}-\d{2})/;
				my $day = $1;

				if ($day && $day ne $last_date) {
					compress_graph_dates($last_date);
					$last_date = $day;
				}

				#if (!defined($$r{coord_x}) && !defined($$r{coord_y}) && !defined($$r{coord_z})) {
				#	print "$$r{id64} missing coordinates.\n" if ($debug);
				#	next;
				#}

				my $loop = 0;

				foreach my $bodyID (keys %{$systemBodies{$$r{id64}}}) {

					my $bodyhash = $systemBodies{$$r{id64}}{$bodyID};
			
					if ($$bodyhash{subType} && $colorclass{$$bodyhash{subType}}) {

						graph_body($r,$bodyhash);

					}
	
					$loop++;

				}
			}
		} else {
			$no_more_data = 1;
			last;
		}
	
		$chunk += $chunk_size;
	}
	print "\n";
	compress_graph_dates($last_date);
}

sub push_images {
	my $fn = shift;

	my $thumb = $fn;
	$thumb =~ s/\.(png|gif)$/-thumb.jpg/;

	my $jpg = $fn;
	$jpg =~ s/\.(png|gif)$/.jpg/;

	print "Copying $fn, $jpg, $thumb...\n";

	my $jpg_size = '1200x1200';
	$jpg_size = '600x600' if ($fn =~ /visited/);

	my_system("$convert $fn -verbose -resize $jpg_size -gamma 1.3 $jpg");
	my_system("$convert $fn -verbose -resize 200x200 -gamma 1.3 $thumb");
	my_system("$scp $fn $jpg $thumb $remote_server") if (!$debug && $allow_scp);
	my_system("~bones/elite/cdn-purge.sh $fn");
	my_system("~bones/elite/cdn-purge.sh $jpg");
	my_system("~bones/elite/cdn-purge.sh $thumb");
	print "\n";
}

sub compress_graph_dates {
	my $date = shift;
	return if (!$date);

	if (0) {

		$date = "$date 12:00:00";
		my $days_ago = $current_absolute_day - floor(date2epoch($date)/86400);
	
		return if ($datedata{perday}{$days_ago}{systems} || !exists($datedata{perday}{$days_ago}{sys}));
	
		$datedata{perday}{$days_ago}{systems} = int(keys %{$datedata{perday}{$days_ago}{sys}});
	
		#print "DAYS_AGO=$days_ago ($date): ".int(keys %{$datedata{perday}{$days_ago}{sys}})." ($datedata{perday}{$days_ago}{stars}/$datedata{perday}{$days_ago}{planets})\n";
	
		delete($datedata{perday}{$days_ago}{sys});
	}
}

sub get_daily_numbers {
	my $test_prepend = '';
	$test_prepend = 'test-' if ($debug);
	open CSV, "</home/bones/elite/scripts/${test_prepend}discovery-dates.csv";
	my $header = <CSV>;

	while (my $line = <CSV>) {
		chomp $line;
		my @v = parse_csv($line);
		my $date = "$v[0] 12:00:00";

		my $days_ago = $current_absolute_day - floor(date2epoch($date)/86400);

		$datedata{perday}{$days_ago}{systems} = $v[1];
		$datedata{perday}{$days_ago}{stars}   = $v[2];
		$datedata{perday}{$days_ago}{planets} = $v[3];
	}

	close CSV;
}

sub graph_system {
	my $r = shift;

	# Exploration history per day:

	if (0 && $$r{date}) {
		my $system_absolute_day = floor(date2epoch($$r{date})/86400);
		my $s_days_ago = $current_absolute_day - $system_absolute_day;
		#$datedata{perday}{$s_days_ago}{sys}{$$r{id64}} = 1 if ($$r{id64}); # Probably will see it more than once
		$datedata{perday}{$s_days_ago}{systems}++; # Tally if seeing once.
	}
}

sub graph_body {
	my ($r, $body) = @_;

	# Exploration history per day:

	#print "$$r{id64}, $$r{date}, $$body{updateTime}\n";

	if (0 && $$body{updateTime}) {
		
		my $body_absolute_day = floor(date2epoch($$body{updateTime})/86400);
		my $b_days_ago = $current_absolute_day - $body_absolute_day;

		$datedata{perday}{$b_days_ago}{stars}++ if ($$body{star});	# Iterates each body only once, so tally
		$datedata{perday}{$b_days_ago}{planets}++ if (!$$body{star});
	}


	# Gas-Giant Helium distribution

	if ($gfile{gasgiant_helium} && ($$body{subType} =~ /^GG/ || $$body{subType} eq 'WG') && defined($$body{he})) {
		my $step = int($$body{he}/$gg_he_steps)*$gg_he_steps;
		$gg_he{$step}{$$body{subType}}++;
		$gg_he{total}{$step}++;
		my $val = 1000*($gg_he{$step}{$$body{subType}} / $gg_he{total}{$step});
		$highest_value{gasgiant_helium} = $val if ($val > $highest_value{gasgiant_helium});
	}

	# Helium and metallicity distribution

	if ($$r{name} =~ /^(\S+.*\S+)\s+[A-Z][A-Z]\-[A-Z] ([a-z])/) {
		my $sector = $1;
		my $masscode = uc($2);
		my $mainstartype = abbreviate_star($$r{type});

		if ($gfile{bodymetals} && $masscode && ($$body{h} || $$body{he} || $$body{metals})) {
			# Totals:
			$bodymetals{bodymetals}{$$body{subType}}{mt} += $$body{metals};
			$bodymetals{bodymetals}{$$body{subType}}{ht} += $$body{h};
			$bodymetals{bodymetals}{$$body{subType}}{het} += $$body{he};

			# Count:
			$bodymetals{bodymetals}{$$body{subType}}{b}++;

			# Averages:
			$bodymetals{bodymetals}{$$body{subType}}{Metals} =
				$bodymetals{bodymetals}{$$body{subType}}{mt} / 
				$bodymetals{bodymetals}{$$body{subType}}{b};
			$bodymetals{bodymetals}{$$body{subType}}{H} = 
				$bodymetals{bodymetals}{$$body{subType}}{ht} / 
				$bodymetals{bodymetals}{$$body{subType}}{b};
			$bodymetals{bodymetals}{$$body{subType}}{He} = 
				$bodymetals{bodymetals}{$$body{subType}}{het} / 
				$bodymetals{bodymetals}{$$body{subType}}{b};

			# Lists for calculating standard deviations and outliers:
			push @{$bodymetals{bodymetals}{$$body{subType}}{num}{Metals}}, $$body{metals}+0;
			push @{$bodymetals{bodymetals}{$$body{subType}}{num}{He}}, $$body{he}+0;
			push @{$bodymetals{bodymetals}{$$body{subType}}{num}{H}}, $$body{h}+0;
		}

		if ($gfile{sectormassmetals} && $masscode && $$body{subType} =~ /G/i && ($$body{h} || $$body{he})) {
			$sectormetals{sectormassmetals}{$sector}{$masscode}{mt} += $$body{metals};
			$sectormetals{sectormassmetals}{$sector}{$masscode}{ht} += $$body{h};
			$sectormetals{sectormassmetals}{$sector}{$masscode}{het} += $$body{he};
			$sectormetals{sectormassmetals}{$sector}{$masscode}{b}++;
			$sectormetals{sectormassmetals}{$sector}{$masscode}{Metals} = 1000 *  
				$sectormetals{sectormassmetals}{$sector}{$masscode}{mt} / 
				$sectormetals{sectormassmetals}{$sector}{$masscode}{b};
			$sectormetals{sectormassmetals}{$sector}{$masscode}{H} = 
				$sectormetals{sectormassmetals}{$sector}{$masscode}{ht} / 
				$sectormetals{sectormassmetals}{$sector}{$masscode}{b};
			$sectormetals{sectormassmetals}{$sector}{$masscode}{He} = 
				$sectormetals{sectormassmetals}{$sector}{$masscode}{het} / 
				$sectormetals{sectormassmetals}{$sector}{$masscode}{b};
#warn "$sector [$masscode] H:$$body{h}, He:$$body{he}, Metals:$$body{metals}\n";
		}
	}


	# Valuable Planet Distribution

	if ($$r{name} =~ /^(\S+.*\S+)\s+[A-Z][A-Z]\-[A-Z] ([a-z])/) {
		my $sector = $1;
		my $masscode = uc($2);
		my $mainstartype = abbreviate_star($$r{type});

		my $type = '';
		$type = 'TFC' if ($$body{terraformingState} eq 'Candidate for terraforming');
		$type = 'WW'  if ($$body{subType} eq 'Water world' || $$body{subType} eq 'WW');
		$type = 'TWW' if (($$body{subType} eq 'Water world' || $$body{subType} eq 'WW') && $$body{terraformingState} eq 'Candidate for terraforming');
		$type = 'ELW' if ($$body{subType} eq 'Earth-like world' || $$body{subType} eq 'ELW');
		$type = 'AW'  if ($$body{subType} eq 'Ammonia world'|| $$body{subType} eq 'AW');
		#print "$sector / $masscode / $type\n";

		if ($gfile{sectormassplanets} && $masscode && $type) {
			$sectorplanets{sectormassplanets}{$sector}{$masscode}{$type}++;
			if ($sectorplanets{sectormassplanets}{$sector}{$masscode}{$type} > $highest_value{sectormassplanets}) {
				$highest_value{sectormassplanets} = $sectorplanets{sectormassplanets}{$sector}{$masscode}{$type};
				#print "New highest: $highest_value{sectormassplanets}\n";
			}
		}

		if ($gfile{systemmassplanets} && $masscode) {
			#vec($system_vector{systemmassplanets}{$masscode}, $$r{id64}, 1) = 1;
			${$system_seen{systemmassplanets}{$masscode}{$$r{id64}}} = \$one;
			#$chunk_seen{systemmassplanets}{$masscode}{$$r{id64}} = 1;

			$systemplanets{systemmassplanets}{$masscode}{$type}++ if ($type);
		}

		if ($gfile{sectorstarplanets} && $mainstartype && $type) {
			$sectorplanets{sectorstarplanets}{$sector}{$mainstartype}{$type}++;
			if ($sectorplanets{sectorstarplanets}{$sector}{$mainstartype}{$type} > $highest_value{sectorstarplanets}) {
				$highest_value{sectorstarplanets} = $sectorplanets{sectorstarplanets}{$sector}{$mainstartype}{$type};
				#print "New highest: $highest_value{sectorstarplanets}\n";
			}
		}

		if ($gfile{systemstarplanets} && $mainstartype) {
			#vec($system_vector{systemstarplanets}{$mainstartype}, $$r{id64}, 1) = 1;	# Mark unique system IDs
			${$system_seen{systemstarplanets}{$mainstartype}{$$r{id64}}} = \$one;
			#$chunk_seen{systemstarplanets}{$masscode}{$$r{id64}} = 1;

			$systemplanets{systemstarplanets}{$mainstartype}{$type}++ if ($type);
		}
	}

	# Galactic radial distance from center:

	if (defined($$r{coord_x}) && defined($$r{coord_z}) && $mapdata{starclass}{bodies}{$$body{subType}}) {

		my $dist = floor(sqrt(($$r{coord_x}-$sgrA_x)**2 + ($$r{coord_z}-$sgrA_z)**2)/$radialdistance_granularity);
		$radialdistance{$dist}{$$body{subType}}++;
	}

	# Galactic-height graph:

	if (defined($$r{coord_y})) {

		if (defined($$body{age})) {
			my $height = $$r{coord_y} - $galcenter_y;
			$height = 0-$height if ($height<0);
			$height = int ($height/$heightgraph_granularity);
			$heightgraphA{$height}{$$body{age}}++ if ($height<=$heightgraph_maxheight);
			#print "Age-Height: $height, $$body{age} = $heightgraphA{$height}{$$body{age}}\n";
		}
			
		if ($mapdata{starclass}{bodies}{$$body{subType}}) {
			my $height = $$r{coord_y} - $galcenter_y;
			$height = 0-$height if ($height<0);
			$height = int ($height/$heightgraph_granularity);
			$heightgraph{$height}{$$body{subType}}++ if ($height<=$heightgraph_maxheight);
	
			my $height2 = floor($$r{coord_y}/$heightgraph2_scale)+floor($heightgraph2_nodes/2);
			$heightgraph2{$height2}{$$body{subType}}++ if ($height2>=0 && $height2<$heightgraph2_nodes-1 && $height2<=$heightgraph_maxheight);
	
			my $height2 = floor($$r{coord_y}/$heightgraph2_scale)+floor($heightgraph2_widenodes/2);
			$heightgraph2W{$height2}{$$body{subType}}++ if ($height2>=0 && $height2<$heightgraph2_widenodes-1 && $height2<=$heightgraph_maxheight);
	
			my ($bc,$Mbol,$L,$inner,$outer) = undef;
	
			if ($$body{subType} =~ /^(O|B|A|F|G|K|M)$/ && $$body{luminosity} && $$body{surfaceTemperature} && defined($$body{absoluteMagnitude})) {
				$bc = bolometric_correction($$body{luminosity},$$body{surfaceTemperature});
				if ($bc) {
					$Mbol = $$body{absoluteMagnitude} + $bc;
					$L = 10**(($Mbol-4.72)/-2.512);
					$inner = int( ( ($L/1.1) ** 0.5 ) * 499.05);
					$outer = int( ( ($L/0.53) ** 0.5 ) * 499.05);
	
					#my $size = $outer-$inner; $size = 0-$size if ($size < 0);
	
					$habitable{calc}{$$body{subType}}{$$body{starType}}{$$body{surfaceTemperature}}{$inner}{$outer}++;
					#print "HABITABLE FOUND: $$body{subType},$$body{starType},$size,$inner,$outer\n";
				}
			}
	
			#print "Class-Height $height, $$body{subType} = $heightgraph{$height}{$$body{subType}} ($$body{surfaceTemperature}, $$body{luminosity} ~ $L) Habitable: $inner - $outer\n";
		}
			
		if ($mapdata{planets}{bodies}{$$body{subType}}) {
			my $height = $$r{coord_y} - $galcenter_y;
			$height = 0-$height if ($height<0);
			$height = int ($height/$heightgraph_granularity);
			$heightgraphP{$height}{$$body{subType}}++ if ($height<=$heightgraph_maxheight);
		}
	}

	if (defined($$body{surfaceTemperature}) && defined($$body{absoluteMagnitude}) && $$body{subType} ne 'BH') {
		$hrdata{hr}{brightest} = $$body{absoluteMagnitude}  if (!defined($hrdata{hr}{brightest}) || $$body{absoluteMagnitude}  < $hrdata{hr}{brightest});
		$hrdata{hr}{darkest}   = $$body{absoluteMagnitude}  if (!defined($hrdata{hr}{darkest})   || $$body{absoluteMagnitude}  > $hrdata{hr}{darkest});
		$hrdata{hr}{coldest}   = $$body{surfaceTemperature} if (!defined($hrdata{hr}{coldest})   || $$body{surfaceTemperature} < $hrdata{hr}{coldest});
		$hrdata{hr}{hottest}   = $$body{surfaceTemperature} if (!defined($hrdata{hr}{hottest})   || $$body{surfaceTemperature} > $hrdata{hr}{hottest});

		$hrdata{hr}{data}{$$body{surfaceTemperature}}{$$body{absoluteMagnitude}}{$$body{subType}}++;
	}
}

sub draw_graphs {

	# HR Diagrams:

	foreach my $graphtype (@hrtypes) { eval {

		next if (!$gfile{$graphtype});

		my $size_x = 1000;
		my $size_y = 600;
		my $startx = 10;
		my $margin = 50;
		my $bottom_add = 200;
		my $top_add = 70;
		my $left_add = 30;

		print "Starting $graphtype (".epoch2date(time).")\n";

		my $bottom = int(2*$margin+$size_y+$bottom_add+$top_add);
		my $right  = int($left_add+2*$margin+$size_x);

		my $image = Image::Magick->new(
			size  => $right.'x'.$bottom,
			type  => 'TrueColor',
			depth => 8,
			verbose => 'true'
		);
		$image->ReadImage('canvas:black');
		$image->Quantize(colorspace=>'RGB');

		$image->Annotate(pointsize=>30,fill=>'white',text=>"Hertzsprung-Russell Diagram, Base-2 Logarithmic",gravity=>'north',x=>0,y=>$margin-5) if ($graphtype eq 'hrlog2');
		$image->Annotate(pointsize=>30,fill=>'white',text=>"Hertzsprung-Russell Diagram, Base-10 Logarithmic",gravity=>'north',x=>0,y=>$margin-5) if ($graphtype eq 'hrlog');
		$image->Annotate(pointsize=>30,fill=>'white',text=>"Hertzsprung-Russell Diagram, Linear",gravity=>'north',x=>0,y=>$margin-5) if ($graphtype eq 'hrdiag');
		$image->Annotate(pointsize=>15,fill=>'white',text=>"Surface Temperature (Kelvin)",gravity=>'south',x=>0,y=>150);
		$image->Annotate(pointsize=>15,fill=>'white',text=>"Absolute Magnitude",gravity=>'west',x=>35,y=>80,rotate=>-90);

		my @map = ();
		my $brightest_pixel = 0;
		my $temp_cap = 8;
		my $temp_div = 6;
		my $top_temp  = 40000;

		if ($graphtype eq 'hrlog2') {
			$temp_cap = 17;
			$temp_div = 10;
		}

		my @temp_list = (100,250,500,1000,2500,5000,10000,25000,50000,100000,250000,500000,1000000,2500000,5000000,10000000,25000000,50000000,100000000);
		my %class_list = ('NS'=>2500000,'O'=>50000,'B'=>18000,'A'=>8250,'F'=>6750,'G'=>5500,'K'=>4250,'M'=>2500,'L'=>1000,'T'=>500,'Y'=>200);

		@temp_list = (40000,35000,30000,25000,20000,15000,10000,5000,0) if ($graphtype eq 'hrdiag');
		@temp_list = (128000,64000,32000,16000,8000,4000,2000,1000,500,250,125,0) if ($graphtype eq 'hrlog2');

		foreach my $class (keys %class_list) {
			my $temp = $class_list{$class};
			my $x_percent = ($temp_cap-log10($temp))/$temp_div;
			$x_percent = ($temp_cap-log2($temp))/$temp_div if ($graphtype eq 'hrlog2');
			$x_percent = ($top_temp-$temp)/$top_temp if ($graphtype eq 'hrdiag');

			next if ($x_percent<0 || $x_percent>1);

			my $x = $margin + $left_add + int($size_x*$x_percent);
			my $y = $margin + $top_add;

			$image->Draw( primitive=>'line', stroke=>'rgb(255,255,255)', fill=>'none', strokewidth=>1,
				points=>sprintf("%u,%u %u,%u",$x,$y,$x,$y-6));
		
			$image->Annotate(pointsize=>15,fill=>'white',text=>$class,x=>$x-4,y=>$y-10);
		}
		foreach my $temp (@temp_list) {
			my $x_percent = ($temp_cap-log10($temp))/$temp_div;
			$x_percent = ($temp_cap-log2($temp))/$temp_div if ($graphtype eq 'hrlog2');
			$x_percent = ($top_temp-$temp)/$top_temp if ($graphtype eq 'hrdiag');

			next if ($x_percent<0 || $x_percent>1);

			my $x = $margin + $left_add + int($size_x*$x_percent);
			my $y = $margin + $top_add + $size_y;

			$image->Draw( primitive=>'line', stroke=>'rgb(63,63,63)', fill=>'none', strokewidth=>1,
				points=>sprintf("%u,%u %u,%u",$x,$margin+$top_add,$x,$margin+$top_add+$size_y));

			$image->Draw( primitive=>'line', stroke=>'rgb(255,255,255)', fill=>'none', strokewidth=>1,
				points=>sprintf("%u,%u %u,%u",$x,$y,$x,$y+6));
		
			$image->Annotate(pointsize=>15,fill=>'white',text=>commify($temp),x=>$x-5,y=>$y+10,rotate=>90);
		}
		for (my $mag=-25; $mag<=30; $mag+=5) {
			my $y_percent = ($mag+$magnitude_boost)/$magnitude_scale;
			my $y = $margin + $top_add + int($size_y*$y_percent);
			my $x = $margin + $left_add;

			$image->Draw( primitive=>'line', stroke=>'rgb(63,63,63)', fill=>'none', strokewidth=>1,
				points=>sprintf("%u,%u %u,%u",$x,$y,$x+$size_x,$y));

			$image->Draw( primitive=>'line', stroke=>'rgb(255,255,255)', fill=>'none', strokewidth=>1,
				points=>sprintf("%u,%u %u,%u",$x,$y,$x-6,$y));
		
			$image->Annotate(pointsize=>15,fill=>'white',text=>$mag,gravity=>'northeast',x=>$margin+$size_x+10,y=>$y-5);
		}


		foreach my $temperature (sort keys %{$hrdata{hr}{data}}) {
			foreach my $magnitude (sort keys %{$hrdata{hr}{data}{$temperature}}) {
				foreach my $starClass (sort keys %{$hrdata{hr}{data}{$temperature}{$magnitude}}) {

					# hrlog:
					my $x_percent = ($temp_cap-log10($temperature))/$temp_div;
					my $y_percent = ($magnitude+$magnitude_boost)/$magnitude_scale;

					$x_percent = ($temp_cap-log2($temperature))/$temp_div if ($graphtype eq 'hrlog2');
					$x_percent = ($top_temp-$temperature)/$top_temp if ($graphtype eq 'hrdiag');

					if ($y_percent >= 0 && $y_percent <= 1 && $x_percent >= 0 && $x_percent <= 1) {
						my $x = int($size_x*$x_percent);
						my $y = int($size_y*$y_percent);

						for (my $n=0; $n<3; $n++) {
							my $ok = 0;
							eval {
								$map[$x][$y][$n] += ${$colorclass{$starClass}}[$n]*$hrdata{hr}{data}{$temperature}{$magnitude}{$starClass};
								$brightest_pixel = $map[$x][$y][$n] if ($map[$x][$y][$n] > $brightest_pixel);
							};
						}
					}
				}
			}
		}

		my $log_add = 2;
		my $brightest_log = log10($brightest_pixel)+$log_add;

		for (my $y=0; $y<$size_y; $y++) {
			for (my $x=0; $x<$size_x; $x++) {
				my @pixel = (0,0,0);

				next if (!$map[$x][$y][0] && !$map[$x][$y][1] && !$map[$x][$y][2]);

				for (my $n=0; $n<3; $n++) {

					# Yes, we want floats from 0..1:
					$pixel[$n] = (log10($map[$x][$y][$n])+$log_add) / $brightest_log;
				}
				$image->SetPixel( x => $margin+$left_add+$x, y => $margin+$top_add+$y, color => \@pixel );
			}
		}

		my $n = 0;
		my $per_row = 5;
		my $pointsize = 15;
		my $spacing = 150;
		my $startx  = $left_add+$margin+160;
		my $starty  = $top_add+$margin+$size_y+130;

		foreach my $startype (@colorkey) {
			my ($code,$name) = split(/\|/,$startype);

			next if (!$starcodes{$code} || $code eq 'BH');

			my $xn = $n % $per_row;
			my $yn = int($n/$per_row);

			my $x1 = $startx+$xn*$spacing;
			my $y1 = $starty+$yn*($pointsize+5);
			my $x2 = $x1 + $pointsize;
			my $y2 = $y1 + $pointsize;
			my $c  = '';

			if ($graphtype eq 'heightgraphA') {
				$c  = "rgb(".join(',',@{$agecolor{$code}}).")";
			} else {
				$c  = "rgb(".join(',',@{$colorclass{$code}}).")";
			}

			$image->Draw( primitive=>'rectangle', stroke=>'#777', fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y2));
			$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>$name,x=>$x2+5,y=>$y2);
			$n++;
		}

		$image->Draw( primitive=>'rectangle', stroke=>'white', fill=>'none', strokewidth=>2,
			points=>sprintf("%u,%u %u,%u",$margin+$left_add,$margin+$top_add,$margin+$left_add+$size_x,$margin+$top_add+$size_y));

		$image->Annotate(pointsize=>12,fill=>'white',x=>5,y=>$bottom-5,text=>"$author - ".epoch2date(time));

		save_image($image,$gfile{$graphtype});
	
	};
	print "ERROR: $@\n" if ($@);
	}


	# Habitable zones:

	foreach my $graphtype (@zonetypes) { eval {
		if ($gfile{$graphtype}) {
			my $n = 0;
			my %graph = ();

			print "Starting '$graphtype' (".epoch2date(time).")\n";

			if ($graphtype eq 'habitablezone') {
				foreach my $class (qw(O B A F G K M)) {
					foreach my $type (reverse ('','D','G','S')) {
						next if (!keys %{$habitable{calc}{$class}{$type}});
		
						my $coolest = (sort {$a <=> $b} keys %{$habitable{calc}{$class}{$type}})[0];
						my $hottest  = (sort {$b <=> $a} keys %{$habitable{calc}{$class}{$type}})[0];
			
						#print "HABITABLE: $class, $type, $starTypeKey{$type} (sizes: $coolest - $hottest)\n";
		
						$graph{$n}{class} = $class;
						$graph{$n}{type} = $type;
						$graph{$n}{coolest} = $coolest;
						$graph{$n}{hottest} = $hottest;
						$n++;
					}
				}
			}
	
			
			my $spany  = 80;
			my $spanheight = $spany+10;
			my $size_x = 820;
			my $size_y = $spanheight*int(keys %graph)+int($spanheight*2/3);
			my $startx = 10;
			my $margin = 50;
			my $bottom_add = 80;
			my $top_add = 70;
			my $left_add = 200;
	
			my $bottom = int(2*$margin+$size_y+$bottom_add+$top_add);
			my $right  = int($left_add+2*$margin+$size_x);
	
			my $logwidth = 100;
	
			my $image = Image::Magick->new(
				size  => $right.'x'.$bottom,
				type  => 'TrueColor',
				depth => 8,
				verbose => 'true'
			);
			$image->ReadImage('canvas:black');
			$image->Quantize(colorspace=>'RGB');
	
			$image->Annotate(pointsize=>30,fill=>'white',text=>"Estimated Goldilocks Habitable Zones",gravity=>'north',x=>0,y=>$margin-5);
			$image->Annotate(pointsize=>15,fill=>'white',text=>"(Calculated from star surface temperature and absolute magnitude)",gravity=>'north',x=>0,y=>$margin+30);
			$image->Annotate(pointsize=>15,fill=>'white',text=>"Light Seconds from Star",gravity=>'south',x=>0,y=>35);
			$image->Annotate(pointsize=>15,fill=>'white',text=>"Surface Temperature",gravity=>'west',x=>35,y=>80,rotate=>-90);
	
			$image->Annotate(pointsize=>12,fill=>'white',x=>5,y=>$bottom-5,text=>"$author - ".epoch2date(time));
	
			my $x = 0;
			my $i = 0;
			while ($x < $size_x) {
				my $num = commify(10 ** $i);
				my $gx = $margin+$left_add+$startx+$x;
				my $gy = $margin+$top_add+$size_y;

				$image->Draw( primitive=>'line', stroke=>'rgb(63,63,63)', fill=>'none', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$gx,$top_add+$margin,$gx,$gy));
				$image->Draw( primitive=>'line', stroke=>'white', fill=>'none', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$gx,$gy,$gx,$gy+5));
				$image->Annotate(pointsize=>14,fill=>'white',text=>$num,x=>$gx-3,y=>$gy+9,rotate=>90);

				$num = commify(10 ** $i / 2);
				$gx = $margin+$left_add+$startx+$x-int((log10(10 ** $i)-log10(10 ** $i / 2))*$logwidth);
				$image->Draw( primitive=>'line', stroke=>'rgb(40,40,40)', fill=>'none', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$gx,$top_add+$margin,$gx,$gy)) if ($i);
				$image->Draw( primitive=>'line', stroke=>'white', fill=>'none', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$gx,$gy,$gx,$gy+5)) if ($i);
				$image->Annotate(pointsize=>14,fill=>'white',text=>$num,x=>$gx-3,y=>$gy+9,rotate=>90) if ($i);

				$num = commify(10 ** $i / 4);
				$gx = $margin+$left_add+$startx+$x-int((log10(10 ** $i)-log10(10 ** $i / 4))*$logwidth);
				$image->Draw( primitive=>'line', stroke=>'rgb(23,23,23)', fill=>'none', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$gx,$top_add+$margin,$gx,$gy)) if ($i);
				$image->Draw( primitive=>'line', stroke=>'white', fill=>'none', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$gx,$gy,$gx,$gy+5)) if ($i);
				$image->Annotate(pointsize=>14,fill=>'white',text=>$num,x=>$gx-3,y=>$gy+9,rotate=>90) if ($i);

				$x += $logwidth;
				$i++;
			}
	
			foreach my $n (sort {$a <=> $b} keys %graph) {
				my $type     = $graph{$n}{type};
				my $class    = $graph{$n}{class};
				my $starType = $starTypeKey{$graph{$n}{type}};
	
				#print "$class $type $starType\n";
	
				my $ps = 40;
	
				my $x = $left_add+$margin;
				my $y = $top_add+$margin+$spanheight*$n+int($spanheight/2);

				my $center_y = $y+int($spanheight/2)-10;
	
				$image->Annotate(pointsize=>$ps,fill=>'white',text=>$class,x=>$x-$ps,y=>$center_y+$ps/2-5);
				$image->Annotate(pointsize=>15,fill=>'white',text=>$starType,gravity=>'northeast',x=>$right-($x-80),y=>$center_y-5);
	
				for(my $i=0; $i<=15; $i++) {
					my @col = @{$colorclass{$class}};
					my $c = scaledColor($col[0],$col[1],$col[2],$i/15);
					my $p = sprintf("%u,%u %u,%u",$x-60,$center_y,$x-60,$center_y-15+$i);
					$image->Draw( primitive=>'circle', stroke=>$c, fill=>$c, strokewidth=>1, points=>$p);
					#print "Circle: $c $p\n";
				}
	
				$image->Draw( primitive=>'line', stroke=>'rgb(63,63,63)', fill=>'none', strokewidth=>1,
					points=>sprintf("%u,%u %u,%u",$margin+$left_add,$y-10,$margin+$left_add+$size_x,$y-10));
				$image->Draw( primitive=>'line', stroke=>'rgb(63,63,63)', fill=>'none', strokewidth=>1,
					points=>sprintf("%u,%u %u,%u",$margin+$left_add,$y+$spany,$margin+$left_add+$size_x,$y+$spany));

				my @span = ();
				my $strongest = 0;
				my $maxx = 0;
				my $maxy = 0;
	
				foreach my $surface_temp (sort keys %{$habitable{calc}{$class}{$type}}) {
					next if ($graph{$n}{hottest}-$graph{$n}{coolest} == 0);
					my $gy = int($spany*($surface_temp-$graph{$n}{coolest})/($graph{$n}{hottest}-$graph{$n}{coolest}));
	
					foreach my $inner (keys %{$habitable{calc}{$class}{$type}{$surface_temp}}) {
						my $gx1 = int(log10($inner)*$logwidth);
	
						foreach my $outer (keys %{$habitable{calc}{$class}{$type}{$surface_temp}{$inner}}) {
							my $gx2 = int(log10($outer)*$logwidth);
							my $strength = $habitable{calc}{$class}{$type}{$surface_temp}{$inner}{$outer};
	
							for (my $gx=$gx1; $gx<=$gx2; $gx++) {
								$span[$gx][$gy] += $strength;
								$strongest = $span[$gx][$gy] if ($span[$gx][$gy] > $strongest);
								$maxx = $gx if ($gx > $maxx);
								$maxy = $gy if ($gy > $maxy);
								#print "$class,$type: $gx,$gy += $strength ($span[$gx][$gy] / $strongest)\n";
							}
						}
					}
				}
	
				my $slog = log10($strongest)+2;
				$maxx = $size_x-$startx if ($maxx > $size_x-$startx);
	
				for (my $gy=0; $gy <= $maxy; $gy++) {
					for (my $gx=0; $gx <= $maxx; $gx++) {
	
						my $l = 0; $l = (log10($span[$gx][$gy])+2)/$slog if ($span[$gx][$gy] && $slog);
						my @pixel = ($l,$l,$l);
						#print "$class,$type: SetPixel: ".($x+$gx).','.($y-$gy).": $l\n";
						$image->SetPixel( x => $x+$gx+$startx, y => $y+$spany-5-$gy, color => \@pixel ) if ($l);
					}
				}
			}

			$image->Draw( primitive=>'rectangle', stroke=>'white', fill=>'none', strokewidth=>2,
				points=>sprintf("%u,%u %u,%u",$margin+$left_add,$margin+$top_add,$margin+$left_add+$size_x,$margin+$top_add+$size_y));
	
			save_image($image,$gfile{$graphtype});
		}
	};
	print "ERROR: $@\n" if ($@);
	}


	# Height / Radial Distance graph:

	foreach my $graphtype (qw(heightgraphA heightgraph heightgraphP heightgraph2 heightgraph2W radialdistance)) { eval {
		next if (!$gfile{$graphtype});

		print "Height/Distance Graph '$graphtype'... (".epoch2date(time).")\n";

		my %graphdata = ();
		%graphdata = %heightgraph    if ($graphtype eq 'heightgraph');
		%graphdata = %heightgraphP   if ($graphtype eq 'heightgraphP');
		%graphdata = %heightgraphA   if ($graphtype eq 'heightgraphA');
		%graphdata = %heightgraph2   if ($graphtype eq 'heightgraph2');
		%graphdata = %heightgraph2W  if ($graphtype eq 'heightgraph2W');
		%graphdata = %radialdistance if ($graphtype eq 'radialdistance');

		my $granularity = $heightgraph_granularity;
		$granularity = $radialdistance_granularity if ($graphtype eq 'radialdistance');

		my $size_x = 1500;
		my $size_y = 500;
		my $margin = 50;
		my $bottom_add = 200;
		my $top_add = 50;
		my $left_add = 100;

		$size_x = 1800 if ($graphtype eq 'heightgraph2');
		$size_x = 5000 if ($graphtype eq 'heightgraph2W');

		my $bottom = int(2*$margin+$size_y+$bottom_add+$top_add);

		my $image = Image::Magick->new(
			size  => int($left_add+2*$margin+$size_x).'x'.$bottom,
			type  => 'TrueColor',
			depth => 8,
			verbose => 'true'
		);
		$image->ReadImage('canvas:black');
		$image->Quantize(colorspace=>'RGB');

		my @types = ();
		my @masterkey = @colorkey;
		@masterkey = @agekey if ($graphtype eq 'heightgraphA');

		foreach my $startype (@masterkey) {
			my ($code,$name) = split(/\|/,$startype);
			push @types, $code;
		}

		my %heights = ();
		my %data = ();
		my $max = (sort {$b <=> $a} keys %graphdata)[0];
		my $highest = 0;

		$max = int($heightgraph_maxheight / $heightgraph_granularity) if ($graphtype !~ /heightgraph2|radial/ && $max > int($heightgraph_maxheight / $heightgraph_granularity));

		foreach my $n (0..$max) {
			foreach my $type (@types) {

				if ($graphdata{$n}{$type}) {
					$data{$n}{$type} = log10($graphdata{$n}{$type});
					$highest = $data{$n}{$type} if ($data{$n}{$type} > $highest);
				} else {
					$data{$n}{$type} = 0;
				}
			}
		}
		my $top = int($highest)+1;
		$max++ if ($graphtype !~ /heightgraph2/);

		foreach my $n (0..$top) {
			my $c = 10 ** $n;
		
			my $x = $margin+$left_add;
			my $y = int($top_add+$margin+$size_y-$n*$size_y/$top);

			my $t = commify($c);

			$image->Annotate(pointsize=>12,fill=>'white',gravity=>'northeast',text=>$t,x=>$size_x+$margin+7,y=>$y-5);
			$image->Draw( primitive=>'line', stroke=>'rgb(50,50,50)', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$y,$x+$size_x,$y));
			$image->Draw( primitive=>'line', stroke=>'white', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$y,$x-5,$y));
		}

		for (my $n=0; $n<=$max; $n++) { eval {
			if ($n) {
				foreach my $type (@types) { eval {
	
					my $x1 = int($left_add+$margin+($n-1)*$size_x/$max);
					my $x2 = int($left_add+$margin+$n*$size_x/$max);
					my $y1 = int($top_add+$margin+$size_y-$data{$n-1}{$type}*$size_y/$top);
					my $y2 = int($top_add+$margin+$size_y-$data{$n}{$type}*$size_y/$top);
					my $c  = 'rgb(0,0,0)';
					$c = "rgb(".join(',',@{$colorclass{$type}}).")" if ($graphtype ne 'heightgraphA');
					$c = "rgb(".join(',',@{$agecolor{$type}}).")" if ($graphtype eq 'heightgraphA');

					$image->Draw( primitive=>'line', stroke=>$c, strokewidth=>2, points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y2));
					$image->Draw( primitive=>'circle', stroke=>$c, fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x2,$y2,$x2+4,$y2)) 
						if ($data{$n}{$type}>0 && $n<$max);
				} };
			}
			my $start = $n*$granularity;
			my $end = ($n+1)*$granularity - 1;

			if ($graphtype =~ /heightgraph2/) {
				$start = ($n-floor($heightgraph2_nodes/2))*$heightgraph2_scale;
				$start = ($n-floor($heightgraph2_widenodes/2))*$heightgraph2_scale if ($graphtype =~ /heightgraph2W/);
				$end  = $start + $heightgraph2_scale-1;
			}

			my $label = $start."  -  ".$end;

			my $x = int($margin+$left_add+$n*$size_x/$max);
			my $y = int($margin+$top_add+$size_y);
			$image->Annotate(pointsize=>14,fill=>'white',text=>$label,x=>$x-3,y=>$y+9,rotate=>90);
			$image->Draw( primitive=>'line', stroke=>'rgb(50,50,50)', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$margin+$top_add,$x,$y));
			$image->Draw( primitive=>'line', stroke=>'white', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$y,$x,$y+5));
		} };
		my $fn = $gfile{$graphtype};

		my $obj = 'Star';
		$obj = 'Planet' if ($graphtype =~ /P$/);

		if ($graphtype =~ /^heightgraphP?$/) {
			$image->Annotate(pointsize=>30,fill=>'white',text=>"$obj distribution by class and distance from galactic plane",gravity=>'north',x=>0,y=>$margin-5);
		} elsif ($graphtype =~ /heightgraph2/) {
			$image->Annotate(pointsize=>30,fill=>'white',text=>"$obj distribution by class and galactic altitude (Y coordinate)",gravity=>'north',x=>0,y=>$margin-5);
		} elsif ($graphtype eq 'heightgraphA') {
			$image->Annotate(pointsize=>30,fill=>'white',text=>"$obj distribution by age and distance from galactic plane",gravity=>'north',x=>0,y=>$margin-5);
		} elsif ($graphtype eq 'radialdistance') {
			$image->Annotate(pointsize=>30,fill=>'white',text=>"$obj distribution by X/Z radial distance from Sagittarius A*",gravity=>'north',x=>0,y=>$margin-5);
		}
		$image->Annotate(pointsize=>16,fill=>'white',text=>'Distance from galactic plane (lightyears)',gravity=>'south',x=>50,y=>$bottom_add/2+30) if ($graphtype !~ /heightgraph2|radialdistance/);
		$image->Annotate(pointsize=>16,fill=>'white',text=>'Distance from galactic center (lightyears)',gravity=>'southwest',x=>$left_add+$margin,y=>$bottom_add/2+20) if ($graphtype =~ /radialdistance/);
		$image->Annotate(pointsize=>16,fill=>'white',text=>'Galactic Altitude, Y-coordinate',gravity=>'south',x=>50,y=>$bottom_add/2+30) if ($graphtype =~ /heightgraph2/);
		$image->Annotate(pointsize=>16,fill=>'white',text=>"Number of $obj".'s',rotate=>270,gravity=>'east',x=>$margin+$size_x+65,y=>-100);

		$image->Draw( primitive=>'rectangle', stroke=>'white', fill=>'none', strokewidth=>2,
			points=>sprintf("%u,%u %u,%u",$margin+$left_add,$margin+$top_add,$margin+$left_add+$size_x,$margin+$top_add+$size_y));

		$image->Annotate(pointsize=>12,fill=>'white',x=>5,y=>$bottom-5,text=>"$author - ".epoch2date(time));

		my $n = 0;
		my $per_row = 6;
		my $pointsize = 15;
		my $spacing = 150;
		my $startx  = $left_add+$margin+300;
		my $starty  = $top_add+$margin+$size_y+150;

		if ($graphtype eq 'heightgraphA') {
			$per_row = 3;
			$spacing = 240;
			#$startx -= 100;
			$starty -= 10;
		}

		if ($graphtype eq 'heightgraphP') {
			$per_row = 5;
			$spacing = 210;
			$startx -= 100;
			$starty -= 20;
		}
		if ($graphtype =~ /heightgraph2/) {
			$per_row = 8;
			$startx += 1600 if ($graphtype eq 'heightgraph2W');
		}

		foreach my $startype (@masterkey) {
			my ($code,$name) = split(/\|/,$startype);

			next if (!$starcodes{$code} && ($graphtype eq 'heightgraph' || $graphtype =~ /heightgraph2|radialdistance/));
			next if (!$planetcodes{$code} && $graphtype eq 'heightgraphP');

			my $xn = $n % $per_row;
			my $yn = int($n/$per_row);

			my $x1 = $startx+$xn*$spacing;
			my $y1 = $starty+$yn*($pointsize+5);
			my $x2 = $x1 + $pointsize;
			my $y2 = $y1 + $pointsize;
			my $c  = '';

			if ($graphtype eq 'heightgraphA') {
				$c  = "rgb(".join(',',@{$agecolor{$code}}).")";
			} else {
				$c  = "rgb(".join(',',@{$colorclass{$code}}).")";
			}

			$image->Draw( primitive=>'rectangle', stroke=>'#777', fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y2));
			$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>$name,x=>$x2+5,y=>$y2);
			$n++;
		}

		save_image($image,$fn);
	} };



	# Sector/System Mass/MainStar/Body Valuable Planets / Metals Distribution:

	foreach my $graphtype (qw(sectorstarplanets sectormassplanets systemstarplanets systemmassplanets sectormassmetals bodymetals gasgiant_helium)) {
		next if (!$gfile{$graphtype});
		my $fn = $gfile{$graphtype};

		my ($size_x,$size_y,$startx,$margin,$bottom_add,$top_add,$left_add,$highest);

		print "Starting $graphtype (".epoch2date(time).")\n";

		$highest = $highest_value{$graphtype};

		if ($graphtype =~ /^system/) {
			$highest = 0;
			foreach my $itemcode (keys %{$systemplanets{$graphtype}}) {
				foreach my $type (keys %{$systemplanets{$graphtype}{$itemcode}}) {
					#my $avg = 1000 * $systemplanets{$graphtype}{$itemcode}{$type} / unpack("%32b*", $system_vector{$graphtype}{$itemcode});
					my $avg = 1000 * $systemplanets{$graphtype}{$itemcode}{$type} / int(keys %{$system_seen{$graphtype}{$itemcode}});
					$highest = $avg if ($avg > $highest);
				}
			}
		}

		my $scale_type = 'log';
		$scale_type = 'linear' if ($graphtype =~ /^(system|gasgiant)/ || $graphtype =~ /metals/);

		if ($graphtype eq 'gasgiant_helium') {
			$size_x = 2400;
			$size_y = 600;
			$startx = 10;
			$margin = 50;
			$bottom_add = 200;
			$top_add = 70;
			$left_add = 50;
		}

		if ($graphtype eq 'bodymetals') {
			$size_x = 1920;
			$size_y = 600;
			$startx = 10;
			$margin = 50;
			$bottom_add = 200;
			$top_add = 70;
			$left_add = 50;
		}

		if ($graphtype eq 'sectormassmetals') {
			$size_x = 1020;
			$size_y = 600;
			$startx = 10;
			$margin = 50;
			$bottom_add = 200;
			$top_add = 70;
			$left_add = 50;
		}

		if ($graphtype eq 'sectormassplanets' || $graphtype eq 'systemmassplanets') {
			$size_x = 1120;
			$size_y = 600;
			$startx = 10;
			$margin = 50;
			$bottom_add = 200;
			$top_add = 70;
			$left_add = 50;
		}

		if ($graphtype eq 'sectorstarplanets' || $graphtype eq 'systemstarplanets') {
			$size_x = 1900;
			$size_y = 600;
			$startx = 10;
			$margin = 50;
			$bottom_add = 200;
			$top_add = 70;
			$left_add = 50;
		}

		my @sectormasstypes = $graphtype eq 'sectormassmetals' ? @sectormassmetalstypes : @sectormassplanetstypes;
		my %sectormasscolor = $graphtype eq 'sectormassmetals' ? %sectormassmetalscolor : %sectormassplanetscolor;
		my %sectormasskey   = $graphtype eq 'sectormassmetals' ? %sectormassmetalskey   : %sectormassplanetskey;

		my $bottom = int(2*$margin+$size_y+$bottom_add+$top_add);
		my $right  = int($left_add+2*$margin+$size_x);

		my $image = Image::Magick->new(
			size  => $right.'x'.$bottom,
			type  => 'TrueColor',
			depth => 8,
			verbose => 'true'
		);
		$image->ReadImage('canvas:black');
		$image->Quantize(colorspace=>'RGB');

		my $linear_intervals = 100;
		$linear_intervals = 200 if ($highest>2000);
		$linear_intervals = 500 if ($highest>5000);
		$linear_intervals = 1000 if ($highest>10000);
		$linear_intervals = 2000 if ($highest>20000);
		$linear_intervals = 5000 if ($highest>50000);
		$linear_intervals = 10000 if ($highest>100000);
		$linear_intervals = 100000 if ($highest>1000000);
		$linear_intervals = 1000000 if ($highest>10000000);

		$linear_intervals = 10 if ($graphtype =~ /metals/);

		my $top = floor(log10($highest))+1;
		$top = (floor($highest/$linear_intervals)+1)*$linear_intervals if ($scale_type eq 'linear');
		$top = 100 if ($graphtype =~ /metals/);
		#$top = 1000 if ($graphtype =~ /gasgiant/);

		my $loop_max = $top;
		$loop_max = floor($top/$linear_intervals) if ($scale_type eq 'linear');

		foreach my $n (0..$loop_max) {
			my ($x,$y);
			my $c = 10 ** $n;
			$c = $linear_intervals * $n if ($scale_type eq 'linear');
		
			$x = $margin+$left_add;
			$y = int($top_add+$margin+$size_y-$n*$size_y/$top) if ($scale_type eq 'log');
			$y = int($top_add+$margin+$size_y-($c/$top)*$size_y) if ($scale_type eq 'linear');

			my $t = commify($c);
			$t = "0 - 1" if ($t eq '1' && $scale_type eq 'log');

			$image->Annotate(pointsize=>12,fill=>'white',gravity=>'northeast',text=>$t,x=>$size_x+$margin+7,y=>$y-5);
			$image->Draw( primitive=>'line', stroke=>'rgb(50,50,50)', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$y,$x+$size_x,$y));
			$image->Draw( primitive=>'line', stroke=>'white', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$y,$x-5,$y));
		}

		my $bar_width = 20;
		$bar_width = 18 if ($graphtype =~ /starplanets/);
		$bar_width = 25 if ($graphtype =~ /metals/);
		$bar_width = 21 if ($graphtype =~ /bodymetals/);
		my $mass_width = (int(@sectormasstypes)+1)*$bar_width;

		my $x1 = int($left_add+$margin);

		my @list = ('A'..'H');
		@list = @starcodelist if ($graphtype =~ /starplanets/);
		@list = @planetcodelist if ($graphtype =~ /bodymetals/);
		@list = @gasgiant_percentages if ($graphtype =~ /gasgiant/);

		my @typelist = @sectormasstypes;
		@typelist = @sectormassmetalstypes if ($graphtype =~ /metals/);
		@typelist = @gasgiantstypes if ($graphtype =~ /gasgiant/);

		my %colorkey = %sectormasscolor;
		%colorkey = %bodymetalscolor if ($graphtype =~ /metals/);
		%colorkey = %gasgiantscolor if ($graphtype =~ /gasgiant/);

		my %keynames = %sectormasskey;
		%keynames = %bodymetalskey  if ($graphtype =~ /metals/);
		%keynames = %gasgiantskey  if ($graphtype =~ /gasgiant/);

		foreach my $itemcode (@list) {
			next if ($itemcode eq 'total');

			my $x_pos = $x1 + floor((int(@typelist)+2)*$bar_width/2);
			my $pointsize = $graphtype =~ /bodymetals/ ? 20 : 30;

			my $offset = $graphtype =~ /bodymetals/ ? floor(length($itemcode)*$pointsize/3) : 10;

			my $item = $graphtype =~ /gasgiant/ ? "$itemcode-".int($itemcode + 100/$gg_he_steps - 1) : $itemcode;
			my $add_y = $graphtype =~ /gasgiant/ ? 0 : 0;
			my $add_x = $graphtype =~ /gasgiant/ ? -22 : 0;

			$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>$item,gravity=>'northwest',x=>$x_pos-$offset+$add_x,y=>$top_add+$margin+$size_y+10+$add_y);
			$image->Draw( primitive=>'line', stroke=>'white', strokewidth=>1, points=>sprintf("%u,%u %u,%u",
				$x1+(int(@typelist)+2)*$bar_width,$top_add+$margin+$size_y+1,$x1+(int(@typelist)+2)*$bar_width,$top_add+$margin+$size_y+10));
#warn "$graphtype / $itemcode : typelist = ".join(',',@typelist)."\n";

			foreach my $type (@typelist) {
				$x1 += $bar_width;
				my $x3 = $x1 + $bar_width - 4;
				my $x2 = $x1 + floor($bar_width/2) - 2;
	
				my $highest = 0;
				my $lowest = 0xFFFFFFFFFFFF;
				my $sum = 0;
				my $num = 0;
				my @list = ();
	
				if ($graphtype =~ /^bodymetals/) {
					#push @{$bodymetals{bodymetals}{$$body{subType}}{num}{Metals}}, $$body{metals}+0;

#warn "$graphtype / $itemcode / $type : ".ref($bodymetals{$graphtype}{$itemcode}{num}{$type})."\n";
					next if (ref($bodymetals{$graphtype}{$itemcode}{num}{$type}) ne 'ARRAY');

					while (@{$bodymetals{$graphtype}{$itemcode}{num}{$type}}) {
						my $n = shift @{$bodymetals{$graphtype}{$itemcode}{num}{$type}};
						$n = 0 if (!$n || $n<0);
						$n = 100 if ($n>100);
	
						$sum += $n;
						$num ++;
	
						$highest = $n if ($n > $highest);
						$lowest  = $n if ($n < $lowest);
#warn "$graphtype / $itemcode / $type = $highest,$lowest, [$n]\n";
	
						push @list, $n;
					}
				} elsif ($graphtype =~ /^sectormassmetals/) {
					foreach my $sector (keys %{$sectormetals{$graphtype}}) {
						my $n = $sectormetals{$graphtype}{$sector}{$itemcode}{$type};
						$n = 0 if (!$n);
	
						$sum += $n;
						$num ++;
	
						$highest = $n if ($n > $highest);
						$lowest  = $n if ($n < $lowest);
	
						push @list, $n;
					}
				} elsif ($graphtype =~ /^sector/) {
					foreach my $sector (keys %{$sectorplanets{$graphtype}}) {
						my $n = $sectorplanets{$graphtype}{$sector}{$itemcode}{$type};
						$n = 0 if (!$n);
	
						$sum += $n;
						$num ++;
	
						$highest = $n if ($n > $highest);
						$lowest  = $n if ($n < $lowest);
	
						push @list, $sectorplanets{$graphtype}{$sector}{$itemcode}{$type};
					}
				} elsif ($graphtype =~ /^system/) {
					#$num = unpack("%32b*", $system_vector{$graphtype}{$itemcode});
					$num = int(keys %{$system_seen{$graphtype}{$itemcode}});
					$sum = $systemplanets{$graphtype}{$itemcode}{$type};
				} elsif ($graphtype =~ /^gasgiant/) {
					$num = $gg_he{total}{$itemcode} ? 1000 * ($gg_he{$itemcode}{$type} / $gg_he{total}{$itemcode}) : 0;
					$sum = $gg_he{total}{$itemcode};
				}
				next if (!$num);

				my $deviation = 0;
				my $average = $sum/$num;

				foreach (@list) {
					$deviation += ($average - $_) ** 2;
				}
				@list = (); # Free memory

				$deviation = sqrt($deviation/$num) if ($deviation && $num);
				$deviation = 0 if (!$num);

				my $color  = "rgb(".join(',',@{$colorkey{$type}}).")";
				my $colorF = colorFormatted(@{$colorkey{$type}});
	
				if ($graphtype =~ /^sector/ || $graphtype =~ /bodymetals/) {
					if (0) { 
						# Bars +/- Std Deviation, allows above zero bottoms

						my $avgUp = $average+$deviation;
						my $avgDn = $average-$deviation;
		
						$highest = 1 if ($highest < 1);
						$avgUp = 1 if ($avgUp < 1);
						$avgDn = 1 if ($avgDn < 1);
						$lowest = 1 if ($lowest < 1);
						$average = 1 if ($average < 1);
		
						my $y1 = int($top_add+$margin+$size_y)-int(log10($highest)*$size_y/$top);
						my $y2 = int($top_add+$margin+$size_y)-int(log10($avgUp)*$size_y/$top);
						my $y3 = int($top_add+$margin+$size_y)-int(log10($avgDn)*$size_y/$top);
						my $y4 = int($top_add+$margin+$size_y)-int(log10($lowest)*$size_y/$top);
						my $yA = int($top_add+$margin+$size_y)-int(log10($average)*$size_y/$top);
		
						my_rectangle($image,$x1,$y1,$x3,$y4,1,$color,'black');
						#$image->Draw( primitive=>'line', stroke=>$colorF, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x2,$y1,$x2,$y4));
						#$image->Draw( primitive=>'line', stroke=>'white', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x1,$y1,$x3,$y1));
						#$image->Draw( primitive=>'line', stroke=>'white', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x1,$y4,$x3,$y4));
						my_rectangle($image,$x1,$y2,$x3,$y3,1,'white',$color);
						$image->Draw( primitive=>'line', stroke=>'white', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x1,$yA,$x3,$yA));
					} else {
						# Average, + Std Deviation, + Max

						my $avgUp = $average+$deviation;
						$avgUp = $top if ($avgUp > $top);
		
						my ($y1,$y2,$yA,$yB);

						if ($scale_type eq 'linear') {
							$highest = 0 if ($highest < 0);
							$avgUp = 0 if ($avgUp < 0);
							$average = 0 if ($average < 0);
		
							$y1 = int($top_add+$margin+$size_y)-int($highest*$size_y/$top);
							$y2 = int($top_add+$margin+$size_y)-int($avgUp*$size_y/$top);
							$yA = int($top_add+$margin+$size_y)-int($average*$size_y/$top);
							$yB = int($top_add+$margin+$size_y);
#warn "$graphtype: $type $itemcode $average ($sum/$num) $deviation\n";
						} else {
							$highest = 1 if ($highest < 1);
							$avgUp = 1 if ($avgUp < 1);
							$average = 1 if ($average < 1);
		
							$y1 = int($top_add+$margin+$size_y)-int(log10($highest)*$size_y/$top);
							$y2 = int($top_add+$margin+$size_y)-int(log10($avgUp)*$size_y/$top);
							$yA = int($top_add+$margin+$size_y)-int(log10($average)*$size_y/$top);
							$yB = int($top_add+$margin+$size_y);
						}

						my $halfcolor = 'rgb(64,64,64)';
						if ($color =~ /rgb\(([\d\,]+)\)/) {
							my @c = split ',',$1;
							for my $i (0..2) {
								$c[$i] = $c[$i] >> 1;
							}

							$halfcolor = "rgb($c[0],$c[1],$c[2])";
						}

						my_rectangle($image,$x1,$y1,$x3,$yB,1,$color,'black');
						my_rectangle($image,$x1,$y2,$x3,$yB,1,$color,$halfcolor);
						my_rectangle($image,$x1,$yA,$x3,$yB,1,'white',$color);

					}

				} elsif ($graphtype =~ /^system/) {
					$average *= 1000;
					$average = 1 if ($average < 1);
#warn "$graphtype: $type $itemcode $average ($sum/$num) $deviation\n";
					my $y1;
					$y1 = int($top_add+$margin+$size_y)-int(log10($average)*$size_y/$top) if ($scale_type eq 'log');
					$y1 = int($top_add+$margin+$size_y)-int($average*$size_y/$top) if ($scale_type eq 'linear');
					my_rectangle($image,$x1,$y1,$x3,int($top_add+$margin+$size_y),1,$color,$color);

				} elsif ($graphtype =~ /^gasgiant/) {
					my $y1;
					$y1 = int($top_add+$margin+$size_y)-int(log10($num)*$size_y/$top) if ($scale_type eq 'log');
					$y1 = int($top_add+$margin+$size_y)-int($num*$size_y/$top) if ($scale_type eq 'linear');
					my_rectangle($image,$x1,$y1,$x3,int($top_add+$margin+$size_y),1,$color,$color);
				}
			}

			$x1 += $bar_width*2;
		}

		my $n = 0;
		my $per_row = 3;
		my $pointsize = 15;
		my $spacing = 300;
		my $startx  = $left_add+$margin+150;
		my $starty  = $top_add+$margin+$size_y+150;

		$per_row = 5 if ($graphtype =~ /gasgiant/);
		$spacing = 250 if ($graphtype =~ /starplanets/);
		$spacing = 150 if ($graphtype =~ /bodymetals/);

		foreach my $type (@typelist) {
			my ($name,$color) = ('','rgb(0,0,0)');

			my $xn = $n % $per_row;
			my $yn = int($n/$per_row);

			my $x1 = $startx+$xn*$spacing;
			my $y1 = $starty+$yn*($pointsize+5);
			my $x2 = $x1 + $pointsize;
			my $y2 = $y1 + $pointsize;

			$name = $keynames{$type};
			$color  = "rgb(".join(',',@{$colorkey{$type}}).")";

			$image->Draw( primitive=>'rectangle', stroke=>'#777', fill=>$color, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y2));
			$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>$name,x=>$x2+5,y=>$y2);
			$n++;
			
		}

		if ($graphtype =~ /bodymetals/) {
			my $n = 0;
			$per_row = 4;
			$pointsize = 15;
			$spacing = 260;
			$startx  = $left_add+$margin+720;
			$starty  = $top_add+$margin+$size_y+100;

			foreach my $type (@planetcodelist) {
				#next if ($type =~ /^(O|B|A|F|G|K|M)$/);

				my $name = '';

				foreach my $ck (@colorkey) {
					if ($ck =~ /^$type\|(.+)$/) {
						$name = "$type = $1";
						last;
					}
				}

				next if (!$name);
	
				my $xn = $n % $per_row;
				my $yn = int($n/$per_row);
	
				my $x1 = $startx+$xn*$spacing;
				my $y1 = $starty+$yn*($pointsize+5);
				my $x2 = $x1 + $pointsize;
				my $y2 = $y1 + $pointsize;
	
				$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>$name,x=>$x2,y=>$y2);
				$n++;
			}
		}

		if ($graphtype =~ /starplanets/) {
			my $n = 0;
			$per_row = 4;
			$pointsize = 15;
			$spacing = 150;
			$startx  = $left_add+$margin+1100;
			$starty  = $top_add+$margin+$size_y+150;

			foreach my $type (@starcodelist) {
				next if ($type =~ /^(O|B|A|F|G|K|M)$/);

				my $name = '';

				foreach my $ck (@colorkey) {
					if ($ck =~ /^$type\|(.+)$/) {
						$name = "$type = $1";
						last;
					}
				}

				next if (!$name);
	
				my $xn = $n % $per_row;
				my $yn = int($n/$per_row);
	
				my $x1 = $startx+$xn*$spacing;
				my $y1 = $starty+$yn*($pointsize+5);
				my $x2 = $x1 + $pointsize;
				my $y2 = $y1 + $pointsize;
	
				$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>$name,x=>$x2,y=>$y2);
				$n++;
			}
		}

		if ($graphtype eq 'bodymetals') {
			$image->Annotate(pointsize=>30,fill=>'white',text=>"Average Metallicity by Body Type",gravity=>'north',x=>0,y=>$margin-5);
		}
		if ($graphtype eq 'sectormassmetals') {
			$image->Annotate(pointsize=>30,fill=>'white',text=>"Average Gas Giant Metallicity per Sector by Mass Code",gravity=>'north',x=>0,y=>$margin-5);
		}
		if ($graphtype eq 'sectormassplanets') {
			$image->Annotate(pointsize=>30,fill=>'white',text=>"Valuable Planets per Sector by Mass Code",gravity=>'north',x=>0,y=>$margin-5);
		}
		if ($graphtype eq 'sectorstarplanets') {
			$image->Annotate(pointsize=>30,fill=>'white',text=>"Valuable Planets per Sector by Main Star Type",gravity=>'north',x=>0,y=>$margin-5);
		}
		if ($graphtype eq 'systemmassplanets') {
			$image->Annotate(pointsize=>30,fill=>'white',text=>"Average Valuable Planets per Thousand Systems by Mass Code",gravity=>'north',x=>0,y=>$margin-5);
		}
		if ($graphtype eq 'systemstarplanets') {
			$image->Annotate(pointsize=>30,fill=>'white',text=>"Average Valuable Planets per Thousand Systems by Main Star Type",gravity=>'north',x=>0,y=>$margin-5);
		}
		if ($graphtype eq 'gasgiant_helium') {
			$image->Annotate(pointsize=>30,fill=>'white',text=>"Average Gas Giants per Thousand within Helium Concentration Range",gravity=>'north',x=>0,y=>$margin-5);
		}

		if ($graphtype =~ /bodymetals/) {
			$image->Annotate(pointsize=>16,fill=>'white',text=>'Body Type',gravity=>'south',x=>-300,y=>$bottom_add/2+50);
		}
		if ($graphtype =~ /massplanets|massmetals/) {
			$image->Annotate(pointsize=>16,fill=>'white',text=>'Mass Code',gravity=>'south',x=>50,y=>$bottom_add/2+75);
		}
		if ($graphtype =~ /starplanets/) {
			$image->Annotate(pointsize=>16,fill=>'white',text=>'Main Star Type',gravity=>'south',x=>50,y=>$bottom_add/2+75);
		}
		if ($graphtype =~ /gasgiant/) {
			$image->Annotate(pointsize=>16,fill=>'white',text=>'Helium Percentage in Atmosphere',gravity=>'south',x=>50,y=>$bottom_add/2+75);
		}

		if ($graphtype =~ /bodymetals/) {
			$image->Annotate(pointsize=>16,fill=>'white',text=>"Average Elements per Body",rotate=>270,gravity=>'east',x=>$margin+$size_x+70,y=>-100);
			$image->Annotate(pointsize=>16,fill=>'white',x=>5,y=>5,text=>"Bright = Average,    Dark =  Avg. + Std. Deviation,    Hollow = Outliers / Max",gravity=>'southeast');
		}
		if ($graphtype =~ /^sector/) {
			$image->Annotate(pointsize=>16,fill=>'white',text=>"Valuable Planets per Sector",rotate=>270,gravity=>'east',x=>$margin+$size_x+70,y=>-100) if ($graphtype =~ /planets/);
			$image->Annotate(pointsize=>16,fill=>'white',text=>"Average Elements per Sector",rotate=>270,gravity=>'east',x=>$margin+$size_x+70,y=>-100) if ($graphtype =~ /metals/);
			$image->Annotate(pointsize=>16,fill=>'white',x=>5,y=>5,text=>"Bright = Average,    Dark =  Avg. + Std. Deviation,    Hollow = Outliers / Max",gravity=>'southeast');
		}
		if ($graphtype =~ /^system/) {
			$image->Annotate(pointsize=>16,fill=>'white',text=>"Valuable Planets per Thousand Systems",rotate=>270,gravity=>'east',x=>$margin+$size_x+70,y=>-100);
		}
		if ($graphtype =~ /^gasgiant/) {
			$image->Annotate(pointsize=>16,fill=>'white',text=>"Number of Gas Giants per Thousand within Helium Range",rotate=>270,gravity=>'east',x=>$margin+$size_x+70,y=>-180);
		}

		$image->Draw( primitive=>'rectangle', stroke=>'white', fill=>'none', strokewidth=>2,
			points=>sprintf("%u,%u %u,%u",$margin+$left_add,$margin+$top_add,$margin+$left_add+$size_x,$margin+$top_add+$size_y));

		$image->Annotate(pointsize=>12,fill=>'white',x=>5,y=>$bottom-5,text=>"$author - ".epoch2date(time));

		save_image($image,$fn);
	}


	# Exploration history per day:

	foreach my $graphtype (@perdaytypes) { eval {

		next if (!$gfile{$graphtype});
		my $fn = $gfile{$graphtype};

		my $show_days = 2400;

		my $size_x = $show_days;
		my $size_y = 600;
		my $startx = 10;
		my $margin = 50;
		my $bottom_add = 200;
		my $top_add = 70;
		my $left_add = 80;

		print "Starting $graphtype (".epoch2date(time).")\n";

		my $bottom = int(2*$margin+$size_y+$bottom_add+$top_add);
		my $right  = int($left_add+2*$margin+$size_x);

		my $image = Image::Magick->new(
			size  => $right.'x'.$bottom,
			type  => 'TrueColor',
			depth => 8,
			verbose => 'true'
		);
		$image->ReadImage('canvas:black');
		$image->Quantize(colorspace=>'RGB');

		my $highest = 0;
		my $threshold = 15;
		my $over_threshold = 0;

		foreach my $i (0..$show_days) {
			if ($graphtype eq 'newfinds') {
				$highest = $datedata{perday}{$i}{systems} if ($datedata{perday}{$i}{systems} > $highest);
				$highest = $datedata{perday}{$i}{planets} if ($datedata{perday}{$i}{planets} > $highest);
				$highest = $datedata{perday}{$i}{stars} if ($datedata{perday}{$i}{stars} > $highest);

			} elsif ($graphtype eq 'bodiespersystem') {
				#compress_graph_dates(epoch2date(($current_absolute_day-$i)*86400));

				if ($datedata{perday}{$i}{systems} > 0) {
					my $p = $datedata{perday}{$i}{planets} / $datedata{perday}{$i}{systems};
					my $s = $datedata{perday}{$i}{stars} / $datedata{perday}{$i}{systems};
	
					$datedata{perday}{$i}{p_persys} = $p;
					$datedata{perday}{$i}{s_persys} = $s;
	
					$highest = $p if ($p > $highest);
					$highest = $s if ($s > $highest);

					$over_threshold++ if ($p>$threshold || $s>$threshold);

					#print "DAYS_AGO=$i, $p/$s ($highest), out of $datedata{perday}{$i}{systems} systems\n";
				} else {
					$datedata{perday}{$i}{p_persys} = 0;
					$datedata{perday}{$i}{s_persys} = 0;
				}
			}
		}

		my $scale_interval = 0;
		my $scale_steps = 0;

		if ($graphtype eq 'newfinds') {
			$scale_interval = 25000;
			$scale_steps = floor($highest/$scale_interval)+1;
		} elsif ($graphtype eq 'bodiespersystem') {
			$scale_interval = 1;
			$scale_steps = floor($highest)+2;
			#$scale_interval = 10;
			#$scale_steps = 5;
		}

		my $top = $scale_steps*$scale_interval;

		if ($top>$threshold && $over_threshold<10 && $graphtype eq 'bodiespersystem') {
			$top = $threshold;
			$scale_steps = $threshold;
			$scale_interval = 1;
		}

		#print "1 highest = $highest; scale_steps = $scale_steps, scale_interval = $scale_interval\n";

		for (my $n=0; $n<=$scale_steps; $n++) {
			my $c = $n * $scale_interval;
		
			my $x = $margin+$left_add;
			my $y = int(($top_add+$margin+$size_y)-($n*$size_y/$scale_steps));

			my $t = commify($c);

			$image->Annotate(pointsize=>12,fill=>'white',gravity=>'northeast',text=>$t,x=>$size_x+$margin+7,y=>$y+5);
			$image->Draw( primitive=>'line', stroke=>'rgb(50,50,50)', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$y,$x+$size_x,$y));
			$image->Draw( primitive=>'line', stroke=>'white', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$y,$x-5,$y));
		}

		my $done = 0;
		my @t = localtime;
		my $year = $t[5]+1900;
		my $month = $t[4]+1;

		while (!$done) {
			my $days_ago = $current_absolute_day - floor(date2epoch(sprintf("%04u-%02u-01 00:00:00",$year,$month))/86400);
			
			if ($days_ago>$show_days) {
				$done = 1;
				last;
			}
			
			my $x = $left_add+$margin+$size_x-$days_ago;

			my $monthyear = sprintf("%04u.%02u",$year,$month);

			$image->Annotate(pointsize=>14,fill=>'white',text=>$monthyear,gravity=>'northwest',rotate=>90,x=>$x+11,y=>$top_add+$margin+$size_y+10) 
				if ($days_ago > 25 && $days_ago < $show_days);

			$image->Draw( primitive=>'line', stroke=>'white', strokewidth=>1, points=>sprintf("%u,%u %u,%u",
				$x,$top_add+$margin+$size_y+1,$x,$top_add+$margin+$size_y+10)) if ($days_ago<$show_days);

			$month--;
			if ($month<1) {
				$month += 12;
				$year--;
			}
		}


		$show_days--;

		my @item_list = qw(stars planets systems);
		@item_list = qw(p_persys s_persys) if ($graphtype eq 'bodiespersystem');

		my %colorkey = ();

		$colorkey{systems} = 'rgb(0,255,0)';
		$colorkey{planets} = 'rgb(80,112,255)';
		$colorkey{stars}   = 'rgb(255,0,0)';
		$colorkey{p_persys} = $colorkey{planets};
		$colorkey{s_persys} = $colorkey{stars};

		my %drew = ();

		foreach my $n (0..$show_days) {
			my $x = int($left_add+$margin)+$size_x-$n;

			foreach my $item (@item_list) {
				my $value = $datedata{perday}{$n}{$item};
				$value = 0 if ($value<0);

				my $y1 = my $y2 = floor(($top_add+$margin+$size_y)-($value*$size_y/$top));

				if ($n > 0 && $y1 > $drew{$item}{$n-1}{y1} && $y1 > $drew{$item}{$n-1}{y2}) {
					$y2 = $drew{$item}{$n-1}{y1};
					$y2 = $drew{$item}{$n-1}{y2} if ($drew{$item}{$n-1}{y2} > $drew{$item}{$n-1}{y1});
				}

				if ($n > 0 && $y1 < $drew{$item}{$n-1}{y1} && $y1 < $drew{$item}{$n-1}{y2}) {
					$y2 = $drew{$item}{$n-1}{y1};
					$y2 = $drew{$item}{$n-1}{y2} if ($drew{$item}{$n-1}{y2} < $drew{$item}{$n-1}{y1});
				}

				$y1 = $top_add+$margin if ($y1 < $top_add+$margin);
				$y2 = $top_add+$margin if ($y2 < $top_add+$margin);
				$y1 = $top_add+$margin+$size_y if ($y1 > $top_add+$margin+$size_y);
				$y2 = $top_add+$margin+$size_y if ($y2 > $top_add+$margin+$size_y);

				additive_line($image,$x,$y1,$y2,$colorkey{$item});

				$drew{$item}{$n}{y1} = $y1;
				$drew{$item}{$n}{y2} = $y2;
			}
		}

		my $x1 = 800;
		$x1 += 100 if (int(@item_list) == 2);
		my $y1 = $top_add+$margin+$size_y+160;
		my $pointsize = 16;

		foreach my $item (@item_list) {
			my $c  = $colorkey{$item};

			my $x2 = $x1 + $pointsize;
			my $y2 = $y1 + $pointsize;

			my $name = 'Systems';
			$name = 'Planets' if ($item =~ /planets|p_/);
			$name = 'Stars' if ($item =~ /stars|s_/);

			$image->Draw( primitive=>'rectangle', stroke=>'#777', fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y2));
			$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>$name,x=>$x2+5,y=>$y2);
			$x1 += 200;
		}

		if ($graphtype eq 'newfinds') {
			$image->Annotate(pointsize=>30,fill=>'white',text=>"New Systems and Body Scan Submissions per Day",gravity=>'north',x=>0,y=>$margin-5);
		}
		if ($graphtype eq 'bodiespersystem') {
			$image->Annotate(pointsize=>30,fill=>'white',text=>"Bodies per System, per Day",gravity=>'north',x=>0,y=>$margin-5);
		}

		$image->Annotate(pointsize=>16,fill=>'white',text=>'Date',gravity=>'south',x=>50,y=>$bottom_add/2+60);
		$image->Annotate(pointsize=>16,fill=>'white',text=>"Submissions per Day",rotate=>270,gravity=>'east',x=>$margin+$size_x+90,y=>-100);

		$image->Draw( primitive=>'rectangle', stroke=>'white', fill=>'none', strokewidth=>2,
			points=>sprintf("%u,%u %u,%u",$margin+$left_add,$margin+$top_add,$margin+$left_add+$size_x,$margin+$top_add+$size_y));

		$image->Annotate(pointsize=>12,fill=>'white',x=>5,y=>$bottom-5,text=>"$author - ".epoch2date(time));

		save_image($image,$fn);

	};
	print "ERROR: $@\n" if ($@);
	}



}

sub save_image {
	my ($image, $fn) = @_;

	my $tmp = $fn;
	$tmp =~ s/\.png/.bmp/;

	print "Writing $fn ($tmp)\n";

	$image->Set(depth => 8);
	my $res = $image->Write( filename => $tmp );
	if ($res) {
		warn $res;
	}

	my $thumb = $fn;
	$thumb =~ s/\.png$/-thumb.jpg/;

	my_system("$convert $tmp $fn");
	my_system("$convert $fn -verbose -resize 200x200 -gamma 1.3 -set gamma 0.454545 $thumb");
	my_system("$scp $fn $thumb $remote_server") if (!$debug && $allow_scp);
	my_system("/usr/bin/rm -f $tmp");
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

sub pixels_from_string {
	my $s = shift;
	$s =~ s/^[^\d]+//s;
	$s =~ s/[^\d]+$//s;
	return split ',', $s;
}

sub additive_line {
	my ($image,$x,$y1,$y2,$color) = @_;
	my $orig_pixels = float_colors(pixels_from_string($color));

	if ($y2<$y1) {
		my $temp = $y1;
		$y1 = $y2;
		$y2 = $temp;
	}

	foreach my $y ($y1..$y2) {
		my @pixels = @$orig_pixels;

		my @p = $image->GetPixel(x=>$x,y=>$y);
		#print "GetPixel($x,$y) = $p[0], $p[1], $p[2]\n";

		if ($p[0] < 0.5 && $p[1] < 0.5 && $p[1] < 0.5) {
			#print "SetPixel($x,$y) = $pixels[0], $pixels[1], $pixels[2]\n";
			$image->SetPixel(x=>$x,y=>$y,color=>\@pixels);
		} else {
			my $highest = 0;
			foreach my $i (0..2) {
				$pixels[$i] += $p[$i];
				$highest = $pixels[$i] if ($pixels[$i] > $highest);
			}

			if ($highest > 0 && $highest != 1) {
				foreach my $i (0..2) {
					$pixels[$i] /= $highest;
				}
			}

			$image->SetPixel(x=>$x,y=>$y,color=>\@pixels);
			#print "SetPixel($x,$y) = $pixels[0], $pixels[1], $pixels[2]\n" if ($highest>1);
		}
	}
}

sub my_rectangle {
	my ($image,$x1,$y1,$x2,$y2,$strokewidth,$color,$fill) = @_;

	#print "Rectangle for $maptype: $x1,$y1,$x2,$y2,$strokewidth,$color\n";

	return if ($x1 < 0 || $y1 < 0 || $x2 < 0 || $y2 < 0);

	if ($fill) {

		$image->Draw( primitive=>'rectangle', stroke=>$color, fill=>$fill, strokewidth=>$strokewidth,
			points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y2));

	} else {

		$image->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
			points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y1));
	
		$image->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
			points=>sprintf("%u,%u %u,%u",$x1,$y2,$x2,$y2));
	
		$image->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
			points=>sprintf("%u,%u %u,%u",$x1,$y1,$x1,$y2));
	
		$image->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
			points=>sprintf("%u,%u %u,%u",$x2,$y1,$x2,$y2));
	}
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
			@rows = db_mysql('elite',"select starID as localID,isPrimary,bodyId64,systemId64,subType,absoluteMagnitude,".
					"luminosity,surfaceTemperature,age,updateTime,discoveryDate ".
					"from stars where systemId64 in $id_list and deletionState=0");
			1;
		};

		unless($ok) {
			print "\n$@\n";
			$retry++;
		}
	}
	print "No stars returned\n" if (($debug || $verbose) && !@rows);
	

	foreach my $r (@rows) {	
		my $subType = $$r{subType};

		my $starType = '';
		$starType = 'D' if ($subType =~ /dwarf/i);
		$starType = 'G' if ($subType =~ /giant/i);
		$starType = 'S' if ($subType =~ /super/i);

		$$r{starType} = $starType;
		my $class = abbreviate_star($subType);

		if ($$r{age}) {
			$$r{age} = 'a'.int(log10($$r{age}));
		} else {
			$$r{age} = undef;
		}

		print "! Unused star type: [".$$r{systemId64}."] $subType\n" if (!$class);

		$$r{subType} = $class;
		$$r{star} = 1;

		%{$$body_ref{$$r{systemId64}}{$$r{localID}}} = %$r;
	}


	@rows  = ();
	$retry = 0;
	$ok = undef;

	while (!$ok && $retry < 3) {
		$ok = eval {
			@rows = db_mysql('elite',"select planetID as localID,bodyId64,systemId64,subType,terraformingState,gravity,".
					"surfaceTemperature,earthMasses,updateTime,discoveryDate ".
					"from planets where systemId64 in $id_list and deletionState=0");
			1;
		};

		unless($ok) {
			print "\n$@\n";
			$retry++;
		}
	}
	print "No planets returned\n" if (($debug || $verbose) && !@rows);


	my %atmo = ();
	my @planet_ids = ();

	foreach my $r (@rows) {
		push @planet_ids, $$r{localID}; # if ($$r{subType} =~ /giant/i);
	}

	if (@planet_ids) {

		my @atmos =  db_mysql('elite',"select planet_id as id,helium as he,hydrogen as h from atmospheres where planet_id in (".join(',',@planet_ids).")");
		foreach my $r (@atmos) {
			$atmo{$$r{id}} = $r;
			delete($atmo{$$r{id}}{id});
		}
	}
	

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

		#if ($atmo{$$r{localID}}{he} || $atmo{$$r{localID}}{h} || ($class =~ /WG|ELW/ && ref($atmo{$$r{localID}}) eq 'HASH' && keys(%{$atmo{$$r{localID}}}))) {
		if ($atmo{$$r{localID}} && ref($atmo{$$r{localID}}) eq 'HASH' && keys(%{$atmo{$$r{localID}}})) {
			$$r{he} = $atmo{$$r{localID}}{he}+0;
			$$r{h}  = $atmo{$$r{localID}}{h}+0;
			$$r{metals} = 100-($$r{he}+$$r{h});
		}
		
		print "! Unused planet type: [".$$r{systemId64}."] $subType\n" if (!$class);

		$$r{subType} = $class;

		%{$$body_ref{$$r{systemId64}}{$$r{localID}+$id_add}} = %$r;
	}
}

sub abbreviate_star {
	my $subType = shift;
	my $class = '';

	if ($subType =~ /^\s*(\S)\s+.*(star|dwarf)/i) {
		$class = uc($1);
	}
	$class = 'BD' if ($subType =~ /brown/i);
	$class = 'WD' if ($subType =~ /white.*dwarf/i);
	$class = 'NS' if ($subType =~ /neutron/i);
	$class = 'TT' if ($subType =~ /tauri/i);
	$class = 'HE' if ($subType =~ /herbig/i);
	$class = 'BH' if ($subType =~ /black hole/i);
	$class = 'C' if ($subType =~ /carbon/i || $subType =~ /^(C|S|MS|CN|CJ)[\-\s](type|star)/i);
	$class = 'WR' if ($subType =~ /wolf|rayet/i || $subType =~ /^Wolf-Rayet/);
	$class = 'U' if (!$class);

	return $class;
}


sub truncate_num {
	my $n = shift;
	$n =~ s/\..*$//;
	return int($n);
}

sub log2 {
        my $n = shift;
        return 0 if (!$n);
        return log($n)/log(2);
}

############################################################################





