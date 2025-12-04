#!/usr/bin/perl
use strict;

# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

#####################################################################

use utf8;
use feature qw( unicode_strings );

use JSON;
use POSIX qw(floor);

use lib "/home/bones/perl";
use DB qw(rows_mysql db_mysql);
use ATOMS qw(btrim parse_csv make_csv epoch2date date2epoch);
use lib "/home/bones/elite";
use EDSM qw(commify system_coordinates get_id64_by_name);

#####################################################################

my $CSVfile	= 'edsmPOI.csv';

open OUT, ">$CSVfile";
print OUT make_csv('POI Type','ID','Name','X','Y','Z','Reference System','Notes')."\r\n";

my %ggg  = ();
my %pn   = ();
my %neb  = ();
my %cc   = ();
my %seen = ();

my %POIname = ();

my %carrierJSONs = ();

my $count = 0;

my %exclude = ();

open TXT, "<POIstuff/exclusions.csv";	# Right now it's one column
while (<TXT>) {
	chomp;
	$exclude{lc($_)} = 1 if ($_);
}
close TXT;

open TXT, "<RAXXLA.txt";
my $raxxla_time = <TXT>; chomp $raxxla_time;
my $raxxla_system = <TXT>; chomp $raxxla_system;
my ($x,$y,$z) = (<TXT>,<TXT>,<TXT>);
close TXT;

chomp $x;
chomp $y;
chomp $z;

if (time - $raxxla_time > 3.5*86400 || !$raxxla_system || !$raxxla_time || (!$x && !$y && !$z)) {
	# Choose new.

	my @max = db_mysql('elite',"select max(ID) as maxID from systems");
	my $maxID = ${$max[0]}{maxID};
	srand(time()^($$+($$ << 15)));

	my $ok = 0;
	while (!$ok) {
		my $id = int(rand $maxID);
		warn "$id\n";
		my @rows = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where ID=? and deletionState=0 and ".
					"coord_x is not null and coord_y is not null and coord_z is not null",[$id]);

		if (@rows) {
			my $r = shift @rows;
			($raxxla_system,$x,$y,$z) = ($$r{name},$$r{coord_x},$$r{coord_y},$$r{coord_z});
			$ok = 1;
		}
	}

	open TXT, ">RAXXLA.txt";
	print TXT time."\n";
	print TXT "$raxxla_system\n";
	print TXT "$x\n";
	print TXT "$y\n";
	print TXT "$z\n";
	close TXT;

}
print join("\t|\t",'raxxla',"919191919191",'Raxxla',$x,$y,$z,$raxxla_system,undef,undef)."\n";


warn "[NEBULAE]\n";
#"Designation","Nebula / Star name","Region","FD by CMDR","Submitted by","Catalogue nickname","GMP nickname","Notes","Verified?","Model","","","","","","","","","","","","","","","","","",""

open CSV, "<nebulae-planetary.csv";
	my %header = ();
	my $h = <CSV>; chomp $h;
	my @v = parse_csv($h);
	my $n = 0;
	foreach my $s (@v) {
		$header{system} = $n if ($s =~ /Star name/i);
		$header{ID} = $n if ($s =~ /Designation/i);
		$header{notes} = $n if ($s =~ /Notes/);
		$header{GMPname} = $n if ($s =~ /nickname/);
		$header{nickname} = $n if ($s =~ /Catalogue nickname/);
		$header{region} = $n if ($s =~ /Region/);
		$n++;
	}
	foreach my $line (<CSV>) {
		chomp $line;
		next if (!$line);
		my @v = parse_csv($line);
		next if (!@v);

		my ($x, $y, $z) = (undef, undef, undef);
		my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where name=? and deletionState=0",[($v[$header{system}])]);
		foreach my $r (@rows) {
			$x = $$r{coord_x};
			$y = $$r{coord_y};
			$z = $$r{coord_z};
		}

		my $name = $v[$header{system}];
		$name = $v[$header{GMPname}] if ($header{GMPname} && $v[$header{GMPname}] && $v[$header{GMPname}] !~ /^\s*none\s*$/i);
		$name = $v[$header{nickname}] if ($header{nickname} && $v[$header{nickname}] && $v[$header{nickname}] !~ /^\s*none\s*$/i);

		if ($x =~ /[^\d\.\-]/ || $y =~ /[^\d\.\-]/ || $z =~ /[^\d\.\-]/ || (!$x && !$y && !$z)) {
			#warn "PN SKIPPED: [$count] $v[$header{system}] no coords.\n";
			next;
		}
	
		if (!$pn{uc($v[$header{system}])}) {
			$count++;
			#warn "PN FOUND: [$v[$header{ID}]] $v[$header{system}] ($x,$y,$z)\n";
			$pn{uc($v[$header{system}])} = join("\t|\t",'planetaryNebula',$v[$header{ID}],$name,$x,$y,$z,$v[$header{system}],undef,undef);
			print OUT make_csv('planetaryNebula',$v[$header{ID}],$name,$x,$y,$z,$v[$header{system}],undef)."\r\n";
		} else {
			# Already in hash
		}
	}
close CSV;

# "Designation","Nebula name","Central Star?","Central Star / Ref. System","Region","Notes","","","","","","","","","","","","","","","","","",""

open CSV, "<nebulae-real.csv";
	my %header = ();
	my $h = <CSV>; chomp $h;
	my @v = parse_csv($h);
	my $n = 0;
	foreach my $s (@v) {
		$header{system} = $n if ($s =~ /Ref\.? system/i);
		$header{ID} = $n if ($s =~ /Designation/i);
		$header{notes} = $n if ($s =~ /Notes/);
		$header{GMPname} = $n if ($s =~ /Nebula name/);
		$header{nickname} = $n if ($s =~ /nickname/);
		$header{region} = $n if ($s =~ /Region/i);
		$n++;
	}
	foreach my $line (<CSV>) {
		chomp $line;
		next if (!$line);
		my @v = parse_csv($line);
		next if (!@v);

		my ($x, $y, $z) = (undef, undef, undef);
		my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where name=? and deletionState=0",[($v[$header{system}])]);
		foreach my $r (@rows) {
			$x = $$r{coord_x};
			$y = $$r{coord_y};
			$z = $$r{coord_z};
		}

		my $name = $v[$header{system}];
		$name = $v[$header{GMPname}] if ($header{GMPname} && $v[$header{GMPname}] && $v[$header{GMPname}] !~ /^\s*none\s*$/i);
		$name = $v[$header{nickname}] if ($header{nickname} && $v[$header{nickname}] && $v[$header{nickname}] !~ /^\s*none\s*$/i);

		if ($x =~ /[^\d\.\-]/ || $y =~ /[^\d\.\-]/ || $z =~ /[^\d\.\-]/ || (!$x && !$y && !$z)) {
			#warn "NEBULA SKIPPED: [$count] $v[$header{system}] no coords.\n";
			next;
		}
	
		if (!$neb{uc($v[$header{system}])}) {
			$count++;
			#warn "NEBULA FOUND: [$v[$header{ID}]] $v[$header{system}] ($x,$y,$z)\n";
			$neb{uc($v[$header{system}])} = join("\t|\t",'nebula',$v[$header{ID}],$name,$x,$y,$z,$v[$header{system}],undef,undef);
			print OUT make_csv('nebula',$v[$header{ID}],$name,$x,$y,$z,$v[$header{system}],undef)."\r\n";
		} else {
			# Already in hash
		}
	}
close CSV;

# "Designation","Nebula name","Region","R. Number","Reference system","Notes","","","","","","","","","","","","","","","",""

open CSV, "<nebulae-procgen.csv";
	my %header = ();
	my $h = <CSV>; chomp $h;
	my @v = parse_csv($h);
	my $n = 0;
	foreach my $s (@v) {
		$header{system} = $n if ($s =~ /Reference system/i);
		$header{ID} = $n if ($s =~ /Designation/i);
		$header{notes} = $n if ($s =~ /Notes/i);
		$header{GMPname} = $n if ($s =~ /Nebula name/i);
		$header{nickname} = $n if ($s =~ /nickname/i);
		$n++;
	}
	foreach my $line (<CSV>) {
		chomp $line;
		next if (!$line);
		my @v = parse_csv($line);
		next if (!@v);

		my ($x, $y, $z) = (undef, undef, undef);

		my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where name=? and deletionState=0",[($v[$header{system}])]);
		foreach my $r (@rows) {
			$x = $$r{coord_x};
			$y = $$r{coord_y};
			$z = $$r{coord_z};
		}

		my $name = $v[$header{system}];
		$name = $v[$header{GMPname}] if ($header{GMPname} && $v[$header{GMPname}] && $v[$header{GMPname}] !~ /^\s*none\s*$/i);
		$name = $v[$header{nickname}] if ($header{nickname} && $v[$header{nickname}] && $v[$header{nickname}] !~ /^\s*none\s*$/i);

		if ($x =~ /[^\d\.\-]/ || $y =~ /[^\d\.\-]/ || $z =~ /[^\d\.\-]/ || (!$x && !$y && !$z)) {
			#warn "NEBULA SKIPPED: [$count] $v[$header{system}] no coords.\n";
			next;
		}
	
		if (!$neb{uc($v[$header{system}])}) {
			$count++;
			#warn "NEBULA FOUND: [$v[$header{ID}]] $v[$header{system}] ($x,$y,$z)\n";
			$neb{uc($v[$header{system}])} = join("\t|\t",'nebula',$v[$header{ID}],$name,$x,$y,$z,$v[$header{system}],undef,undef);
			print OUT make_csv('nebula',$v[$header{ID}],$name,$x,$y,$z,$v[$header{system}],undef)."\r\n";
		} else {
			# Already in hash
		}
	}
