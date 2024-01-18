#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10 id64_subsector);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

#use lib "/home/bones/elite/id64";
#use EliteTools::ID64;

use Image::Magick;
use POSIX qw(floor);
use File::Basename;
use Time::HiRes q(usleep);

############################################################################

$0 = basename($0);

my $hostname = `/usr/bin/hostname -s`; chomp $hostname;

my $debug		= 0;
my $allow_scp           = 1;
my $german_tank_problem	= 0;
my $attenuation		= 0.25;
my $output_file		= '/DATA/tmp/exploration-saturation-map.txt';
my $allow_maxlog_bands	= 1;
my $scale_factor	= 10;
my $boxel_factoring	= 0;
my $density_floor	= 0;
my $density_floor_mask	= 0;
my $density_floor_div	= 1500;
my $verbose		= 0;
my $write_output	= 0;
my $read_output_file	= 0;
my $debug_floor		= 2; # added to the opacity floor

if ($ARGV[0] eq 'cron') {
	$write_output = 1;
	$debug = 0;
	$allow_scp = 1;
	shift @ARGV;
} elsif ($ARGV[0] eq 'read') {
	$debug = 0;
	$read_output_file = 1;
	$allow_scp = 0;
	$debug_floor = 0;
	shift @ARGV;
} elsif ($ARGV[0] eq 'debug') {
	$debug = 1;
	$read_output_file = 0;
	$allow_scp = 0;
	$debug_floor = 0;
	shift @ARGV;
}

$debug = 1 if ($ARGV[0]);
$allow_scp = 0 if ($debug || $ARGV[1]);
$debug_floor = 0 if (!$debug);

my $maxChildren         = 8;
my $fork_verbose        = 0;

my $location_type	= 'estimated'; # either "measured" or "estimated"

my $band_y		= 4500;
my $band_height		= 1000;
my $band_fade		= 1000;

my $sectorcenter_x      = -65;
my $sectorcenter_y      = -25;
my $sectorcenter_z      = 25815;
my $sectoroffset_z	= 215;

my $sol_fudge		= 150;
my $debug_count		= 50;
my $margin		= 500;

my $scriptpath          = "/home/bones/elite";
my $scripts_path	= "/home/bones/elite/scripts";
my $debug_limit		= ' limit 50000' if ($debug);

my $remote_server       = 'www@services:/www/edastro.com/mapcharts/';
my $ssh                 = '/usr/bin/ssh';
my $scp                 = '/usr/bin/scp -P222';	$scp .= " -O" if ($hostname =~ /ghoul/);
my $convert		= '/usr/bin/convert';
my $filepath            = "/home/bones/www/elite";
$filepath .= "/test" if ($debug);
my $fn			= "$filepath/exploration-saturation-map.bmp";

#my @expl_level = (0,1.5,4,7,9.5,10);
my @expl_level = ();

if ($german_tank_problem) {
	@expl_level = (0,0.5,4,7,9.5,10);
} else {
	@expl_level = (0,1,4.5,8,9.5,10);
}
#@expl_level = (0,0.2,4,7,9.8,10);
@expl_level = (0,0.2,2,5,8,9.8,10);

my %heatindex = ();
@{$heatindex{$expl_level[0]}}	= (0,0,0);
@{$heatindex{$expl_level[1]}}	= (0,0,128);
@{$heatindex{$expl_level[2]}}	= (0,0,255);
@{$heatindex{$expl_level[3]}}	= (0,255,255);
@{$heatindex{$expl_level[4]}}	= (255,255,255);
@{$heatindex{$expl_level[5]}}	= (255,0,0);
@{$heatindex{$expl_level[6]}}	= (255,0,0);
@{$heatindex{1000}}		= (255,0,255);
my $mapcolor_scaling		= 10;

############################################################################

show_queries(0);

my $shellscript = "$filepath/exploration-saturation.sh";
open TXT, ">$shellscript";
print TXT "#!/bin/bash\n";

print "Getting sector list...\n";
open CSV, "<$scripts_path/sector-list-stable.csv";

my @sectorname = ();
my %sector = ();
my %extent = ();
my $header = <CSV>;
my $sectornum = 0;
my %sectorbox = ();
my %sectorchunks = ();
my %sectoroverrides = ();

