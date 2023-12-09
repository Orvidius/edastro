#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch parse_csv make_csv btrim);

use Image::Magick;
use File::Basename;
use POSIX qw(floor ceil);

############################################################################

show_queries(0);

my $debug		= 0;
my $verbose		= 0;
my $allow_scp		= 1;

############################################################################
# DEFAULTS

my $title		= "DSSA Deployment Map";
my $author		= "Map by CMDR Orvidius (edastro.com) - Data Provided by The DSSA Tracker spreadsheet + EDDN";

my $scp			= '/usr/bin/scp -P222';
my $convert		= '/usr/bin/convert';
my $web_server		= 'www@services:/www/edastro.com';
my $remote_server	= "$web_server/mapcharts";
my $scriptpath		= "/home/bones/elite/csv-maps";
my $filepath		= "/home/bones/www/elite";
my $img_path		= "/home/bones/elite/images";
my $logo_path		= "/home/bones/elite/images/csv-maps";
my $tsv_filename	= "/home/bones/elite/DSSA-carriers.tsv";
my $map_logo		= '';
my $skip_file		= '';
my $system_col		= '';
my $count_col		= '';
my $outname		= 'DSSA-map';
my $somethings		= '';

$filepath .= '/test'	if ($0 =~ /\.pl\.\S+/);
$allow_scp = 0		if ($0 =~ /\.pl\.\S+/);

my $galrad		= 45000;
my $galsize		= $galrad*2;
my $galcenter_y		= 25000;
my $size_x		= 3200;
my $size_y		= $size_x;
my $edge_height		= 400;
my $pointsize		= 40;
my $strokewidth		= 3;

my $myself		= "$scriptpath/".basename($0);
#warn "MYSELF: $myself\n";

my %months = ('January'=>1,'February'=>2,'March'=>3,'April'=>4,'May'=>5,'June'=>6,'July'=>7,'August'=>8,'September'=>9,'October'=>10,'November'=>11,'December'=>12);

############################################################################
# Load config, and cascading settings


my $save_x	      = $size_x; #3200;
my $save_y	      = $save_x;
my $thumb_x	     = 600;
my $thumb_y	     = $thumb_x;

my $scale_factor	= 1;
my $scaled_size		= '3200x3200+0+0';

if ($size_x != 3200) {
	$scale_factor	= $save_x/3200;	# Scale factor to use for static elements if map area is not 3200x3200

	$edge_height	= int($edge_height*$scale_factor);
	$pointsize	= int($pointsize*$scale_factor);
	$strokewidth	= ceil($strokewidth*$scale_factor);
}
my $scaled_map		= $size_x.'x'.$size_y.'+0+0';
my $img			= int(3600 * $scale_factor);
my $scaled_image	= $img.'x'.$img.'+0+0';

print "Map geometry: $scaled_map, Image geometry: $scaled_image\n";


############################################################################


print "Reading CSVs\n";

if ($skip_file) {
	open SKIP, ">$skip_file";
	print SKIP "System,Count,Reason\r\n";
}

my %fc = ();

open TSV, "<$tsv_filename";
while (<TSV>) {
	chomp;
	$_ =~ s/[\r\n]+$//s;
	my @v = split /\t/,$_;

	next if (!@v);

	my $id = $v[1];
	$id =~ s/[^a-zA-Z0-9\-]*//gs;

	$fc{$id} = {name=>$v[2],owner=>$v[3],system=>$v[4],x=>$v[5],y=>$v[6],z=>$v[7],status=>$v[10],region=>$v[11],until=>$v[12]};
}
close TSV;

my @rows = db_mysql('elite',"select * from carriers where callsign in ('".join("','",keys(%fc))."')");
foreach my $r (@rows) {
	my $id = $$r{callsign};

	foreach my $k (qw(systemName systemId64 coord_x coord_y coord_z lastSeen lastEvent)) {
		$fc{$id}{$k} = $$r{$k};
	}
}


print "\n".int(keys(%fc))." total carriers loaded.\nCreating Canvas\n";

my %dotimage = ();

my $galaxymap = Image::Magick->new;
show_result($galaxymap->Read("$img_path/galaxy-3200px-3600px-sides.bmp"));
show_result($galaxymap->Resize(geometry=>$scaled_image)) if ($size_x != 3200);
show_result($galaxymap->Quantize(colorspace=>'RGB'));
show_result($galaxymap->Set(depth => 8));

my $galaxyreplace = Image::Magick->new;
show_result($galaxyreplace->Read("$scriptpath/gamegalaxy-9000px.png"));
#show_result($galaxyreplace->Gamma( gamma=>1.5, channel=>"all" ));
show_result($galaxyreplace->Resize(geometry=>'3200x3200+0+0'));
show_result($galaxymap->Composite(image=>$galaxyreplace,compose=>'over', gravity=>'northwest'));