close CSV;

warn "[GGG]\n";

foreach my $file ('GGG.csv','GGG2.csv') {
	open CSV, "<$file";
	my %header = ();
	my $h = <CSV>; chomp $h;
	my @v = parse_csv($h);
	my $n = 0;
	foreach my $s (@v) {
		$header{system} = $n if ($s =~ /System/);
		$header{planet} = $n if ($s =~ /Planet/);
		$header{type} = $n if ($s =~ /Giant Type/);
		$header{coords} = $n if ($s =~ /ordinate/);
		$header{x} = $n if ($s =~ /Coord X/i);
		$header{y} = $n if ($s =~ /Coord Y/i);
		$header{z} = $n if ($s =~ /Coord Z/i);
		$header{GMPname} = $n if ($s =~ /GMP/);
		$header{quality} = $n if ($s =~ /Quality/);
		$n++;
	}
	foreach my $line (<CSV>) {
		chomp $line;
		next if (!$line);
		my @v = parse_csv($line);
		next if (!@v);
	
		my ($x,$y,$z) = split /[\s\/\|]+/, $v[$header{coords}];
		$x = $v[$header{x}] if ($header{x} && $v[$header{x}]);
		$y = $v[$header{y}] if ($header{y} && $v[$header{y}]);
		$z = $v[$header{x}] if ($header{z} && $v[$header{z}]);
	
		my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where name=? and deletionState=0",[($v[$header{system}])]);
		foreach my $r (@rows) {
			$x = $$r{coord_x};
			$y = $$r{coord_y};
			$z = $$r{coord_z};
		}

		my $name = $v[$header{system}].' '.$v[$header{planet}];
		$name .= ": $v[$header{GMPname}]" if ($header{GMPname} && $v[$header{GMPname}] && $v[$header{GMPname}] !~ /^\s*none\s*$/i);

		if ($x =~ /[^\d\.\-]/ || $y =~ /[^\d\.\-]/ || $z =~ /[^\d\.\-]/ || (!$x && !$y && !$z)) {
			warn "GGG SKIPPED ($file): [$count] $v[$header{system}] no coords.\n";
			next;
		}
	
		if (!$ggg{uc($v[$header{system}])}) {
			$count++;
			warn "GGG FOUND ($file): [$count] $v[$header{system}] ($x,$y,$z)\n";
			$ggg{uc($v[$header{system}])} = join("\t|\t",'GGG',$count,$name,$x,$y,$z,$v[$header{system}],'GGG',undef);
			print OUT make_csv('GGG',$count,$name,$x,$y,$z,$v[$header{system}],undef)."\r\n";
		} else {
			# Already in hash
		}
	}
	close CSV;
}

my %tri = ();
$count = 0;

# FROM: https://script.google.com/macros/s/AKfycbx6cEi2RRVZum98jZinXqzyK74RrHPVF71Qlmg8HEE1Z6e-4FLw/exec
#       https://docs.google.com/spreadsheets/d/1DfcVCHYgPHZnxUmsrGWXKdNK-2iz7t2MG80EGGW9XGI/edit#gid=0

if (0) {	##### DISABLED #####

warn "[TRIT]\n";
print "TRIT FILE 1: tritium.csv\n";
open CSV, "<tritium.csv";
	my %header = ();
	my $h = <CSV>; chomp $h;
	my @v = parse_csv($h);
	my $n = 0;
	foreach my $s (@v) {
		$header{x} = $n if ($s =~ /^\s*x\s*$/i);
		$header{y} = $n if ($s =~ /^\s*y\s*$/i);
		$header{z} = $n if ($s =~ /^\s*z\s*$/i);
		$header{system} = $n if ($s =~ /system/i);
		$header{ring} = $n if ($s =~ /ring name/i);
		$header{type} = $n if ($s =~ /classification/i);
		$n++;
	}

	if (!$header{z}) {
		$header{x} = 0;
		$header{y} = 2;
		$header{z} = 1;
	}

	foreach my $line (<CSV>) {
		chomp $line;
		next if (!$line);
		my @v = parse_csv($line);
		next if (!@v);
	
		my ($x,$y,$z) = split /[\s\/\|]+/, $v[$header{coords}];
		$x = $v[$header{x}];
		$y = $v[$header{y}];
		$z = $v[$header{z}];

		my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where name=? and deletionState=0",[($v[$header{system}])]);
		foreach my $r (@rows) {
			$x = $$r{coord_x};
			$y = $$r{coord_y};
			$z = $$r{coord_z};
		}

		next if (sqrt($x**2 + $y**2 + $z**2) < 500);

		my $type = '';

		if ($v[$header{type}] =~ /(\(Tri\d+\))/i) {
			$type = $1;
		}

		next if (!$v[$header{ring}] || !$type);

		my $name = $v[$header{ring}]." ".$type;

		if ($x =~ /[^\d\.\-]/ || $y =~ /[^\d\.\-]/ || $z =~ /[^\d\.\-]/ || (!$x && !$y && !$z)) {
			warn "TRIT SKIPPED: [$count] $v[$header{system}] no coords.\n";
			next;
		}
	
		if (!$tri{$v[$header{system}]}) {
			$count++;
			warn "TRIT FOUND: [$count] $v[$header{system}] ($x,$y,$z)\n";
			$tri{$v[$header{system}]} = join("\t|\t",'tritium',$count,$name,$x,$y,$z,$v[$header{system}],undef,undef);
			print OUT make_csv('tritium',$count,$name,$x,$y,$z,$v[$header{system}],undef)."\r\n";
		} else {
			# Already in hash
		}
		
	}
close CSV;
print "TRIT FILE 2: tritium2.csv\n";
open CSV, "<tritium2.csv";
	my %header = ();
	my $h = <CSV>; chomp $h;
	my @v = parse_csv($h);
	my $n = 0;
	#"entry","System Name","Galactic Sector","Body","# of Hotspots","Overlapping?","FARK Command","Distance from Colonia","","Distance from Sol","","Discovered By","Discovered on (MM/DD/YY)","Ring/Ls from star","Discord Image link ","TriPN Entry (Admin)","","","","","","","","","","","","","",""
	foreach my $s (@v) {
		$header{system} = $n if ($s =~ /System/i);
		$header{ring} = $n if ($s =~ /Body/i);
		$header{type} = $n if ($s =~ /Overlap/i);
		$header{hotspots} = $n if ($s =~ /Hotspots/i);
		$n++;
	}

	foreach my $line (<CSV>) {
		chomp $line;
		next if (!$line);
		my @v = parse_csv($line);
		next if (!@v);

		next if ($v[$header{type}] eq 'No' || $v[$header{type}] !~ /x[2-9]/);
	
		my ($x, $y, $z) = (undef, undef, undef);
		my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where name=? and deletionState=0",[($v[$header{system}])]);
		foreach my $r (@rows) {
			$x = $$r{coord_x};
			$y = $$r{coord_y};
			$z = $$r{coord_z};
		}

		next if (sqrt($x**2 + $y**2 + $z**2) < 500);

		my $type = '';

		if ($v[$header{type}] =~ /x(\d+)/i) {
			$type = 'Tri'.$1;
		}

		#next if (!$v[$header{ring}] || !$type);
		next if (!$type);

#print "TRIT2: $v[$header{system}], $v[$header{ring}], $v[$header{type}] \n";

		my $name = $v[$header{system}];
		$name .= ' '.$v[$header{ring}] if ($v[$header{system}] !~ /\s+$v[$header{ring}]\s*$/);
		$name .= $type;

		if ($x =~ /[^\d\.\-]/ || $y =~ /[^\d\.\-]/ || $z =~ /[^\d\.\-]/ || (!$x && !$y && !$z)) {
			warn "TRIT SKIPPED: [$count] $v[$header{system}] no coords.\n";
			next;
		}
	
		if (!$tri{$v[$header{system}]}) {
			$count++;
			warn "TRIT FOUND: [$count] $v[$header{system}] ($x,$y,$z)\n";
			$tri{$v[$header{system}]} = join("\t|\t",'tritium',$count,$name,$x,$y,$z,$v[$header{system}],undef,undef);
			print OUT make_csv('tritium',$count,$name,$x,$y,$z,$v[$header{system}],undef)."\r\n";
		} else {
			# Already in hash
		}
		
	}
close CSV;
}


