#!/usr/bin/perl
use strict;
$|=1;

############################################################################

use File::Basename;

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
my $verbose		= 0;
my $allow_scp		= 1;

my $scp			= '/usr/bin/scp -P222';
my $remote_server	= 'www@services:/www/edastro.com/mapcharts/';
my $cdn_url		= 'https://edastro.b-cdn.net/mapcharts/';
my $scriptpath		= "/home/bones/elite";
my $filepath		= "/home/bones/www/elite";
my $img_path		= "/home/bones/elite/images";
my $cdn_purge		= "$scriptpath/cdn-purge.sh";

my $fileout		= "inhabited";

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

my $bubble_size_x	= $size_x + $edge_height;
my $bubble_size_y	= $size_y + $edge_height;
my $bubble_radius	= 8000;
my $bubble_diameter	= $bubble_radius*2;

my $save_x              = 3600;
my $save_y              = 1800;
my $thumb_x             = 400;
my $thumb_y             = $thumb_x;

my $title		= "Inhabited Systems with Docking Locations";
my $author		= "Map by CMDR Orvidius (edastro.com) - CC BY-NC-SA 3.0 - Data via EDDN & EDSM";


############################################################################

die "Usage: $0 [YYYY-MM-DD [radius]]\n" if (@ARGV && $ARGV[0] !~ /^\d{4}-\d{2}-\d{2}/);

if ($ARGV[1]) {
	$bubble_radius = $ARGV[1];
	$bubble_diameter = $bubble_radius*2;
	print timestamp()."Bubble Radius: $bubble_radius\n";
}

my $time = time;
$time = date2epoch($ARGV[0]." 12:00:00") if (@ARGV);

my @t = localtime($time);
my $date = sprintf("%04u%02u%02u",$t[5]+1900,$t[4]+1,$t[3]);
my $today = sprintf("%04u-%02u-%02u",$t[5]+1900,$t[4]+1,$t[3]);

print timestamp()."Reading DATA for $today\n";

my %id64 = ();
my %data = ();
my %coords = ();

get_data();

print "\n".timestamp().int(keys(%data))." total systems loaded.\nCreating Canvas\n";

my %dotimage = ();

my $galaxymap = Image::Magick->new;
show_result($galaxymap->Read("$scriptpath/images/galaxy-3200px-3600px-sides.bmp"));
show_result($galaxymap->Gamma( gamma=>1.2, channel=>"all" ));
show_result($galaxymap->Modulate( saturation=>60 ));
show_result($galaxymap->Modulate( brightness=>45 ));
show_result($galaxymap->Quantize(colorspace=>'RGB'));
show_result($galaxymap->Set(depth => 8));

my $regionmap = $galaxymap->Clone();

my $regions = Image::Magick->new;
show_result($regions->Read("$scriptpath/images/region-lines.bmp"));
show_result($regions->Resize(geometry=>"3200x3200+0+0"));
#show_result($regions->Gamma(gamma=>'0.4'));
#show_result($regions->Modulate( saturation=>80 ));
#show_result($regions->Modulate( brightness=>50 ));
show_result($regionmap->Composite(image=>$regions,compose=>'screen', gravity=>'northwest'));

my $logo_size = int($size_y*0.15);

my $compass = Image::Magick->new;
show_result($compass->Read("$scriptpath/images/thargoid-rose-hydra.bmp"));
show_result($compass->Resize(geometry=>$logo_size.'x'.$logo_size.'+0+0'));

my $logo = Image::Magick->new;
show_result($logo->Read("$scriptpath/images/edastro-550px.bmp"));
show_result($logo->Resize(geometry=>$logo_size.'x'.$logo_size.'+0+0'));

my $scale_vert = Image::Magick->new;
show_result($scale_vert->Read("$scriptpath/images/scale-9k-vertical.bmp"));
show_result($scale_vert->Resize(geometry=>'178x3200+0+0'));

my $scale_horiz = Image::Magick->new;
show_result($scale_horiz->Read("$scriptpath/images/scale-9k-horizontal.bmp"));
show_result($scale_horiz->Resize(geometry=>'3200x178+0+0'));

my $x1 = $size_x+$edge_height;
my $x2 = $x1*2 - 1;
my $y1 = 0;
my $y2 = $size_y+$edge_height-1;