show_result($galaxymap->Gamma( gamma=>1.1, channel=>"all" ));
#show_result($galaxymap->Modulate( saturation=>90 ));
show_result($galaxymap->Modulate( brightness=>90 ));

my $regionmap = $galaxymap->Clone();

my $regions = Image::Magick->new;
show_result($regions->Read("$img_path/region-lines.bmp"));
show_result($regions->Resize(geometry=>$scaled_map));
#show_result($regions->Gamma(gamma=>'0.4'));
#show_result($regions->Modulate( saturation=>80 ));
#show_result($regions->Modulate( brightness=>50 ));
show_result($regionmap->Composite(image=>$regions,compose=>'screen', gravity=>'northwest'));

my $logo_size = int($size_y*0.15);
my $logo_dimensions = $logo_size.'x'.$logo_size.'+0+0';

my $compass = Image::Magick->new;
show_result($compass->Read("$img_path/thargoid-rose-hydra.bmp"));
show_result($compass->Resize(geometry=>$logo_size.'x'.$logo_size.'+0+0'));
show_result($regionmap->Composite(image=>$compass, compose=>'over', gravity=>'southeast',x=>$pointsize/2,y=>$pointsize/2));
show_result($galaxymap->Composite(image=>$compass, compose=>'over', gravity=>'southeast',x=>$pointsize/2,y=>$pointsize/2));

my $logo = Image::Magick->new;
show_result($logo->Read("$img_path/edastro-550px.bmp"));
show_result($logo->Resize(geometry=>$logo_dimensions));
show_result($galaxymap->Composite(image=>$logo, compose=>'over', gravity=>'northwest',x=>$pointsize/2,y=>$pointsize*1.5));
show_result($regionmap->Composite(image=>$logo, compose=>'over', gravity=>'northwest',x=>$pointsize/2,y=>$pointsize*1.5));

if ($map_logo) {
	my $customlogo = Image::Magick->new;
	show_result($customlogo->Read($map_logo));
	show_result($customlogo->Resize(geometry=>$logo_dimensions));
	show_result($galaxymap->Composite(image=>$customlogo, compose=>'over', gravity=>'northwest',x=>$size_x*0.825,y=>$pointsize*3));
	show_result($regionmap->Composite(image=>$customlogo, compose=>'over', gravity=>'northwest',x=>$size_x*0.825,y=>$pointsize*3));
}

my $rulers_length = int(3200*$scale_factor);
my $rulers_width  = int(178*$scale_factor);

my $scale_vert = Image::Magick->new;
show_result($scale_vert->Read("$img_path/scale-9k-vertical.bmp"));
show_result($scale_vert->Resize(geometry=>$rulers_width.'x'.$rulers_length.'+0+0'));
show_result($galaxymap->Composite(image=>$scale_vert, compose=>'screen', gravity=>'northeast',x=>$edge_height*0.8,y=>0));
show_result($regionmap->Composite(image=>$scale_vert, compose=>'screen', gravity=>'northeast',x=>$edge_height*0.8,y=>0));

my $scale_horiz = Image::Magick->new;
show_result($scale_horiz->Read("$img_path/scale-9k-horizontal.bmp"));
show_result($scale_horiz->Resize(geometry=>$rulers_length.'x'.$rulers_width.'+0+0'));
show_result($galaxymap->Composite(image=>$scale_horiz, compose=>'screen', gravity=>'southwest',x=>0,y=>$edge_height*0.8));
show_result($regionmap->Composite(image=>$scale_horiz, compose=>'screen', gravity=>'southwest',x=>0,y=>$edge_height*0.8));


$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>"$title - ".epoch2date(time).' - '.$author, x=>$pointsize, y=>$pointsize*1.5);
#$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$author, x=>$pointsize, y=>$pointsize*3);

$regionmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>"$title - ".epoch2date(time).' - '.$author, x=>$pointsize, y=>$pointsize*1.5);
#$regionmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$author, x=>$pointsize, y=>$pointsize*3);

print "Drawing\n";

my $n = 0;
my $total = 0;