# Tritium Highway
my %trit_hwy = ();
$count = 0;
print "Tritium Highway: trit_highway.csv\n";
open CSV, "<trit_highway.csv";
	my %header = ();
	my $h = <CSV>; chomp $h;
	my @v = parse_csv($h);
	my $n = 0;
#"SYSTEM","BODY 1","BODY 2","NOTES","QUALITY","HIGHWAY"
#"DRYOOE PROU WW-H C24-533","A4","","","","COLONIA NORTH"
#type

	foreach my $s (@v) {
		$header{system} = $n if ($s =~ /SYSTEM/i);
		$header{body1} = $n if ($s =~ /Body 1/i);
		$header{body2} = $n if ($s =~ /Body 2/i);
		$header{notes} = $n if ($s =~ /notes/i);
		#$header{quality} = $n if ($s =~ /quality/i);
		#$header{highway} = $n if ($s =~ /highway/i);
		$header{color} = $n if ($s =~ /COLOR/i);
		$n++;
	}

	foreach my $line (<CSV>) {
		chomp $line;
		next if (!$line);
		my @v = parse_csv($line);
		next if (!@v);

		my ($x, $y, $z) = (undef, undef, undef);
		my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where name=? and deletionState=0",[($v[$header{system}])]);
		foreach my $r (@rows) {
			$x = $$r{coord_x};
			$y = $$r{coord_y};
			$z = $$r{coord_z};
		}

		my $C = '';

		if ($v[$header{color}] && $v[$header{color}] =~ /(ORANGE|WHITE)/i) {
			$C = uc($v[$header{color}]);
		}

		next if (sqrt($x**2 + $y**2 + $z**2) < 500);

		#my $name = $v[$header{highway}].': '.$v[$header{system}];
		#my $name = $v[$header{system}];
		my $name = "Tritium Highway";

		if ($x =~ /[^\d\.\-]/ || $y =~ /[^\d\.\-]/ || $z =~ /[^\d\.\-]/ || (!$x && !$y && !$z)) {
			warn "TRIT SKIPPED: [$count] $v[$header{system}] no coords.\n";
			next;
		}

		my $notes = $v[$header{notes}];

#		if ($v[$header{quality}]) {
#			$notes = "Quality: $v[$header{quality}]\\n$notes";
#		}

		if ($v[$header{body1}] || $v[$header{body2}]) {
			my @list = ();
			push @list, btrim($v[$header{body1}]) if ($v[$header{body1}] =~ /\S+/);
			push @list, btrim($v[$header{body2}]) if ($v[$header{body2}] =~ /\S+/);
			$notes = "Body: ".join(', ', @list)."\\n$notes";
		}
	
		if (!$tri{$v[$header{system}]}) {
			$count++;
			warn "TRIT FOUND: [$count] $v[$header{system}] ($x,$y,$z)\n";
			$trit_hwy{$v[$header{system}]} = join("\t|\t",'trit_hwy'.$C,$count,$name,$x,$y,$z,$v[$header{system}],undef,$notes);
			print OUT make_csv('trit_hwy'.$C,$count,$name,$x,$y,$z,$v[$header{system}],$notes)."\r\n";
		} else {
			# Already in hash
		}
		
	}
close CSV;


warn "[CANONN]\n";

# CANONN challenge

open CSV, "<canonn-challenge.csv";
	my %header = ();
	my $h = <CSV>; chomp $h;
	my @v = parse_csv($h);
	my $n = 0;
	foreach my $s (@v) {
		$header{ID} = $n if ($s =~ /^\s*1\*$/i);
		$header{system} = $n if ($s =~ /System/i);
		$header{notes} = $n if ($s =~ /Feature/);
		$header{region} = $n if ($s =~ /Region/);
		$n++;
	}
	foreach my $line (<CSV>) {
		chomp $line;
		next if (!$line);
		my @v = parse_csv($line);
		next if (!@v);

		my ($x, $y, $z) = (undef, undef, undef);
		my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where name=? and deletionState=0",[($v[$header{system}])]);
		foreach my $r (@rows) {
			$x = $$r{coord_x};
			$y = $$r{coord_y};
			$z = $$r{coord_z};
		}

		my $name = $v[$header{system}];
		my $id = 'CC'.int($v[$header{ID}]-1);

		if ($x =~ /[^\d\.\-]/ || $y =~ /[^\d\.\-]/ || $z =~ /[^\d\.\-]/ || (!$x && !$y && !$z)) {
			warn "CANONN CHALLENEGE SKIPPED: [$count] $v[$header{system}] no coords.\n";
			next;
		}
	
		$count++;
		warn "CANONN CHALLENEGE FOUND: [$id] $v[$header{system}] ($x,$y,$z)\n";
		print join("\t|\t",'canonn',$id,$name,$x,$y,$z,$v[$header{system}],'canonn',$v[$header{notes}])."\r\n";
		print OUT make_csv('canonn',$id,$name,$x,$y,$z,$v[$header{system}],$v[$header{notes}])."\r\n";
	}
close CSV;


# Marx's Codex Completionist List

my $ccl_num = 0;

open CSV, "<codex_completionist_nsp.csv";
open CSV, "<codex_completionist_horizon_bio.csv";
open CSV, "<codex_completionist_odyssey_bio_regions.csv";
foreach my $fn ('codex_completionist_nsp.csv','codex_completionist_horizon_bio.csv','codex_completionist_odyssey_bio_regions.csv') {
	open CSV, "<$fn";

	my %header = ();
	my $h = <CSV>; chomp $h;
	my @v = parse_csv($h);
	my $n = 0;
	foreach my $s (@v) {
		$header{system} = $n if ($s =~ /System/i);
		$header{feature} = $n if ($s =~ /feature/i);
		$header{species} = $n if ($s =~ /species/i);
		$header{notes} = $n if ($s =~ /regions|notes/i);
		$header{discoverer} = $n if ($s =~ /discover/i);
		$n++;
	}
	


	my $type = 'CCLNSP';
	$type = 'CCLHBIO' if ($fn =~ /horizon/i);
	$type = 'CCLOBIO' if ($fn =~ /odyssey/i);


	foreach my $line (<CSV>) {
		chomp $line;
		next if (!$line);
		my @v = parse_csv($line);
		next if (!@v);

		my ($x, $y, $z) = (undef, undef, undef);
		my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where name=? and deletionState=0",[($v[$header{system}])]);
		foreach my $r (@rows) {
			$x = $$r{coord_x};
			$y = $$r{coord_y};
			$z = $$r{coord_z};
		}

		my $name = $v[$header{system}];
		next if (!$name);
		$ccl_num++;
		my $id = "CCL$ccl_num";

		if ($x =~ /[^\d\.\-]/ || $y =~ /[^\d\.\-]/ || $z =~ /[^\d\.\-]/ || (!$x && !$y && !$z)) {
			warn "COMPLETIONIST LIST SKIPPED: [$count] $v[$header{system}] no coords.\n";
			next;
		}

		$v[$header{notes}] = $v[$header{notes}] .'+|+Feature: '. $v[$header{feature}] if (defined($header{feature}) && $v[$header{feature}]);
		$v[$header{notes}] = $v[$header{notes}] .'+|+Species '. $v[$header{species}] if (defined($header{species}) && $v[$header{species}]);
		$v[$header{notes}] = $v[$header{notes}] .'+|+Discovered by: '. $v[$header{discoverer}] if (defined($header{discoverer}) && $v[$header{discoverer}]);
	
		$count++;
		warn "COMPLETIONIST LIST FOUND: [$id] $v[$header{system}] ($x,$y,$z)\n";
		print join("\t|\t",$type,$id,$name,$x,$y,$z,$v[$header{system}],$type,$v[$header{notes}])."\r\n";
		print OUT make_csv($type,$id,$name,$x,$y,$z,$v[$header{system}],$v[$header{notes}])."\r\n";
	}
	close CSV;
}


warn "[DSSA]\n";

# DSSA carriers

my $unknown_y = -17000;
my $unknown_x = -45000;