my $graphcolor = 'rgb(200,128,36)';
my $minorcolor = 'rgb(166,85,24)';

my %POI = ();

$POI{'Pleiades'}{x} = -81;
$POI{'Pleiades'}{z} = -344;
$POI{'Pleiades'}{r} = 98;

$POI{'Witch Head'}{x} = 371;
$POI{'Witch Head'}{z} = -715;
$POI{'Witch Head'}{r} = 96;

$POI{'Pencil Sector'}{x} = 814;
$POI{'Pencil Sector'}{z} = -44;
$POI{'Pencil Sector'}{r} = 98;

$POI{'Orion Sector'}{x} = 627;
$POI{'Orion Sector'}{z} = -1113;
$POI{'Orion Sector'}{r} = 86;

$POI{'California Sector'}{x} = -331;
$POI{'California Sector'}{z} = -920;
$POI{'California Sector'}{r} = 98;

$POI{'Coalsack Sector'}{x} = 419;
$POI{'Coalsack Sector'}{z} = 272;
$POI{'Coalsack Sector'}{r} = 99;

$POI{"Sothis"}{x} = -353;
$POI{"Sothis"}{z} = -346;
$POI{"Sothis"}{r} = 60;

$POI{"Cone Sector"}{x} = 859;
$POI{"Cone Sector"}{z} = -2027;
$POI{"Cone Sector"}{r} = 92;

$POI{"NGC 6188 Sector"}{x} = 1704;
$POI{"NGC 6188 Sector"}{z} = 4055;
$POI{"NGC 6188 Sector"}{r} = 98;

$POI{"Cat's Paw"}{x} = 851;
$POI{"Cat's Paw"}{z} = 5433;
$POI{"Cat's Paw"}{r} = 98;

$POI{"Lagoon Sector"}{x} = -470;
$POI{"Lagoon Sector"}{z} = 4474;
$POI{"Lagoon Sector"}{r} = 99;

$POI{"Trifid Sector"}{x} = -634;
$POI{"Trifid Sector"}{z} = 5161;
$POI{"Trifid Sector"}{r} = 99;

$POI{"Omega Sector"}{x} = -1432;
$POI{"Omega Sector"}{z} = 5309;
$POI{"Omega Sector"}{r} = 99;

$POI{"NGC 5367 Sector"}{x} = 1349;
$POI{"NGC 5367 Sector"}{z} = 1423;
$POI{"NGC 5367 Sector"}{r} = 94;

$POI{"Seagull Sector"}{x} = 2655;
$POI{"Seagull Sector"}{z} = -2713;
$POI{"Seagull Sector"}{r} = 95;

$POI{"Jellyfish Sector"}{x} = 790;
$POI{"Jellyfish Sector"}{z} = -4930;
$POI{"Jellyfish Sector"}{r} = 98;

$POI{"Rosette Sector"}{x} = 2347;
$POI{"Rosette Sector"}{z} = -4749;
$POI{"Rosette Sector"}{r} = 98;

$POI{"Monkey Head Sector"}{x} = 1132;
$POI{"Monkey Head Sector"}{z} = -6299;
$POI{"Monkey Head Sector"}{r} = 98;

$POI{"Crab Sector"}{x} = 555;
$POI{"Crab Sector"}{z} = -6942;
$POI{"Crab Sector"}{r} = 92;

$POI{"NGC 1931 Sector"}{x} = -745;
$POI{"NGC 1931 Sector"}{z} = -6959;
$POI{"NGC 1931 Sector"}{r} = 97;

$POI{"NGC 7822 Sector"}{x} = -2444;
$POI{"NGC 7822 Sector"}{z} = -1332;
$POI{"NGC 7822 Sector"}{r} = 92;

$POI{"Heart & Soul"}{x} = -5209;
$POI{"Heart & Soul"}{z} = -5394;
$POI{"Heart & Soul"}{r} = 209;

$POI{"North America Sector"}{x} = -1893;
$POI{"North America Sector"}{z} = 148;
$POI{"North America Sector"}{r} = 99;

$POI{"Crescent Sector"}{x} = -4836;
$POI{"Crescent Sector"}{z} = 1249;
$POI{"Crescent Sector"}{r} = 92;

$POI{"Statue of Liberty Sector"}{x} = 5589;
$POI{"Statue of Liberty Sector"}{z} = 2178;
$POI{"Statue of Liberty Sector"}{r} = 97;