while (<CSV>) {
	chomp;
	my ($s,$c,$x,$y,$z,$x1,$y1,$z1,$x2,$y2,$z2,$bx,$bz,@extra) = parse_csv($_);
	# format: ${$sectorname[$x][$z]}{$n} = $$r{coord_y};
	#my $bx = floor(($x-$sectorcenter_x)/1280)+$sector_radius;
	#my $bz = floor(($z-$sectorcenter_z)/1280)+$sector_radius;

	$bz += 0;

	#if (!$debug || ($bx>=31 && $bx<=35 && $bz > 60)) {				# beagle point
	#if (!$debug || ($bz > 59)) {							# top edge
	#if (!$debug || ($bx>=33 && $bx<=36 && $bz >= 13 && $bz <= 15)) {		# bubble
	#if (!$debug || ($bx>=33 && $bx<=36 && $bz >= 13 && $bz <= 15) || $bz > 59) {	# bubble + top edge
	#if (!$debug || ($bx == 35 && $bz == 14) || ($bx == 35 && $bz == 35) || ($bx == 26 && $bz == 30)) {	# bubble + colonia + sgr a*
	#if (!$debug || $bx == 35) {							# bubble + sgr a*, central vertical column
	#if (!$debug || (($bx >= 35 && $bx <= 38) && $bz == 63)) {
	if (!$debug || ($bx >= 34 && $bx <= 36)) {					# bubble + sgr a*, central vertical column
	#if (!$debug || ($bx >= 20 && $bx <= 22)) {					# left band
	#if (!$debug || ($bz >= 13 && $bz <= 15)) {					# bubble-centric horizontal band
	#if (1) {									# everything, even when in debug
		${$sectorname[$bx][$bz]}{$s} = $y;
		$sectorbox{floor(($x1+1-$sectorcenter_x)/1280)}{floor(($y1+1-$sectorcenter_y)/1280)}{floor(($z1+1-$sectorcenter_z)/1280)} = $s if ($s !~ /region|sector/i);
		$sector{$s}{x} = $bx;
		$sector{$s}{y} = $bz;
		#print "$s: $bx,$bz\n";
		$sectornum++;

		if ($s !~ /region|sector/i) {
			my $box = sprintf("%02u,%02u",$bx,$bz);
			$sectorchunks{$box}{$s}{x} = $x;
			$sectorchunks{$box}{$s}{y} = $y;
			$sectorchunks{$box}{$s}{z} = $z;
		} else {
			$sectoroverrides{$s} = 1;
		}
	}

	$extent{x_high} = $bx if (!defined($extent{x_high}) || $bx > $extent{x_high});
	$extent{x_low}  = $bx if (!defined($extent{x_low}) || $bx < $extent{x_low});
	$extent{y_high} = $bz if (!defined($extent{y_high}) || $bz > $extent{y_high});
	$extent{y_low}  = $bz if (!defined($extent{y_low}) || $bz < $extent{y_low});
}

print "Sectors: $sectornum\n";
print "X: $extent{x_low} - $extent{x_high}\n";
print "Y: $extent{y_low} - $extent{y_high}\n";

close CSV;

#exit if ($debug);

my @maptop = ();
my @mapdata = ();
my @mapcol = ();
my @mapmax = ();
my $max_log = 0;
my @max_logA = ();
my $systemcount = 0;
my $sectorcount = 0;


sub parse_system {
        my $s = shift;

        if ($s =~ /^(.+\S)\s+([A-Z])([A-Z])\-([A-Z])\s+([a-z])(\d*)\-(\d+)/i) {
                return ($1,$2,$3,$4,$5,$6+0,$7);
        } elsif ($s =~ /^(.+\S)\s+([A-Z])([A-Z])\-([A-Z])\s+([a-z])(\d+)$/i) {
                return ($1,$2,$3,$4,$5,0,$6);
        }
        return undef;
}

print "Looping systems...\n";

my %subsect = ();

#foreach my $sectorname (sort keys %sectoroverrides) {
#	printf("[%05u] %s\n",$$,$sectorname);
#	process_sectors(0,$sectorname);
#}

my @kids = ();
my @childpid = ();

my @sectorloop = sort keys %sectorchunks;