open DSSAOUT, ">DSSAdisplaced.csv";
print DSSAOUT make_csv(qw(Num Callsign Name Commander Status DeploymentLocation LastSeenLocation))."\r\n";
open TSV, "<DSSA-carriers.tsv";
while (my $line = <TSV>) {
	$line =~ s/\s+$//s;
	my @v = split ("\t",$line);

	warn "DSSALINE: ".join(', ',@v)."\n";

	next if ($seen{uc($v[4])} && $seen{uc($v[1])});

	my $serial = '';
	if ($v[13]) {
		$serial = '#'.$v[13].' ';
	}

	my $displayName = "$v[2] [$v[1]] $serial($v[11])";
	$displayName =~ s/\s+$//s;
	$displayName =~ s/^\s+//s;

	my %months = ('January'=>1,'February'=>2,'March'=>3,'April'=>4,'May'=>5,'June'=>6,'July'=>7,'August'=>8,'September'=>9,'October'=>10,'November'=>11,'December'=>12);

	my $type = 'DSSAtmp';
	$type = 'DSSAcarrier' if (uc($v[9]) eq uc($v[4]) || $v[10] =~ /Operational/); 
	$type = 'DSSAsuspend' if ($v[10] =~ /Suspend/i); 
	$type = 'DSSAunknown' if (!$v[5] && !$v[6] &&!$v[7]);
	$type = 'DSSAtmp' if ($v[10] =~ /Disable/i);
	$type = 'DSSArefit' if ($v[10] =~ /Refit/i);

	next if ($v[10] =~ /Retire/i);

	if ($v[12] =~ /(\w+)\s+(\d+),\s+(\d+)/) {
		my ($mon,$day,$year) = ($1,$2,$3);
		my $month = $months{$mon};

		if (date2epoch(sprintf("%04u-%02u-%02u 12:00:00",$year,$month,$day)) < time) {
			$type = 'DSSAundeploy';
		}
		
	}

	$seen{uc($v[4])} = 1;
	$seen{uc($v[1])} = 1;

	my $services = $v[8];
	$services =~ s/,+\s*/, /gs;

	if ($type eq 'DSSAunknown') {
		$v[5] = $unknown_x;
		$v[6] = 0;
		$v[7] = $unknown_y;
		$unknown_x += 1000;
	}

	my $skip = 0;

	if ($v[1] && $type ne 'DSSAunknown' ) {
		my ($x,$y,$z,$n,$id64) = (undef,undef,undef,undef,undef);
		my @rows = db_mysql('elite',"select systemId64 from carriers where callsign=?",[($v[1])]);
		if (@rows) {
			my $r = shift @rows;

			if ($$r{systemId64}) {
				my @sys = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where id64=?",[($$r{systemId64})]);
				if (@sys) {
					$x = ${$sys[0]}{coord_x};
					$y = ${$sys[0]}{coord_y};
					$z = ${$sys[0]}{coord_z};
					$n = ${$sys[0]}{name};
					$id64 = $$r{systemId64} ? $$r{systemId64}+0 : undef;
				}
			}
		}

		if (defined($x) && defined($y) && defined($z) && defined($n) &&
			($x != $v[5] || $y != $v[6] || $z != $v[7] || btrim(lc($n)) ne btrim(lc($v[4])))) {
			print join("\t|\t",'DSSAseen',"DSSA$v[0]REAL",$displayName,$x,$y,$z,$n,undef,"($services)")."\n";
			print OUT make_csv('DSSAseen',"DSSA$v[0]REAL",$displayName,$x,$y,$z,$n,$services)."\r\n";
			$skip = 1;
			my $t = 'DSSAtmp';
			$t = $type if ($type =~ /refit/i);

			my %car = ();
			$car{coords}{x} = $x ? $x+0 : undef;
			$car{coords}{y} = $y ? $y+0 : undef;
			$car{coords}{z} = $z ? $z+0 : undef;
			$car{name} = $displayName;
			$car{system} = $n;
			$car{id64} = $id64 ? $id64+0 : undef;
			push @{$carrierJSONs{DSSA}{carriers}}, \%car;

			print join("\t|\t",$t,"DSSA$v[0]",$displayName,$v[5],$v[6],$v[7],$v[4],undef,"($services)")."\n";
			print OUT make_csv($t,"DSSA$v[0]",$displayName,$v[5],$v[6],$v[7],$v[4],$services)."\r\n";

			print DSSAOUT make_csv($v[0],$v[1],$v[2],$v[3],$v[10],$v[4],$n)."\r\n";
		}
	}

	if (!$skip) {
		my %car = ();
		$car{coords}{x} = $v[5] ? $v[5]+0 : undef;
		$car{coords}{y} = $v[6] ? $v[6]+0 : undef;
		$car{coords}{z} = $v[7] ? $v[7]+0 : undef;
		$car{name} = $displayName;
		$car{system} = $v[4];
		$car{id64} = get_id64_by_name($v[4]);
		$car{id64} = $car{id64} ? $car{id64}+0 : undef;
		push @{$carrierJSONs{DSSA}{carriers}}, \%car;

		print join("\t|\t",$type,"DSSA$v[0]",$displayName,$v[5],$v[6],$v[7],$v[4],undef,"($services)")."\n";
		print OUT make_csv($type,"DSSA$v[0]",$displayName,$v[5],$v[6],$v[7],$v[4],$services)."\r\n";
		print DSSAOUT make_csv($v[0],$v[1],$v[2],$v[3],$v[10],$v[4],'')."\r\n" if ($type eq 'DSSAtmp');
	}
}
close TSV;
close DSSAOUT;


warn "[OASIS]\n";

# OASIS carriers

my $unknown_y = -17000;
my $unknown_x = -45000;

#"Timestamp","Cmdr Name","Email","Preferred communications","Fleet Carrier ID","Fleet Carrier Name","System Deployed","Cmdr Platform","UTC Time Zone","My FC Services","Maximum Available Car go (Tons)","Tritium Market Maximum (Tons)","Tritium Available in Market (Tons)","Email Address","Tritium Required","Buy Orders","Sell Orders"

my @column_patterns = qw(SYSTEM CARRIER SERVICES);
my %col  = ();
my $id = 0;
my %carrier = ();
open CSV, "<oasis-carriers.csv";
while (<CSV>) {
        chomp;
        my @v = parse_csv($_);
#"","REF","Fleet Carrier ID","Fleet Carrier Name","System Deployed","Cmdr Platform","UTC Time Zone","My FC Services","Maximum Available Cargo (Tons)","","","Buy Orders","","Sell Orders","Inara Station","Tritium Required"
#"","1","XZH-NXF","[IGAU] Cygni-Vanguard","Floalk QQ-Q c20-2","PC","-5","Buy Tritium","13999","5000","0","5000","5000","0","https://inara.cz/station/184282/",""


        if (!keys(%col)) {
		my $header = uc($_);
		#$header =~ s/ID/CALLSIGN/gis;
		#$header =~ s/Carrier Name/CARRIERNAME/gis;

        	@v = parse_csv($header);

		print "OASIS ";

                foreach my $key (@column_patterns) {
                        for (my $i=0; $i<@v; $i++) {
                                if (!$col{$key} && $v[$i] =~ /$key/i) {
                                        $col{$key} = $i;
                                        last;
                                }
                        }

                        #$col{$key} = 1 if ($key eq '#' && !$col{$key});

                        print $key.'['.$col{$key}."], ";
                }
                print "\n\n";

        } else {
		$id++;
		next if ($v[$col{CARRIER}] !~ /\S/ && $v[$col{SYSTEM}] !~ /\S/);
                warn "OASIS CARRIER[$id]: ".join(' +|+ ', @v), "\n";

		$v[$col{SYSTEM}] =~ s/\s+\(.*\)\s*$//;
		my $callsign = '-';
		if ($v[$col{CARRIER}] =~ /\s+\[(\S+)\]\s*$/) {
			$callsign = $1;
			$v[$col{CARRIER}] =~ s/\s+\[\S+\]\s*$//s;
		}

		my ($x,$y,$z,$e) = system_coordinates($v[$col{SYSTEM}]);
		next if (!defined($x) || !defined($z));

		my $pixel = floor($x/10).'x'.floor($z);

                $carrier{$pixel}{$id}{callsign} = uc($callsign);
                $carrier{$pixel}{$id}{callsign} = "OASIS#$id" if (!$callsign);
                $carrier{$pixel}{$id}{name} = $v[$col{CARRIER}];
                $carrier{$pixel}{$id}{num} = $id;
                $carrier{$pixel}{$id}{system} = $v[$col{SYSTEM}];
                $carrier{$pixel}{$id}{current} = $v[$col{SYSTEM}];
                $carrier{$pixel}{$id}{services} = $v[$col{SERVICES}];

                $carrier{$pixel}{$id}{name} =~ s/[^\x00-\x7f]//g;

		#my @rows = db_mysql('elite',"select systemId64,systemName from carriers where callsign=? and LastEvent>=date_sub(NOW(),interval 2 month)",[($carrier{$id}{callsign})]);
		my @rows = db_mysql('elite',"select systemId64,systemName from carriers where callsign=?",[($carrier{$pixel}{$id}{callsign})]);
		if (!@rows || lc(${$rows[0]}{systemName}) ne lc($carrier{$pixel}{$id}{system})) {
			warn "OASIS CARRIER[$id]: Carrier not found in correct place.\n";
			#delete $carrier{$pixel}{$id};
			$carrier{$pixel}{$id}{color} = 'white' if ($carrier{$id}{color} !~ /purple/i);
		}
	}
}
close CSV;

warn "OASIS carriers: ".int(keys(%carrier))."\n";

my $consolidate = 1;