$POI{"Bubble Sector"}{x} = -6573;
$POI{"Bubble Sector"}{z} = -2683;
$POI{"Bubble Sector"}{r} = 99;

$POI{"Eagle Sector"}{x} = -2046;
$POI{"Eagle Sector"}{z} = 6692;
$POI{"Eagle Sector"}{r} = 98;

$POI{"NGC 6357 Sector"}{x} = 965;
$POI{"NGC 6357 Sector"}{z} = 8091;
$POI{"NGC 6357 Sector"}{r} = 98;

$POI{"Eta Carina Sector"}{x} = 8581;
$POI{"Eta Carina Sector"}{z} = 2705;
$POI{"Eta Carina Sector"}{r} = 98;




foreach my $image ($regionmap,$galaxymap) {
	show_result($image->Composite(image=>$compass, compose=>'over', gravity=>'southeast',x=>$pointsize/2,y=>$pointsize/2));
	show_result($image->Composite(image=>$scale_vert, compose=>'screen', gravity=>'northeast',x=>$edge_height*0.8,y=>0));
	show_result($image->Composite(image=>$scale_horiz, compose=>'screen', gravity=>'southwest',x=>0,y=>$edge_height*0.8));
	
	show_result($image->Extent(width=>(($size_y+$edge_height)*2),height=>($size_y+$edge_height)));

	$image->Draw(primitive=>'rectangle',fill=>'black',stroke=>'black',strokewidth=>2,points=>"$x1,$y1 $x2,$y2");

	my $radius = floor(($size_y+$edge_height)/2);
	my $cx = $size_x+$edge_height+$radius;
	my $cy = $radius;

	show_result($image->Draw(primitive=>'line',fill=>$graphcolor,stroke=>$graphcolor,strokewidth=>3,points=>($cx-$radius).",$cy ".($cx+$radius).",$cy"));
	show_result($image->Draw(primitive=>'line',fill=>$graphcolor,stroke=>$graphcolor,strokewidth=>3,points=>"$cx,".($cy-$radius)." $cx,".($cy+$radius)));

	my $ring_radius = $bubble_radius/10;

	for (my $i=1; $i<=10; $i++) {
		my $rad = floor(($i*$ring_radius)*($bubble_size_x/$bubble_diameter));

		$image->Draw(primitive=>'circle',fill=>'none',stroke=>$graphcolor,strokewidth=>3,points=>"$cx,$cy $cx,".($cy+$rad));
	}

	foreach my $p (keys %POI) {

		my $px_ly = $bubble_size_x/$bubble_diameter;
		my $px = $cx + ($POI{$p}{x}*$px_ly);
		my $py = $cy - ($POI{$p}{z}*$px_ly);
		my $pr = $POI{$p}{r}*$px_ly;
		$image->Draw(primitive=>'circle',fill=>'none',stroke=>$minorcolor,strokewidth=>2,points=>"$px,$py $px,".($py+$pr));
		annotate_border($image,30, $graphcolor, 8, $p, undef, $px+$pr+8, $py+13);
	}

	for (my $i=1; $i<=10; $i++) {
		my $rad = floor(($i*($bubble_radius/10))*($bubble_size_x/$bubble_diameter));

		#$image->Annotate(pointsize=>30,fill=>$graphcolor,text=>($i*$ring_radius).' ly', x=>$cx+8, y=>$cy-$rad-10);
		#$image->Annotate(pointsize=>30,fill=>$graphcolor,text=>($i*$ring_radius).' ly', x=>$cx+8, y=>$cy+$rad+35);
		#$image->Annotate(pointsize=>30,fill=>$graphcolor,text=>($i*$ring_radius).' ly', x=>$cx+$rad+8, y=>$cy-10);
		#$image->Annotate(pointsize=>30,fill=>$graphcolor,text=>($i*$ring_radius).' ly', x=>$cx-$rad+8, y=>$cy-10);

		annotate_border($image,30, $graphcolor, 8, ($i*$ring_radius).' ly', undef, $cx+8,$cy-$rad-10);
		annotate_border($image,30, $graphcolor, 8, ($i*$ring_radius).' ly', undef, $cx+8,$cy+$rad+32);
		annotate_border($image,30, $graphcolor, 8, ($i*$ring_radius).' ly', undef, $cx+$rad+8,$cy-10);
		annotate_border($image,30, $graphcolor, 8, ($i*$ring_radius).' ly', undef, $cx-$rad+8,$cy-10);
	}

	my $solx = floor($size_x/2);
	my $soly = floor($size_y*7/9);
	my $rad = floor($size_x*$bubble_radius/90000);

	$image->Draw(primitive=>'rectangle',fill=>'none',stroke=>$graphcolor,strokewidth=>2,points=>($solx-$rad).",".($soly-$rad).' '.($solx+$rad).",".($soly+$rad));
	$image->Draw(primitive=>'circle',fill=>'none',stroke=>$graphcolor,strokewidth=>2,points=>"$solx,$soly $solx,".($soly+$rad));

}

