#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch parse_csv make_csv);

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

my $title		= "Fuel Rat Rescue Locations";
my $author		= "Map by CMDR Orvidius (edastro.com) - Data Provided by The Fuel Rats";

my %heatindex = ();
@{$heatindex{0}}	= (0,0,0);
@{$heatindex{1}}	= (127,127,255);
@{$heatindex{2}}	= (0,255,255);
@{$heatindex{3}}	= (0,255,0);
@{$heatindex{5}}        = (255,255,0);
@{$heatindex{10}}       = (255,0,0);
@{$heatindex{20}}       = (255,0,127);
@{$heatindex{50}}       = (255,0,255);
@{$heatindex{100}}      = (128,0,255);
@{$heatindex{200}}      = (128,0,0);
@{$heatindex{999999999}}= (128,0,255);

my $scp			= '/usr/bin/scp -P222';
my $convert		= '/usr/bin/convert';
my $web_server		= 'www@services:/www/edastro.com';
my $remote_server	= "$web_server/mapcharts/test/";
my $scriptpath		= "/home/bones/elite/csv-maps";
my $filepath		= "/home/bones/www/elite";
my $img_path		= "/home/bones/elite/images";
my $logo_path		= "/home/bones/elite/images/csv-maps";
my $map_logo		= '';
my $skip_file		= '';
my $filename		= '';
my $system_col		= '';
my $count_col		= '';
my $outname		= '';
my $somethings		= '';

$filepath .= '/test'	if ($0 =~ /\.pl\.\S+/);
$allow_scp = 0		if ($0 =~ /\.pl\.\S+/);

my $galrad		= 45000;
my $galsize		= $galrad*2;
my $galcenter_y		= 25000;
my $size_x		= 1600;
my $size_y		= $size_x;
my $edge_height		= 400;
my $pointsize		= 40;
my $strokewidth		= 3;

my $myself		= "$scriptpath/".basename($0);
#warn "MYSELF: $myself\n";

############################################################################
# Load config, and cascading settings

if (@ARGV) {
	load_config(shift @ARGV);
} else {
	die "Usage: $0 <configFile>\n";
}

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


die "Need filename!\n" if (!$filename);
die "Need system reference column!\n" if (!$system_col);

print "Reading CSVs\n";

if ($skip_file) {
	open SKIP, ">$skip_file";
	print SKIP "System,Count,Reason\r\n";
}

my %systems = ();

do_csv($filename,$system_col,$count_col);

print "\n".int(keys(%systems))." total systems loaded.\nCreating Canvas\n";

my %dotimage = ();

my $galaxymap = Image::Magick->new;
show_result($galaxymap->Read("$img_path/galaxy-3200px-3600px-sides.bmp"));
show_result($galaxymap->Resize(geometry=>$scaled_image)) if ($size_x != 3200);
show_result($galaxymap->Gamma( gamma=>1.2, channel=>"all" ));
show_result($galaxymap->Modulate( saturation=>60 ));
show_result($galaxymap->Modulate( brightness=>45 ));
show_result($galaxymap->Quantize(colorspace=>'RGB'));
show_result($galaxymap->Set(depth => 8));

my $regionmap = $galaxymap->Clone();

my $regions = Image::Magick->new;
show_result($regions->Read("$img_path/region-lines.bmp"));
show_result($regions->Resize(geometry=>$scaled_map));
#show_result($regions->Gamma(gamma=>'0.4'));
show_result($regions->Modulate( saturation=>80 ));
show_result($regions->Modulate( brightness=>50 ));
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
show_result($galaxymap->Composite(image=>$logo, compose=>'over', gravity=>'northwest',x=>$pointsize/2,y=>$pointsize*3));
show_result($regionmap->Composite(image=>$logo, compose=>'over', gravity=>'northwest',x=>$pointsize/2,y=>$pointsize*3));

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


$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>"$title - ".epoch2date(time), x=>$pointsize, y=>$pointsize*1.5);
$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$author, x=>$pointsize, y=>$pointsize*3);

$regionmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>"$title - ".epoch2date(time), x=>$pointsize, y=>$pointsize*1.5);
$regionmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$author, x=>$pointsize, y=>$pointsize*3);

print "Drawing\n";

my %map = ();
my $n = 0;
my $total = 0;