foreach my $id (keys %fc) {
	my $refsys = $fc{$id}{system};

	my ($x,$y, $xb,$yb, $xr,$yr) = get_coords($refsys);

	if ($x || $y || $xb || $yb || $xr || $yr) {

		#warn "High count: $refsys [$systems{$refsys}]\n" if ($systems{$refsys}>50);
		warn "DSSA Carrier: [$id] $fc{$id}{name}\n";

		my $c  = 'rgb(255,0,0)';
		my $radius = 8;
		my $smallrad = 4;

		next if ($fc{$id}{status} =~ /Retire/i);

		$c = 'rgb(0,255,0)' if ($fc{$id}{status}=~/Operational/);
		$c = 'rgb(255,0,0)' if ($fc{$id}{status}=~/Suspend|Refit|Disable/);

		if ($fc{$id}{until} =~ /(\w+)\s+(\d+),\s+(\d+)/) {
			my ($mon,$day,$year) = ($1,$2,$3);
			my $month = $months{$mon};
	
			if (date2epoch(sprintf("%04u-%02u-%02u 12:00:00",$year,$month,$day)) < time) {
				$c = 'rgb(255,255,0)';
			}

		}

		if (btrim($fc{$id}{systemName}) && uc(btrim($fc{$id}{systemName})) ne uc(btrim($refsys))) {
			$c = 'rgb(255,0,0)';
			my $c2 = 'rgb(255,0,255)';

			my ($x2,$y2, $xb2,$yb2, $xr2,$yr2) = get_coords($fc{$id}{systemName});

			if ($x || $y || $xb || $yb || $xr || $yr) {
				$galaxymap->Draw( primitive=>'line', stroke=>$c2, strokewidth=>2, points=>sprintf("%u,%u %u,%u",$x,$y,$x2,$y2));
				$galaxymap->Draw( primitive=>'line', stroke=>$c2, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$xb,$yb,$xb2,$yb2));
				$galaxymap->Draw( primitive=>'line', stroke=>$c2, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$xr,$yr,$xr2,$yr2));
				$regionmap->Draw( primitive=>'line', stroke=>$c2, strokewidth=>2, points=>sprintf("%u,%u %u,%u",$x,$y,$x2,$y2));
				$regionmap->Draw( primitive=>'line', stroke=>$c2, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$xb,$yb,$xb2,$yb2));
				$regionmap->Draw( primitive=>'line', stroke=>$c2, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$xr,$yr,$xr2,$yr2));
	
				$galaxymap->Draw( primitive=>'circle', stroke=>$c2, fill=>$c2, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x2,$y2,$x2+$radius,$y2));
				$regionmap->Draw( primitive=>'circle', stroke=>$c2, fill=>$c2, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x2,$y2,$x2+$radius,$y2));
		
				$galaxymap->Draw( primitive=>'circle', stroke=>$c2, fill=>$c2, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$xb2,$yb2,$xb2+$smallrad,$yb2));
				$regionmap->Draw( primitive=>'circle', stroke=>$c2, fill=>$c2, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$xb2,$yb2,$xb2+$smallrad,$yb2));
	
				$galaxymap->Draw( primitive=>'circle', stroke=>$c2, fill=>$c2, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$xr2,$yr2,$xr2+$smallrad,$yr2));
				$regionmap->Draw( primitive=>'circle', stroke=>$c2, fill=>$c2, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$xr2,$yr2,$xr2+$smallrad,$yr2));
			}

		}

		$galaxymap->Draw( primitive=>'circle', stroke=>$c, fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$y,$x+$radius,$y));
		$regionmap->Draw( primitive=>'circle', stroke=>$c, fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$y,$x+$radius,$y));

		$galaxymap->Draw( primitive=>'circle', stroke=>$c, fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$xb,$yb,$xb+$smallrad,$yb));
		$regionmap->Draw( primitive=>'circle', stroke=>$c, fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$xb,$yb,$xb+$smallrad,$yb));

		$galaxymap->Draw( primitive=>'circle', stroke=>$c, fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$xr,$yr,$xr+$smallrad,$yr));
		$regionmap->Draw( primitive=>'circle', stroke=>$c, fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$xr,$yr,$xr+$smallrad,$yr));

		$total++;

		$n++;
		#print '.' if ($n % 100 == 0);

	} else {
		#print "\nSkipped $refsys\n";
		skip_entry($refsys,$fc{$id}{name},'missing coordinates');
	}
}


#print "\n";


show_result($galaxymap->Resize(geometry=>int($save_x).'x'.int($save_y).'+0+0')) if ($save_x != $size_x);

my $f = sprintf("%s/$outname.png",$filepath);
print "Writing to: $f\n";
show_result($galaxymap->Write( filename => $f ));

show_result($galaxymap->Gamma( gamma=>1.2, channel=>"all" ));
show_result($galaxymap->Resize(geometry=>int($thumb_x).'x'.int($thumb_y).'+0+0'));

my $f2 = sprintf("%s/$outname-thumb.jpg",$filepath);
print "Writing to: $f2\n";
show_result($galaxymap->Write( filename => $f2 ));

my $png1 = $f;  
my $png2 = $f2; 

if ($png1 !~ /\.png$/) {
	$png1 =~ s/\.bmp/.png/;
	my_system("$convert $f $png1") if (!$debug && $allow_scp);
}
if ($png2 !~ /\.jpg$/) {
	$png2 =~ s/\.bmp/.jpg/;
	my_system("$convert $f2 $png2") if (!$debug && $allow_scp);
}
my_system("$scp $png1 $png2 $remote_server/") if (!$debug && $allow_scp);

