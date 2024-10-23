#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch);

use Image::Magick;
use POSIX qw(floor);

############################################################################

my $debug		= 0;
my $skip_framing	= 0;
my $short_date		= 0;
my $verbose		= 1;
my $allow_scp		= 1;
my $max_frames		= 0;
my $use_bodies		= 1;

my $doing_dw2		= 0;
$doing_dw2 = 0 if (time > date2epoch('2019-06-14 00:00:00'));

my $dw2_start		= '2019-01-01';
my $dw2_stop		= '2019-06-14';
my $dw2_first		= 0;
my $dw2_last		= 0;

my $decay_rate		= 0;
$decay_rate = 0.95 if ($ARGV[0]);

my $filepath		= "/home/bones/www/elite/galactic-history";
my $scriptpath		= "/home/bones/elite";
my $datapath		= "$scriptpath/videoscratch";
$datapath .= '-decay' if ($decay_rate);

my $vidscript		= "$scriptpath/complete-video.sh";
$vidscript =~ s/\.sh/-decay.sh/s if ($decay_rate);

my $remote_server       = 'www@services:/www/edastro.com/mapcharts';
my $remote_frame	= "$remote_server/vid-heatmap.jpg";

my $author		= "By CMDR Orvidius (edastro.com) - CC BY-NC-SA 3.0";

my $galrad		= 45000;
my $galsize		= $galrad*2;

my $scale_factor	= 1;

my $size_y		= 1080*$scale_factor;
my $size_x		= int($size_y*16/9);

my $pointsize		= 20*$scale_factor;
my $smallpointsize	= 14*$scale_factor;

my $scp			= '/usr/bin/scp -P222';
my $rm			= '/bin/rm';
my $ffmpeg		= '/usr/bin/ffmpeg';
my $format		= 'jpg';

my $max_heat		= 8;
my @heatcolor		= ();
@{$heatcolor[0]}	= (0,0,200);
@{$heatcolor[1]}	= (63,63,255);
@{$heatcolor[2]}	= (63,127,255);
@{$heatcolor[3]}	= (0,255,255);
@{$heatcolor[4]}	= (0,255,0);
@{$heatcolor[5]}	= (255,255,0);
@{$heatcolor[6]}	= (255,255,255);
@{$heatcolor[7]}	= (255,0,0);
@{$heatcolor[8]}	= (255,0,255);
@{$heatcolor[9]}	= (255,255,255);	# Out of range
@{$heatcolor[10]}	= (0,0,0);		# Out of range

my %intensity_scale	= ();
$intensity_scale{main}	= 1.5; #1.9;
$intensity_scale{sec}	= 2.2; #2.5;
my $decay_multiplier	= 1.6;  #1.8;

my $zoomsize		= int(($size_x-$size_y)/2);
my $zoomscale		= int(20/$scale_factor);

my %zooms		= ();

$zooms{beagle}{mapx}	= -1111.56;
$zooms{beagle}{mapy}	= 65269.8 - 1000;
$zooms{beagle}{title1}	= 'Beagle Point';
$zooms{beagle}{x1}	= $size_y;
$zooms{beagle}{x2}	= $size_y+$zoomsize-1;
$zooms{beagle}{y1}	= $size_y-$zoomsize*2;
$zooms{beagle}{y2}	= $size_y-$zoomsize-1;

$zooms{sagA}{mapx}	= 25.2188;
$zooms{sagA}{mapy}	= 25900;
$zooms{sagA}{title1}	= 'Sagittarius A*';
$zooms{sagA}{x1}	= $size_y+$zoomsize;
$zooms{sagA}{x2}	= $size_y+$zoomsize*2-1;
$zooms{sagA}{y1}	= $size_y-$zoomsize*2;
$zooms{sagA}{y2}	= $size_y-$zoomsize-1;

$zooms{colonia}{mapx}	= -9530.5;
$zooms{colonia}{mapy}	= 19808.1;
$zooms{colonia}{title2}	= 'Colonia';
$zooms{colonia}{x1}	= $size_y;
$zooms{colonia}{x2}	= $size_y+$zoomsize;
$zooms{colonia}{y1}	= $size_y-$zoomsize;
$zooms{colonia}{y2}	= $size_y-1;

