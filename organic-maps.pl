#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10 ssh_options scp_options);

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

my $compose_type	= ''; #'screen';

my $scp			= '/usr/bin/scp'.scp_options();
my $remote_server	= 'www@services:/www/edastro.com/mapcharts/organic/';
my $scriptpath		= "/home/bones/elite";
my $filepath		= "/home/bones/www/elite";
my $img_path		= "/home/bones/elite/images";

my $fileout		= "organic";

$filepath .= '/test'	if ($debug || $0 =~ /\.pl\.\S+/);
$allow_scp = 0		if ($debug || $0 =~ /\.pl\.\S+/);

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

my $title		= "Odyssey Organics";
my $author		= "Map by CMDR Orvidius (edastro.com) - CC BY-NC-SA 3.0 - Data Provided by EDSM & IGAU";

############################################################################

my %map = ();
my %mapkey = ();
my %mapcounts = ();
my %maptitle = ();
my %known_type = ();
my %specific = ();
my %exact = ();
my %typecount  = ();

my %speciesname = ();
my %genusname = ();
my %genusspecies = ();


############################################################################


open DEBUG, ">organic-debug.txt" if ($debug);

my %id64 = ();
my %data = ();
my %pattern = ();

print "Loading data:\n";

my $dot_count = 0;
get_database();
#do_csv($filename,'System','Name','Name_Localised','SystemAddress');
print "\n";

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

foreach my $genusID (keys %genusname) {
	my $n = 0;
	%mapkey = ();

#next if (lc($genusname{$genusID}) ne 'frutexa');

	foreach my $i (0,sort keys %{$genusspecies{$genusID}}) {
		$n++ if ($i);

		my $color = 'rgb(0,0,0)';

		$color = 'rgb(160,160,160)' if (!$i);
		$color = 'rgb(80,112,255)' if ($n == 1);
		$color = 'rgb(0,255,0)' if ($n == 2);
		$color = 'rgb(0,255,255)' if ($n == 3);
		$color = 'rgb(255,0,0)' if ($n == 4);
		$color = 'rgb(255,0,255)' if ($n == 5);
		$color = 'rgb(255,255,0)' if ($n == 6);
		$color = 'rgb(255,128,32)' if ($n == 7);
		#$color = 'rgb(200,120,25)' if ($n == 7);
		$color = 'rgb(140,0,255)' if ($n == 8);
		$color = 'rgb(255,200,40)' if ($n == 9);
		$color = 'rgb(0,0,255)' if ($n == 10);
		$color = 'rgb(200,100,32)' if ($n == 11);
		$color = 'rgb(32,100,200)' if ($n == 12);
		$color = 'rgb(100,200,100)' if ($n == 13);
		$color = 'rgb(200,32,200)' if ($n == 14);
		$color = 'rgb(255,255,255)' if ($n == 15);

		$mapkey{$i} = $color;
	}

	draw_map('',$genusname{$genusID},$genusID);
}


sub draw_map {
	my $maptitle = shift;
	my $organic_type = shift;
	my $genusID = shift;

	my %count = ();

	my $rmap = $regionmap->Clone();
	my $gmap = $galaxymap->Clone();

	my $typename = $maptitle ? $maptitle : ucfirst($organic_type);

	$gmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>"$title ($typename) - ".epoch2date(time), x=>$pointsize, y=>$pointsize*1.5);
	$gmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$author, x=>$pointsize, y=>$pointsize*3);

	$rmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>"$title ($typename) - ".epoch2date(time), x=>$pointsize, y=>$pointsize*1.5);
	$rmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$author, x=>$pointsize, y=>$pointsize*3);

	my $counter = 0;

	print "$typename";

#	foreach my $plusrad (1,0) {
my $plusrad=0;
		foreach my $refsys (keys %data) {
			foreach my $type (keys %{$data{$refsys}{$genusID}}) {
				next if (!defined($type));

				my ($x,$y, $xb,$yb, $xr,$yr) = get_coords($refsys);
			
				if (defined($x) && defined($y)) {
					my $radius = 2;
			
					my $c = $mapkey{$type};
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

					$mapcounts{$type}++ if (!$plusrad);

					draw_dots($rmap,$gmap, $x,$y, $xb,$yb, $xr,$yr, $radius+$plusrad, $c) if ($type!=0 || int(keys %{$data{$refsys}{$genusID}})==1);
					$counter++;
					print '.' if ($counter % 10 == 0);
			
					$count{$type}++ if (!$plusrad);
				} elsif (!$plusrad) {
					print "\nSkipped $refsys ($data{$type}{$refsys})\n";
					#skip_data($refsys,$data{$type}{$refsys},'missing coordinates');
				}
			}
		}
