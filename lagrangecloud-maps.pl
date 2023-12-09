#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch);

#use Spreadsheet::XLSX;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use Image::Magick;
use POSIX qw(floor);

############################################################################

show_queries(0);

my $debug		= 0;
my $verbose		= 0;
my $allow_scp		= 1;

my $imagename		= 'lagrangeclouds-noPLC';

my %color = ();
$color{'proto'}		= "rgb(200,200,200)";
$color{'protoE'}	= "rgb(100,100,100)";
$color{'caeruleum'}	= "rgb(0,64,224)";
$color{'caeruleumE'}	= "rgb(0,32,128)";
$color{'viride'}	= "rgb(0,224,0)";
$color{'virideE'}	= "rgb(0,128,0)";
$color{'luteolum'}	= "rgb(224,128,0)";
$color{'luteolumE'}	= "rgb(128,64,0)";
$color{'roseum'}	= "rgb(224,0,0)";
$color{'roseumE'}	= "rgb(128,0,0)";
$color{'rubicundum'}	= "rgb(224,0,224)";
$color{'rubicundumE'}	= "rgb(128,0,128)";
$color{'croceum'}	= "rgb(0,224,224)";
$color{'croceumE'}	= "rgb(0,128,128)";

my %keytable = ();
$keytable{proto}	= 'Proto-Lagrange Clouds';
$keytable{caeruleum}	= 'Caeruleum Lagrange Clouds';
$keytable{viride}	= 'Viride Lagrange Clouds';
$keytable{luteolum}	= 'Luteolum Lagrange Clouds';
$keytable{roseum}	= 'Roseum Lagrange Clouds';
$keytable{rubicundum}	= 'Rubicundum Lagrange Clouds';
$keytable{croceum}	= 'Croceum Lagrange Clouds';

my %skip = ();
$skip{proto}		= 1;

my $scp			= '/usr/bin/scp -P222';
my $remote_server	= 'www@services:/www/edastro.com/mapcharts/';
my $scriptpath		= "/home/bones/elite";
my $filepath		= "/home/bones/www/elite";
my $img_path		= "/home/bones/elite/images";

my $filename		= "$scriptpath/lagrangeclouds.xlsx";

$filepath .= '/test'	if ($0 =~ /\.pl\.\S+/);
$allow_scp = 0		if ($0 =~ /\.pl\.\S+/);

my $galrad	      = 45000;
my $galsize	     = $galrad*2;
my $galcenter_y		= 25000;
my $size_x	      = 3200;
my $size_y	      = $size_x;
my $edge_height		= 400;
my $pointsize	   = 40;
my $strokewidth	 = 3;

my $save_x	      = 1800;
my $save_y	      = $save_x;
my $thumb_x	     = 600;
my $thumb_y	     = $thumb_x;

my $title		= "Lagrange Clouds";
my $author		= "Map by CMDR Orvidius (edastro.com) - CC BY-NC-SA 3.0 - Data Provided by CMDR Marx, via Lagrange Clouds spreadsheet";

############################################################################

print "Reading $filename\n";

my $parser = Spreadsheet::ParseXLSX->new;
my $workbook = $parser->parse($filename);

my %nebula = ();


for my $worksheet ( $workbook->worksheets() ) {

	my $sheetname = $worksheet->get_name();

	if ($sheetname =~ /Colourful/i) {
 		parse_sheet($worksheet,'*','System name','NSP type');

	} elsif ($sheetname =~ /Proto/i) {
 		parse_sheet($worksheet,'proto','System name');
	}
}


print "\n".int(keys(%nebula))." total entries loaded.\nCreating Canvas\n";

my %dotimage = ();

my $galaxymap = Image::Magick->new;
$galaxymap->Read("$scriptpath/images/galaxy-3200px-3600px-sides.png");
$galaxymap->Gamma( gamma=>1.2, channel=>"all" );
$galaxymap->Modulate( saturation=>80 );
$galaxymap->Modulate( brightness=>16 );
$galaxymap->Quantize(colorspace=>'RGB');
$galaxymap->Set(depth => 8);