$zooms{bubble}{mapx}	= 0;
$zooms{bubble}{mapy}	= 0;
$zooms{bubble}{title2}	= 'Bubble / Sol';
$zooms{bubble}{x1}	= $size_y+$zoomsize;
$zooms{bubble}{x2}	= $size_y+$zoomsize*2-1;
$zooms{bubble}{y1}	= $size_y-$zoomsize;
$zooms{bubble}{y2}	= $size_y-1;

############################################################################
my @rows = ();
$SIG{TERM} = $SIG{'INT'} = sub { cleanup(); exit; };

@rows = db_mysql('elite',"select edsm_date from systems where edsm_date is not null and edsm_date>'2010-01-01 00:00:00' order by edsm_date limit 1");
my $firstdate = ${$rows[0]}{edsm_date};
$firstdate =~ s/\s+.*$//;

$firstdate = '2019-01-01' if ($debug && $short_date);

@rows = db_mysql('elite',"select edsm_date from systems where edsm_date is not null order by edsm_date desc limit 1");
my $lastdate = ${$rows[0]}{edsm_date};
$firstdate =~ s/\s+.*$//;

print "Date range: $firstdate  ->  $lastdate (decay rate: $decay_rate)\n";

my $date = $firstdate;

my $sys_vector = '';

my $logo = Image::Magick->new;
#$logo->Read("$scriptpath/images/logo-elite-explorer.png");
$logo->Read("$scriptpath/images/edastro-550px.bmp");
$logo->Resize(geometry=>int(220*$scale_factor).'x'.int(220*$scale_factor).'+0+0');

my $galaxymap = Image::Magick->new;
$galaxymap->Read("$scriptpath/images/galaxy-2k-plain.bmp") if ($size_y >  1080);
$galaxymap->Read("$scriptpath/images/galaxy-1k-plain.bmp") if ($size_y <= 1080);
$galaxymap->Gamma( gamma=>0.9, channel=>"all" );
$galaxymap->Modulate( saturation=>60 );
$galaxymap->Modulate( brightness=>40 );
$galaxymap->Quantize(colorspace=>'RGB');
$galaxymap->Set(depth => 8);
$galaxymap->Resize(geometry=>int($size_y).'x'.int($size_y).'+0+0');

my $image = Image::Magick->new( size  => $size_x.'x'.$size_y, type  => 'TrueColor', depth => 8, verbose => 'false');
$image->ReadImage('canvas:black');
$image->Composite(image=>$galaxymap, compose=>'over');
$image->Quantize(colorspace=>'RGB');
$image->Set(depth => 8);
$image->Set(quality=>90);
$image->Flatten();
$image->Draw( primitive=>'rectangle', stroke=>'rgb(0,0,0)', fill=>'rgb(0,0,0)', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$size_y,0,$size_x,$size_y-$zoomsize*2));

$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>"Exploration Heatmap Time Lapse", x=>$size_y+$pointsize, y=>$pointsize*8);
$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>"Elite:Dangerous Astrometrics (edastro.com)", x=>$size_y+$pointsize, y=>$pointsize*9.5);
$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>"by CMDR Orvidius - Data from EDSM.net", x=>$size_y+$pointsize, y=>$pointsize*11);

$image->Composite(image=>$logo, compose=>'over', gravity=>'northeast',x=>int(15*$scale_factor),y=>int(15*$scale_factor));

system("$rm -f $datapath/*jpg") if (!$debug && !$skip_framing);

open TXT, ">$vidscript";
print TXT "#!/bin/bash\n";

make_video();
cleanup();

close TXT;
 
exec "/bin/bash $vidscript";
exit;

############################################################################