print timestamp()."Drawing $today\n";

my $rmap = $regionmap->Clone();
my $gmap = $galaxymap->Clone();


my $count = 0;
my $dotcount = 0;

foreach my $image ($rmap,$gmap) {
	foreach my $plusrad (1,0) {
		foreach my $refsys (keys %data) {
			my ($x,$y, $xb,$yb, $xr,$yr, $xs,$ys) = get_coords($refsys);
		
			if ($x && $y) {
				my $radius = 2;
		
				my $c = 'rgb(5,255,1)';
	
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

				my $plusgraph = 2;

				draw_dots($image, $x,$y, $xb,$yb, $xr,$yr, $xs,$ys, $radius+$plusrad, $plusgraph, $c);

				if (!$plusrad && $image==$rmap) {
					$count++;
				}
				$dotcount ++;
				print '.' if ($dotcount % 1000 == 0);
				print " $dotcount\n" if ($dotcount % 100000 == 0);
			} elsif (!$plusrad) {
				#print "\nSkipped $refsys\n";
			}
		}
	}
}

print timestamp()."\n$count inhabited systems plotted for $today.\n";

foreach my $image ($rmap,$gmap) {
	
	$image->Draw(primitive=>'rectangle',fill=>'none',stroke=>$graphcolor,strokewidth=>2,points=>"$x1,$y1 $x2,$y2");

	#show_result($image->Annotate(pointsize=>$pointsize,fill=>'white',text=>"$title - ".epoch2date(time)." - $count inhabiteds shown.", gravity=>'northwest', x=>$pointsize, y=>$pointsize));
	#show_result($image->Annotate(pointsize=>$pointsize,fill=>'white',text=>$author, gravity=>'northeast', x=>$pointsize, y=>$pointsize));

	show_result($image->Composite(image=>$logo, compose=>'over', gravity=>'northeast',x=>$pointsize/2,y=>$pointsize*2));

	annotate_border($image,$pointsize,'white',10,"$title - $today - $count inhabited systems shown.",'northwest',$pointsize,$pointsize);
	annotate_border($image,$pointsize,'white',10,$author,'northeast',$pointsize,$pointsize);

	annotate_border($image,$pointsize*3,'white',30,'Sol / Bubble', undef, $size_x+$edge_height+$pointsize, $pointsize*4);
}


system('/usr/bin/mkdir','-p',"$scriptpath/inhabited-history") if (!-d "$scriptpath/inhabited-history");

my $fn = sprintf("%s/inhabited-history/$fileout-$date.bmp",$scriptpath);
print timestamp()."Writing to: $fn\n";
show_result($gmap->Write( filename => $fn ));
my $do = "/usr/bin/convert $fn";
my $rm = $fn;
$fn =~ s/bmp/png/;
my_system("$do $fn");
unlink $rm if (-e $fn);

my $fn = sprintf("%s/inhabited-history/$fileout-regions-$date.bmp",$scriptpath);
print timestamp()."Writing to: $fn\n";
show_result($rmap->Write( filename => $fn ));
my $do = "/usr/bin/convert $fn";
my $rm = $fn;
$fn =~ s/bmp/png/;
my_system("$do $fn");
unlink $rm if (-e $fn);






#show_result($gmap->Resize(geometry=>int($save_x).'x'.int($save_y).'+0+0'));

my $f = sprintf("%s/$fileout.bmp",$filepath);
print timestamp()."Writing to: $f\n";
show_result($gmap->Write( filename => $f ));
my $do = "/usr/bin/convert $f";
$f =~ s/bmp/png/;
my_system("$do $f");