my $regionmap = $galaxymap->Clone();

my $regions = Image::Magick->new;
$regions->Read("$scriptpath/images/region-lines.png");
$regions->Resize(geometry=>"3200x3200+0+0");
#$regions->Gamma(gamma=>'0.4');
$regions->Modulate( saturation=>80 );
$regions->Modulate( brightness=>50 );
$regionmap->Composite(image=>$regions,compose=>'screen', gravity=>'northwest');

$galaxymap->Resize(geometry=>int($size_x+$edge_height).'x'.int($size_y+$edge_height).'+0+0') if ($size_x+$edge_height != 3600);

my $logo_size = int($size_y*0.15);

my $compass = Image::Magick->new;
$compass->Read("$scriptpath/images/thargoid-rose-hydra.png");
$compass->Resize(geometry=>$logo_size.'x'.$logo_size.'+0+0');
$regionmap->Composite(image=>$compass, compose=>'over', gravity=>'southeast',x=>$pointsize/2,y=>$pointsize/2);
$galaxymap->Composite(image=>$compass, compose=>'over', gravity=>'southeast',x=>$pointsize/2,y=>$pointsize/2);

my $logo = Image::Magick->new;
$logo->Read("$scriptpath/images/edastro-550px.png");
$logo->Resize(geometry=>$logo_size.'x'.$logo_size.'+0+0');
$galaxymap->Composite(image=>$logo, compose=>'over', gravity=>'northwest',x=>$pointsize/2,y=>$pointsize*3);
$regionmap->Composite(image=>$logo, compose=>'over', gravity=>'northwest',x=>$pointsize/2,y=>$pointsize*3);

my $scale_vert = Image::Magick->new;
$scale_vert->Read("$scriptpath/images/scale-9k-vertical.png");
$scale_vert->Resize(geometry=>'178x3200+0+0');
$galaxymap->Composite(image=>$scale_vert, compose=>'screen', gravity=>'northeast',x=>$edge_height*0.8,y=>0);
$regionmap->Composite(image=>$scale_vert, compose=>'screen', gravity=>'northeast',x=>$edge_height*0.8,y=>0);

my $scale_horiz = Image::Magick->new;
$scale_horiz->Read("$scriptpath/images/scale-9k-horizontal.png");
$scale_horiz->Resize(geometry=>'3200x178+0+0');
$galaxymap->Composite(image=>$scale_horiz, compose=>'screen', gravity=>'southwest',x=>0,y=>$edge_height*0.8);
$regionmap->Composite(image=>$scale_horiz, compose=>'screen', gravity=>'southwest',x=>0,y=>$edge_height*0.8);


$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>"$title - ".epoch2date(time), x=>$pointsize, y=>$pointsize*1.5);
$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$author, x=>$pointsize, y=>$pointsize*3);

$regionmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>"$title - ".epoch2date(time), x=>$pointsize, y=>$pointsize*1.5);
$regionmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$author, x=>$pointsize, y=>$pointsize*3);

print "Drawing\n";

my %count = ();
my %dotoverlay = ();

if (0) {
	foreach my $plusrad (1,0) {
		foreach my $refsys (keys %nebula) {
			my ($x,$y, $xb,$yb, $xr,$yr) = get_coords($refsys);
		
			if ($x && $y) {
				my $type = $nebula{$refsys};
				next if ($skip{$type});
		
				my $radius = 1;
				#$radius = 1 if ($type eq 'proto');
		
				my $c = $color{$type};
				$c = 'rgb(64,64,64)' if (!$c);
	
				if ($plusrad) {
					if ($color{$type.'E'}) {
						$c = $color{$type.'E'};
					} else {
						$c = 'rgb(64,64,64)';
					}
				}
		
				draw_dots($x,$y, $xb,$yb, $xr,$yr, $radius+$plusrad, $c);
				print '.';
		
				$count{$type}++ if (!$plusrad);
			}
		}
	}
}

