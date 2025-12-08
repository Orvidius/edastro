#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch);

use Image::Magick;

############################################################################

my $debug               = 0;
my $verbose             = 0;
my $allow_scp           = 1;

my $remote_server       = 'www@services:/www/orvidius.com/images/';
my $filepath            = "/home/bones/www/elite";
my $scriptpath          = "/home/bones/elite";

#my $journal_path	= '/DATA/myDocuments/Saved Games/Frontier Developments/Elite Dangerous';
my $journal_path	= '/mnt/EliteDangerousJournals';
my $esc_path		= $journal_path; $esc_path =~ s/ /\\ /gs;

my $scp                 = '/usr/bin/scp -P222';
my $rm                  = '/bin/rm';

my $cmdrID		= 1;
my $cmdrName		= '';

my $galrad              = 45000;
my $galsize             = $galrad*2;
my $size_x		= 4000;
my $size_y		= $size_x;
my $pointsize		= 60;
my $strokewidth		= 3;
my $max_jump		= 15000;	# Lightyears

my $save_x		= 1600;
my $save_y		= $save_x;
my $thumb_x		= 600;
my $thumb_y		= $thumb_x;

############################################################################

my $currentDate = epoch2date(time);

my $refDate = $ARGV[2];

print "Reference date: $refDate\n" if ($refDate);

$cmdrID = $ARGV[0] if ($ARGV[0]);
$cmdrID =~ s/[^\d]+//g;
my @rows = db_mysql('elite',"select name from commanders where ID=$cmdrID");
foreach my $r (@rows) {
	$cmdrName = $$r{name};
}
print "Processing CMDR $cmdrName\n";

my $cmdr_path = "$scriptpath/historydata/$cmdrID";

system('/usr/bin/mkdir','-p',$cmdr_path) if (!-d $cmdr_path);

my $jetcones = 0;
if ($cmdrID==1) {
#	my $jetcone_grep	= "grep '\"event\":\"JetConeBoost\"' $esc_path/Journal.* $esc_path/archive/Journal.* | wc -l |";
#	print "Getting jet cones: $jetcone_grep\n";	open TXT, $jetcone_grep;
#	open TXT, $jetcone_grep;
#	$jetcones = <TXT>;
#	chomp $jetcones;
#	close TXT;
#	$jetcones += 0;

	print "Jet Cones...\n";

	my %jetcone = ();
	my $jpath = "$scriptpath/jetcone-cache";

	opendir DIR, $jpath;
	while (my $fn = readdir DIR) {
		if ($fn =~ /^jetcone-$cmdrID-(.+)$/) {
			open TXT, "<$jpath/$fn";
			$jetcone{$1} = <TXT>;
			chomp $jetcone{$1};
			$jetcone{$1}+=0;
			close TXT;
		}
	}
	closedir DIR;

	foreach my $jpath ($journal_path, "$journal_path/archive") {
		opendir DIR, $jpath;
		while (my $fn = readdir DIR) {
			if ($fn =~ /^Journal\./) {
				next if (defined($jetcone{$fn}));

				open TXT, "<$jpath/$fn";
				my @lines = <TXT>;
				close TXT;

				my $count = 0;
				my $cmdrFound = 0;
				foreach my $line (@lines) {
					$cmdrFound=1 if ($line =~ /"event"\s*:\s*"LoadGame"/ && $line =~ /"Commander"\s*:\s*"$cmdrName"/);
					$count++ if ($line =~ /"event"\s*:\s*"JetConeBoost"/);
				}

				if ($cmdrFound && $count) {
					$jetcone{$fn} = $count;
					open OUT, ">$scriptpath/jetcone-cache/jetcone-$cmdrID-$fn";
					print OUT "$count\n";
					close OUT;
				} else {
					open OUT, ">$scriptpath/jetcone-cache/jetcone-$cmdrID-$fn";
					print OUT "0\n";
					close OUT;
				}
			}
		}
	}

	foreach my $fn (keys %jetcone) {
		$jetcones += $jetcone{$fn};
	}
}
print "JET CONES: $jetcones\n";
#$jetcones = int($jetcones/100)*100;


