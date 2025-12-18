#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10 id64_subsector ssh_options scp_options);

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
my $scale_factor	= 10;
my $verbose		= 0;
my $write_output	= 0;

if ($ARGV[0] eq 'cron') {
	$write_output = 1;
	$debug = 0;
	$allow_scp = 1;
	shift @ARGV;
} elsif ($ARGV[0] eq 'read') {
	$debug = 0;
	$allow_scp = 0;
	shift @ARGV;
} elsif ($ARGV[0] eq 'debug') {
	$debug = 1;
	$allow_scp = 0;
	shift @ARGV;
}

$debug = 1 if ($ARGV[0]);
$allow_scp = 0 if ($debug || $ARGV[1]);

my $galaxy_radius       = 45000;
my $galaxy_height       = 6000;

my $galcenter_x         = 0;
my $galcenter_y         = -25;
my $galcenter_z         = 25000;

my $pixellightyears	= 10;

my $sol_fudge		= 150;
my $debug_count		= 50;
my $margin		= 0; #500;

my $scriptpath          = "/home/bones/elite";
my $scripts_path	= "/home/bones/elite/scripts";
my $debug_limit		= ' limit 50000' if ($debug);

my $remote_server       = 'www@services:/www/edastro.com/mapcharts/';
my $ssh                 = '/usr/bin/ssh'.ssh_options();
my $scp                 = '/usr/bin/scp'.scp_options();
my $convert		= '/usr/bin/convert';
my $filepath            = "/home/bones/www/elite";
$filepath .= "/test" if ($debug);
my $fn			= "$filepath/inhabited-overlay.bmp";

my @expl_level = ();

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

my $shellscript = "$filepath/inhabited-overlay.sh";
open TXT, ">$shellscript";
print TXT "#!/bin/bash\n";

sub parse_system {
        my $s = shift;

        if ($s =~ /^(.+\S)\s+([A-Z])([A-Z])\-([A-Z])\s+([a-z])(\d*)\-(\d+)/i) {
                return ($1,$2,$3,$4,$5,$6+0,$7);
        } elsif ($s =~ /^(.+\S)\s+([A-Z])([A-Z])\-([A-Z])\s+([a-z])(\d+)$/i) {
                return ($1,$2,$3,$4,$5,0,$6);
        }
        return undef;
}

print "Pulling systems...\n";

my @rows = db_mysql('elite',"select id64,coord_x,coord_y,coord_z from stations,systems where ".
		"type is not NULL and type!='Mega ship' and type!='Fleet Carrier' and type!='GameplayPOI' and ".
		"type!='PlanetaryConstructionDepot' and type!='SpaceConstructionDepot' and type!='Mega Ship' and stations.deletionState=0 and ".
		"id64=systemId64 and systems.deletionState=0");


print "Looping systems...\n";
my @map = ();
my %chart = ();

$chart{main}{size_x}    = int($galaxy_radius/$pixellightyears);
$chart{main}{size_y}    = int($galaxy_radius/$pixellightyears);
$chart{main}{center_x}  = $chart{main}{size_x};
$chart{main}{center_y}  = $chart{main}{size_y};
$chart{main}{x}         = $galcenter_x;
$chart{main}{y}         = $galcenter_y;
$chart{main}{z}         = $galcenter_z;

$chart{front}{size_x}   = int($galaxy_radius/$pixellightyears);
$chart{front}{size_y}   = int($galaxy_height/$pixellightyears);
$chart{front}{center_x} = $chart{front}{size_x};
$chart{front}{center_y} = $chart{front}{size_y} + $chart{main}{size_y} + $chart{main}{center_y};
$chart{front}{zoom}     = 1;
$chart{front}{x}        = $galcenter_x;
$chart{front}{y}        = $galcenter_y;
$chart{front}{z}        = $galcenter_z;

$chart{side}{size_x}    = int($galaxy_height/$pixellightyears);
$chart{side}{size_y}    = int($galaxy_radius/$pixellightyears);
$chart{side}{center_x}  = $chart{side}{size_x} + $chart{main}{size_x} + $chart{main}{center_x};
$chart{side}{center_y}  = $chart{side}{size_y};
$chart{side}{zoom}      = 1;
$chart{side}{x}         = $galcenter_x;
$chart{side}{y}         = $galcenter_y;
$chart{side}{z}         = $galcenter_z;