my $count = 0;
foreach my $pixel (sort {$a <=> $b} keys %carrier) {
	my ($markertype,$markerdisplay,$marker_x,$marker_y,$marker_z,$markersystem,$markertext) = undef;

	foreach my $id (sort {$a <=> $b} keys %{$carrier{$pixel}}) {
		my $displayName = "$carrier{$pixel}{$id}{name} [$carrier{$pixel}{$id}{callsign}]";
		$displayName =~ s/\s+$//s;
		$displayName =~ s/^\s+//s;
		my $type = 'OASIScarrier';

		#$type = 'OASISred' if ($carrier{$pixel}{$id}{color}=~/red/i);
		#$type = 'OASISgreen' if ($carrier{$pixel}{$id}{color}=~/green/i);
		#$type = 'OASISyellow' if ($carrier{$pixel}{$id}{color}=~/yellow/i);
		#$type = 'OASISpurple' if ($carrier{$pixel}{$id}{color}=~/purple/i);
		#$type = 'OASISblue' if ($carrier{$pixel}{$id}{color}=~/blue/i);
		#$type = 'OASIScyan' if ($carrier{$pixel}{$id}{color}=~/cyan/i);

		my ($x,$y,$z,$e) = system_coordinates($carrier{$pixel}{$id}{system});
		$n = $carrier{$pixel}{$id}{system};
		$e = "+/- $e" if ($e);
		$e = '' if (!$e);
		
		if ($type eq 'OASISunknown' || !defined($x) || !defined($y) || !defined($z)) {
			$type = 'OASISunknown';
			$x = $unknown_x;
			$y = 0;
			$z = $unknown_y;
			$unknown_x += 1000;
		}

		$carrier{$pixel}{$id}{url} =~ s/\s+$//s;

		my $add = '';
		my $status = 'Oasis Carrier';

		$status .= "+|+Services: ".$carrier{$pixel}{$id}{services} if ($carrier{$pixel}{$id}{services});

		if ($carrier{$pixel}{$id}{current} && lc(btrim($carrier{$pixel}{$id}{current})) ne lc(btrim($carrier{$pixel}{$id}{system}))) {
			$add = " (NOT PRESENT)";

			if (!$consolidate) {
				# Draw pin directly, no consolidation
				print join("\t|\t","OASIStmp","OASIS0$id",$displayName.$add,$x,$y,$z,$n,undef,"$status")."\n";
				print OUT make_csv("OASIStmp","OASIS0$id",$displayName.$add,$x,$y,$z,$n,"$status")."\r\n";
			} else {	
				# Consolidate pins
				if (!$markerdisplay && !$markersystem) {
					$markertype = "OASIStmp";
					$markerdisplay = $displayName.$add;
					$marker_x = $x; $marker_y = $y; $marker_z = $z;
					$markersystem = $n;
					$markertext = "$status";
				} else {
					my $s = uc($markersystem) eq uc($n) ? '' : " -- $n";
					$markertext .= "+|++|+$displayName$add$s+|+$status";
				}
			}

			($x,$y,$z,$e) = system_coordinates($carrier{$pixel}{$id}{current});
			$n = $carrier{$pixel}{$id}{current};
			$e = "+/- $e" if ($e);
			$e = '' if (!$e);

			#my $linecoords = sprintf("%.02f/%.02f/%.02f",$x,$y,$z);
			my $linecoords = "0/0/0/f0f";

			print join("\t|\t",$type,"OASIS0${id}REAL",$displayName." (CURRENT LOCATION)",$x,$y,$z,$n,undef,"$status",$linecoords)."\n";
			print OUT make_csv($type,"OASIS0${id}REAL",$displayName." (CURRENT LOCATION)",$x,$y,$z,$n,"$status",$linecoords)."\r\n";

		} else {
			if (!$consolidate) {
				# Draw pin directly, no consolidation
				print join("\t|\t",$type,"OASIS0$id",$displayName,$x,$y,$z,$n,undef,"$status")."\n";
				print OUT make_csv($type,"OASIS0$id",$displayName,$x,$y,$z,$n,"$status")."\r\n";
			} else {	
				# Consolidate pins
				if (!$markerdisplay && !$markersystem) {
					$markertype = $type;
					$markerdisplay = $displayName;
					$marker_x = $x; $marker_y = $y; $marker_z = $z;
					$markersystem = $n;
					$markertext = "$status";
				} else {
					my $s = uc($markersystem) eq uc($n) ? '' : " -- $n";
					$markertext .= "+|++|+$displayName$s+|+$status";
					$markertype = $type if ($type =~ /green/);
					$markertype = $type if ($type =~ /yellow/ && $markertype !~ /(green)/);
					$markertype = $type if ($type =~ /red/    && $markertype !~ /(green|yellow)/);
					$markertype = $type if ($type =~ /cyan/   && $markertype !~ /(green|yellow|red)/);
					$markertype = $type if ($type =~ /purple/ && $markertype !~ /(green|yellow|red|cyan)/);
				}
			}
		}
		
	}
	if ($consolidate && defined($markertype) && defined($markerdisplay) && defined($marker_x) && defined($marker_z) && defined($markertext)) {
		# Consolidated output, stubbed out, does not cooperate with marker lines
		$count++;
		print join("\t|\t",$markertype,"OASIS0$count",$markerdisplay,$marker_x,$marker_y,$marker_z,$markersystem,undef,$markertext)."\n";
		print OUT make_csv($markertype,"OASIS0$count",$markerdisplay,$marker_x,$marker_y,$marker_z,$markersystem,$markertext)."\r\n";
	}
}
%carrier = ();



warn "[STAR]\n";


# STAR carriers

my $unknown_y = -17000;
my $unknown_x = -45000;

#"Timestamp","Cmdr Name","Email","Preferred communications","Fleet Carrier ID","Fleet Carrier Name","System Deployed","Cmdr Platform","UTC Time Zone","My FC Services","Maximum Available Car go (Tons)","Tritium Market Maximum (Tons)","Tritium Available in Market (Tons)","Email Address","Tritium Required","Buy Orders","Sell Orders"

my @column_patterns = qw(CALLSIGN CARRIERNAME DEPLOY CURRENT COLOUR URL TONNAGE PRICE UPDATE ACTIVE);
my %col  = ();
my $id = 0;
my %carrier = ();
open CSV, "<STAR-carriers.csv";
while (<CSV>) {
        chomp;
        my @v = parse_csv($_);
#"","REF","Fleet Carrier ID","Fleet Carrier Name","System Deployed","Cmdr Platform","UTC Time Zone","My FC Services","Maximum Available Cargo (Tons)","","","Buy Orders","","Sell Orders","Inara Station","Tritium Required"
#"","1","XZH-NXF","[IGAU] Cygni-Vanguard","Floalk QQ-Q c20-2","PC","-5","Buy Tritium","13999","5000","0","5000","5000","0","https://inara.cz/station/184282/",""


        if (!keys(%col)) {
		my $header = uc($_);
		$header =~ s/ID/CALLSIGN/gis;
		$header =~ s/Name/CARRIERNAME/gis;

        	@v = parse_csv($header);

		print "STAR ";

                foreach my $key (@column_patterns) {
                        for (my $i=0; $i<@v; $i++) {
                                if (!$col{$key} && $v[$i] =~ /$key/i) {
                                        $col{$key} = $i;
                                        last;
                                }
                        }

                        #$col{$key} = 1 if ($key eq '#' && !$col{$key});

                        print $key.'['.$col{$key}."], ";
                }
                print "\n\n";

        } else {
		$id++;
		next if ($v[$col{CARRIERNAME}] !~ /\S/ && $v[$col{CALLSIGN}] !~ /\S/);
		next if ($v[$col{ACTIVE}] && $v[$col{ACTIVE}] !~ /true/i);
                warn "STAR CARRIER[$id]: ".join(' +|+ ', @v), "\n";

		my ($x,$y,$z,$e) = system_coordinates($v[$col{DEPLOY}]);
		next if (!defined($x) || !defined($z));

		my $pixel = floor($x/10).'x'.floor($z);

                $carrier{$pixel}{$id}{callsign} = uc($v[$col{CALLSIGN}]);
                $carrier{$pixel}{$id}{callsign} = "STAR#$id" if (!$carrier{$pixel}{$id}{callsign});
                $carrier{$pixel}{$id}{name} = $v[$col{CARRIERNAME}];
                $carrier{$pixel}{$id}{num} = $id;
                $carrier{$pixel}{$id}{system} = $v[$col{DEPLOY}];
                $carrier{$pixel}{$id}{current} = $v[$col{CURRENT}];
                $carrier{$pixel}{$id}{color} = $v[$col{COLOUR}];
                $carrier{$pixel}{$id}{url} = btrim($v[$col{URL}]);
                $carrier{$pixel}{$id}{tonnage} = $v[$col{TONNAGE}];
                $carrier{$pixel}{$id}{price} = $v[$col{PRICE}];

		if ($v[$col{UPDATE}] =~ /(\d+)/) {
			$carrier{$pixel}{$id}{updated} = epoch2date($1);
		}

		$carrier{$pixel}{$id}{tonnage} =~ s/,+//;
		$carrier{$pixel}{$id}{price} =~ s/,+//;

		$carrier{$pixel}{$id}{owner} =~ s/[^\x00-\x7f]//g;
                $carrier{$pixel}{$id}{name} =~ s/[^\x00-\x7f]//g;

		#my @rows = db_mysql('elite',"select systemId64,systemName from carriers where callsign=? and LastEvent>=date_sub(NOW(),interval 2 month)",[($carrier{$id}{callsign})]);
		my @rows = db_mysql('elite',"select systemId64,systemName from carriers where callsign=?",[($carrier{$pixel}{$id}{callsign})]);
		if (!@rows || lc(${$rows[0]}{systemName}) ne lc($carrier{$pixel}{$id}{system})) {
			warn "STAR CARRIER[$id]: Carrier not found in correct place.\n";
			#delete $carrier{$pixel}{$id};
			$carrier{$pixel}{$id}{color} = 'white' if ($carrier{$id}{color} !~ /purple/i);
		}
	}
}
close CSV;

