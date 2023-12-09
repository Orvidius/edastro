#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch parse_csv make_csv);

use Image::Magick;
use POSIX qw(floor);

############################################################################

show_queries(0);

my $debug		= 0;
my $debug_types		= 0;
my $debug_file		= 0;
my $verbose		= 0;
my $allow_scp		= 1;

my %color = ();
$color{'procgen'}	= "rgb(192,0,96)";
$color{'procgenE'}	= "rgb(96,0,48)";
$color{'real'}		= "rgb(192,96,0)";
$color{'realE'}		= "rgb(96,48,0)";
$color{'planetary'}	= "rgb(0,144,224)";
$color{'planetaryE'}	= "rgb(0,64,128)";

my $scp			= '/usr/bin/scp -P222';
my $remote_server	= 'www@services:/www/edastro.com/mapcharts/IGAU/';
my $scriptpath		= "/home/bones/elite";
my $filepath		= "/home/bones/www/elite";
my $img_path		= "/home/bones/elite/images";

my $patterns_file	= "$scriptpath/codex-patterns.csv";
#$patterns_file	= "$scriptpath/test.csv" if ($debug && $debug_file);
my $filename		= "$scriptpath/IGAU_Codex.csv";
my $fileout		= "IGAU-Codex";

$filepath .= '/test'	if ($0 =~ /\.pl\.\S+/);
$allow_scp = 0		if ($0 =~ /\.pl\.\S+/);

my $galrad              = 45000;
my $galsize             = $galrad*2;
my $galcenter_y		= 25000;
my $size_x              = 3200;
my $size_y              = $size_x;
my $edge_height		= 400;
my $pointsize           = 40;
my $strokewidth         = 3;

my $save_x              = 1800;
my $save_y              = $save_x;
my $thumb_x             = 400;
my $thumb_y             = $thumb_x;

my $title		= "Codex Entry Detections";
my $author		= "Map by CMDR Orvidius (edastro.com) - CC BY-NC-SA 3.0 - Data Provided by Intergalactic Astronomical Union";

############################################################################

my %map = ();
my %mapkey = ();
my %mapcounts = ();
my %maptitle = ();
my %known_type = ();
my %specific = ();
my %exact = ();

$exact{codex_ent_tube} = 'Roseum Sinuous Tubers';
$specific{'Roseum Sinuous Tubers'} = 1;

map_set('molluscs','Bell Molluscs','Bulb Molluscs','Bullet Mollusc','Capsule Molluscs','Gourd Molluscs','Reel Molluscs','Squid Molluscs','Torus Molluscs','Umbrella Molluscs');
map_set('pods', 'Aster Pods', 'Chalice Pods', 'Collared Pods', 'Gyre Pods', 'Octahedral Pods', 'Peduncle Pods', 'Quadripartite Pods', 'Rhizome Pods', 'Stolon Pods');
map_set('trees', 'Aster Trees', 'Peduncle Trees', 'Gyre Trees', 'Void Hearts', 'Stolon Trees' ,'Brain Trees');
map_set('surface', 'Crystalline Shards', 'Anemones', 'Bark Mounds','Sinuous Tubers','Amphora Plants');
map_set('crystals', 'Ice Crystals', 'Metallic Crystals', 'Silicate Crystals','Mineral Spheres','Calcite Plates');
map_set('lagrangeclouds', 'Lagrange Clouds','Lagrange Storm Clouds');
map_set('aliens', 'Thargoid Wreck', 'Thargoid Barnacles', 'Guardians','Thargoid Scavengers', 'Thargoid Interceptor', 'Thargoid Devices','Thargoid Structure');
map_set('anomalies', 'E-Type Anomalies', 'L-Type Anomalies', 'P-Type Anomalies', 'Q-Type Anomalies', 'T-Type Anomalies','K-Type Anomalies');
map_set('roseumtubers', 'Roseum Sinuous Tubers');
#map_set('geology', 'Fumaroles','Gas Vents','Ice Crystals');

$maptitle{trees} = 'Space Trees';
$maptitle{braintrees} = 'Brain Trees';
$maptitle{roseumtubers} = 'Roseum Sinuous Tubers';



############################################################################

