#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

use Image::Magick;
use POSIX qw(floor);

############################################################################

my $debug		= 0;
my $verbose		= 0;
my $allow_scp           = 1;

my $scriptpath		= "/home/bones/elite";
my $scripts_path	= "/home/bones/elite/scripts";
my $debug_limit		= ' limit 250000' if ($debug);

my $margin		= 500;

my $remote_server       = 'www@services:/www/edastro.com/mapcharts/';
my $ssh                 = '/usr/bin/ssh';
my $scp                 = '/usr/bin/scp -P222';
my $convert		= '/usr/bin/convert';
my $filepath            = "/home/bones/www/elite";
my $fn			= "$filepath/missing-coordinates-map.bmp";

my %heatindex = ();
@{$heatindex{0}}        = (0,0,0);
@{$heatindex{1}}        = (31,63,255);
@{$heatindex{2}}        = (63,127,255);
@{$heatindex{3}}        = (0,255,255);
@{$heatindex{5}}        = (0,255,0);
@{$heatindex{10}}       = (255,255,0);
@{$heatindex{20}}       = (255,255,255);
@{$heatindex{30}}       = (255,0,0);
@{$heatindex{40}}       = (255,0,127);
@{$heatindex{50}}       = (255,0,255);
@{$heatindex{100}}      = (128,0,255);
@{$heatindex{1000}}     = (128,0,0);
@{$heatindex{999999999}}= (128,0,255);
#@{$heatindex{0}}        = (0,0,0);
#@{$heatindex{1}}        = (0,0,128);
#@{$heatindex{5}}        = (0,0,255);
#@{$heatindex{10}}       = (63,63,255);
#@{$heatindex{50}}       = (63,127,255);
#@{$heatindex{100}}      = (0,255,255);
#@{$heatindex{200}}      = (0,255,0);
#@{$heatindex{300}}      = (255,255,0);
#@{$heatindex{400}}      = (255,255,255);
#@{$heatindex{800}}      = (255,0,0);
#@{$heatindex{1600}}     = (255,0,127);
#@{$heatindex{3200}}     = (255,0,255);
#@{$heatindex{6400}}     = (128,0,255);
#@{$heatindex{12800}}    = (128,0,0);
#@{$heatindex{999999999}}= (128,0,255);

my %addition = ();
#$addition{0}		= 100;
#$addition{1}		= 40;
#$addition{2}		= 20;
#$addition{3}		= 12;
#$addition{4}		= 8;
#$addition{5}		= 4;
#$addition{6}		= 3;
#$addition{7}		= 2;
#$addition{8}		= 1;
#$addition{9}		= 1;

$addition{0}		= 128;
$addition{1}		= 64;
$addition{2}		= 32;
$addition{3}		= 16;
$addition{4}		= 8;
$addition{5}		= 4;
$addition{6}		= 2;
$addition{7}		= 1;
$addition{8}		= 1;
$addition{9}		= 1;

############################################################################

show_queries(0);

my $shellscript = "$filepath/missing-coords-conversions.sh";
open TXT, ">$shellscript";
print TXT "#!/bin/bash\n";

print "Getting sector list...\n";
open CSV, "<$scripts_path/sector-list.csv";

my @sectorname = ();
my %sector = ();

while (<CSV>) {
	chomp;
	my ($s,$c,$x,$y,$z,$x1,$y1,$z1,$x2,$y2,$z2,$bx,$bz,@extra) = parse_csv($_);
	# format: ${$sectorname[$x][$z]}{$n} = $$r{coord_y};
	#my $bx = floor(($x-$sectorcenter_x)/1280)+$sector_radius;
	#my $bz = floor(($z-$sectorcenter_z)/1280)+$sector_radius;
	${$sectorname[$bx][$bz]}{$s} = $y;
	$sector{$s}{x} = $bx;
	$sector{$s}{y} = $bz;
}

close CSV;

print "Getting logos...\n";

my $compass = Image::Magick->new;
show_result($compass->Read("images/thargoid-rose-hydra.bmp"));

my $logo1 = Image::Magick->new;
show_result($logo1->Read("images/edastro-550px.bmp"));

my $logo2 = Image::Magick->new;
show_result($logo2->Read("images/edastro-greyscale-550px.bmp"));

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


my @mapdata = ();

print "Pulling systems...\n";

my @rows = db_mysql('elite',"select name from systems where coord_x is null or coord_y is null or coord_z is null $debug_limit");

my $systemcount = 0;

print "Looping systems...\n";