if ($read_output_file) {
	open OUTPUTFILE, "<$output_file";
	while (my $line = <OUTPUTFILE>) {
		chomp $line;

		parse_line($line);
	}
	close OUTPUTFILE;
} else {
	if ($write_output) {
		system('/usr/bin/mv',$output_file,"$output_file.old");
		open OUTPUTFILE, ">$output_file";
		print OUTPUTFILE "SCALE:$scale_factor\n";
	}
	
	while (@sectorloop) {
		foreach my $childNum (0..$maxChildren-1) {
	
			last if (!@sectorloop);
			my $sectorchunk = shift @sectorloop;
			printf("[%05u] %s (fork) %s\n",$$,$sectorchunk, join(',',keys %{$sectorchunks{$sectorchunk}}));
	
			my $pid = open $kids[$childNum] => "-|";
			die "Failed to fork: $!" unless defined $pid;
	
			if ($pid) {
				# Parent.
				$childpid[$childNum] = $pid;
			} else {
				# Child.
				$0 .= ' ('.$sectorchunk.')';
				disconnect_all();
				#sleep floor($childNum/4)+1 if ($childNum);
				usleep 100_000*$childNum if ($childNum);
				process_sectors(1,$sectorchunk,keys %{$sectorchunks{$sectorchunk}});
				exit;
			}
		}
	
		my $cn = 0;
		foreach my $fh (@kids) {
			next if (!defined($fh));
	
			my @lines = <$fh>;
	
			while (@lines) {
				my $line = shift @lines;
				chomp $line;
	
				print "$line\n" if ($fork_verbose);
	
				print OUTPUTFILE "$line\n" if ($write_output);
	
				parse_line($line);
	
			}
	
			waitpid $childpid[$cn], 0;
			$kids[$cn] = undef;
			$cn++;
		}
	}
	close OUTPUTFILE if ($write_output);
}

sub parse_line {
	my $line = shift;

	if ($line =~ /^SCALE:(\d+)/) {
		$scale_factor += $1;
	} elsif ($line =~ /^SYSTEMS:(\d+)/) {
		$systemcount += $1;
	} elsif ($line =~ /\|/) {
		my ($x,$y,$found,$max,$top,$boxelstring) = split /\|/, $line;
		if ($found || $max) {
			$mapdata[$x][$y] += $found/$scale_factor;
			$mapmax[$x][$y] += $max/$scale_factor;

			$maptop[$x][$y] = $top if (!defined($maptop[$x][$y]) || $top > $maptop[$x][$y]);

			if ($boxel_factoring) {
				my $mc = 0;
				BOXELS1: foreach my $boxellist (split ':', $boxelstring) {
					push @{$mapcol[$x][$y][$mc]}, split /,/, $boxellist;
					#print "$x, $y [$mc] = ".join(',',@{$mapcol[$x][$y][$mc]})."\n" if ($boxellist);
					$mc++;
				}
			}
		}
	} else {
		print "$line\n" if (!$fork_verbose);	# Redundant with above print if verbose
	}
}