sub map_set {
	my $type = shift;
	my @list = @_;

	my $n = 0;

	foreach my $i (@list) {
		$map{$type}{$i} = 1;
		$n++;

		my $color = 'rgb(255,255,255)';

		$color = 'rgb(80,112,255)' if ($n == 1);
		$color = 'rgb(0,255,0)' if ($n == 2);
		$color = 'rgb(0,255,255)' if ($n == 3);
		$color = 'rgb(255,0,0)' if ($n == 4);
		$color = 'rgb(255,0,255)' if ($n == 5);
		$color = 'rgb(255,255,0)' if ($n == 6);
		$color = 'rgb(255,128,32)' if ($n == 7);
		$color = 'rgb(200,120,25)' if ($n == 7);
		$color = 'rgb(140,0,255)' if ($n == 8);

		$mapkey{$type}{$i} = $color;
	}
}

print "Reading CSVs\n";

open SKIP, ">IGAU-skipped.csv";
print SKIP "Ref.System,Type,Reason\r\n";

my %id64 = ();
my %data = ();
my %pattern = ();


open CSV,"<$patterns_file";
while (my $line = <CSV>) {
	chomp $line;
	next if ($line =~ /^\s*#/);
	my ($p,$s) = parse_csv($line);
	$pattern{$p} = $s;
	$known_type{$p} = 1;
	$known_type{$s} = 1;
}
close CSV;

do_csv($filename,'System','Name','Name_Localised','SystemAddress');

print "\n".int(keys(%data))." total entries loaded.\nCreating Canvas\n";

my %dotimage = ();

my $galaxymap = Image::Magick->new;
show_result($galaxymap->Read("$scriptpath/images/galaxy-3200px-3600px-sides.bmp"));
show_result($galaxymap->Gamma( gamma=>1.2, channel=>"all" ));
show_result($galaxymap->Modulate( saturation=>80 ));
show_result($galaxymap->Modulate( brightness=>16 ));
show_result($galaxymap->Quantize(colorspace=>'RGB'));
show_result($galaxymap->Set(depth => 8));

my $regionmap = $galaxymap->Clone();

my $regions = Image::Magick->new;
show_result($regions->Read("$scriptpath/images/region-lines.bmp"));
show_result($regions->Resize(geometry=>"3200x3200+0+0"));
#show_result($regions->Gamma(gamma=>'0.4'));
show_result($regions->Modulate( saturation=>80 ));
show_result($regions->Modulate( brightness=>50 ));
show_result($regionmap->Composite(image=>$regions,compose=>'screen', gravity=>'northwest'));

my $logo_size = int($size_y*0.15);

my $compass = Image::Magick->new;
show_result($compass->Read("$scriptpath/images/thargoid-rose-hydra.bmp"));
show_result($compass->Resize(geometry=>$logo_size.'x'.$logo_size.'+0+0'));
show_result($regionmap->Composite(image=>$compass, compose=>'over', gravity=>'southeast',x=>$pointsize/2,y=>$pointsize/2));
show_result($galaxymap->Composite(image=>$compass, compose=>'over', gravity=>'southeast',x=>$pointsize/2,y=>$pointsize/2));

my $logo = Image::Magick->new;
show_result($logo->Read("$scriptpath/images/edastro-550px.bmp"));
show_result($logo->Resize(geometry=>$logo_size.'x'.$logo_size.'+0+0'));
show_result($galaxymap->Composite(image=>$logo, compose=>'over', gravity=>'northwest',x=>$pointsize/2,y=>$pointsize*3));
show_result($regionmap->Composite(image=>$logo, compose=>'over', gravity=>'northwest',x=>$pointsize/2,y=>$pointsize*3));

my $scale_vert = Image::Magick->new;
show_result($scale_vert->Read("$scriptpath/images/scale-9k-vertical.bmp"));
show_result($scale_vert->Resize(geometry=>'178x3200+0+0'));
show_result($galaxymap->Composite(image=>$scale_vert, compose=>'screen', gravity=>'northeast',x=>$edge_height*0.8,y=>0));
show_result($regionmap->Composite(image=>$scale_vert, compose=>'screen', gravity=>'northeast',x=>$edge_height*0.8,y=>0));

my $scale_horiz = Image::Magick->new;
show_result($scale_horiz->Read("$scriptpath/images/scale-9k-horizontal.bmp"));
show_result($scale_horiz->Resize(geometry=>'3200x178+0+0'));
show_result($galaxymap->Composite(image=>$scale_horiz, compose=>'screen', gravity=>'southwest',x=>0,y=>$edge_height*0.8));
show_result($regionmap->Composite(image=>$scale_horiz, compose=>'screen', gravity=>'southwest',x=>0,y=>$edge_height*0.8));


print "Drawing\n";

#print $typecount{'Roseum Sinuous Tubers'}{'Roseum Sinuous Tubers'}."\n";


foreach my $maptype (sort keys %map) {
	my %count = ();

	my $rmap = $regionmap->Clone();
	my $gmap = $galaxymap->Clone();

	my $typename = $maptitle{$maptype} ? $maptitle{$maptype} : ucfirst($maptype);

	$gmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>"$title ($typename) - ".epoch2date(time), x=>$pointsize, y=>$pointsize*1.5);
	$gmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$author, x=>$pointsize, y=>$pointsize*3);

	$rmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>"$title ($typename) - ".epoch2date(time), x=>$pointsize, y=>$pointsize*1.5);
	$rmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$author, x=>$pointsize, y=>$pointsize*3);

	my $counter = 0;

	print "$maptype:";

	foreach my $type (keys %{$map{$maptype}}) {
	
		foreach my $plusrad (1,0) {
			foreach my $refsys (keys %{$data{$type}}) {
				my ($x,$y, $xb,$yb, $xr,$yr) = get_coords($refsys);
			
				if ($x && $y) {
					my $radius = 2;
			
					my $c = $mapkey{$maptype}{$type};
					$c = 'rgb(255,255,255)' if (!$c);
		
					if ($plusrad) {
						my $temp = $c;
						$temp =~ s/rgb\(//;
						$temp =~ s/\)//;
						my @col = split ',', $temp;
		
						for (my $i=0; $i<3; $i++) {
							$col[$i] = $col[$i] >> 2;
						}
						$c = "rgb(".join(',',@col).")";
					}

					$mapcounts{$maptype}{$type}++ if (!$plusrad);

					draw_dots($rmap,$gmap, $x,$y, $xb,$yb, $xr,$yr, $radius+$plusrad, $c);
					$counter++;
					print '.' if ($counter % 10 == 0);
			
					$count{$type}++ if (!$plusrad);
				} elsif (!$plusrad) {
					#print "\nSkipped $refsys ($data{$type}{$refsys})\n";
					skip_data($refsys,$data{$type}{$refsys},'missing coordinates');
				}
			}
		}
	}
	print "\n";
	
	
	my $legend_x = $size_x*0.75;
	my $legend_y = $pointsize;
	#my $legend_y = $size_y-$pointsize*5.5;
	
	my $line_spacing = $pointsize*1.5;
	my $yy = $legend_y+$pointsize*1.2;
	my $ay = $legend_y+$pointsize*1;

	foreach my $key (sort keys %{$mapkey{$maptype}}) {
		my $color = $mapkey{$maptype}{$key};
		$color = 'rgb(200,200,200)' if (!$color);

		my $text = "$key ($mapcounts{$maptype}{$key})";
		print "KEY: $text\n";

		show_result($gmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$text, x=>$legend_x+$pointsize*2, y=>$ay));
		show_result($rmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$text, x=>$legend_x+$pointsize*2, y=>$ay));

		$gmap->Draw( primitive=>'rectangle',stroke=>'white', fill=>$color,  strokewidth=>2, points=>sprintf("%u,%u %u,%u",
				$legend_x+$pointsize*0.5,$yy-$pointsize,$legend_x+$pointsize*1.5,$yy));
		$rmap->Draw( primitive=>'rectangle',stroke=>'white', fill=>$color,  strokewidth=>2, points=>sprintf("%u,%u %u,%u",
				$legend_x+$pointsize*0.5,$yy-$pointsize,$legend_x+$pointsize*1.5,$yy));

		$yy += $line_spacing;
		$ay += $line_spacing;
	}
	
	
	show_result($gmap->Resize(geometry=>int($save_x).'x'.int($save_y).'+0+0'));
	
	my $f = sprintf("%s/$fileout-$maptype.jpg",$filepath);
	print "Writing to: $f\n";
	show_result($gmap->Write( filename => $f ));
	
	show_result($gmap->Gamma( gamma=>1.2, channel=>"all" ));
	show_result($gmap->Resize(geometry=>int($thumb_x).'x'.int($thumb_y).'+0+0'));
	
	my $f2 = sprintf("%s/$fileout-$maptype-thumb.jpg",$filepath);
	print "Writing to: $f2\n";
	show_result($gmap->Write( filename => $f2 ));
	
	my_system("$scp $f $f2 $remote_server/") if (!$debug && $allow_scp);
	
	show_result($rmap->Resize(geometry=>int($save_x).'x'.int($save_y).'+0+0'));
	
	my $f = sprintf("%s/$fileout-$maptype-regions.jpg",$filepath);
	print "Writing to: $f\n";
	show_result($rmap->Write( filename => $f ));
	
	show_result($rmap->Gamma( gamma=>1.2, channel=>"all" ));
	show_result($rmap->Resize(geometry=>int($thumb_x).'x'.int($thumb_y).'+0+0'));
	
	my $f2 = sprintf("%s/$fileout-$maptype-regions-thumb.jpg",$filepath);
	print "Writing to: $f2\n";
	show_result($rmap->Write( filename => $f2 ));
	
	my_system("$scp $f $f2 $remote_server/") if (!$debug && $allow_scp);
}