foreach my $refsys (keys %systems) {
	my ($x,$y, $xb,$yb, $xr,$yr) = get_coords($refsys);

	if ($x || $y || $xb || $yb || $xr || $yr) {

		#warn "High count: $refsys [$systems{$refsys}]\n" if ($systems{$refsys}>50);

		$map{$x}{$y}   += $systems{$refsys};
		$map{$xb}{$yb} += $systems{$refsys};
		$map{$xr}{$yr} += $systems{$refsys};

		$total += $systems{$refsys};

		$n++;
		print '.' if ($n % 100 == 0);

	} else {
		#print "\nSkipped $refsys ($systems{$refsys})\n";
		skip_entry($refsys,$systems{$refsys},'missing coordinates');
	}
}

foreach my $x (sort keys %map) {
	foreach my $y (sort keys %{$map{$x}}) {
		#warn "High count: $x,$y {$map{$x}{$y}}\n" if ($map{$x}{$y}>50);
		my @pixels = indexed_heat_pixels($map{$x}{$y});
		$galaxymap->SetPixel( x => $x, y => $y, color => float_colors(@pixels) );
		$regionmap->SetPixel( x => $x, y => $y, color => float_colors(@pixels) );
	}
}


print "\n";

my $legend_x = $size_x*0.9;
my $legend_y = $size_y*0.8;
#my $legend_y = $size_y-$pointsize*5.5;

$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>commify($total)." total $somethings in ".commify($n)." systems shown", 
			gravity=>'northeast', x=>$edge_height+$pointsize*2, y=>$pointsize*1.5);

$regionmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>commify($total)." total $somethings in ".commify($n)." systems shown", 
			gravity=>'northeast', x=>$edge_height+$pointsize*2, y=>$pointsize*1.5);

if (1) {
	my @list = sort {$a<=>$b} keys %heatindex;

	$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Color Index:',x=>$legend_x,y=>$legend_y);
	$regionmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Color Index:',x=>$legend_x,y=>$legend_y);

	for(my $i=0; $i<@list-1; $i++) {
		my $s = "$list[$i]";
		$s .= "-".int($list[$i+1]-1) if ($list[$i+1]-1 > $list[$i] && $i+1<@list-1);
		$s .= "+" if ($i+1 >= @list-1);

		$legend_y += int($pointsize*1.3);
		my $color = "rgb(".join(',',@{$heatindex{$list[$i]}}).")";
		print "\t$list[$i] = $color\n";

		$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$s,x=>$legend_x+$pointsize*2,y=>$legend_y+$pointsize-1);
		$regionmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$s,x=>$legend_x+$pointsize*2,y=>$legend_y+$pointsize-1);

		my_rectangle($legend_x+$pointsize*0.5,$legend_y,$legend_x+$pointsize*1.5-1,$legend_y+$pointsize-1,1,'#777',$color);
	}
}


show_result($galaxymap->Resize(geometry=>int($save_x).'x'.int($save_y).'+0+0')) if ($save_x != $size_x);

my $f = sprintf("%s/$outname-rescues.bmp",$filepath);
print "Writing to: $f\n";
show_result($galaxymap->Write( filename => $f ));

show_result($galaxymap->Gamma( gamma=>1.2, channel=>"all" ));
show_result($galaxymap->Resize(geometry=>int($thumb_x).'x'.int($thumb_y).'+0+0'));

my $f2 = sprintf("%s/$outname-rescues-thumb.jpg",$filepath);
print "Writing to: $f2\n";
show_result($galaxymap->Write( filename => $f2 ));

my $png1 = $f;  $png1 =~ s/\.bmp/.png/;
my $png2 = $f2; $png2 =~ s/\.bmp/.png/;

my_system("$convert $f $png1") if (!$debug && $allow_scp);
my_system("$convert $f2 $png2") if (!$debug && $allow_scp);
my_system("$scp $png1 $png2 $remote_server/") if (!$debug && $allow_scp);

show_result($regionmap->Resize(geometry=>int($save_x).'x'.int($save_y).'+0+0')) if ($save_x != $size_x);

my $f = sprintf("%s/$outname-rescues-regions.bmp",$filepath);
print "Writing to: $f\n";
show_result($regionmap->Write( filename => $f ));

show_result($regionmap->Gamma( gamma=>1.2, channel=>"all" ));
show_result($regionmap->Resize(geometry=>int($thumb_x).'x'.int($thumb_y).'+0+0'));