sub make_video {

	my $last_frame = '';
	my @map = ();
	my $img_count = 0;
	my $sys_count = 0;
	my @window = ();

	my @orig = ();
	for (my $y=0; $y<$size_y; $y++) {
		for (my $x=0; $x<$size_y; $x++) {	# Uses "size_y" intentionally
			my @pixels = $galaxymap->GetPixel(x=>$x,y=>$y);
			$orig[$x][$y][0] = int($pixels[0]*255);
			$orig[$x][$y][1] = int($pixels[1]*255);
			$orig[$x][$y][2] = int($pixels[2]*255);
		}
	}

	while ($date lt $lastdate) {
		$dw2_first = $img_count if (!$dw2_first && ($date gt $dw2_start || $date eq $dw2_start));
		$dw2_last = $img_count if (!$dw2_last && ($date gt $dw2_stop || $date eq $dw2_stop));

		my $show_date = $date;
		my $starttime = "$date 00:00:00";
		advance_date(\$date);
		my $endtime = "$date 00:00:00";

		if (!$debug && !$skip_framing) {
			my $orig_sys_count = unpack("%32b*", $sys_vector);
	
			my @rows = db_mysql('elite',"select distinct edsm_id,coord_x,coord_z,0.75 as v from systems where ".
						"(date_added>='$starttime' and date_added<'$endtime') or ".
						"(edsm_date>='$starttime' and edsm_date<'$endtime') or ".
						"(updateTime>='$starttime' and updateTime<'$endtime')");

			push @rows, db_mysql('elite',"select distinct systemId as edsm_id,coord_x,coord_z,0.25 as v from systems,stars where stars.systemId=systems.edsm_id and ".
				"( (stars.updateTime>='$starttime' and stars.updateTime<'$endtime') or (stars.edsm_date>='$starttime' and stars.edsm_date<'$endtime') or ".
				"(stars.date_added>='$starttime' and stars.date_added<'$endtime') or (discoveryDate>='$starttime' and discoveryDate<'$endtime') )") if ($use_bodies);

			push @rows, db_mysql('elite',"select distinct systemId as edsm_id,coord_x,coord_z,0.25 as v from systems,planets where planets.systemId=systems.edsm_id and ".
				"( (planets.updateTime>='$starttime' and planets.updateTime<'$endtime') or (planets.edsm_date>='$starttime' and planets.edsm_date<'$endtime') or ".
				"(planets.date_added>='$starttime' and planets.date_added<'$endtime') or (discoveryDate>='$starttime' and discoveryDate<'$endtime') )") if ($use_bodies);

			my $systems = int(@rows);
	
			printf("%s -> %s: %7u systems. [%s] ",$starttime,$endtime,$systems,epoch2date(time)) if ($debug || $verbose);
	
			my $galrad_y = $galrad-25000;
	
			my @changed = ();
	
			if ($decay_rate) {
				for (my $y=0; $y<$size_y; $y++) {
					for (my $x=0; $x<$size_x; $x++) {
						if ($map[$x][$y] > 0) {
							$map[$x][$y] *= $decay_rate;
							$map[$x][$y] = 0 if ($map[$x][$y] < 0.1);
							$changed[$x][$y] = 1;
						}
					}
				}
			}
	
			foreach my $r (@rows) {
				my $x = int((($$r{coord_x}+$galrad)/$galsize)*$size_y);
				my $y = int((($galsize-($$r{coord_z}+$galrad_y))/$galsize)*$size_y);
				$map[$x][$y] += 1;
				$changed[$x][$y] = 1;

				vec($sys_vector, $$r{edsm_id}, 1) = 1;
	
				foreach my $loc (keys %zooms) {
					my $x = floor(($$r{coord_x}-$zooms{$loc}{mapx})/$zoomscale)+floor(($zooms{$loc}{x2}+$zooms{$loc}{x1})/2);
					my $y = floor(($zooms{$loc}{mapy}-$$r{coord_z})/$zoomscale)+floor(($zooms{$loc}{y2}+$zooms{$loc}{y1})/2);
	
					if ($x>$zooms{$loc}{x1} && $x<$zooms{$loc}{x2} && $y>$zooms{$loc}{y1} && $y<$zooms{$loc}{y2}) {
						$map[$x][$y] += $$r{v};
						$changed[$x][$y] = 1;
					}
				}
			}
	
			for (my $y=0; $y<$size_y; $y++) {
				for (my $x=0; $x<$size_x; $x++) {
	
					next if (!$changed[$x][$y]);
	
					my @col = (0,0,0);
	
					if ($map[$x][$y]) {
						my $int_scale = $intensity_scale{main};
						$int_scale = $intensity_scale{sec} if ($x>$size_y);
		
						my $intensity = my_log($map[$x][$y]+1)*$int_scale;
						$intensity *= $decay_multiplier if ($decay_rate);
						my $integer = int($intensity);
						my $decimal = $intensity;
						$decimal = $intensity - $integer if ($integer);
		
						my $capped_intensity = $intensity;
						$capped_intensity = $max_heat if ($capped_intensity > $max_heat);
		
						my $opacity= 1;
						#my $opacity = ($decimal/4)+0.75;
						#$opacity = 1 if ($integer || $opacity>1);
		
						#print "$x,$y = $intensity = $integer, $decimal\n" if ($decimal || $integer);
		
						my @pixels = (int($orig[$x][$y][0]),int($orig[$x][$y][1]),int($orig[$x][$y][2]));
		
						if ($integer >= $max_heat) {
							$integer = $max_heat;
							$decimal = 0;
						}
						my $bottomset = $integer;
						my $topset = $integer+1;
		
						my @tmp = scaledColor($heatcolor[$bottomset][0],$heatcolor[$bottomset][1],$heatcolor[$bottomset][2],$decimal,
								$heatcolor[$topset][0],$heatcolor[$topset][1],$heatcolor[$topset][2]);
		
						@col = @tmp;
						@col = additiveColor($pixels[0],$pixels[1],$pixels[2],$opacity,$tmp[0],$tmp[1],$tmp[2]) if ($opacity < 1);
					} else {
						@col = @{$orig[$x][$y]};
					}
	
					$image->SetPixel( x => $x, y => $y, color => float_colors(@col) );
				}
			}

			$sys_count = unpack("%32b*", $sys_vector);

			my $new_systems = $sys_count - $orig_sys_count;

			push @window, $new_systems;
			shift @window if (int(@window) >= 7);
			my $avg_systems = 0;
			foreach my $n (@window) {
				$avg_systems += $n;
			}
			$avg_systems = int($avg_systems/int(@window)) if (@window);
			$avg_systems = 0 if (!@window);
	
			$image->Draw( primitive=>'rectangle', stroke=>'rgb(0,0,0)', fill=>'rgb(0,0,0)', strokewidth=>1, 
				points=>sprintf("%u,%u %u,%u",$size_y,0,$size_y+$pointsize*20,$pointsize*6.5));
	
			$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>"Date: $show_date", x=>$size_y+$pointsize, y=>$pointsize*2);
			$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>"Systems: ".commify($sys_count)." (Avg: ".commify($avg_systems)."/day)", 
						x=>$size_y+$pointsize, y=>$pointsize*3.5);

			$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>"Approximately ".sprintf("%f",$sys_count*100/400000000000).'%% of galaxy', 
				x=>$size_y+$pointsize, y=>$pointsize*5);
	
			my $out = $image->Clone();
	
			foreach my $loc (keys %zooms) {
				my_rectangle($out,$zooms{$loc}{x1},$zooms{$loc}{y1},$zooms{$loc}{x2},$zooms{$loc}{y2},1,'#fff');
	
				$out->Annotate(pointsize=>$pointsize,fill=>'black',text=>$zooms{$loc}{title1}, x=>$zooms{$loc}{x1}+$pointsize+1, y=>$zooms{$loc}{y1}+1+$pointsize*2)
					if $zooms{$loc}{title1};
				$out->Annotate(pointsize=>$pointsize,fill=>'white',text=>$zooms{$loc}{title1}, x=>$zooms{$loc}{x1}+$pointsize, y=>$zooms{$loc}{y1}+$pointsize*2)
					if $zooms{$loc}{title1};
	
				$out->Annotate(pointsize=>$pointsize,fill=>'black',text=>$zooms{$loc}{title2}, x=>$zooms{$loc}{x1}+$pointsize+1, y=>$zooms{$loc}{y2}+1-$pointsize)
					if $zooms{$loc}{title2};
				$out->Annotate(pointsize=>$pointsize,fill=>'white',text=>$zooms{$loc}{title2}, x=>$zooms{$loc}{x1}+$pointsize, y=>$zooms{$loc}{y2}-$pointsize)
					if $zooms{$loc}{title2};
			}

			my $f = sprintf("%s/img-%06u.$format",$datapath,$img_count);
			print "> $f\n";
			$last_frame = $f;

			my $res = $out->Write( filename => $f );
			if ($res) {
				warn $res;
			}

			undef $out;
		} else {
			print "> $img_count\n";
		}

		$img_count++;
		#last if ($debug);
		last if ($max_frames && $img_count>$max_frames);
	}
	$dw2_last = $img_count-1 if (!$dw2_last);

	print "# DW2: [$decay_rate] $dw2_start -> $dw2_stop ($dw2_first - $dw2_last)\n" if ($doing_dw2);

	if ($img_count >= 10) {
		my $fps = 10;
		my $new_fps = 20;

		my $decay = '';
		$decay = '-decay' if ($decay_rate);
	
		my $fn = "$filepath/galactic-history$decay.mp4";
		my $filter = ''; #"-filter \"minterpolate='fps=$new_fps'\"";
	
		my $syscall = "$ffmpeg -y -framerate $fps -i $datapath/img-%06d.$format -c:v libx264 -profile:v high -crf 20 -pix_fmt yuv420p $filter $fn";
		print "$syscall\n";
		system($syscall);

		$remote_frame =~ s/\.jpg/-decay.jpg/ if ($decay_rate);

		my_system("$scp $fn $remote_server/") if (!$debug && $allow_scp);
		my_system("$scp $last_frame $remote_frame") if (!$debug && $allow_scp);

		if ($doing_dw2 && $decay_rate && $dw2_first && $dw2_last && $img_count<=$dw2_last+7) {
			my $dw2_fn = $fn;
			$dw2_fn =~ s/galactic-history-decay/dw2-history-decay/gs;

			my $framecount = 1+$dw2_last-$dw2_first;

			my $syscall = "$ffmpeg -y -framerate 6 -start_number $dw2_first -i $datapath/img-%06d.$format -c:v libx264 -profile:v high -crf 20 -pix_fmt yuv420p $filter $dw2_fn";
			print "$syscall\n";
			system($syscall);

			my $last = sprintf("%06d",$dw2_last);

			$remote_frame =~ s/vid-heatmap-decay/dw2-heatmap-decay/gs;
			$last_frame =~ s/\d+/$last/gs;

			my_system("$scp $dw2_fn $remote_server/") if (!$debug && $allow_scp);
			my_system("$scp $last_frame $remote_frame") if (!$debug && $allow_scp);
		}
	}
}