#	}
	print "\n";
	

	my $keypointsize = $pointsize*2/3;
	
	my $legend_x = $size_x*0.80;
	my $legend_y = $keypointsize;
	#my $legend_y = $size_y-$keypointsize*5.5;
	
	my $line_spacing = $keypointsize*1.5;
	my $yy = $legend_y+$keypointsize*1.2;
	my $ay = $legend_y+$keypointsize*1;

	foreach my $key (sort keys %mapkey) {
		my $color = $mapkey{$key};
		$color = 'rgb(200,200,200)' if (!$color);

		my $count = $mapcounts{$key};
		$count = 0 if (!$count);

		my $text = "$speciesname{$key} ($count)";
		$text = "Genus $organic_type ($count)" if (!$speciesname{$key});
		print "KEY: $key $text\n";

		show_result($gmap->Annotate(pointsize=>$keypointsize,fill=>'white',text=>$text, x=>$legend_x+$keypointsize*2, y=>$ay));
		show_result($rmap->Annotate(pointsize=>$keypointsize,fill=>'white',text=>$text, x=>$legend_x+$keypointsize*2, y=>$ay));

		$gmap->Draw( primitive=>'rectangle',stroke=>'white', fill=>$color,  strokewidth=>2, points=>sprintf("%u,%u %u,%u",
				$legend_x+$keypointsize*0.5,$yy-$keypointsize,$legend_x+$keypointsize*1.5,$yy));
		$rmap->Draw( primitive=>'rectangle',stroke=>'white', fill=>$color,  strokewidth=>2, points=>sprintf("%u,%u %u,%u",
				$legend_x+$keypointsize*0.5,$yy-$keypointsize,$legend_x+$keypointsize*1.5,$yy));

		$yy += $line_spacing;
		$ay += $line_spacing;
	}
	
	
	show_result($gmap->Resize(geometry=>int($save_x).'x'.int($save_y).'+0+0'));

	my $maptype = lc($organic_type);
	$maptype =~ s/\s+/-/gs;
	
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

close DEBUG if ($debug);

#my_system("$scp organic-skipped.csv $remote_server/") if (!$debug && $allow_scp);

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
		#$dotimage{$radius}{$c}->ReadImage('canvas:black');
		$dotimage{$radius}{$c}->ReadImage('canvas:none');
		$dotimage{$radius}{$c}->Quantize(colorspace=>'RGB');

		$dotimage{$radius}{$c}->Draw( primitive=>'circle', stroke=>$c, fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",5,5,5+$radius,5));
	}

	if ($compose_type) {
		show_result($gmap->Composite(image=>$dotimage{$radius}{$c}, compose=>$compose_type, gravity=>'northwest',x=>$x-5,y=>$y-5));
		show_result($rmap->Composite(image=>$dotimage{$radius}{$c}, compose=>$compose_type, gravity=>'northwest',x=>$x-5,y=>$y-5));
	} else {
		show_result($gmap->Composite(image=>$dotimage{$radius}{$c}, gravity=>'northwest',x=>$x-5,y=>$y-5));
		show_result($rmap->Composite(image=>$dotimage{$radius}{$c}, gravity=>'northwest',x=>$x-5,y=>$y-5));
	}
}

sub get_database {
	%speciesname = ();
	%genusname = ();
	%genusspecies = ();

	my %genusID = ();
	my %speciesID = ();

	my $FIX = 0; # This should always be ZERO, unless doing a fix while debugging.

	my @rows = db_mysql('elite',"select id,speciesID,name from species_local order by speciesID,preferred");
	foreach my $r (@rows) {
		$speciesname{$$r{speciesID}} = $$r{name};
		$speciesID{$$r{speciesID}} = $$r{id};
	}
	foreach my $id (sort {$a <=> $b} keys %speciesname) {
		print "SPECIES $id = ($speciesID{$id}) $speciesname{$id}\n";

		if ($FIX) {
			db_mysql('elite',"update species_local set preferred=1 where id=?",[($speciesID{$id})]);
		}
	}

	my @rows = db_mysql('elite',"select id,genusID,name from genus_local order by genusID,preferred");
	foreach my $r (@rows) {
		$genusname{$$r{genusID}} = $$r{name};
		$genusID{$$r{genusID}} = $$r{id};
	}
	foreach my $id (sort {$a <=> $b} keys %genusname) {
		print "GENUS $id = ($genusID{$id}) $genusname{$id}\n";

		if ($FIX) {
			db_mysql('elite',"update genus_local set preferred=1 where id=?",[($genusID{$id})]);
		}
	}

	my $ref = rows_mysql('elite',"select systemId64,speciesID,genusID,name as systemName from organic,systems where systemId64=id64 and systems.deletionState=0");

	while (@$ref) {
		my $r = shift @$ref;

		$genusspecies{$$r{genusID}}{$$r{speciesID}} = 1;
		$data{$$r{systemId64}}{$$r{genusID}}{$$r{speciesID}}=1;

		#print "$$r{systemName},$$r{systemId64},$genusname{$$r{genusID}},$speciesname{$$r{speciesID}}\n";
	}

	my $ref = rows_mysql('elite',"select systemId64,genusID,name as systemName from organicsignals,systems where systemId64=id64 and systems.deletionState=0");

	while (@$ref) {
		my $r = shift @$ref;

		$genusspecies{$$r{genusID}}{0} = 1;
		$data{$$r{systemId64}}{$$r{genusID}}{0}=1;

		#print "$$r{systemName},$$r{systemId64},$genusname{$$r{genusID}},$speciesname{$$r{speciesID}}\n";
	}

	foreach my $genus (keys %genusspecies) {
		foreach my $id (keys %{$genusspecies{$genus}}) {
			my $ref = rows_mysql('elite',"select systemId64 from codex,codexname_local where codexnameID=nameID and (codexname_local.name=? or codexname_local.name like concat(?,' \%'))",[($speciesname{$id},$speciesname{$id})]);
			while (@$ref) {
				my $r = shift @$ref;
				$data{$$r{systemId64}}{$genus}{$id}=1;
			}
		}
	}

	print int(keys %data)." systems with organics found.\n";
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
	my $id64 = shift;
	my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where id64=? and deletionState=0",[($id64)]);

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