if (1) {
	foreach my $refsys (keys %nebula) {
		my $type = $nebula{$refsys};
		next if ($skip{$type});
		my @pixel = (255,255,255);

		if ($color{$type} =~ /rgb\((\d+),(\d+),(\d+)\)/) {
			@pixel = ($1,$2,$3);
		}

		my ($x,$y, $xb,$yb, $xr,$yr) = get_coords($refsys);

		if ($x && $y) {
			$dotoverlay{$x}{$y}{r} += $pixel[0];
			$dotoverlay{$x}{$y}{g} += $pixel[1];
			$dotoverlay{$x}{$y}{b} += $pixel[2];
			$dotoverlay{$x}{$y}{n} ++;

			$dotoverlay{$xb}{$yb}{r} += $pixel[0];
			$dotoverlay{$xb}{$yb}{g} += $pixel[1];
			$dotoverlay{$xb}{$yb}{b} += $pixel[2];
			$dotoverlay{$xb}{$yb}{n} ++;

			$dotoverlay{$xr}{$yr}{r} += $pixel[0];
			$dotoverlay{$xr}{$yr}{g} += $pixel[1];
			$dotoverlay{$xr}{$yr}{b} += $pixel[2];
			$dotoverlay{$xr}{$yr}{n} ++;
			$count{$type}++;
		}
	}

	foreach my $x (keys %dotoverlay) {
		foreach my $y (keys %{$dotoverlay{$x}}) {
			print '+',next if (!$dotoverlay{$x}{$y}{n});

			my @pixels = (int($dotoverlay{$x}{$y}{r}/$dotoverlay{$x}{$y}{n}), 
					int($dotoverlay{$x}{$y}{g}/$dotoverlay{$x}{$y}{n}), 
					int($dotoverlay{$x}{$y}{b}/$dotoverlay{$x}{$y}{n}));

			#print "$x,$y = $pixels[0],$pixels[1],$pixels[2]\n";

			#$galaxymap->SetPixel( x => $x, y => $y, color => float_colors(@pixels) );
			#$regionmap->SetPixel( x => $x, y => $y, color => float_colors(@pixels) );

			draw_single_dot($x,$y,1,sprintf("rgb(%u,%u,%u)",$pixels[0],$pixels[1],$pixels[2]));
			print '.';
		}
	}
}

print "\n";

sub float_colors {
        my $r = shift(@_)/255;
        my $g = shift(@_)/255;
        my $b = shift(@_)/255;
        return [($r,$g,$b)];
}

sub draw_dots {
	my ($x,$y, $xb,$yb, $xr,$yr, $radius,$c) = @_;

	draw_single_dot($x,$y,$radius,$c);
	draw_single_dot($xb,$yb,$radius,$c);
	draw_single_dot($xr,$yr,$radius,$c);
}

sub draw_single_dot {
	my ($x,$y,$radius,$c) = @_;
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

	$galaxymap->Composite(image=>$dotimage{$radius}{$c}, compose=>'screen', gravity=>'northwest',x=>$x-5,y=>$y-5);
	$regionmap->Composite(image=>$dotimage{$radius}{$c}, compose=>'screen', gravity=>'northwest',x=>$x-5,y=>$y-5);
}

my $legend_x = $size_x*0.75;
my $legend_y = $pointsize;
#my $legend_y = $size_y-$pointsize*5.5;