show_result($gmap->Resize(geometry=>int($save_x/3).'x'.int($save_y/3).'+0+0'));

my $f1 = sprintf("%s/$fileout.jpg",$filepath);
print timestamp()."Writing to: $f1\n";
show_result($gmap->Write( filename => $f1 ));

show_result($gmap->Gamma( gamma=>1.2, channel=>"all" ));
show_result($gmap->Resize(geometry=>int($thumb_x).'x'.int($thumb_y).'+0+0'));

my $f2 = sprintf("%s/$fileout-thumb.jpg",$filepath);
print timestamp()."Writing to: $f2\n";
show_result($gmap->Write( filename => $f2 ));

if (!$debug && $allow_scp) {
	my_system("$scp $f $f1 $f2 $remote_server/");
	if ($cdn_url) {
		my_system("$cdn_purge $cdn_url".basename($f));
		my_system("$cdn_purge $cdn_url".basename($f1));
		my_system("$cdn_purge $cdn_url".basename($f2));
	}
}

#show_result($rmap->Resize(geometry=>int($save_x).'x'.int($save_y).'+0+0'));

my $f = sprintf("%s/$fileout-regions.bmp",$filepath);
print timestamp()."Writing to: $f\n";
show_result($rmap->Write( filename => $f ));
my $do = "/usr/bin/convert $f";
$f =~ s/bmp/png/;
my_system("$do $f");

show_result($rmap->Resize(geometry=>int($save_x/3).'x'.int($save_y/3).'+0+0'));

my $f1 = sprintf("%s/$fileout-regions.jpg",$filepath);
print timestamp()."Writing to: $f1\n";
show_result($rmap->Write( filename => $f1 ));

show_result($rmap->Gamma( gamma=>1.2, channel=>"all" ));
show_result($rmap->Resize(geometry=>int($thumb_x).'x'.int($thumb_y).'+0+0'));

my $f2 = sprintf("%s/$fileout-regions-thumb.jpg",$filepath);
print timestamp()."Writing to: $f2\n";
show_result($rmap->Write( filename => $f2 ));

if (!$debug && $allow_scp) {
	my_system("$scp $f $f1 $f2 $remote_server/");
	if ($cdn_url) {
		my_system("$cdn_purge $cdn_url".basename($f));
		my_system("$cdn_purge $cdn_url".basename($f1));
		my_system("$cdn_purge $cdn_url".basename($f2));
	}
}


exit;

############################################################################

sub annotate_border {
	my ($image,$pointsize, $fill, $borderwidth, $text, $gravity, $x, $y) = @_;

	annotate($image,$pointsize, 'black', 'black', $borderwidth, $text, $gravity, $x, $y);
	annotate($image,$pointsize, $fill, undef, undef, $text, $gravity, $x, $y);
}

sub annotate {
	my ($image,$pointsize, $fill, $stroke, $strokewidth, $text, $gravity, $x, $y) = @_;

	if ($stroke) {
		if ($gravity) {
			show_result($image->Annotate(pointsize=>$pointsize,fill=>$fill,stroke=>$stroke,strokewidth=>$strokewidth,text=>$text, gravity=>$gravity, x=>$x, y=>$y));
		} else {
			show_result($image->Annotate(pointsize=>$pointsize,fill=>$fill,stroke=>$stroke,strokewidth=>$strokewidth,text=>$text, x=>$x, y=>$y));
		}
	} else {
		if ($gravity) {
			show_result($image->Annotate(pointsize=>$pointsize,fill=>$fill,text=>$text, gravity=>$gravity, x=>$x, y=>$y));
		} else {
			show_result($image->Annotate(pointsize=>$pointsize,fill=>$fill,text=>$text, x=>$x, y=>$y));
		}
	}
}