warn "STAR carriers: ".int(keys(%carrier))."\n";

my $consolidate = 1;

my $count = 0;
foreach my $pixel (sort {$a <=> $b} keys %carrier) {
	my ($markertype,$markerdisplay,$marker_x,$marker_y,$marker_z,$markersystem,$markertext) = undef;

	foreach my $id (sort {$a <=> $b} keys %{$carrier{$pixel}}) {
		my $displayName = "$carrier{$pixel}{$id}{name} [$carrier{$pixel}{$id}{callsign}]";
		$displayName =~ s/\s+$//s;
		$displayName =~ s/^\s+//s;
		my $type = 'STARcarrier';	# white

		$type = 'STARred' if ($carrier{$pixel}{$id}{color}=~/red/i);
		$type = 'STARgreen' if ($carrier{$pixel}{$id}{color}=~/green/i);
		$type = 'STARyellow' if ($carrier{$pixel}{$id}{color}=~/yellow/i);
		$type = 'STARpurple' if ($carrier{$pixel}{$id}{color}=~/purple/i);
		$type = 'STARblue' if ($carrier{$pixel}{$id}{color}=~/blue/i);
		$type = 'STARcyan' if ($carrier{$pixel}{$id}{color}=~/cyan/i);

		my ($x,$y,$z,$e) = system_coordinates($carrier{$pixel}{$id}{system});
		$n = $carrier{$pixel}{$id}{system};
		$e = "+/- $e" if ($e);
		$e = '' if (!$e);
		
		if ($type eq 'STARunknown' || !defined($x) || !defined($y) || !defined($z)) {
			$type = 'STARunknown';
			$x = $unknown_x;
			$y = 0;
			$z = $unknown_y;
			$unknown_x += 1000;
		}

		$carrier{$pixel}{$id}{url} =~ s/\s+$//s;

		my $status = 'Unknown';
		$status = 'High Reserves' if ($type =~ /green/i);
		$status = 'Moderate Reserves' if ($type =~ /yellow/i);
		$status = 'Low Reserves' if ($type =~ /red/i);
		$status = 'Resupply Underway' if ($type =~ /cyan/i);
		$status = 'Resupply Pending' if ($type =~ /blue/i);
		$status = 'Anomalous' if ($type =~ /purple/i);
		$status = "Status: $status";

		my $links = '';
		$links .= "+|+Tonnage: $carrier{$pixel}{$id}{tonnage} (price: $carrier{$pixel}{$id}{price})" if ($carrier{$pixel}{$id}{tonnage} && $carrier{$pixel}{$id}{price});
		$links .= "+|+Updated: $carrier{$pixel}{$id}{updated}" if ($carrier{$pixel}{$id}{updated});
		$links .= "+|+(<a href=\"$carrier{$pixel}{$id}{url}\">Carrier info link</a>)" if ($carrier{$pixel}{$id}{url});

		my $add = '';

		if ($carrier{$pixel}{$id}{current} && lc(btrim($carrier{$pixel}{$id}{current})) ne lc(btrim($carrier{$pixel}{$id}{system}))) {
			$add = " (NOT PRESENT)";

			if (!$consolidate) {
				# Draw pin directly, no consolidation
				print join("\t|\t","STARtmp","STAR0$id",$displayName.$add,$x,$y,$z,$n,undef,"$status$links")."\n";
				print OUT make_csv("STARtmp","STAR0$id",$displayName.$add,$x,$y,$z,$n,"$status$links")."\r\n";
			} else {	
				# Consolidate pins
				if (!$markerdisplay && !$markersystem) {
					$markertype = "STARtmp";
					$markerdisplay = $displayName.$add;
					$marker_x = $x; $marker_y = $y; $marker_z = $z;
					$markersystem = $n;
					$markertext = "$status$links";
				} else {
					my $s = uc($markersystem) eq uc($n) ? '' : " -- $n";
					$markertext .= "+|++|+$displayName$add$s+|+$status$links";
				}
			}

			($x,$y,$z,$e) = system_coordinates($carrier{$pixel}{$id}{current});
			$n = $carrier{$pixel}{$id}{current};
			$e = "+/- $e" if ($e);
			$e = '' if (!$e);

			#my $linecoords = sprintf("%.02f/%.02f/%.02f",$x,$y,$z);
			my $linecoords = "0/0/0/f0f";

			print join("\t|\t",$type,"STAR0${id}REAL",$displayName." (CURRENT LOCATION)",$x,$y,$z,$n,undef,"$status$links",$linecoords)."\n";
			print OUT make_csv($type,"STAR0${id}REAL",$displayName." (CURRENT LOCATION)",$x,$y,$z,$n,"$status$links",$linecoords)."\r\n";

		} else {
			if (!$consolidate) {
				# Draw pin directly, no consolidation
				print join("\t|\t",$type,"STAR0$id",$displayName,$x,$y,$z,$n,undef,"$status$links")."\n";
				print OUT make_csv($type,"STAR0$id",$displayName,$x,$y,$z,$n,"$status$links")."\r\n";
			} else {	
				# Consolidate pins
				if (!$markerdisplay && !$markersystem) {
					$markertype = $type;
					$markerdisplay = $displayName;
					$marker_x = $x; $marker_y = $y; $marker_z = $z;
					$markersystem = $n;
					$markertext = "$status$links";
				} else {
					my $s = uc($markersystem) eq uc($n) ? '' : " -- $n";
					$markertext .= "+|++|+$displayName$s+|+$status$links";
					$markertype = $type if ($type =~ /green/);
					$markertype = $type if ($type =~ /yellow/ && $markertype !~ /(green)/);
					$markertype = $type if ($type =~ /red/    && $markertype !~ /(green|yellow)/);
					$markertype = $type if ($type =~ /cyan/   && $markertype !~ /(green|yellow|red)/);
					$markertype = $type if ($type =~ /purple/ && $markertype !~ /(green|yellow|red|cyan)/);
				}
			}
		}
		
	}
	if ($consolidate && defined($markertype) && defined($markerdisplay) && defined($marker_x) && defined($marker_z) && defined($markertext)) {
		# Consolidated output, stubbed out, does not cooperate with marker lines
		$count++;
		print join("\t|\t",$markertype,"STAR0$count",$markerdisplay,$marker_x,$marker_y,$marker_z,$markersystem,undef,$markertext)."\n";
		print OUT make_csv($markertype,"STAR0$count",$markerdisplay,$marker_x,$marker_y,$marker_z,$markersystem,$markertext)."\r\n";
	}
}
%carrier = ();




warn "[PIONEER]\n";

# Pioneer Project

my $unknown_y = -17000;
my $unknown_x = -45000;

#"Timestamp","Cmdr Name","Email","Preferred communications","Fleet Carrier ID","Fleet Carrier Name","System Deployed","Cmdr Platform","UTC Time Zone","My FC Services","Maximum Available Car go (Tons)","Tritium Market Maximum (Tons)","Tritium Available in Market (Tons)","Email Address","Tritium Required","Buy Orders","Sell Orders"

my @column_patterns = qw(CALLSIGN CARRIERNAME DEPLOYED CURRENT REGION FLEETCARRIER INARA CODENAME);
my %col  = ();
my $id = 0;
my %carrier = ();
open CSV, "<pioneerproject.csv";
while (<CSV>) {
        chomp;
        my @v = parse_csv($_);
#"","REF","Fleet Carrier ID","Fleet Carrier Name","System Deployed","Cmdr Platform","UTC Time Zone","My FC Services","Maximum Available Cargo (Tons)","","","Buy Orders","","Sell Orders","Inara Station","Tritium Required"
#"","1","XZH-NXF","[IGAU] Cygni-Vanguard","Floalk QQ-Q c20-2","PC","-5","Buy Tritium","13999","5000","0","5000","5000","0","https://inara.cz/station/184282/",""

        if (!keys(%col)) {
		my $header = uc($_);
		$header =~ s/Reg\. No/CALLSIGN/gis;
		$header =~ s/Carrier Name/CARRIERNAME/gis;
		$header =~ s/System Assigned/DEPLOYED/gis;
		$header =~ s/System Anchored/CURRENT/gis;
		$header =~ s/Designated Region/REGION/gis;
		$header =~ s/FleetCarrier(\.Space)?/FLEETCARRIER/gis;
		$header =~ s/Inara(\.cz)?/INARA/gis;
		$header =~ s/(Point )?Codename/CODENAME/gis;

        	@v = parse_csv($header);

		print "PIONEER ";

                foreach my $key (@column_patterns) {
                        for (my $i=0; $i<@v; $i++) {
                                if (!$col{$key} && $v[$i] =~ /$key/i) {
                                        $col{$key} = $i;
                                        last;
                                }
                        }

                        $col{$key} = 1 if ($key eq '#' && !$col{$key});

                        print $key.'['.$col{$key}."], ";
                }
                print "\n\n";

        } else {
		next if (!$v[$col{CALLSIGN}] || $v[$col{CALLSIGN}] !~ /^\s*[a-zA-Z0-9]{3}\-[a-zA-Z0-9]{3}\s*$/);
		next if ($v[$col{CARRIERNAME}] !~ /\S/ && $v[$col{CALLSIGN}] !~ /\S/);
		$id++;
                warn "PIONEER CARRIER[$id]: ".join(' +|+ ', @v), "\n";

                $carrier{$id}{callsign} = uc(btrim($v[$col{CALLSIGN}]));
                $carrier{$id}{callsign} = "STAR#$id" if (!$carrier{$id}{callsign});
                $carrier{$id}{name} = $v[$col{CARRIERNAME}];
                $carrier{$id}{num} = $id;
                $carrier{$id}{system} = $v[$col{DEPLOYED}];
                $carrier{$id}{current} = $v[$col{CURRENT}];
                $carrier{$id}{fleetcarrier} = $v[$col{FLEETCARRIER}];
                $carrier{$id}{inara} = $v[$col{INARA}];
                $carrier{$id}{region} = $v[$col{REGION}];
                $carrier{$id}{codename} = $v[$col{CODENAME}];

                $carrier{$id}{name} =~ s/[^\x00-\x7f]//g;
	}
}
close CSV;