foreach my $map ($galaxymap,$regionmap) {
	my $i = 0;
	foreach my $key (sort {$keytable{$a} cmp $keytable{$b}} keys %count) {
		next if ($skip{$key});

		my $text = $keytable{$key};
		$text = $key if (!$text);
		$text .= " ($count{$key})";
		$map->Annotate(pointsize=>$pointsize,fill=>'white',text=>$text, x=>$legend_x+$pointsize*2, y=>$legend_y+$pointsize*(1+$i*1.5));
		print "$text\n";
	
		my $col = $color{$key};
		#$col = $keyOverride{$key} if ($keyOverride{$key});
	
		$map->Draw( primitive=>'rectangle',stroke=>'white', fill=>$color{$key},  strokewidth=>2, points=>sprintf("%u,%u %u,%u",
			$legend_x+$pointsize*0.5,$legend_y+$pointsize*(0.2+$i*1.5),$legend_x+$pointsize*1.5,$legend_y+$pointsize*(1.2+$i*1.5)));
		$i++;
	}
}




$galaxymap->Resize(geometry=>int($save_x).'x'.int($save_y).'+0+0') if ($save_x != $size_x+$edge_height);

my $f = sprintf("%s/$imagename.jpg",$filepath);
print "Writing to: $f\n";
my $res = $galaxymap->Write( filename => $f );
if ($res) {
	warn $res;
}

$galaxymap->Gamma( gamma=>1.2, channel=>"all" );
$galaxymap->Resize(geometry=>int($thumb_x).'x'.int($thumb_y).'+0+0');

my $f2 = sprintf("%s/$imagename-thumb.jpg",$filepath);
print "Writing to: $f2\n";
my $res = $galaxymap->Write( filename => $f2 );
if ($res) {
	warn $res;
}

my_system("$scp $f $f2 $remote_server/") if (!$debug && $allow_scp);

$regionmap->Resize(geometry=>int($save_x).'x'.int($save_y).'+0+0') if ($save_x != $size_x+$edge_height);

my $f = sprintf("%s/$imagename-regions.jpg",$filepath);
print "Writing to: $f\n";
my $res = $regionmap->Write( filename => $f );
if ($res) {
	warn $res;
}

$regionmap->Gamma( gamma=>1.2, channel=>"all" );
$regionmap->Resize(geometry=>int($thumb_x).'x'.int($thumb_y).'+0+0');

my $f2 = sprintf("%s/$imagename-regions-thumb.jpg",$filepath);
print "Writing to: $f2\n";
my $res = $regionmap->Write( filename => $f2 );
if ($res) {
	warn $res;
}

my_system("$scp $f $f2 $remote_server/") if (!$debug && $allow_scp);

exit;

############################################################################

sub get_columns {
	my ($href,$cn,$cell,$refmatch,$typematch) = @_;
	$$href{ref}  = $cn if ($refmatch && $cell =~ /$refmatch/i);
	$$href{type} = $cn if ($typematch && $cell =~ /$typematch/i);
}

sub parse_sheet {
	my $worksheet	= shift;
	my $type	= shift;
	my $refmatch	= shift;
	my $typematch	= shift;

	my ( $row_min, $row_max ) = $worksheet->row_range();
	my ( $col_min, $col_max ) = $worksheet->col_range();

	my %col = ();

	for my $cn ( $col_min .. $col_max ) {
		my $cell = $worksheet->get_cell( 0, $cn );
		next if (!defined($cell));
		get_columns(\%col,$cn,$cell->unformatted(),$refmatch,$typematch);
	}

	for my $row ( 1 .. $row_max ) {

		my $ref  = '';
		my $cell = $worksheet->get_cell( $row, $col{ref} );
		$ref = $cell->value() if (defined($cell));

		if ($ref) { 
			$nebula{$ref} = $type;
			if ($nebula{$ref} eq '*') {
				my $rowtype  = '';
				my $cell = $worksheet->get_cell( $row, $col{type} );
				$rowtype = $cell->value() if (defined($cell));

				if ($rowtype) { 
					foreach my $t (keys %keytable) {
						if ($rowtype =~ /$t/i && $t !~ /E$/) {
							$nebula{$ref} = $t;
						}
					}
				}
			}
		}
		#print '.';
	}
}

sub get_coords {
	my $name = shift;
	my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where name=? and deletionState=0",[($name)]);

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

############################################################################