sub get_data {
#	my @rows = db_mysql('elite',"select systemId64,systemName,coord_x,coord_y,coord_z from inhabiteds where (callsign in ('W21-G9Z','W48-Q1Z') or ".
#			"lastEvent>date_sub(NOW(), interval 60 day) or lastMoved>date_sub(NOW(), interval 60 day)) and ((systemName is not null and systemName!='') or systemId64>0)");

	my @rows = db_mysql('elite',"select systemId64,stations.systemName,coord_x,coord_y,coord_z from stations,systems where stations.date_added<=? and ((stations.systemName is not null and stations.systemName!='') or systemId64>0) and type is not NULL and type!='Mega ship' and type!='Fleet Carrier' and type!='GameplayPOI' and type!='PlanetaryConstructionDepot' and type !='SpaceConstructionDepot' and stations.deletionState=0 and id64=systemId64",[($today)]);

# This adds systems where we don't have station data, but know it's inhabited:
#	push @rows, db_mysql('elite',"select id64 as systemId64, name as systemName,coord_x,coord_y,coord_z from systems where SystemGovernment is not null and SystemGovernment>3 and SystemEconomy is not null and SystemEconomy>5 and deletionState=0");

	foreach my $r (@rows) {
		$$r{systemName} = $$r{systemId64} if ($$r{systemId64} && !$$r{systemName});

		$data{$$r{systemName}} = $r;

		$coords{$$r{systemName}}{x} = $$r{coord_x} if ($$r{systemName} && defined($$r{coord_x}));
		$coords{$$r{systemName}}{y} = $$r{coord_y} if ($$r{systemName} && defined($$r{coord_y}));
		$coords{$$r{systemName}}{z} = $$r{coord_z} if ($$r{systemName} && defined($$r{coord_z}));
	
		$id64{$$r{systemName}} = $$r{systemId64} if ($$r{systemName} && $$r{systemId64});
	}
}

sub draw_dots {
	my ($gmap, $x,$y, $xb,$yb, $xr,$yr, $xs,$ys, $radius,$plusgraph,$c) = @_;

	draw_single_dot($gmap, $x,$y,$radius,$c);
	draw_single_dot($gmap, $xb,$yb,$radius,$c);
	draw_single_dot($gmap, $xr,$yr,$radius,$c);
	draw_single_dot($gmap, $xs,$ys,$radius+$plusgraph,$c);
}

sub draw_single_dot {
	my ($gmap, $x,$y,$radius,$c) = @_;
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

	my @rows = ();

	push @rows, $data{$name} if (exists($data{$name}));

	@rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where deletionState=0 and name=?",[($name)]) if (!@rows);

	if (!@rows && $id64{$name}) {
		@rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where deletionState=0 and id64=?",[($id64{$name})]);
	}

	if (!@rows && exists($coords{$name})) {
		my %hash = ('coord_x'=>$coords{$name}{x}, 'coord_y'=>$coords{$name}{y}, 'coord_z'=>$coords{$name}{z});
		push @rows, \%hash;
	}

	if (@rows) {
		my $r = shift @rows;

		my ($x1,$y1) = ( ($$r{coord_x}+$galrad)*$size_x/$galsize , ($galrad+$galcenter_y-$$r{coord_z})*$size_y/$galsize );
		if ($x1<0 || $y1<0 || $x1>$size_x || $y1>$size_y) { $x1 = 0; $y1=0; }

		my ($x2,$y2) = ( ($$r{coord_x}+$galrad)*$size_x/$galsize , $size_y+($edge_height/2)-($$r{coord_y}*$size_y/$galsize) );
		if ($x2<0 || $y2<$size_y || $x2>$size_x || $y2>$size_y+$edge_height) { $x2 = 0; $y2=0; }

		my ($x3,$y3) = ( $size_x+($edge_height/2)-($$r{coord_y}*$size_x/$galsize) , ($galrad+$galcenter_y-$$r{coord_z})*$size_y/$galsize );
		if ($x3<$size_x || $y3<0 || $x3>$size_x+$edge_height || $y3>$size_y) { $x3 = 0; $y3=0; }

		my ($x4,$y4) = ( floor($$r{coord_x}*$bubble_size_x/$bubble_diameter + $bubble_size_x*1.5) , floor($bubble_size_y/2 - $$r{coord_z}*$bubble_size_y/$bubble_diameter) );
		if ($x4<$size_x+$edge_height+1 || $y4<1 || $x4>($size_x+$edge_height)*2-1 || $y4>$size_y+$edge_height-1) { $x4 = 0; $y4=0; }

		return ( $x1,$y1, $x2,$y2, $x3,$y3, $x4,$y4 );
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

sub timestamp {
	my $date = epoch2date(time);
	return "[$date] ";
}

############################################################################