foreach my $id (sort {$a <=> $b} keys %carrier) {
	my $displayName = "$carrier{$id}{name} [$carrier{$id}{callsign}]";
	$displayName =~ s/\s+$//s;
	$displayName =~ s/^\s+//s;
	my $type = 'PIONEERcarrier';

	my ($x,$y,$z,$e) = system_coordinates($carrier{$id}{system});
	$n = $carrier{$id}{system};
	$e = "+/- $e" if ($e);
	$e = '' if (!$e);
	
	if ($type eq 'PIONEERunknown' || !defined($x) || !defined($y) || !defined($z)) {
		$type = 'PIONEERunknown';
		$x = $unknown_x;
		$y = 0;
		$z = $unknown_y;
		$unknown_x += 1000;
	}

	my $links = '';

	if ($carrier{$id}{current} && $carrier{$id}{system} && uc(btrim($carrier{$id}{current})) ne uc(btrim($carrier{$id}{system}))) {
		$type = 'PIONEERtmp';
		$links .= "+|+Currently Anchored: $carrier{$id}{current}";
	}

	$links .= "+|+(<a href=\"$carrier{$id}{inara}\">Inara link</a>)" if ($carrier{$id}{inara});
	$links .= "+|+(<a href=\"$carrier{$id}{fleetcarrier}\">FleetCarrier.Space link</a>)" if ($carrier{$id}{fleetcarrier});

	print join("\t|\t",$type,"PIONEER$id",$displayName,$x,$y,$z,$n,undef,"(Point Codename: $carrier{$id}{codename})$links")."\n";
	print OUT make_csv($type,"PIONEER$id",$displayName,$x,$y,$z,$n,"$carrier{$id}{codename}$links")."\r\n";
	
}
%carrier = ();



my $rows = rows_mysql('elite',"select callsign,c.name,services,DockingAccess,s.name as systemname,s.coord_x,s.coord_y,s.coord_z,sol_dist from carriers c,systems s ".
			"where systemId64=id64 and lastEvent>=date_sub(NOW(),interval 30 day) and sqrt(pow(s.coord_x,2)+pow(s.coord_z,2))>=500 and ".
			"sqrt(pow(s.coord_x+9530.5,2)+pow(s.coord_z-19808.1,2))>=200 and s.deletionState=0 and c.invisible=0");
foreach my $r (@$rows) {
	my $x = floor($$r{coord_x}/10)*10;
	my $y = floor($$r{coord_z}/10)*10;
	$carrier{$x}{$y}{$$r{callsign}} = $r;
}
my $i=0;
foreach my $x (keys %carrier) {
	foreach my $y (keys %{$carrier{$x}}) {
		my $n = int(keys %{$carrier{$x}{$y}});
		$i++;
		my $type = 'carrier';

		if ($n == 1) {
			my $callsign = (keys %{$carrier{$x}{$y}})[0];
			my $r = $carrier{$x}{$y}{$callsign};
			my $displayName = "$$r{name} [$$r{callsign}]";
			$displayName =~ s/\s+$//s;
			$displayName =~ s/^\s+//s;
			$$r{DockingAccess} = 'unknown' if (!$$r{DockingAccess});
			my $docking = 'DockingPermit: '.uc($$r{DockingAccess});
			my $services = strip_services($$r{services},$r);

			print join("\t|\t",$type,"FC$i",$displayName,$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{systemname},undef,"$docking+|+($services)")."\n";
			print OUT make_csv($type,"FC$i",$displayName,$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{systemname},"$docking+|+$services")."\r\n";
		} elsif ($n > 1) {

			my $displayName = 'Multiple Fleet Carriers';
			my $out = '';

			foreach my $callsign (sort keys %{$carrier{$x}{$y}}) {
				my $r = $carrier{$x}{$y}{$callsign};
				$$r{DockingAccess} = 'unknown' if (!$$r{DockingAccess});
				my $docking = 'DockingPermit: '.uc($$r{DockingAccess});
				my $services = strip_services($$r{services},$r);

				$out .= "+|++|+$$r{name} [$callsign] -- $$r{systemname}+|+$docking+|+($services)";
			}
			$out .= '+|++|+';
			print join("\t|\t",$type,"FC$i",$displayName,$x,0,$y,'',undef,$out)."\n";
			print OUT make_csv($type,"FC$i",$displayName,$x,0,$y,'',$out)."\r\n";
		}
	}
}
%carrier = ();

sub strip_services {
	my $s = shift;
	my $r = shift;

	$s =~ s/(autodock|carriermanagement|commodities|crewlounge|engineer|flightcontroller|contacts|stationMenu|stationoperations)//gis;
	$s =~ s/(dock|carrierfuel)//gis;
	$s =~ s/voucherredemption/redemption/gs;
	$s =~ s/exploration/UC/gs;
	$s =~ s/\s*,+\s*/, /gs;
	$s =~ s/^[,\s]+//s;
	$s =~ s/[,\s]+$//s;

	$s = 'no services' if (!$s);

	return $s;
}


warn "[GUARDIAN]\n";

my @rows = db_mysql('elite',"select codexname_local.name type,systems.name sysname,coord_x,coord_y,coord_z from codex,codexname_local,systems where nameID=codexnameID and ".
			"codex.deletionState=0 and codexname_local.name like '%guardian %' and systemId64=id64 and systems.deletionState=0");

warn "GUARDIAN SITES: ".int(@rows)."\n";
my %pixel = ();
foreach my $r (sort { $$a{sysname} cmp $$b{sysname} } @rows) {
	my $c = floor($$r{coord_x}/10).','.floor($$r{coord_z}/10);

	#warn "GUARDIAN: $c $$r{coord_x} $$r{coord_z} $$r{sysname} $$r{type}\n";

	$pixel{$c}{x} = floor($$r{coord_x}/10)*10 + 5;
	$pixel{$c}{z} = floor($$r{coord_z}/10)*10 + 5;

	$pixel{$c}{sys}{$$r{sysname}}{$$r{type}}++;
}

my $i = 0;
foreach my $c (sort { $a cmp $b } keys %pixel) {
	my $d = '';
	$i++;
	my $id = "GUARDIAN$i";

	foreach my $s (sort { $a cmp $b } keys %{$pixel{$c}{sys}}) {
		$d .= $s."<br>";

		my $n = 0;
		foreach my $type (sort { $a cmp $b } keys %{$pixel{$c}{sys}{$s}}) {
#warn "\t\t^ $type\n";
			if ($type =~ /Guardian\s+(\S+.*)$/i) {
				$d .= ', ' if ($n);
				#$d .= "$1 ($pixel{$c}{sys}{$s}{$type})";
				$d .= $1;
				$n++;
			}
		}

		#if (int(keys %{$pixel{$c}{sys}})>1) {
			#$d .= "<br>" if ($n);
			$d .= "<br><br>";
		#}
	}

	print join("\t|\t",'guardian',$id,'Guardian Sites',$pixel{$c}{x},0,$pixel{$c}{z},'',undef,$d)."\n";
	print OUT make_csv('guardian',$id,'Guardian Sites',$pixel{$c}{x},0,$pixel{$c}{z},'',undef)."\r\n";
}


warn "[POI]\n";

my @rows = db_mysql('elite',"select edsm_id,gec_id,score,summary,name,type,coord_x,coord_y,coord_z,galMapSearch,galMapUrl,poiUrl,descriptionHtml from POI ".
			"where (skip is null or skip=0) and hidden=0 and (gec_id is null or score>=3 or type='Deep Space Outpost')");
my @out = ();
my %POIseen = ();