my $f2 = sprintf("%s/$outname-rescues-regions-thumb.jpg",$filepath);
print "Writing to: $f2\n";
show_result($regionmap->Write( filename => $f2 ));

my $png1 = $f;  $png1 =~ s/\.bmp/.png/;
my $png2 = $f2; $png2 =~ s/\.bmp/.png/;

my_system("$convert $f $png1") if (!$debug && $allow_scp);
my_system("$convert $f2 $png2") if (!$debug && $allow_scp);
my_system("$scp $png1 $png2 $remote_server/") if (!$debug && $allow_scp);

close SKIP if ($skip_file);

my_system("$scp $skip_file $remote_server/") if (!$debug && $allow_scp);


if (@ARGV) {
	my @args = @ARGV;
	unshift @args, $myself;
	exec @args;
}


exit;

############################################################################

sub do_csv {
	my $csv_file	= shift;
	my $refmatch	= shift;
	my $countmatch	= shift;

	open CSV, "<$csv_file";

	my $line = <CSV>;
	my %col  = ();
	my @cols = parse_csv($line);
	for(my $i=0; $i<@cols; $i++) {
		$col{ref}  = $i if ($refmatch && $cols[$i] =~ /$refmatch/i);
		$col{count} = $i if ($countmatch && $cols[$i] =~ /$countmatch/i);
	}

	print "READ: $csv_file ($refmatch = $col{ref}, $countmatch = $col{count})\n";

	while (<CSV>) {
		chomp;
		my @v = fix_trim(parse_csv($_));
		my $ref = '';

		$ref = $v[$col{ref}] if (defined($col{ref}));
		$ref =~ s/\s+/ /gs;
		$ref =~ s/[\/\#].*$//gs;

		my $count = 1;
		$count = $v[$col{count}] if (defined($col{count}));

		#warn "High count: $ref ($count)\n" if ($count>10);

		if ($ref && $count) {
			$systems{$ref} += $count;
		}
#print join("\t|\t",@v)."\n" if (!$ref);
	}

	close CSV;
}

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

sub indexed_heat_pixels {
	my ($heat) = @_;
	return (0,0,0) if (!$heat);

	my $bottomIndex = 0;
	my $topIndex = 0;

	my @list = sort {$a<=>$b} keys %heatindex;
	my $i = 0;
	while ($i<@list-1 && !$topIndex) {
		$i++;
		if ($heat >= $list[$i] && $heat < $list[$i+1]) {
			$bottomIndex = $i; $topIndex = $i+1;
			last;
		}
	}

	return (0,0,0) if (!$topIndex || $list[$topIndex]-$list[$bottomIndex] == 0);

	my $decimal = ($heat-$list[$bottomIndex]) / ($list[$topIndex]-$list[$bottomIndex]);

	my @bottomColor = @{$heatindex{$list[$bottomIndex]}};
	my @topColor    = @{$heatindex{$list[$topIndex]}};

	my @pixels = scaledColorRange($bottomColor[0],$bottomColor[1],$bottomColor[2],$decimal,$topColor[0],$topColor[1],$topColor[2]);

	return @pixels;
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

sub load_config {
	my $fn = shift;

	open TXT, "<$fn";

	while (my $line = <TXT>) {
		chomp $line;

		$line =~ s/#.*$//;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;

		next if (!$line);

		warn "$line\n";

		my ($var,$val) = split /\s+/, $line, 2;
		$var = lc($var);
		my $colors = '';
		
		if ($var eq 'clearindex') {
			%heatindex = ();
		}

		if ($var eq 'heatindex') {
			($val,$colors) = split /\s+/, $val, 2;
			my @color = split /[\s,]+/,$colors;
			
			@{$heatindex{$val}} = @color;
		}

		$filename   = $val if ($var eq 'csv');
		$map_logo   = $val if ($var eq 'logo');
		$skip_file  = $val if ($var eq 'skip_file');
		$count_col  = $val if ($var eq 'count_col');
		$system_col = $val if ($var eq 'system_col');
		$size_x     = $val if ($var eq 'size');
		$size_y     = $val if ($var eq 'size');
		$title      = $val if ($var eq 'title');
		$author     = $val if ($var eq 'author');
		$outname    = $val if ($var eq 'outname');
		$somethings = $val if ($var eq 'what');
		$remote_server = "$web_server/$val" if ($var eq 'remote_server');
	}

	close TXT;
}

############################################################################