print "Pulling logs.\n";
my @rows = db_mysql('elite',"select name,date,coord_x,coord_z,firstDiscover from logs,systems where cmdrID=$cmdrID and (logs.systemId=systems.edsm_id or logs.systemId64=id64) order by date");
print int(@rows)." log entries pulled.\n";

exit if (@rows < 1);

my $last_row = $rows[int(@rows)-1];
my $new_loc = $$last_row{name};
my $jumps = int(@rows);

print "Current location: $new_loc\n";

my $cmdr_loc = "$cmdr_path/cmdr-loc.txt";

open TXT, "<$cmdr_loc";
my $prev_loc = <TXT>; chomp $prev_loc;
my $prev_jumps = <TXT>; chomp $prev_jumps; $prev_jumps = int($prev_jumps);
close TXT;

if (!$ARGV[1] && uc($prev_loc) eq uc($new_loc) && $jumps == $prev_jumps) {
	print "Hasn't moved.\n";
	exit;
}

print "Creating canvas.\n";
my $galaxymap = Image::Magick->new;

my %discoveries = ();
my %visited = ();
my $distance;
my $totaldistance;
my $jumpdistance;
my $refJumps = 0;
my $last_x = 0;
my $last_y = 0;
my $last_z = 0;

my $mapfile = "$cmdr_path/cmdr-map.bmp";
my $jumpfile = "$cmdr_path/cmdr-jumps.txt";
my $last_jump = 0;

if (-e $mapfile && -e $jumpfile) {
	$galaxymap->Read($mapfile);
	open TXT, "<$jumpfile";
	$last_jump = <TXT>; chomp $last_jump;
	close TXT;
} else {
	#$galaxymap->Read("$scriptpath/images/galaxy-3200px-enhanced.jpg");
	$galaxymap->Read("$scriptpath/images/gamegalaxy-3200px-plain.bmp");
	$galaxymap->Gamma( gamma=>1.9 );
	$galaxymap->Modulate( saturation=>70 );
	$galaxymap->Modulate( brightness=>90 );
	$galaxymap->Quantize(colorspace=>'RGB');
	$galaxymap->Set(depth => 8);
	$galaxymap->Resize(geometry=>int($size_y).'x'.int($size_y).'+0+0') if ($size_x != 3200);
	
	my $logo_size = int($size_y*0.15);
	
	my $compass = Image::Magick->new;
	$compass->Read("$scriptpath/images/thargoid-rose-hydra.bmp");
	$compass->Resize(geometry=>$logo_size.'x'.$logo_size.'+0+0');
	$galaxymap->Composite(image=>$compass, compose=>'over', gravity=>'southeast',x=>$pointsize/2,y=>$pointsize/2);
	
	my $logo = Image::Magick->new;
	$logo->Read("$scriptpath/images/edastro-550px.bmp");
	$logo->Resize(geometry=>$logo_size.'x'.$logo_size.'+0+0');
	$galaxymap->Composite(image=>$logo, compose=>'over', gravity=>'northeast',x=>$pointsize/2,y=>$pointsize/2);
}

my $galrad_y = $galrad-25000;

my $x = 0;
my $y = 0;
my $x2 = 0;
my $y2 = 0;
my $date = '';

my $max_pixels = int($max_jump/($galsize/$size_x))+1;

my $n = 0;