foreach my $r (sort { $$b{score}+0 <=> $$a{score}+0 } @rows) {
	push @out,$r if (!$POIseen{$$r{galMapSearch}});
	$POIseen{$$r{galMapSearch}} = 1;
}

foreach my $r (sort { $$a{type} cmp $$b{type} || $$a{name} cmp $$b{name} } @out) {
	my $typeOverride = '';
	my $name = $$r{name};

	next if ($exclude{lc($$r{name})} || $exclude{lc($$r{galMapSearch})});

	$$r{summary} =~ s/^$$r{name}\s*//si;

	foreach my $v ('summary','descriptionHtml') {
		$$r{$v} = html_encode($$r{$v});
	}

	if (exists($tri{$$r{galMapSearch}})) {
		$typeOverride = 'tritium';
		delete($tri{$$r{galMapSearch}});
	}

	if (exists($ggg{uc($$r{galMapSearch})})) {
		$typeOverride = 'GGG';
		delete($ggg{uc($$r{galMapSearch})});
	}

	if ($$r{type} =~ /^nebulae?\s*$/i) {
		$$r{type} = 'nebula';
	}

	my $poilink_added = 0;

	if (exists($pn{uc($$r{galMapSearch})})) {
		#$typeOverride = 'planetaryNebula';
		if ($pn{uc($$r{galMapSearch})} =~ /planetaryNebula\t\|\t[^\t]+\t\|\t([^\t]+)\t/) {
			if (uc(btrim($name)) ne uc(btrim($1))) {
				my $poiname = '';
				($name, $poiname) = ($1, $name);

				if ($$r{galMapUrl} || $$r{poiUrl}) {
					my $url = $$r{poiUrl} ? $$r{poiUrl} : $$r{galMapUrl};
					$$r{summary} .= "<br/>" if ($$r{summary});
					$$r{summary} .= "(POI: <a href=\"$url\" target=\"_blank\">$poiname</a>)";
					$poilink_added = 1;
				} else {
					$name = "$name\\n(POI: $poiname)";
					$poilink_added = 1;
				}
			}
		}
		#delete($pn{uc($$r{galMapSearch})});
		##next;
	}

	if (!$poilink_added) {
		if  ($$r{galMapUrl} || $$r{poiUrl}) {
			my $url = $$r{poiUrl} ? $$r{poiUrl} : $$r{galMapUrl};
			$$r{summary} .= "<br/>" if ($$r{summary});
			$$r{summary} .= "(<a href=\"$url\" target=\"_blank\">View POI</a>)";
			$poilink_added = 1;
		}
	}

	if ($$r{type} =~ /deepSpaceOutpost/ && ($$r{descriptionHtml} =~ /DSSA/ || $$r{name} =~ /DSSA/)) {
		#$seen{uc($$r{galMapSearch})} = 1;
		$typeOverride = 'carrier';
		next if ($seen{uc($$r{galMapSearch})});
	}

	if ($$r{type} =~ /blackHole|pulsar/) {
		$typeOverride = 'stellarRemnant';
	}

	my $id = $$r{edsm_id} ? $$r{edsm_id} : 'GEC'.$$r{gec_id};

	my $string = $$r{summary} ? $$r{summary} : '';

	$POIseen{$$r{galMapSearch}} = 1;
	$POIname{$name} = 1;

	print join("\t|\t",$$r{type},$id,$name,$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{galMapSearch},$typeOverride,html_encode($string))."\n";
	print OUT make_csv($$r{type},$id,$name,$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{galMapSearch},undef)."\r\n";
}


warn "[MEGASHIP]\n";
my @rows = db_mysql('elite',"select stations.id,stations.name shipname,systems.name sysname,sol_dist,coord_x,coord_y,coord_z,edsm_id,eddnDate from ".
			"stations,systems where id64=systemId64 and type='Mega ship' and stations.name not like 'Rescue Ship - \%' and ".

			"systems.deletionState=0 and stations.deletionState=0 order by sol_dist");
my %megaship_done = ();

foreach my $r (@rows) {
	my $typeOverride = undef;

	my $type = 'megaship';
	$type .= '2' if (!$$r{eddnDate});

	next if ($megaship_done{$$r{shipname}}{$$r{sysname}});
	$megaship_done{$$r{shipname}}{$$r{sysname}} = 1;

	print join("\t|\t",$type,$$r{id},$$r{shipname},$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{sysname},$typeOverride,undef)."\n";
	print OUT make_csv($type,$$r{id},$$r{shipname},$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{sysname},undef)."\r\n";
	$POIseen{$$r{sysname}} = 1;
}

foreach my $sys (keys %pn) {
	print "$pn{$sys}\n";
	$POIseen{$sys} = 1;
}

foreach my $sys (keys %neb) {
	my $ok = 1;
	my $name = '';

	if ($neb{$sys} =~ /^(.+?)\\n/) {
		$name = $1;
	}

	foreach my $n (keys %POIname) {
		$ok = 0 if (($n && $neb{$sys} =~ /\t$n\t/is) || ($name && $neb{$sys} =~ /\t$name\t/is));
	}

	$POIname{$name} = 1 if ($name);

	print "$neb{$sys}\n" if (!$POIseen{$sys} && $ok);
}

foreach my $sys (keys %ggg) {
	print "$ggg{$sys}\n";
}

foreach my $sys (keys %tri) {
	print "$tri{$sys}\n";
}

foreach my $sys (keys %trit_hwy) {
	print "$trit_hwy{$sys}\n";
}

print "\n";

my %hash;
@{$hash{markers}} = ();


warn "[IGAU]\n";


my @rows = db_mysql('elite',"select ID,name,callsign,systemName,systemId64,services,coord_x,coord_y,coord_z,note from carriers where isIGAU=1 order by callsign");
foreach my $r (@rows) {
	my $services = $$r{services};
	$services =~ s/(autodock|carrierfuel|carriermanagement|commodities|contacts|crewlounge|dock|engineer|flightcontroller|stationMenu|stationoperations)//gs;
	$services =~ s/exploration/UC/gs;
	$services =~ s/voucherredemption/redemption/gs;
	$services =~ s/,+\s*/, /gs;
	$services =~ s/^\s*,+\s*//s;
	$services =~ s/\s*,+\s*$//s;
	$services = 'no services' if (!$services);
	#print join("\t|\t",'carrierIGAU',"C#$$r{ID}","$$r{name} [$$r{callsign}]",$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{systemName},undef,"($services)")."\n";

	my $sol_dist = commify(sprintf("%.02f",sqrt($$r{coord_x}**2 + $$r{coord_y}**2 + $$r{coord_z}**2)));

	my $text = "$$r{name} [$$r{callsign}]\n$$r{systemName}\n($services)\n$sol_dist ly from Sol";
	my $added = 0;

	foreach my $marker (@{$hash{markers}}) {
		my $dist = sqrt(($$marker{x}-$$r{coord_x})**2 + ($$marker{y}-$$r{coord_y})**2 + ($$marker{z}-$$r{coord_z})**2);

		if ($dist <= 30) {
			$$marker{text} .= "\n\n$text";
			$added = 1;
			last;
		}
	}

	if (!$added) {
		my %car = ();
		$car{text} = $text;
		$car{text} .= "\n$$r{note}" if ($$r{note});
		$car{x} = $$r{coord_x}+0;
		$car{y} = $$r{coord_y}+0;
		$car{z} = $$r{coord_z}+0;
		$car{pin} = 'carrierIGAU';
		push @{$hash{markers}}, \%car;

		my %ca = ();
		$ca{coords}{x} = $$r{coord_x} ? $$r{coord_x}+0 : undef;
		$ca{coords}{y} = $$r{coord_y} ? $$r{coord_y}+0 : undef;
		$ca{coords}{z} = $$r{coord_z} ? $$r{coord_z}+0 : undef;
		$ca{name} = $$r{name};
		$ca{system} = $$r{systemName};
		$ca{id64} = $$r{systemId64} ? $$r{systemId64}+0 : undef;
		push @{$carrierJSONs{IGAU}{carriers}}, \%ca;

		if ($$r{ID}==1) {
			print join("\t|\t",'edastrocarrier','EDASTRO1',"$$r{name} [$$r{callsign}]",$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{systemName},undef,
				"($services)\\n$$r{note}")."\n";
		}
		print join("\t|\t",'IGAUcarrier','IGAU'.int(@{$hash{markers}}),"$$r{name} [$$r{callsign}]",$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{systemName},undef,
			"($services)\\n$$r{note}")."\n";

	}
}
open JSON, ">IGAU-carriers.json";
print JSON encode_json( \%hash );
close JSON;

close OUT;


foreach my $type (keys %carrierJSONs) {
	open JSON, ">carriers-$type.json";
	print JSON encode_json( $carrierJSONs{$type} );
	close JSON;
}

exit;



#####################################################################

sub html_encode {
        my $s = shift;

        $s =~ s/\x{c2}\x{b0}/\&deg;/gs;
        $s =~ s/\x{e2}\x{80}\x{99}/\&apos;/gs;

        return $s;
}