sub get_image_coords {
	my ($chartmap,$r) = @_;
	my ($x,$y,$in_range) = (0,0,0);

        if ($chartmap =~ /front/) {
                $x = int( $chart{$chartmap}{center_x} + (($$r{coord_x} - $chart{$chartmap}{x}) / $pixellightyears));
                $y = int( $chart{$chartmap}{center_y} - (($$r{coord_y} - $chart{$chartmap}{y}) / $pixellightyears));
        } elsif ($chartmap =~ /side/) {
                $x = int( $chart{$chartmap}{center_x} - (($$r{coord_y} - $chart{$chartmap}{y}) / $pixellightyears));
                $y = int( $chart{$chartmap}{center_y} - (($$r{coord_z} - $chart{$chartmap}{z}) / $pixellightyears));
        } else {
                $x = int( $chart{$chartmap}{center_x} + (($$r{coord_x} - $chart{$chartmap}{x}) / $pixellightyears));
                $y = int( $chart{$chartmap}{center_y} - (($$r{coord_z} - $chart{$chartmap}{z}) / $pixellightyears));
        }

	if (       $x >= $chart{$chartmap}{center_x} - $chart{$chartmap}{size_x}
                && $x <  $chart{$chartmap}{center_x} + $chart{$chartmap}{size_x}
                && $y >= $chart{$chartmap}{center_y} - $chart{$chartmap}{size_y}
                && $y <  $chart{$chartmap}{center_y} + $chart{$chartmap}{size_y} ) {
                $in_range = 1;
        }

        $in_range = 1 if ($in_range);

	return ($x,$y,$in_range);
}

my $systemcount = 0;

my %systems = ();


while (@rows) {
	my $r = shift @rows;
	$systems{$$r{id64}} = $r;
	delete($systems{$$r{id64}}{id64});
}

foreach my $id64 (keys %systems) {
	$systemcount++;
	my $view = 'main';

	#foreach my $view ('main','front','side') {
		my ($x,$y) = get_image_coords($view,$systems{$id64});

		$map[$x][$y]++;
	#}

}


#print "Getting logos...\n";
#
#my $compass = Image::Magick->new;
#show_result($compass->Read("images/thargoid-rose-hydra.bmp"));
#
#my $logo1 = Image::Magick->new;
#show_result($logo1->Read("images/edastro-550px.bmp"));
#
#my $logo2 = Image::Magick->new;
#show_result($logo2->Read("images/edastro-greyscale-550px.bmp"));



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

#my $scale_vert = Image::Magick->new;
#show_result($scale_vert->Read("$scriptpath/images/scale-9k-vertical.bmp"));
#show_result($mapimage->Composite(image=>$scale_vert, compose=>'screen', gravity=>'northwest',x=>8800,y=>0));
#
#my $scale_horiz = Image::Magick->new;
#show_result($scale_horiz->Read("$scriptpath/images/scale-9k-horizontal.bmp"));
#show_result($mapimage->Composite(image=>$scale_horiz, compose=>'screen', gravity=>'northwest',x=>0,y=>8800));

print "Drawing...\n";

my $dotcount = 0;

for(my $x=0; $x<9000; $x++) {
	for(my $y=0; $y<9000; $y++) {
		if ($map[$x][$y]) {

			my @pixels = (255,0,255);
			$pixels[1] = 255*($map[$x][$y]/200); $pixels[1] = 255 if ($pixels[1] > 255);

			$mapimage->SetPixel( x => $x, y => $y, color => float_colors(@pixels) );
		}
	}
	$dotcount++;

	print '.'  if ($dotcount % 9 == 0);
	print "\n" if ($dotcount % 900 == 0);
	
}
print "\n";


my $pointsize = 130;
if (0) {
$mapimage->Annotate(pointsize=>$pointsize,fill=>'white',x=>$pointsize,y=>$pointsize*1.8,text=>"Inhabited Systems with Docking Locations");
my $author = "By CMDR Orvidius (edastro.com) - CC BY-NC-SA 3.0 - Data from EDDN & EDSM.net";
my $additional = commify($systemcount)." systems";
$mapimage->Annotate(pointsize=>$pointsize,fill=>'white',x=>$pointsize,y=>$pointsize*0.8,gravity=>'southwest',text=>"$author - ".epoch2date(time)." - $additional");
}



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
my_system("$convert $fn -verbose -transparent black $png") if ($fn ne $png);
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




