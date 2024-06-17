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
my $verbose		= 0;
my $allow_scp		= 1;

my %color = ();
#$color{'procgen'}	= "rgb(255,0,128)";
#$color{'procgenE'}	= "rgb(128,0,64)";
#$color{'real'}		= "rgb(255,128,0)";
#$color{'realE'}		= "rgb(128,64,0)";
#$color{'planetary'}	= "rgb(0,128,255)";
#$color{'planetaryE'}	= "rgb(0,64,128)";
$color{'procgen'}	= "rgb(192,0,96)";
$color{'procgenE'}	= "rgb(96,0,48)";
$color{'real'}		= "rgb(192,96,0)";
$color{'realE'}		= "rgb(96,48,0)";
$color{'planetary'}	= "rgb(0,144,224)";
$color{'planetaryE'}	= "rgb(0,64,128)";

my $scp			= '/usr/bin/scp -P222';
my $remote_server	= 'www@services:/www/edastro.com/mapcharts';
my $scriptpath		= "/home/bones/elite";
my $filepath		= "/home/bones/www/elite";
my $img_path		= "/home/bones/elite/images";

my $filename_real	= "$scriptpath/nebulae-real.csv";
my $filename_procgen	= "$scriptpath/nebulae-procgen.csv";
my $filename_planetary	= "$scriptpath/nebulae-planetary.csv";

my $output_sheet	= "$scriptpath/nebulae-coordinates.csv";

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
my $thumb_x             = 600;
my $thumb_y             = $thumb_x;

my $title		= "Procedurally Generated Nebulae and Planetary Nebulae";
my $author		= "Map by CMDR Orvidius (edastro.com) - CC BY-NC-SA 3.0 - Data Provided by CMDR Marx, via Catalogue of Galactic Nebulae";
my $submit		= "Submit new nebulae discoveries here: https://edastro.com/r/nebulae";

############################################################################

print "Reading CSVs\n";

open SKIP, ">nebulae-skipped.csv";
print SKIP "Ref.System,Type,Reason\r\n";

my %nebula = ();
my %nebulaname = ();

do_csv($filename_real,'real','Ref. System','Nebula Name');
do_csv($filename_procgen,'procgen','Reference','Nebula Name');
do_csv($filename_planetary,'planetary','star name','nickname');

print "\n".int(keys(%nebula))." total entries loaded.\nCreating Canvas\n";

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
show_result($galaxymap->Composite(image=>$logo, compose=>'over', gravity=>'northwest',x=>$pointsize/2,y=>$pointsize*4.5));
show_result($regionmap->Composite(image=>$logo, compose=>'over', gravity=>'northwest',x=>$pointsize/2,y=>$pointsize*4.5));

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


$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>"$title - ".epoch2date(time), x=>$pointsize, y=>$pointsize*1.5);
$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$author, x=>$pointsize, y=>$pointsize*3);
$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$submit, x=>$pointsize, y=>$pointsize*4.5);

$regionmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>"$title - ".epoch2date(time), x=>$pointsize, y=>$pointsize*1.5);
$regionmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$author, x=>$pointsize, y=>$pointsize*3);
$regionmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>$submit, x=>$pointsize, y=>$pointsize*4.5);

print "Drawing\n";

my %count = ();

open OUT, ">$output_sheet";
print OUT make_csv("Name","System","X","Y","Z","Type")."\r\n";

foreach my $plusrad (1,0) {
	foreach my $refsys (sort { $nebula{$a} cmp $nebula{$b} || lc($nebulaname{$a}) cmp lc($nebulaname{$b}) } keys %nebula) {
		my ($x,$y, $xb,$yb, $xr,$yr, $xx,$yy,$zz) = get_coords($refsys);
	
		if ($x && $y) {
			my $type = $nebula{$refsys};
	
			my $radius = 3;
			$radius = 1 if ($type eq 'planetary');
	
			my $c = $color{$type};
			$c = 'white' if (!$c);

			if ($plusrad) {
				if ($color{$type.'E'}) {
					$c = $color{$type.'E'};
				} else {
					$c = 'rgb(64,64,64)';
				}
			}
	
			draw_dots($x,$y, $xb,$yb, $xr,$yr, $radius+$plusrad, $c);
			#print '.';
			print "$nebulaname{$refsys} ($refsys) $xx,$yy,$zz [$type]\n";

			print OUT make_csv($nebulaname{$refsys},$refsys,$xx,$yy,$zz,$type)."\r\n" if ($plusrad);
	
			$count{$type}++ if (!$plusrad);
		} elsif (!$plusrad) {
			print "\nSkipped $refsys ($nebula{$refsys})\n";
			skip_nebula($refsys,$nebula{$refsys},'missing coordinates');
		}
	}
}
print "\n";