sub process_sectors {
	my $draw_mode = shift;
	my $sectorchunk = shift;
	my @sectorlist = @_;

	my %maptop = ();
	my %mapdata = ();
	my %mapcol = ();
	my %mapmax = ();
	my %coords  = ();
	my $rowcount = 0;
	my $systemcount_internal = 0;
	
	foreach my $sectorname (@sectorlist) {

		next if (!$sectorname);
	
		my $sectornamesafe = $sectorname;
		$sectornamesafe =~ s/(['%^$"]+)/\\$1/gs;

		#print "$sectorname: $sectorchunks{$sectorchunk}{$sectorname}{x}, $sectorchunks{$sectorchunk}{$sectorname}{y}, $sectorchunks{$sectorchunk}{$sectorname}{z}\n";

		my $x1 = floor(($sectorchunks{$sectorchunk}{$sectorname}{x}-$sectorcenter_x)/1280)*1280 + $sectorcenter_x;
		my $y1 = floor(($sectorchunks{$sectorchunk}{$sectorname}{y}-$sectorcenter_y)/1280)*1280 + $sectorcenter_y;
		my $z1 = floor(($sectorchunks{$sectorchunk}{$sectorname}{z}-$sectorcenter_z)/1280)*1280 + $sectorcenter_z;
	
		my @rows = db_mysql('elite',"select name,id64,coord_x,coord_z from systems where coord_x>=? and coord_x<? and coord_y>=? and coord_y<? and ".
					"coord_z>=? and coord_z<? and coord_x is not null and coord_y is not null and coord_z is not null and deletionState=0",
					[($x1,$x1+1280,$y1,$y1+1280,$z1,$z1+1280)]);

		printf("[%05u] %9u %s\n",$$,int(@rows),$sectorname);

		$rowcount += int(@rows);

		%subsect = ();
	
		foreach my $r (@rows) {
			my ($subsector,$sec,$l1,$l2,$l3,$masscode,$n,$num) = ();

			$sec = $sectorname; # Override it back into the sector that owns this coordinate range.
	
			if ($$r{id64}) {
				($masscode,$subsector,$num) = id64_subsector($$r{id64});
				#warn "$masscode,$subsector: $num\t$$r{id64}\n";

				$subsect{$sec}{$masscode}{$subsector}{sys}{$num} = 1;
				$subsect{$sec}{$masscode}{$subsector}{max} = $num if (!$subsect{$sec}{$masscode}{$subsector}{max} || $num > $subsect{$sec}{$masscode}{$subsector}{max});
	
				$subsect{$sec}{$masscode}{$subsector}{x_min} = $$r{coord_x} if (!defined($subsect{$sec}{$masscode}{$subsector}{x_min}) || 
						$$r{coord_x} < $subsect{$sec}{$masscode}{$subsector}{x_min});
	
				$subsect{$sec}{$masscode}{$subsector}{x_max} = $$r{coord_x} if (!defined($subsect{$sec}{$masscode}{$subsector}{x_max}) || 
						$$r{coord_x} > $subsect{$sec}{$masscode}{$subsector}{x_max});
	
				$subsect{$sec}{$masscode}{$subsector}{y_min} = $$r{coord_z} if (!defined($subsect{$sec}{$masscode}{$subsector}{y_min}) || 
						$$r{coord_z} < $subsect{$sec}{$masscode}{$subsector}{y_min});
	
				$subsect{$sec}{$masscode}{$subsector}{y_max} = $$r{coord_z} if (!defined($subsect{$sec}{$masscode}{$subsector}{y_max}) || 
						$$r{coord_z} > $subsect{$sec}{$masscode}{$subsector}{y_max});
	
				$systemcount_internal++;
			}
		}

		if ($draw_mode) {
			my $sec = $sectorname;
			#print "$sec = ".int(keys %{$subsect{$sec}})." mass codes\n";

			foreach my $masscode (keys %{$subsect{$sec}}) {	
				foreach my $subsector (keys %{$subsect{$sec}{$masscode}}) {	
		
					my $max = $subsect{$sec}{$masscode}{$subsector}{max}+1; # include zero
		
					next if (!$max);
		
					my $found = 0;
					for (my $i=0; $i<=$max; $i++) {
						$found++ if ($subsect{$sec}{$masscode}{$subsector}{sys}{$i});
					}
		
					$found = $max if ($found > $max);
					my $complete = $found / $max;
		
					next if (!$found);
			
					my $bitcount = letter_ord(uc($masscode));
					my $size = 1 << $bitcount;
					my $width = 128 >> $bitcount;
		
					## Assumes boxel lettering wraps and continues:
					#my $mask = $width-1;
					#my $shiftbits = $bitcount;
		
					# Uses fixed bit widths for non-contiguous boxel lettering:
					my $mask = 127;
					my $shiftbits = 7;
		
					my $x = ($subsector & $mask)*$size;
					my $y = (($subsector >> $shiftbits) & $mask)*$size;
					my $z = (($subsector >> ($shiftbits*2)) & $mask)*$size;
		
					my $sec_height = floor($sectorchunks{$sectorchunk}{$sectorname}{y}/1280);
					my @boxelcolumn = $sec_height*$width + (($subsector >> $shiftbits) & $mask);

					my $height1 = $sec_height*1280+$y+$size;
					my $height2 = 0-($sec_height*1280+$y);

					if (ord($masscode) > ord('e')) {
						$height1 = 0;
						$height2 = 0;
					}
					
					if ($location_type eq 'estimated' && $sector{$sec}{x} && $sector{$sec}{y}) {
		#print ">> $width\t$x\t$z\n";
		
						#my $mapx = 128*$sector{$sectorname}{x} + $x;
						#my $mapy = 8800 - (128*$sector{$sectorname}{y} + $z);
		
						my $mapx = 4500 + (128*($sector{$sec}{x}-35) + $x) + floor($sectorcenter_x/10);
						my $mapy = 7107 - (128*($sector{$sec}{y}-14) + $z);
		
						my $area = $size**1.7;
						my $found_pixel = $found / $area;
						my $max_pixel = $max / $area;

						for(my $mx=0; $mx<$size; $mx++) {
							for(my $my=0; $my<$size; $my++) {

								my $drawx = $mapx+$mx;
								my $drawy = $mapy-$my;

								$mapdata{$drawx}{$drawy} += $found_pixel;
								$mapmax{$drawx}{$drawy} += $max_pixel;

								$maptop{$drawx}{$drawy} = $height1 if (!defined($maptop{$drawx}{$drawy}) || $height1 > $maptop{$drawx}{$drawy});
								$maptop{$drawx}{$drawy} = $height2 if (!defined($maptop{$drawx}{$drawy}) || $height2 > $maptop{$drawx}{$drawy});
	
								if ($boxel_factoring) {
									@{$mapcol{$mapx+$mx}{$mapy-$my}{$bitcount}} = () if (!exists($mapcol{$mapx+$mx}{$mapy-$my}{$bitcount}) || 
												ref($mapcol{$mapx+$mx}{$mapy-$my}{$bitcount}) ne 'ARRAY');
									push @{$mapcol{$mapx+$mx}{$mapy-$my}{$bitcount}}, @boxelcolumn;
								}
							}
						}

					} else { 
						# location_type eq 'measured'
		
						my $startx = floor($subsect{$sec}{$masscode}{$subsector}{x_min}/10)+4500;
						my $widthx = floor($subsect{$sec}{$masscode}{$subsector}{x_max}-$subsect{$sec}{$masscode}{$subsector}{x_min}) + 1;
						my $starty = 7000-floor($subsect{$sec}{$masscode}{$subsector}{y_max}/10);
						my $widthy = floor($subsect{$sec}{$masscode}{$subsector}{y_max}-$subsect{$sec}{$masscode}{$subsector}{y_min}) + 1;
		
						$widthx = $width if ($widthx>$width);
						$widthy = $width if ($widthy>$width);
		
						my $penaltypercent = 1;
		
						if (0) {
							if ($widthy < $width) {
								$penaltypercent *= $widthy/$width;
								$starty -= floor(($width-$widthy)/2);
								$widthy = $width;
							}
			
							if ($widthx < $width) {
								$penaltypercent *= $widthx/$width;
								$startx -= floor(($width-$widthx)/2);
								$widthx = $width;
							}
						}
		
						if ($widthy == 1 && $width>1) {
							$starty --;
							$widthy = 3;
						}
		
						if ($widthx == 1 && $width>1) {
							$startx --;
							$widthx = 3;
						}
		
						#print ">> $startx	$starty	($widthx,$widthy)\n";
		
						my $area = $widthx * $widthy;
						my $found_pixel = $found / $area;
						my $max_pixel = $max / $area;
					
						for(my $mx=0; $mx<$widthx; $mx++) {
							for(my $my=0; $my<$widthy; $my++) {
								$mapdata{$startx+$mx}{$starty+$my} += $found_pixel * $penaltypercent;
								$mapmax{$startx+$mx}{$starty+$my} += $max_pixel;

								if ($boxel_factoring) {
									@{$mapcol{$startx+$mx}{$starty+$my}{$bitcount}} = () if (!exists($mapcol{$startx+$mx}{$starty+$my}{$bitcount}) || 
												ref($mapcol{$startx+$mx}{$starty+$my}{$bitcount}) ne 'ARRAY');
									push @{$mapcol{$startx+$mx}{$starty+$my}{$bitcount}}, @boxelcolumn;
								}
							}
						}
					}
				}
			}

			delete($subsect{$sectorname});
		}
	}

	if ($draw_mode) {
		printf("[%05u] %9u [Total] %s\n",$$,$rowcount,join(', ',@sectorlist));

		print "SYSTEMS:$systemcount_internal\n";

		foreach my $x (keys %mapdata) {
			foreach my $y (keys %{$mapdata{$x}}) {
				my $boxels = '';

				if ($boxel_factoring) {
					BOXELS2: foreach my $mc (0..7) {
						$boxels .= ":" if ($mc);
						$boxels .= join(',',sort @{$mapcol{$x}{$y}{$mc}}) if (exists($mapcol{$x}{$y}{$mc}) && 
									ref($mapcol{$x}{$y}{$mc}) eq 'ARRAY' && @{$mapcol{$x}{$y}{$mc}});
					}
				}
				printf("%u|%u|%.06f|%.06f|%i|%s\n",$x,$y,$mapdata{$x}{$y}*$scale_factor,$mapmax{$x}{$y}*$scale_factor,$maptop{$x}{$y},$boxels);
			}
		}
	} else {

		# nothing
	}

	#print "END DATA\n";
}



print "Getting logos...\n";

my $compass = Image::Magick->new;
show_result($compass->Read("images/thargoid-rose-hydra.bmp"));

my $logo1 = Image::Magick->new;
show_result($logo1->Read("images/edastro-550px.bmp"));

my $logo2 = Image::Magick->new;
show_result($logo2->Read("images/edastro-greyscale-550px.bmp"));



print "Creating canvas...\n";

my $depth = 8;
my $colorspace = 'RGB';
my $imagetype = 'TrueColor';
my $size = 9000+$margin;

my $mapimage = Image::Magick->new(
	size  => $size.'x'.$size,
	type  => $imagetype,
	depth => $depth,
	verbose => $verbose
);
show_result($mapimage->ReadImage('canvas:black'));
show_result($mapimage->Quantize(colorspace=>$colorspace));

my $scale_vert = Image::Magick->new;
show_result($scale_vert->Read("$scriptpath/images/scale-9k-vertical.bmp"));
show_result($mapimage->Composite(image=>$scale_vert, compose=>'screen', gravity=>'northwest',x=>8800,y=>0));

my $scale_horiz = Image::Magick->new;
show_result($scale_horiz->Read("$scriptpath/images/scale-9k-horizontal.bmp"));
show_result($mapimage->Composite(image=>$scale_horiz, compose=>'screen', gravity=>'northwest',x=>0,y=>8800));

my $mask_layer = Image::Magick->new;
show_result($mask_layer->Read("images/galmap-mask.bmp")) if ($density_floor && $density_floor_mask);

print "Calculating max logs...\n";

my $dotcount = 0;

for(my $x=0; $x<9000; $x++) {
	for(my $y=0; $y<9000; $y++) {
		if ($mapdata[$x][$y] && $mapmax[$x][$y]) {
			my $log = log10($mapmax[$x][$y]);

			if ($log > $max_log) {
				$max_log = $log;
				#print "New MAX-LOG: $log ($x, $y)\n";
			}

			if ($allow_maxlog_bands) {
				#my $i = abs($y-7000); $i = 3000 if ($i>3000);
				my $b = abs($y-$band_y);
				my $i = 0; $i=1 if ($b >= $band_height);
				$max_logA[$i] = $log if ($log > $max_logA[$i]);
			}
		}
	}
}
print "max_log = $max_log\nmax_logA[0] = $max_logA[0]\nmax_logA[1] = $max_logA[1]\n";

print "Drawing...\n";

for(my $x=0; $x<9000; $x++) {
	for(my $y=0; $y<9000; $y++) {
		if ($mapdata[$x][$y] && $mapmax[$x][$y]) {

			my $max = $mapmax[$x][$y];
			my $percent = 0;

			if (!$german_tank_problem) {
				$percent = $mapdata[$x][$y]/$mapmax[$x][$y];
			} else {
				my $germantank_max = $max + ($max/$mapdata[$x][$y]) - 1;
				if ($germantank_max) { 
					$percent = $mapdata[$x][$y]/$germantank_max;
				} else {
					$percent = 1;
				}
			}

			if ($density_floor) {
				my $floormax = $maptop[$x][$y]/$density_floor_div;

	     	        	if ($mapmax[$x][$y]<$floormax) {
		                        my @pixels = $mask_layer->GetPixel(x=>$x,y=>$y) if ($density_floor_mask);
		                        #$max = $max+($floormax-$max)*(1-$pixels[0]);
	
					my $percent2 = $mapdata[$x][$y]/$floormax;
					$percent = $percent+(($percent2-$percent)*(1-$pixels[0])) if ($density_floor_mask);
					$percent = $percent2 if (!$density_floor_mask);
		                }
			}

			my $sol_dist = 100000; 
			$sol_dist = sqrt(($x-4500)**2 + ($y-7000)**2) if (abs($x-4500)<=$sol_fudge && abs($y-7000)<=$sol_fudge);

			$percent += (($sol_fudge-$sol_dist)/$sol_fudge)*(1-$percent) if ($sol_dist <= $sol_fudge);


			my $colpercent_total = 0;
			my $colpercent_num = 0;

			if ($boxel_factoring) {
				BOXELS3: foreach my $masscode (0..7) {
	
					if (exists($mapcol[$x][$y][$masscode]) && ref($mapcol[$x][$y][$masscode]) eq 'ARRAY') {
						my @boxels = ();
						my %seen = ();
	
						my $boxelpercent = 1; # Assume no penalty?
	
						# Sort and de-dupe:
						foreach my $n (sort @{$mapcol[$x][$y][$masscode]}) {
							push @boxels if (!$seen{$n});
							$seen{$n}=1;
						}
		
						@boxels = sort @boxels; #not needed, sorted above
		
						if (@boxels>1) {
							my $num = $boxels[@boxels] - $boxels[0] + 1;
							$boxelpercent = int(@boxels)/$num;
	
							$colpercent_total += $boxelpercent;
							$colpercent_num++;
						} elsif (@boxels == 1) {
							$colpercent_total++;
							$colpercent_num++;
						}
					}
				}
				my $colpercent = 1;
				$colpercent = $colpercent_total / $colpercent_num if ($colpercent_num);

				$percent = ($percent*0.8) + ($percent*$colpercent*0.2);
			}

			my $ml = undef;

			if ($allow_maxlog_bands) {
				#my $i = abs($y-7000); $i = 3000 if ($i>3000); $ml = $max_logA[$i];

				my $b = abs($y-$band_y);
				if ($b < $band_height) {
					$ml = $max_logA[0];
				} elsif ($b >= $band_height + $band_fade) {
					$ml = $max_logA[1];
				} else {
					my $diff = $max_logA[1]-$max_logA[0];
					$ml = (($b-$band_height)/$band_fade)*$diff + $max_logA[0];
				}
			}

			if ($attenuation) {
				my $maxL = $max_log;
				$maxL = $ml if ($ml);

				#my $atten = 1-(sin((log10($mapmax[$x][$y])/$maxL)*3.1415926)*$attenuation);
				my $atten = 1-(sin($percent*3.1415926)*$attenuation*(1-(log10($mapmax[$x][$y])/$maxL)));
				$percent *= $atten;
			}


			my @pixels = indexed_heat_pixels($mapcolor_scaling * $percent, log10($mapmax[$x][$y]), $ml);
			$mapimage->SetPixel( x => $x, y => $y, color => float_colors(@pixels) );
		}
	}
	$dotcount++;

	print '.'  if ($dotcount % 9 == 0);
	print "\n" if ($dotcount % 900 == 0);
	
}
print "\n";


my $pointsize = 130;

$mapimage->Annotate(pointsize=>$pointsize,fill=>'white',x=>$pointsize,y=>$pointsize*1.8,text=>"Estimated Exploration Saturation Relative to Star Density");
my $author = "By CMDR Orvidius (edastro.com) - CC BY-NC-SA 3.0 - Data from EDDN & EDSM.net";
my $additional = commify($systemcount)." systems";
$mapimage->Annotate(pointsize=>$pointsize,fill=>'white',x=>$pointsize,y=>$pointsize*0.8,gravity=>'southwest',text=>"$author - ".epoch2date(time)." - $additional");

show_result($logo1->Resize(geometry=>'1000x1000+0+0'));
show_result($mapimage->Composite(image=>$logo1, compose=>'over', gravity=>'northeast',x=>75+$margin,y=>75));
show_result($compass->Resize(geometry=>'1000x1000+0+0'));
show_result($mapimage->Composite(image=>$compass, compose=>'over', gravity=>'southeast',x=>75+$margin,y=>75+$margin));



$pointsize *= 0.75;

my $legend_x = $pointsize;
my $legend_y = 9000*0.88;

show_result($mapimage->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Barely Explored', x=>$legend_x+$pointsize*2, y=>$legend_y+$pointsize*1));
show_result($mapimage->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Very Lightly Explored', x=>$legend_x+$pointsize*2, y=>$legend_y+$pointsize*2.5));
show_result($mapimage->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Lightly Explored', x=>$legend_x+$pointsize*2, y=>$legend_y+$pointsize*4));
show_result($mapimage->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Moderately Explored', x=>$legend_x+$pointsize*2, y=>$legend_y+$pointsize*5.5));
show_result($mapimage->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Heavily Explored', x=>$legend_x+$pointsize*2, y=>$legend_y+$pointsize*7));
show_result($mapimage->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Very Heavily Explored', x=>$legend_x+$pointsize*2, y=>$legend_y+$pointsize*8.5));

$mapimage->Draw( primitive=>'rectangle',stroke=>'white', fill=>"rgb(".join(',',indexed_heat_pixels($expl_level[0])).")",  strokewidth=>2, points=>sprintf("%u,%u %u,%u",
                                                                $legend_x+$pointsize*0.5,$legend_y+$pointsize*0.2,$legend_x+$pointsize*1.5,$legend_y+$pointsize*1.2));
$mapimage->Draw( primitive=>'rectangle',stroke=>'white', fill=>"rgb(".join(',',indexed_heat_pixels($expl_level[1])).")", strokewidth=>2, points=>sprintf("%u,%u %u,%u",
                                                                $legend_x+$pointsize*0.5,$legend_y+$pointsize*1.7,$legend_x+$pointsize*1.5,$legend_y+$pointsize*2.7));
$mapimage->Draw( primitive=>'rectangle',stroke=>'white', fill=>"rgb(".join(',',indexed_heat_pixels($expl_level[2])).")", strokewidth=>2, points=>sprintf("%u,%u %u,%u",
                                                                $legend_x+$pointsize*0.5,$legend_y+$pointsize*3.2,$legend_x+$pointsize*1.5,$legend_y+$pointsize*4.2));
$mapimage->Draw( primitive=>'rectangle',stroke=>'white', fill=>"rgb(".join(',',indexed_heat_pixels($expl_level[3])).")", strokewidth=>2, points=>sprintf("%u,%u %u,%u",
                                                                $legend_x+$pointsize*0.5,$legend_y+$pointsize*4.7,$legend_x+$pointsize*1.5,$legend_y+$pointsize*5.7));
$mapimage->Draw( primitive=>'rectangle',stroke=>'white', fill=>"rgb(".join(',',indexed_heat_pixels($expl_level[4])).")", strokewidth=>2, points=>sprintf("%u,%u %u,%u",
                                                                $legend_x+$pointsize*0.5,$legend_y+$pointsize*6.2,$legend_x+$pointsize*1.5,$legend_y+$pointsize*7.2));
$mapimage->Draw( primitive=>'rectangle',stroke=>'white', fill=>"rgb(".join(',',indexed_heat_pixels($expl_level[5])).")", strokewidth=>2, points=>sprintf("%u,%u %u,%u",
                                                                $legend_x+$pointsize*0.5,$legend_y+$pointsize*7.7,$legend_x+$pointsize*1.5,$legend_y+$pointsize*8.7));


print "Writing $fn ($depth)\n";
show_result($mapimage->Set(depth => $depth));
show_result($mapimage->Set(gamma => 0.454545));
show_result($mapimage->Write( filename => $fn ));

my $png = $fn;
$png =~ s/\.(png|gif|bmp|jpg|tga|tif)$/.png/;
my $thumb = $fn;
$thumb =~ s/\.(png|gif|bmp|jpg|tga|tif)$/-thumb.jpg/;
my $jpg = $fn;
$jpg =~ s/\.(png|gif|bmp|jpg|tga|tif)$/.jpg/;
#my $large = $fn;
#$large =~ s/\.(png|gif|bmp|jpg|tga|tif)$/-large.png/;


#my_system("$convert $fn -verbose $large");
#my_system("$convert $fn -verbose -resize 1600x1600 $png");
my_system("$convert $fn -verbose $png") if ($fn ne $png);
my_system("$convert $fn -verbose -resize 1200x1200 $jpg");
my_system("$convert $fn -verbose -resize 200x200 -gamma 1.1 $thumb");
my_system("$scp $png $jpg $thumb $remote_server") if (!$debug && $allow_scp);

close TXT;
print "EXEC $shellscript\n";
exec "/bin/bash $shellscript";

exit;

############################################################################

sub pick_sector {
        my $href = shift;
        return $sectorbox{floor(($$href{coord_x}-$sectorcenter_x)/1280)}{floor(($$href{coord_y}-$sectorcenter_y)/1280)}{floor(($$href{coord_z}-$sectorcenter_z)/1280)};
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

sub indexed_heat_pixels {
	my $heat = shift;
	my $strength = shift;
	my $maxLog = shift;
	$maxLog = $max_log if (!$maxLog || !$allow_maxlog_bands);
	$maxLog = $strength if (!$maxLog && $strength);
	$maxLog = 1 if (!$maxLog);
	$strength = $maxLog if (!defined($strength));

	return (0,0,0) if (!$heat);

	my $bottomIndex = 0;
	my $topIndex = 0;

	my @list = sort {$a<=>$b} keys %heatindex;
	my $i = 0;
	while ($i<@list-1 && !$topIndex) {
		if ($heat >= $list[$i] && $heat < $list[$i+1]) {
			$bottomIndex = $i; $topIndex = $i+1;
			last;
		}
		$i++;
	}

	return (0,0,0) if (!$topIndex);

	my $opacity_floor = $maxLog*(2.5+$debug_floor);

	if ($strength) {
		#$heat = ($heat/2) + (($strength/$maxLog)*($heat/2));
	}

	my $decimal = ($heat-$list[$bottomIndex]) / ($list[$topIndex]-$list[$bottomIndex]);
	my $opacity = ($strength+$opacity_floor) / ($maxLog+$opacity_floor);

	my @bottomColor = @{$heatindex{$list[$bottomIndex]}};
	my @topColor    = @{$heatindex{$list[$topIndex]}};

	my @pixels = scaledColorRange($bottomColor[0],$bottomColor[1],$bottomColor[2],$decimal,$topColor[0],$topColor[1],$topColor[2]);

	#return @pixels;

	for (my $i=0; $i<3; $i++) {
		$pixels[$i] *= $opacity;
	}

	return @pixels;
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

sub letter_ord {
	return ord(uc(shift))-ord('A');
}

sub show_result {
	foreach (@_) {
		warn "WARN: $_\n" if ($_);
	}
}


############################################################################