############################################################################

sub float_colors {
	my $r = shift(@_)/255;
	my $g = shift(@_)/255;
	my $b = shift(@_)/255;
	return [($r,$g,$b)];
}

sub colorFormatted {
	return "rgb(".join(',',@_).")";
}

sub additiveColor {
	my ($r,$g,$b,$opacity,$tr,$tg,$tb) = @_;

	my $highest = 0;
	$highest = $r if ($r>$highest);
	$highest = $g if ($g>$highest);
	$highest = $b if ($b>$highest);

	$opacity = 0 if ($opacity < 0);
	$opacity = 1 if ($opacity > 1);

	my $base_scale = 1-$opacity;
	my $target_scale = int((255-int(($highest*$base_scale)))/255);

	$r = int($r*$base_scale) + int($tr*$target_scale);
	$g = int($g*$base_scale) + int($tg*$target_scale);
	$b = int($b*$base_scale) + int($tb*$target_scale);

	return ($r,$g,$b);
}

sub scaledColor {
	my ($r,$g,$b,$scale,$tr,$tg,$tb) = @_;

	$r = int(($tr-$r)*$scale+$r);
	$g = int(($tg-$g)*$scale+$g);
	$b = int(($tb-$b)*$scale+$b);

	return ($r,$g,$b);
}

sub advance_date {
	my $dateref = shift;
	$$dateref = epoch2date(date2epoch("$$dateref 12:00:00")+86400);
	$$dateref =~ s/\s+.*$//;
	return $$dateref;
}

sub cleanup {
	undef $image;
	undef $galaxymap;
}

sub my_log {
	return 0 if ($_[0] <= 0 || !$_[0]);
	return log10($_[0]);
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

sub my_rectangle {
	my ($image,$x1,$y1,$x2,$y2,$strokewidth,$color,$fill) = @_;

	#print "Rectangle for $maptype: $x1,$y1,$x2,$y2,$strokewidth,$color\n";

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

############################################################################