show_result($regionmap->Resize(geometry=>int($save_x).'x'.int($save_y).'+0+0')) if ($save_x != $size_x);

my $f = sprintf("%s/$outname-regions.png",$filepath);
print "Writing to: $f\n";
show_result($regionmap->Write( filename => $f ));

show_result($regionmap->Gamma( gamma=>1.2, channel=>"all" ));
show_result($regionmap->Resize(geometry=>int($thumb_x).'x'.int($thumb_y).'+0+0'));

my $f2 = sprintf("%s/$outname-regions-thumb.jpg",$filepath);
print "Writing to: $f2\n";
show_result($regionmap->Write( filename => $f2 ));

my $png1 = $f;  
my $png2 = $f2; 

if ($png1 !~ /\.png$/) {
	$png1 =~ s/\.bmp/.png/;
	my_system("$convert $f $png1") if (!$debug && $allow_scp);
}
if ($png2 !~ /\.jpg$/) {
	$png2 =~ s/\.bmp/.jpg/;
	my_system("$convert $f2 $png2") if (!$debug && $allow_scp);
}
my_system("$scp $png1 $png2 $remote_server/") if (!$debug && $allow_scp);

close SKIP if ($skip_file);

#my_system("$scp $skip_file $remote_server/") if (!$debug && $allow_scp);


if (@ARGV) {
	my @args = @ARGV;
	unshift @args, $myself;
	exec @args;
}


exit;

############################################################################

sub skip_entry {
	my ($ref,$type,$reason) = @_;

	return if (!$skip_file);
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

sub my_rectangle {
	my ($x1,$y1,$x2,$y2,$strokewidth,$color,$fill) = @_;

	#print "Rectangle for $maptype: $x1,$y1,$x2,$y2,$strokewidth,$color\n";

	return if ($x1 < 0 || $y1 < 0 || $x2 < 0 || $y2 < 0);

	if ($fill) {

		$galaxymap->Draw( primitive=>'rectangle', stroke=>$color, fill=>$fill, strokewidth=>$strokewidth,
				points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y2));
		$regionmap->Draw( primitive=>'rectangle', stroke=>$color, fill=>$fill, strokewidth=>$strokewidth,
				points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y2));

	} else {

		$galaxymap->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
				points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y1));
		$regionmap->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
				points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y1));

		$galaxymap->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
				points=>sprintf("%u,%u %u,%u",$x1,$y2,$x2,$y2));
		$regionmap->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
				points=>sprintf("%u,%u %u,%u",$x1,$y2,$x2,$y2));

		$galaxymap->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
				points=>sprintf("%u,%u %u,%u",$x1,$y1,$x1,$y2));
		$regionmap->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
				points=>sprintf("%u,%u %u,%u",$x1,$y1,$x1,$y2));

		$galaxymap->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
				points=>sprintf("%u,%u %u,%u",$x2,$y1,$x2,$y2));
		$regionmap->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
				points=>sprintf("%u,%u %u,%u",$x2,$y1,$x2,$y2));
	}
}

sub get_coords {
	my $name = shift;
	my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where name=? and deletionState=0",[($name)]);

	if (!@rows) {
		@rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems,stars where systemId64=id64 and stars.name=? and systems.deletionState=0 and stars.deletionState=0",[($name)]);
	}

	if (@rows) {
		my $r = shift @rows;

		my ($x1,$y1) = ( ($$r{coord_x}+$galrad)*$size_x/$galsize , ($galrad+$galcenter_y-$$r{coord_z})*$size_y/$galsize );
		if ($x1<0 || $y1<0 || $x1>$size_x || $y1>$size_y) { $x1 = 0; $y1=0; }

		my ($x2,$y2) = ( ($$r{coord_x}+$galrad)*$size_x/$galsize , $size_y+($edge_height/2)+($$r{coord_y}*$size_y/$galsize) );
		if ($x2<0 || $y2<$size_y || $x2>$size_x || $y2>$size_y+$edge_height) { $x2 = 0; $y2=0; }

		my ($x3,$y3) = ( $size_x+($edge_height/2)+($$r{coord_y}*$size_x/$galsize) , ($galrad+$galcenter_y-$$r{coord_z})*$size_y/$galsize );
		if ($x3<$size_x || $y3<0 || $x3>$size_x+$edge_height || $y3>$size_y) { $x3 = 0; $y3=0; }

		return ( floor($x1),floor($y1), floor($x2),floor($y2), floor($x3),floor($y3) );
	}

	return (0,0,0,0,0,0);
}


sub float_colors {
	my $r = shift(@_)/255;
	my $g = shift(@_)/255;
	my $b = shift(@_)/255;
	return [($r,$g,$b)];
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