close SKIP;

my_system("$scp IGAU-skipped.csv $remote_server/") if (!$debug && $allow_scp);

exit;

############################################################################

sub draw_dots {
	my ($rmap,$gmap, $x,$y, $xb,$yb, $xr,$yr, $radius,$c) = @_;

	draw_single_dot($rmap,$gmap, $x,$y,$radius,$c);
	draw_single_dot($rmap,$gmap, $xb,$yb,$radius,$c);
	draw_single_dot($rmap,$gmap, $xr,$yr,$radius,$c);
}

sub draw_single_dot {
	my ($rmap,$gmap, $x,$y,$radius,$c) = @_;
	my $p = sprintf("%u,%u %u,%u",$x,$y,$x+$radius,$y);

	if (!defined($dotimage{$radius}{$c})) {
		$dotimage{$radius}{$c} = Image::Magick->new(
			size  => '11x11',
			type  => 'TrueColor',
			depth => 8,
			verbose => 0
		);
		$dotimage{$radius}{$c}->ReadImage('canvas:black');
		$dotimage{$radius}{$c}->Quantize(colorspace=>'RGB');

		$dotimage{$radius}{$c}->Draw( primitive=>'circle', stroke=>$c, fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",5,5,5+$radius,5));
	}

	show_result($gmap->Composite(image=>$dotimage{$radius}{$c}, compose=>'screen', gravity=>'northwest',x=>$x-5,y=>$y-5));
	show_result($rmap->Composite(image=>$dotimage{$radius}{$c}, compose=>'screen', gravity=>'northwest',x=>$x-5,y=>$y-5));
}

sub do_csv {
	my $csv_file	= shift;
	my $refmatch	= shift;
	my $namematch	= shift;
	my $localmatch	= shift;
	my $id64match	= shift;

	open CSV, "<$csv_file";

	my $line = <CSV>;
	my %col  = ();
	my %typecount  = ();

	my @cols = parse_csv($line);
	for(my $i=0; $i<@cols; $i++) {
		$col{ref}  = $i if (!$col{ref} && $cols[$i] =~ /$refmatch/i);
		$col{name} = $i if (!$col{name} && $cols[$i] =~ /$namematch/i);
		$col{local} = $i if (!$col{local} && $cols[$i] =~ /$localmatch/i);
		$col{id64} = $i if (!$col{id64} && $cols[$i] =~ /$id64match/i);
	}

	print "READ: $csv_file ($refmatch = $col{ref}, $namematch = $col{name})\n";

	while (my $line = <CSV>) {
		chomp $line;
		my @v = fix_trim(parse_csv($line));
		my $ref = '';
		$ref = $v[$col{ref}] if (defined($col{ref}));
		my $name = '';
		$name = $v[$col{name}] if (defined($col{name}));
		my $local = '';
		$local = $v[$col{local}] if (defined($col{local}));

		$name = '' if ($name =~ /^\s*[^\w]\s*$/);
		my $type = '';

		foreach my $p (reverse sort keys %pattern) {
			if ($p && $name =~ /$p/) {
				$type = $pattern{$p};
				last;
			}
		}

		if (!$type) {
			foreach my $t (sort keys %typecount) {
				foreach my $l (sort keys %{$typecount{$t}}) {
					if ($local =~ /$l/ || $l =~ /$local/) {
						$type = $t;
						last;
					}
				}
			}
		}

		if (!$type) {
			$type = $local;

			foreach my $p (reverse sort keys %pattern) {
				if ($p && $type =~ /$p/) {
					$type = $pattern{$p};
					last;
				}
			}
		}

		if (!$type || !$known_type{$type}) {
			print "$name,$local\n" if ($debug_types);

			#print "UNKNOWN TYPE: $name / $type\n";
		}

		if ($specific{$local} || $exact{$name}) {
			# Do this one out of band, as an additional save.
			my $t = $local;
			$t = $exact{$name} if ($exact{$name});
			$data{$t}{$ref}++;
			$id64{$ref} = $v[$col{id64}] if ($v[$col{id64}]);
			$typecount{$t}{$local}++;
#print "TUBER: $name {$local} = $t\n" if ($type =~ /tuber/i);
		}

		if (!defined($col{ref}) || !$ref || !defined($col{name}) || !$type) {

			print "UNREADABLE: $line\n";

		} elsif ($data{$type}{$ref}) {

			#print "Duplicate: $ref ($type)\n";
			skip_data($ref,$type,'duplicate');
		} else {

			$data{$type}{$ref}++;
			$id64{$ref} = $v[$col{id64}] if ($v[$col{id64}]);
			$typecount{$type}{$local}++;
		}


#print join("\t|\t",@v)."\n" if (!$ref);
	}

	if (1) {
		foreach my $t (sort keys %typecount) {
			my $total = 0;
			my $list = '';
			foreach my $l (sort keys %{$typecount{$t}}) {
				$total += $typecount{$t}{$l};
				$list .= ", $l ($typecount{$t}{$l})";
			}
			$list =~ s/^[\s\,]+//;
			print "$t ($total) = $list\n";
		}
	}
			
	close CSV;
}

sub skip_data {
	my ($ref,$type,$reason) = @_;

	print SKIP make_csv($ref,$type,$reason)."\r\n";
}

sub fix_trim {
	my @list = ();
	foreach my $s (@_) {
		$s =~ s/\s+$//;
		$s =~ s/^\s+//;
		push @list, $s;
	}

	return @list;
}

sub get_coords {
	my $name = shift;
	my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where name=? and deletionState=0",[($name)]);

	if (!@rows && $id64{$name}) {
		@rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where id64=? and deletionState=0",[($id64{$name})]);
	}

	if (@rows) {
		my $r = shift @rows;

		my ($x1,$y1) = ( ($$r{coord_x}+$galrad)*$size_x/$galsize , ($galrad+$galcenter_y-$$r{coord_z})*$size_y/$galsize );
		if ($x1<0 || $y1<0 || $x1>$size_x || $y1>$size_y) { $x1 = 0; $y1=0; }

		my ($x2,$y2) = ( ($$r{coord_x}+$galrad)*$size_x/$galsize , $size_y+($edge_height/2)+($$r{coord_y}*$size_y/$galsize) );
		if ($x2<0 || $y2<$size_y || $x2>$size_x || $y2>$size_y+$edge_height) { $x2 = 0; $y2=0; }

		my ($x3,$y3) = ( $size_x+($edge_height/2)+($$r{coord_y}*$size_x/$galsize) , ($galrad+$galcenter_y-$$r{coord_z})*$size_y/$galsize );
		if ($x3<$size_x || $y3<0 || $x3>$size_x+$edge_height || $y3>$size_y) { $x3 = 0; $y3=0; }

		return ( $x1,$y1, $x2,$y2, $x3,$y3 );
	}

	return (0,0,0,0,0,0);
}

sub my_system {
        my $string = shift;
        print "# $string\n";
        #print TXT "$string\n";
	system($string);
}

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}

sub show_result {
	foreach (@_) {
		warn "WARN: $_\n" if ($_);
	}
}

############################################################################