foreach my $r (@rows) {
	$x = int((($$r{coord_x}+$galrad)/$galsize)*$size_y);
	$y = int((($galsize-($$r{coord_z}+$galrad_y))/$galsize)*$size_y);
	$date = $$r{date};

	$discoveries{uc($$r{name})}++ if ($$r{firstDiscover});
	$visited{uc($$r{name})}++;

	my $jump_dist = sqrt(($$r{coord_x}-$last_x)**2 + ($$r{coord_y}-$last_y)**2 + ($$r{coord_z}-$last_z)**2);

	if ($n) {
		my $dist = $jump_dist;
		$dist = int($dist*0.4) if ($dist>300);

		if (date2epoch($date) >= date2epoch($refDate)) {
			$distance += $dist;
			$refJumps++;
		}
		$totaldistance += $dist;
		$jumpdistance += $dist if ($$r{eventtype} eq 'FSDJump');
	}
		
	if ($n >= $last_jump) {
		my @col = (255,255,255);

		print "[$$r{date}] $$r{name}: $$r{coord_x},$$r{coord_z} -> $x,$y\n" if ($verbose);
		print "." if (!$verbose && $n % 50 == 0);
	
		if ($n && abs($x-$x2)<=$max_pixels && abs($y-$y2)<=$max_pixels) {	
			$galaxymap->Draw( primitive=>'line', stroke=>colorFormatted(@col), strokewidth=>$strokewidth, points=>sprintf("%u,%u %u,%u",$x,$y,$x2,$y2));
		} else {
			$galaxymap->SetPixel( x => $x, y => $y, color => float_colors(@col) );
		}
	}
	
	$x2 = $x;
	$y2 = $y;

	$last_x = $$r{coord_x};
	$last_y = $$r{coord_y};
	$last_z = $$r{coord_z};

	$n++;

	print "$date|$$r{name} > $x, $y ($$r{coord_x}, $$r{coord_z})\n" if ($verbose > 1);
}
print "\n";

$last_jump = $n;

print "Writing to: $mapfile\n";
my $res = $galaxymap->Write( filename => $mapfile );
if ($res) {
        warn $res;
}
open TXT, ">$jumpfile";
print TXT "$last_jump\n";
close TXT;

my $distance_estimate = int($totaldistance/1000)*1000;
$totaldistance = sprintf("%.02f",$totaldistance);
$jumpdistance  = sprintf("%.02f",$jumpdistance );

print "Draw location: $x, $y\n";

my $c  = 'rgb(0,180,0)';
$galaxymap->Draw( primitive=>'circle', stroke=>$c, fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$y,$x+$strokewidth*2+2,$y));
my $c  = 'rgb(0,255,0)';
$galaxymap->Draw( primitive=>'circle', stroke=>$c, fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$y,$x+$strokewidth*2,$y));

$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>"CMDR $cmdrName - ".$currentDate, x=>$pointsize*0.5, y=>$pointsize*1.5);
$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>commify($n)." jumps, ".commify(int(keys %visited))." total visited systems.", x=>$pointsize*0.5, y=>$size_y-($pointsize*0.5));
$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>commify(int(keys %discoveries))." systems discovered for EDSM", x=>$pointsize*0.5, y=>$size_y-($pointsize*1.8));
$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>commify(int($distance_estimate))."+ Lightyears", x=>$pointsize*0.5, y=>$size_y-($pointsize*3.1));
$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>commify(int($jetcones))." Jet Cone Boosts", x=>$pointsize*0.5, y=>$size_y-($pointsize*4.4)) if ($jetcones);

$galaxymap->Resize(geometry=>int($save_x).'x'.int($save_y).'+0+0');

my $f = sprintf("%s/travelmap-%s.jpg",$filepath,lc($cmdrName));
print "Writing to: $f\n";
my $res = $galaxymap->Write( filename => $f );
if ($res) {
	warn $res;
}

$galaxymap->Resize(geometry=>int($thumb_x).'x'.int($thumb_y).'+0+0');

my $f2 = sprintf("%s/travelmap-%s-thumb.jpg",$filepath,lc($cmdrName));
print "Writing to: $f2\n";
my $res = $galaxymap->Write( filename => $f2 );
if ($res) {
	warn $res;
}

my_system("$scp $f $f2 $remote_server/") if (!$debug && $allow_scp);

open TXT, ">$cmdr_loc";
print TXT "$new_loc\n";
print TXT "$jumps\n";
close TXT;

print "Jet Cone Bosts: $jetcones+\n";
print "Total distance: ".commify(sprintf("%.02f",$distance))." ($jumps jumps)\n";
print " Jump distance: ".commify(sprintf("%.02f",$jumpdistance))." ($jumps jumps)\n";
print "Total distance since $refDate: ".commify(sprintf("%.02f",$distance))." ($refJumps jumps)\n" if ($refDate);
print commify(int(keys %visited))." unique visited systems\n";

exit;

############################################################################

sub colorFormatted {
        return "rgb(".join(',',@_).")";
}

sub float_colors {
        my $r = shift(@_)/255;
        my $g = shift(@_)/255;
        my $b = shift(@_)/255;
        return [($r,$g,$b)];
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