close OUT;

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

show_result($galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Real  Nebulae ('.commify($count{real}).')', x=>$legend_x+$pointsize*2, y=>$legend_y+$pointsize*1));
show_result($galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Proc.Gen. Standard Nebulae ('.commify($count{procgen}).')', x=>$legend_x+$pointsize*2, y=>$legend_y+$pointsize*2.5));
show_result($galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Proc.Gen. Planetary Nebulae ('.commify($count{planetary}).')', x=>$legend_x+$pointsize*2, y=>$legend_y+$pointsize*4));

$galaxymap->Draw( primitive=>'rectangle',stroke=>'white', fill=>$color{real},  strokewidth=>2, points=>sprintf("%u,%u %u,%u",
								$legend_x+$pointsize*0.5,$legend_y+$pointsize*0.2,$legend_x+$pointsize*1.5,$legend_y+$pointsize*1.2));
$galaxymap->Draw( primitive=>'rectangle',stroke=>'white', fill=>$color{procgen}, strokewidth=>2, points=>sprintf("%u,%u %u,%u",
								$legend_x+$pointsize*0.5,$legend_y+$pointsize*1.7,$legend_x+$pointsize*1.5,$legend_y+$pointsize*2.7));
$galaxymap->Draw( primitive=>'rectangle',stroke=>'white', fill=>$color{planetary}, strokewidth=>2, points=>sprintf("%u,%u %u,%u",
								$legend_x+$pointsize*0.5,$legend_y+$pointsize*3.2,$legend_x+$pointsize*1.5,$legend_y+$pointsize*4.2));

show_result($regionmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Real  Nebulae ('.commify($count{real}).')', x=>$legend_x+$pointsize*2, y=>$legend_y+$pointsize*1));
show_result($regionmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Proc.Gen. Standard Nebulae ('.commify($count{procgen}).')', x=>$legend_x+$pointsize*2, y=>$legend_y+$pointsize*2.5));
show_result($regionmap->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Proc.Gen. Planetary Nebulae ('.commify($count{planetary}).')', x=>$legend_x+$pointsize*2, y=>$legend_y+$pointsize*4));

$regionmap->Draw( primitive=>'rectangle',stroke=>'white', fill=>$color{real},  strokewidth=>2, points=>sprintf("%u,%u %u,%u",
								$legend_x+$pointsize*0.5,$legend_y+$pointsize*0.2,$legend_x+$pointsize*1.5,$legend_y+$pointsize*1.2));
$regionmap->Draw( primitive=>'rectangle',stroke=>'white', fill=>$color{procgen}, strokewidth=>2, points=>sprintf("%u,%u %u,%u",
								$legend_x+$pointsize*0.5,$legend_y+$pointsize*1.7,$legend_x+$pointsize*1.5,$legend_y+$pointsize*2.7));
$regionmap->Draw( primitive=>'rectangle',stroke=>'white', fill=>$color{planetary}, strokewidth=>2, points=>sprintf("%u,%u %u,%u",
								$legend_x+$pointsize*0.5,$legend_y+$pointsize*3.2,$legend_x+$pointsize*1.5,$legend_y+$pointsize*4.2));


show_result($galaxymap->Resize(geometry=>int($save_x).'x'.int($save_y).'+0+0'));

my $f = sprintf("%s/nebulae.jpg",$filepath);
print "Writing to: $f\n";
show_result($galaxymap->Write( filename => $f ));

show_result($galaxymap->Gamma( gamma=>1.2, channel=>"all" ));
show_result($galaxymap->Resize(geometry=>int($thumb_x).'x'.int($thumb_y).'+0+0'));

my $f2 = sprintf("%s/nebulae-thumb.jpg",$filepath);
print "Writing to: $f2\n";
show_result($galaxymap->Write( filename => $f2 ));

my_system("$scp $f $f2 $remote_server/") if (!$debug && $allow_scp);

show_result($regionmap->Resize(geometry=>int($save_x).'x'.int($save_y).'+0+0'));

my $f = sprintf("%s/nebulae-regions.jpg",$filepath);
print "Writing to: $f\n";
show_result($regionmap->Write( filename => $f ));

show_result($regionmap->Gamma( gamma=>1.2, channel=>"all" ));
show_result($regionmap->Resize(geometry=>int($thumb_x).'x'.int($thumb_y).'+0+0'));

my $f2 = sprintf("%s/nebulae-regions-thumb.jpg",$filepath);
print "Writing to: $f2\n";
show_result($regionmap->Write( filename => $f2 ));

my_system("$scp $f $f2 $remote_server/") if (!$debug && $allow_scp);

close SKIP;

my_system("$scp nebulae-skipped.csv $remote_server/") if (!$debug && $allow_scp);
my_system("$scp nebulae-coordinates.csv $remote_server/files/") if (!$debug && $allow_scp);

exit;

############################################################################

sub do_csv {
	my $csv_file	= shift;
	my $type	= shift;
	my $refmatch	= shift;
	my $namematch	= shift;

	open CSV, "<$csv_file";

	my $line = <CSV>;
	my %col  = ();

	my @cols = parse_csv($line);
	for(my $i=0; $i<@cols; $i++) {
		$col{ref}  = $i if ($cols[$i] =~ /$refmatch/i);
		$col{name} = $i if ($cols[$i] =~ /$namematch/i);
	}

	print "READ: $csv_file ($refmatch = $col{ref}, $namematch = $col{name})\n";

	while (<CSV>) {
		chomp;
		my @v = fix_trim(parse_csv($_));
		my $ref = '';
		my $name = '';
		$ref = $v[$col{ref}] if (defined($col{ref}));
		$name = $v[$col{name}] if (defined($col{name}));

		print "UNREADABLE: $_\n" if (!defined($col{ref}) || !$ref);

		if ($nebula{$ref}) {
			print "Duplicate: $ref ($type)\n";
			skip_nebula($ref,$type,'duplicate');
		}

		$nebula{$ref} = $type if ($ref);

		if ($type eq 'planetary') {
			$nebulaname{$ref} = $ref;
			$nebulaname{$ref} .= " ($name)" if ($name);
		} else {
			$nebulaname{$ref} = $name if ($name);
		}
#print join("\t|\t",@v)."\n" if (!$ref);
	}

	close CSV;
}

sub skip_nebula {
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

	if (@rows) {
		my $r = shift @rows;

		my ($x1,$y1) = ( ($$r{coord_x}+$galrad)*$size_x/$galsize , ($galrad+$galcenter_y-$$r{coord_z})*$size_y/$galsize );
		if ($x1<0 || $y1<0 || $x1>$size_x || $y1>$size_y) { $x1 = 0; $y1=0; }

		my ($x2,$y2) = ( ($$r{coord_x}+$galrad)*$size_x/$galsize , $size_y+($edge_height/2)+($$r{coord_y}*$size_y/$galsize) );
		if ($x2<0 || $y2<$size_y || $x2>$size_x || $y2>$size_y+$edge_height) { $x2 = 0; $y2=0; }

		my ($x3,$y3) = ( $size_x+($edge_height/2)+($$r{coord_y}*$size_x/$galsize) , ($galrad+$galcenter_y-$$r{coord_z})*$size_y/$galsize );
		if ($x3<$size_x || $y3<0 || $x3>$size_x+$edge_height || $y3>$size_y) { $x3 = 0; $y3=0; }

		return ( $x1,$y1, $x2,$y2, $x3,$y3, $$r{coord_x},$$r{coord_y},$$r{coord_z} );
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