foreach my $r (@rows) {
	my $subsector = 0;

	my ($sectorname,$l1,$l2,$l3,$masscode,$n) = ();

	if ($$r{name} =~ /^(.*\S)\s+([A-Z])([A-Z])\-([A-Z])\s+([a-z])(\d*)\-\d+/) {
		($sectorname,$l1,$l2,$l3,$masscode,$n) = ($1,$2,$3,$4,$5,$6);
	} elsif ($$r{name} =~ /^(.*\S)\s+([A-Z])([A-Z])\-([A-Z])\s+([a-z])(\d*)$/) {
		($sectorname,$l1,$l2,$l3,$masscode,$n) = ($1,$2,$3,$4,$5,0);
	}

	next if ($sectorname =~ /sector|region/i);
	next if (!exists($sector{$sectorname}));
		
	if ($sectorname && $l1 && $l2 && $l3 && $masscode) {
		$subsector = ($n*17576) + (letter_ord($l3)*676) + (letter_ord($l2)*26) + letter_ord($l1);
	}

	my $bitcount = letter_ord(uc($masscode));
	my $size = 1 << $bitcount;
	my $width = 128 >> $bitcount;

	## Assumes boxel lettering wraps and continues:
	#my $mask = $width-1;
	#my $shiftbits = $bitcount;

	# Uses fixed bit widths for non-contiguous boxel lettering:
	my $mask = 127;
	my $shiftbits = 7;
	
	my $brightness = $addition{$bitcount};
	$brightness = 1 if ($brightness < 1);

	my $x = ($subsector & $mask)*$size;
	my $y = (($subsector >> $shiftbits) & $mask)*$size;
	my $z = (($subsector >> ($shiftbits*2)) & $mask)*$size;

	my $mapx = 4500 + floor((1280*($sector{$sectorname}{x}-35)-65)/10) + $x;
	my $mapy = 7000 - floor((1280*($sector{$sectorname}{y}-15)+215)/10) - $z;

	for(my $mx=0; $mx<$size; $mx++) {
		for(my $my=0; $my<$size; $my++) {
			$mapdata[$mapx+$mx][$mapy-$my] += $brightness;
		}
	}
	$systemcount++;
}

print "Drawing...\n";

my $dotcount = 0;

for(my $x=0; $x<9000; $x++) {
	for(my $y=0; $y<9000; $y++) {
		if ($mapdata[$x][$y]) {
			my $n = int($mapdata[$x][$y]/100);
			$n = 1 if ($n < 1);
			my @pixels = indexed_heat_pixels($n);
			$mapimage->SetPixel( x => $x, y => $y, color => float_colors(@pixels) );
		}
	}
	$dotcount++;

	print '.'  if ($dotcount % 9 == 0);
	print "\n" if ($dotcount % 900 == 0);
	
}
print "\n";

my $pointsize = 130;

$mapimage->Annotate(pointsize=>$pointsize,fill=>'white',x=>$pointsize,y=>$pointsize*1.8,text=>"Star Systems with unknown coordinates, estimated locations");
my $author = "By CMDR Orvidius (edastro.com) - CC BY-NC-SA 3.0 - Data from EDSM.net";
my $additional = commify($systemcount)." systems";
$mapimage->Annotate(pointsize=>$pointsize,fill=>'white',x=>$pointsize,y=>$pointsize*0.8,gravity=>'southwest',text=>"$author - ".epoch2date(time)." - $additional");

show_result($logo1->Resize(geometry=>'1000x1000+0+0'));
show_result($mapimage->Composite(image=>$logo1, compose=>'over', gravity=>'northeast',x=>75+$margin,y=>75));
show_result($compass->Resize(geometry=>'1000x1000+0+0'));
show_result($mapimage->Composite(image=>$compass, compose=>'over', gravity=>'southeast',x=>75+$margin,y=>75+$margin));

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

my_system("$convert $fn -verbose -resize 1600x1600 $png");
my_system("$convert $fn -verbose -resize 1200x1200 $jpg");
my_system("$convert $fn -verbose -resize 200x200 -gamma 1.1 $thumb");
my_system("$scp $png $jpg $thumb $remote_server") if (!$debug && $allow_scp);

close TXT;
print "EXEC $shellscript\n";
exec "/bin/bash $shellscript";

exit;

############################################################################

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
	return ord(shift)-ord('A');
}

sub show_result {
	foreach (@_) {
		warn "WARN: $_\n" if ($_);
	}
}


############################################################################




