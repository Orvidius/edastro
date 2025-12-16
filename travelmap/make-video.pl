#!/usr/bin/perl
use strict;
$|=1;

############################################################################

use lib "/home/bones/perl";
use ATOMS qw(epoch2date date2epoch btrim ltrim rtrim sec2string make_csv);

use Image::Magick;
use File::Path;

############################################################################

my $debug	= 0;
my $verbose	= 0;

my $overwrite	= 1;
my $delete_img	= 0;
my $skip_tiny	= 1;

my $galrad	= 45000;
my $galsize	= $galrad*2;
my $galvert	= 4500;
my $galheight	= $galvert*2;

my $zoomchase	= 45000;
my $zoomrad	= $zoomchase;
my $chasescale	= 2;

my $framespersec= 30;
my $frame_int	= 2;		# Frame interval. How many pixel-jumps to show per actual video frame.
my $frame_intmax= 10;
my $maxframes	= 36000;

my $zoomsize_y	= 840;
my $zoomsize_x	= $zoomsize_y;
my $zoommargin	= 100;

my $size_y	= 1080; #2160;
my $size_x	= $size_y+$zoomsize_x;

my $pointsize	= int($size_y/54);
my $strokewidth	= int($size_y/1080); $strokewidth = 1 if ($strokewidth <= 1);

my $mappath	= '/www/edastro.com/mapcharts';

#my @color_main	= (0,225,0);
#my @color_new	= (255,255,255);
#my @color_old	= (255,255,127);

my @color_streak	= (255,255,255);
my @cmdrColor		= ();
@{$cmdrColor[0]}	= (0,225,0);
@{$cmdrColor[1]}	= (255,0,0);
@{$cmdrColor[2]}	= (255,255,0);
@{$cmdrColor[3]}	= (0,255,255);
@{$cmdrColor[4]}	= (255,0,255);
@{$cmdrColor[5]}	= (100,135,255);
@{$cmdrColor[6]}	= (224,224,224);
my $cmdrMax		= 6;

my $format	= 'jpg';

#my @tz		= (-5,1);
my @tz		= ();

my $scriptpath	= "/www/EDtravelhistory";
my $queuepath	= "$scriptpath/queue";
my $ffmpeg	= '/usr/bin/ffmpeg';
my $mkdir	= '/bin/mkdir';
my $rm		= '/bin/rm';
my $scp		= '/usr/bin/scp';
my $drawnFile	= 'drawn.txt';

############################################################################

info("Started: $0 ".join(' ',@ARGV));

my $vidtype   = 0;
my $showEdges = 0;
my $cmdrCount = 0;
my $cmdrName  = '';
my %cmdrNum   = ();
my %cmdrJumps = ();
my %cmdrShip  = ();
my %cmdrShipName = ();
my %stats     = ();
my $queueID   = '';
my $minPerSec = 15;
my $maxGapFrames = 0;
my $overlayString = '';

$queueID = $ARGV[0];
$queueID =~ s/[^\w\d\-]+//gs;

$frame_int = $ARGV[1] if ($ARGV[1]);
$frame_int = 1 if ($frame_int < 1);
$frame_int = $frame_intmax if ($frame_int > $frame_intmax);

#my $fadescale = log($frame_int)/log($frame_intmax);
#my $fadejumps = int($framespersec*$frame_int);
#if ($frame_int > 2) {
#	$fadejumps = int($fadejumps/($fadescale+1));	# Fadejumps /= 1..2
#}
my $fadejumps = 30;

if (defined($ARGV[2])) {
	$zoomrad = 5000 if ($ARGV[2] == 1);
	$zoomrad = 2500 if ($ARGV[2] == 2);
	$zoomrad = 1000 if ($ARGV[2] == 3);
	$zoomrad = 500  if ($ARGV[2] == 4);
	$zoomrad = 250  if ($ARGV[2] == 5);
	$zoomrad = $zoomchase  if ($ARGV[2] > 5);  # Chase-mode
	$chasescale = 1   if ($ARGV[2] == 6);
	$chasescale = 1.5 if ($ARGV[2] == 7);
	$chasescale = 2   if ($ARGV[2] == 8);
}
if ($zoomrad == $zoomchase) {
	print "Zoom is in chase mode, scale $chasescale.\n";
}

if (!$queueID) {
	error_die("Invalid or missing Video ID");
}

$showEdges = 1 if ($ARGV[3]);
$vidtype   = int($ARGV[4]);
$vidtype = 1 if ($vidtype > 0);
$vidtype = -1 if ($vidtype < 0);

my $make_video = 1;
$make_video = 0 if ($vidtype < 0);

$minPerSec = int($ARGV[5]) if ($ARGV[5]);
$maxGapFrames = int($ARGV[6]) if ($ARGV[6]);
$maxGapFrames = 0 if (!$maxGapFrames);
$overlayString = $ARGV[7] if (length($ARGV[7]));

$overlayString =~ s/[^\w\d\,]//gs;
my %overlays = ();
foreach my $o (split /,+/,$overlayString) {
	$overlays{$o}=1 if (length($o));
}

$minPerSec = 5 if ($minPerSec < 5);
$minPerSec = 1000 if ($minPerSec > 1000);

my $secPerFrame = $minPerSec*2;
$secPerFrame = 10 if ($secPerFrame<10);

$maxGapFrames = -1 if ($maxGapFrames < -1);
$maxGapFrames = 300 if ($maxGapFrames > 300);

print "Zoom Radius: $zoomrad lightyears\n";
print "Pixel-Jumps per frame: $frame_int\n";
print "Frame rate: $framespersec\n";
print "Fade Jumps: $fadejumps\n";
print "Processing: $queueID\n";
print "Show Edges: $showEdges\n";
print "Video Type: $vidtype ($make_video)\n";
print "Min/Sec:    $minPerSec\n";
print "Sec/Frame:  $secPerFrame\n";
print "Gap Frames: $maxGapFrames\n";
print "Overlays:   ".join(',',sort keys %overlays)."\n";

my $workingPath = "$queuepath/$queueID";
my $imagePath   = "$workingPath/images";
my $journalPath = "$workingPath/journals";
$drawnFile = "$workingPath/$drawnFile";

my $limit = '';

if ($debug) {
	$limit = " limit 50";
}

if (!$make_video && !keys(%overlays)) {
	error_die("Nothing to do: No selected video mode or map overlays.");
}

mkpath([$imagePath],0,0770);

my @rows = ();
my @events = ();

#	db_mysql($db,"select name from commanders where ID=?",[($cmdrID)]);
#	
#	if (!@rows) {
#		die "Commander not found.\n";
#	}
#	
#	print "Processing $cmdrName\n";
#	
#	my $name_safe = $cmdrName;
#	$name_safe =~ s/[^\w\d\-\_]//gs;
#	
#	@rows = db_mysql($db,"select name,coord_x,coord_y,coord_z,firstDiscover,date from logs,systems where logs.systemId=systems.edsm_id and logs.cmdrID=? and ".
#				"date<date_sub(NOW(),interval 1 day)order by date $limit",[($cmdrID)]);


if (-e "$workingPath/colorlist.txt") {
	open TXT, "<$workingPath/colorlist.txt";
	while (<TXT>) {
		chomp;
		my ($num, $name) = split /\t/, $_, 2;
		$num = int(btrim($num));
		$name = btrim($name);
		$cmdrNum{$name} = $num if ($name && $num =~ /\d+/);
		$cmdrCount = $num+1 if ($num+1 > $cmdrCount);
	}
	close TXT;
}


opendir DIR, $journalPath;
while (my $fn = readdir DIR) {
	if ($fn =~ /\.log$/ && $fn !~ /^\./) {

		# Get a CMDR name right away.
		

		$cmdrName = '';
		my $foundJump = 0;

		open TXT, "<$journalPath/$fn";
		while (my $data = <TXT>) {
			if ($data =~ /"+event"+\s*:\s*"+LoadGame"+/) {
				if ($data =~ /"+Commander"+\s*:\s*"+([^"]+)"+/) {
					$cmdrName = btrim($1);
					#print "Commander: $cmdrName\n" if ($verbose || $debug);

					if ($data =~ /"+Ship"+\s*:\s*"+([^"]+)"+/) {
						$cmdrShip{$cmdrName} = get_ship($1,$cmdrShip{$cmdrName});
					}
				}
			}

			if ($data =~ /"+event"+\s*:\s*"+(FSDJump|CarrierJump)"+/) {
				$foundJump = 1;
			}

			last if ($cmdrName && $foundJump);
		}
		close TXT;

		if ($cmdrNum{$cmdrName} < 0) {
			# User requested to skip this commander
			print "\tskipped $fn, commander name skip.\n" if ($verbose);
			next;
		}

		if (!$foundJump) {
			# Probably a tutorial
			print "\tskipped $fn, no jumps.\n" if ($verbose);
			next;
		}

		open TXT, "<$journalPath/$fn";
		my $string = '';

		while (my $data = <TXT>) {
			chomp $data;

			next if ($data =~ /^\s*$/); # contains nothing

			if ($string) {
				$string .= btrim($data);
				if ($data =~ /^\}\"*\s*$/) {
					process_line($string,$fn);
					$string = '';
				}
			} elsif ($data =~ /^\"*\{.+\}\"*\s*$/) {
				process_line($data,$fn);
			} else {
				$string .= btrim($data);
			}
		}
		close TXT;
	}
}
closedir DIR;

sub process_line {
	my $line = shift;
	my $file = shift;

	my %dummy = ();
	my $r = \%dummy;

	#print "< $line\n" if ($line =~ /Commander/i);
	
	if ($line =~ /"+event"+\s*:\s*"+LoadGame"+/) {
		if ($line =~ /"+Commander"+\s*:\s*"+([^"]+)"+/) {
			$cmdrName = btrim($1);

			if ($line =~ /"+Ship"+\s*:\s*"+([^"]+)"+/) {
				$cmdrShip{$cmdrName} = get_ship($1,$cmdrShip{$cmdrName});

				if ($line =~ /"+ShipName"+\s*:\s*"+([^"]+)"+/) {
					$cmdrShipName{$cmdrName} =  btrim($1);
	
					if ($line =~ /"+ShipIdent"+\s*:\s*"+([^"]+)"+/) {
						$cmdrShipName{$cmdrName} .= " ($1)";
					}
				}
			}
		}

	} elsif ($line =~ /"+event"+\s*:\s*"+Embark"+/) {
		if ($line =~ /"+Taxi"+\s*:\s*true/) {
			$cmdrShipName{$cmdrName} = '';
			$cmdrShip{$cmdrName} = get_ship('adder_taxi');
		}
	} elsif ($line =~ /"+event"+\s*:\s*"+ShipyardSwap"+/) {

		if ($cmdrName && $line =~ /"+ShipType"+\s*:\s*"+([^"]+)"+/) {
			$cmdrShip{$cmdrName} = get_ship($1,$cmdrShip{$cmdrName});
			$cmdrShipName{$cmdrName} = '';
		}

	} elsif ($line =~ /"+event"+\s*:\s*"+Loadout"+/) {
		if ($line =~ /"+Ship"+\s*:\s*"+([^"]+)"+/) {
			$cmdrShip{$cmdrName} = get_ship($1,$cmdrShip{$cmdrName});

			if ($line =~ /"+ShipName"+\s*:\s*"+([^"]+)"+/) {
				$cmdrShipName{$cmdrName} = btrim($1);
	
				if ($line =~ /"+ShipIdent"+\s*:\s*"+([^"]+)"+/) {
					$cmdrShipName{$cmdrName} .= " ($1)";
				}
			}
		}

	} elsif ($line =~ /"+event"+\s*:\s*"+(FSDJump|Location|CarrierJump)"+/) {
		$$r{event} = $1;

		my $docked = 0;
		if ($line =~ /"+Docked"+\s*:\s*true/) {
			$docked = 1;
		}

		$$r{cmdr}  = $cmdrName if ($cmdrName);
		$$r{ship}  = $cmdrShip{$cmdrName} if ($cmdrShip{$cmdrName});
		$$r{shipName}  = $cmdrShipName{$cmdrName} if ($cmdrShipName{$cmdrName});

		if ($cmdrName && !defined($cmdrNum{$cmdrName})) {
			$cmdrNum{$cmdrName} = $cmdrCount;
			$cmdrCount++;
			$cmdrCount = $cmdrMax if ($cmdrCount>$cmdrMax);
		}

		if ($line =~ /"+timestamp"+\s*:\s*"+([\w\d\:\-\s]+)"+/) {
			$$r{date} = $1;
			$$r{date} =~ s/[^\d\s\:\-]/ /gs;
			$$r{date} = btrim($$r{date});
		}
		if ($line =~ /"+StarSystem"+\s*:\s*"+([^"]+)"+/) {
			$$r{name} = btrim($1);
		}
		if ($line =~ /"+StarPos"+\s*:\s*\[\s*([\d\.\-]+)\s*,\s*([\d\.\-]+)\s*,\s*([\d\.\-]+)\s*\]/) {
			$$r{coord_x} = $1;
			$$r{coord_y} = $2;
			$$r{coord_z} = $3;
		}


		$$r{f} = $file;

		#print "LOG: $cmdrName $$r{date}: $$r{coord_x}, $$r{coord_y}, $$r{coord_z} ($$r{name})\n";
		if ($$r{event} ne 'CarrierJump' || $docked == 1) {
			push @events, $r;
		}
	}
}

open TXT, ">$workingPath/commanders.txt";
foreach my $c (keys %cmdrNum) {
	print TXT "$c\n";
}
close TXT;

@events = sort { $$a{date} cmp $$b{date} } @events;

my %loc = ();
#my ($x,$y,$z) = (0,0,0);

while (@events) {
	my $r = shift @events;
	my $c = $$r{cmdr};

	$$r{timebucket} = int(date2epoch($$r{date})/$secPerFrame);

	if (!defined($loc{$c}{x}) && !defined($loc{$c}{y}) && !defined($loc{$c}{z})) {
		$loc{$c}{x} = $$r{coord_x};
		$loc{$c}{y} = $$r{coord_y};
		$loc{$c}{z} = $$r{coord_z};
		$loc{$c}{src} = $$r{name};
	}

	if ($$r{event} eq 'FSDJump' || $$r{event} eq 'CarrierJump') {
		my $jumpdist = ( ($$r{coord_x}-$loc{$c}{x})**2 + ($$r{coord_y}-$loc{$c}{y})**2 + ($$r{coord_z}-$loc{$c}{z})**2) ** 0.5;

		$$r{died} = 1 if ($jumpdist > 350 && $$r{event} eq 'FSDJump');		# Had to have been a teleport/spawn event that we missed.
		$$r{died} = 1 if ($jumpdist > 510 && $$r{event} eq 'CarrierJump');	# Had to have been a teleport/spawn event that we missed.
		print "Died(jump). $jumpdist\n" if ($$r{died} && ($debug || $verbose));

		$$r{from_x} = $loc{$c}{x};
		$$r{from_y} = $loc{$c}{y};
		$$r{from_z} = $loc{$c}{z};
		$$r{from_name} = $loc{$c}{src};
		$$r{distance} = $jumpdist;

		if (!$$r{died}) {
			$stats{$$r{cmdr}}{all}{jumps}++;
			$stats{$$r{cmdr}}{all}{ly}+=$jumpdist;
			$stats{$$r{cmdr}}{$$r{ship}}{jumps}++;
			$stats{$$r{cmdr}}{$$r{ship}}{ly}+=$jumpdist;
		}

		push @rows, $r;
		($loc{$c}{x},$loc{$c}{y},$loc{$c}{z}) = ($$r{coord_x},$$r{coord_y},$$r{coord_z});
	} else {
		my ($dx,$dy,$dz) = ($$r{coord_x}-$loc{$c}{x},$$r{coord_y}-$loc{$c}{y},$$r{coord_z}-$loc{$c}{z});
		my $jumpdist = ( ($$r{coord_x}-$loc{$c}{x})**2 + ($$r{coord_y}-$loc{$c}{y})**2 + ($$r{coord_z}-$loc{$c}{z})**2) ** 0.5;

		$$r{from_x} = $loc{$c}{x};
		$$r{from_y} = $loc{$c}{y};
		$$r{from_z} = $loc{$c}{z};
		$$r{from_name} = $loc{$c}{src};
		$$r{distance} = $jumpdist;

		if ($dx < -1 || $dx > 1 || $dy < -1 || $dy > 1 || $dz < -1 || $dz > 1) {
			# Teleported, died, etc
			$$r{died} = 1;
			print "Died(loc). $jumpdist\n" if ($$r{died} && ($debug || $verbose));
			push @rows, $r;
			($loc{$c}{x},$loc{$c}{y},$loc{$c}{z}) = ($$r{coord_x},$$r{coord_y},$$r{coord_z});
		}
	}
}

open TXT, ">$workingPath/stats.csv";
print TXT make_csv('Commander','Ship','Jumps','Lightyears')."\r\n";
foreach my $c (sort keys %stats) {
	next if (!$c);
	print TXT make_csv($c,'All',$stats{$c}{all}{jumps},$stats{$c}{all}{ly})."\r\n";
	foreach my $s (sort keys %{$stats{$c}}) {
		next if (!$s || $s eq 'all');
		print TXT make_csv($c,$s,$stats{$c}{$s}{jumps},$stats{$c}{$s}{ly})."\r\n";
	}
}
close TXT;


print int(@rows)." log entries pulled.\n";

if (@rows<10) {
	error_die("Not enough log entries.");
}

if ($vidtype==1 && $maxGapFrames<0) {
	my $timespan = date2epoch(${$rows[int(@rows)-1]}{date})-date2epoch(${$rows[0]}{date});

	print "History Time-Span: ".sec2string($timespan)." ($timespan seconds)\n";

	my $totalframes = $timespan/$secPerFrame;
	if ($totalframes != int($totalframes)) {
		$totalframes = int($totalframes)+1;
	}
	my $videoLength = $totalframes/$framespersec;

	if ($totalframes > $maxframes) {
		error_die("Video length too long for Realistic timing. Projected length: ".sec2string($videoLength)." ($totalframes frames)");
	} else {
		print "Projected length: ".sec2string($videoLength)." ($totalframes frames)\n";
	}
}

print "Making image canvases.\n";

my $zoomimagesize	= undef;
my $galaxymap		= undef;
my $image		= undef;
my $image2		= undef;
my $overlayImage	= undef;
my $overlayImage2	= undef;
my $overlayImage3	= undef;
my $overlayWhite	= undef;
my $logo_img		= undef;
my $compass		= undef;
$SIG{TERM} = $SIG{'INT'} = sub { cleanup(); exit; };

if (keys(%overlays)) {
	$overlayImage = Image::Magick->new( size  => '9000x9000', type  => 'TrueColor', depth => 8, verbose => 'false');
	$overlayImage->ReadImage('canvas:black');
	$overlayWhite = Image::Magick->new( size  => '9000x9000', type  => 'TrueColor', depth => 8, verbose => 'false');
	$overlayWhite->ReadImage('canvas:grey90');
}

if ($make_video) {
	$galaxymap = Image::Magick->new;
	$galaxymap->Read("$scriptpath/galaxy-2k-plain.png") if ($size_y == 2160);
	$galaxymap->Read("$scriptpath/galaxy-1k-plain.png") if ($size_y == 1080);
	#$galaxymap->Resize(width=>$size_y,height=>$size_y);

	$zoomimagesize = $zoomsize_x.'x'.$zoomsize_y;
	$zoomimagesize = '9000x9000' if ($zoomrad == $zoomchase);

	$image2 = Image::Magick->new(size=>$zoomimagesize, type  => 'TrueColor', depth => 8, verbose => 'false');
	$image2->Read("$scriptpath/galaxy-zoom-10kly.png") if ($zoomrad == 5000);
	$image2->Read("$scriptpath/galaxy-zoom-5kly.png") if ($zoomrad == 2500);
	$image2->Read("$scriptpath/galaxy-zoom-2kly.png") if ($zoomrad == 1000);
	$image2->Read("$scriptpath/galaxy-zoom-1kly.png") if ($zoomrad == 500);
	$image2->Read("$scriptpath/galaxy-zoom-500ly.png") if ($zoomrad == 250);
	$image2->Read("$scriptpath/galaxy-9k-plain.jpg") if ($zoomrad == $zoomchase);
	$image2->Resize(width=>$zoomsize_x,height=>$zoomsize_y) if ($zoomrad != $zoomchase);
	if ($zoomrad == $zoomchase && $chasescale != 1) {
		my $zoomedge = 9000*$chasescale;
		$zoomimagesize = $zoomedge.'x'.$zoomedge;
		print "Chase zoom: $zoomrad,$chasescale: $zoomedge\n";
		my $result = $image2->Resize(width=>$zoomedge,height=>$zoomedge);
		print "Resize to $zoomedge x $zoomedge: $result\n";
		#$image2->Set( page=>'0x0+0+0' );
	}
	$image2->Gamma( gamma=>0.9, channel=>"all" );
	$image2->Modulate( brightness=>60 );
	$image2->Set(quality=>95);

	$image = Image::Magick->new( size  => $size_x.'x'.$size_y, type  => 'TrueColor', depth => 8, verbose => 'false');
	$image->ReadImage('canvas:black');

	if ($showEdges) {
		$galaxymap->Resize(width=>$size_y*0.9, height=>$size_y*0.9);
		$image->Composite(image=>$galaxymap, compose=>'over');
	
		my $edgemap = Image::Magick->new;
		$edgemap->Read("$scriptpath/galaxy-edge-4500px.jpg");
		$edgemap->Modulate( brightness=>50 );
		$edgemap->Gamma( gamma=>0.9, channel=>"all" );
		$edgemap->Resize(width=>$size_y*0.9,height=>$size_y*0.1);
		$image->Composite(image=>$edgemap, y=>$size_y*0.9, compose=>'over');
		$edgemap->Rotate(degrees=>90);
		$image->Composite(image=>$edgemap, x=>$size_y*0.9, compose=>'over');
	} else {
		$image->Composite(image=>$galaxymap, compose=>'over');
	}

	$logo_img = Image::Magick->new;
	$logo_img->Read("$scriptpath/edastro-550px.png");
	$logo_img->Resize(width=>$size_y*0.1, height=>$size_y*0.1);
	$image->Composite(image=>$logo_img, x=>$size_y*0.9, y=>$size_y*0.9, compose=>'over');
	$logo_img = undef;

	$image->Quantize(colorspace=>'RGB');
	$image->Set(depth => 8);
	$image->Gamma( gamma=>0.9, channel=>"all" );
	$image->Modulate( brightness=>60 );
	$image->Set(quality=>90);
	$image->Draw( primitive=>'rectangle', stroke=>'rgb(0,0,0)', fill=>'rgb(0,0,0)', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$size_y,0,$size_x,$size_y));
	#$image->Composite(image=>$image2, compose=>'over', x=>$size_x, y=>int($size_x/2));
	$image->Composite(image=>$image2, compose=>'over', gravity=>'southeast') if ($zoomrad != $zoomchase);
	$image->Flatten();

}

system("$rm -f $imagePath/*jpg") if ($overwrite);

my $img_count = 0;
my $j = 1;
my $n = 0;

my $r = shift @rows;

my @lines  = ();
my @jumps  = ();

my ($x,$y, $x2,$y2, $x3,$y3, $x4,$y4) = image_coords($r);
my $portalx = $x2;
my $portaly = $y2;

my $lineBucket = 0;

for (my $i=0; $i<$fadejumps; $i++) {

	add_line(1,$x,$y,$x,$y,0,0,0,0);
	add_line(2,$x2,$y2,$x2,$y2,0,0,0,0);
	add_line(3,$x3,$y3,$x3,$y3,0,0,0,0);
	add_line(4,$x4,$y4,$x4,$y4,0,0,0,0);
	$lineBucket++; # Only place this is ever incremented. Afterward it will always point to the end of the queue.
}
$lineBucket = $fadejumps; # Last change for this variable, setting it back to the same bucket as the last loop above.

sub add_line {
	my ($group,$x1,$y1,$x2,$y2,$r,$g,$b,$died) = @_;

	# $lineBucket always points to the last bucket in the queue for each group:

	if (ref($lines[$group][$lineBucket]) ne 'ARRAY') {
		@{$lines[$group][$lineBucket]} = ();
	}

	my $i = int(@{$lines[$group][$lineBucket]});
	@{$lines[$group][$lineBucket][$i]} = ($x1,$y1,$r,$g,$b,$x2,$y2,$died);
}

sub dump_lines {
	# This shifts off the first bucket from each group. New lines will be added to the newly non-existent final bucket, pointed to by $lineBucket

	foreach my $group (1..4) {
		shift @{$lines[$group]}; # Dump the first "lineBucket", not specific lines in it.
	}
}

sub calc_coords {
	my ($mapx, $mapy, $mapz) = @_;
	my ($x,$y, $x2,$y2, $x3,$y3, $x4,$y4) = (0,0, 0,0, 0,0, 0,0);

	if ($showEdges) {
		$x = int((($mapx+$galrad)/$galsize)*$size_y*0.9);
		$y = int((($galsize-($mapz+$galrad-25000))/$galsize)*$size_y*0.9);

		# Bottom edge
		$x3 = $x;
		$y3 = int((($galvert-$mapy)/$galheight)*$size_y*0.1)+int($size_y*0.9);

		# Right edge
		$x4 = int((($galvert-$mapy)/$galheight)*$size_y*0.1)+int($size_y*0.9);
		$y4 = $y;
	} else {
		$x = int((($mapx+$galrad)/$galsize)*$size_y);
		$y = int((($galsize-($mapz+$galrad-25000))/$galsize)*$size_y);
	}

	if ($zoomrad == $zoomchase) {
		$x2 = int((($mapx+$galrad)/$galsize)*9000*$chasescale);
		$y2 = int((($galsize-($mapz+$galrad-25000))/$galsize)*9000*$chasescale);
		#print "CALC: $x2,$y2\n";
	} else {
		$x2 = int(($mapx/$zoomrad)*$zoomsize_x/2+$zoomsize_x/2);
		$y2 = int((0-$mapz/$zoomrad)*$zoomsize_y/2+$zoomsize_y/2);
	}

	my $overlay_x = int((($mapx+$galrad)/$galsize)*9000);
	my $overlay_y = int((($galsize-($mapz+$galrad-25000))/$galsize)*9000);

	return ($x,$y, $x2,$y2, $x3,$y3, $x4,$y4, $overlay_x,$overlay_y);
}

sub image_coords {
	my $r = shift;
	
	my ($x,$y, $x2,$y2, $x3,$y3, $x4,$y4, $overlay_x,$overlay_y) = calc_coords($$r{coord_x},$$r{coord_y},$$r{coord_z});
	my ($prevx,$prevy, $prevx2,$prevy2, $prevx3,$prevy3, $prevx4,$prevy4, $overlay_prevx,$overlay_prevy) = calc_coords($$r{from_x},$$r{from_y},$$r{from_z});

	my $inrange = 0;
	$inrange = 1 if ($zoomrad==$zoomchase || ($x2 > 0-$zoomsize_x*0.1 && $x2 < $zoomsize_x*1.1 && $y2 > 0-$zoomsize_y*0.1 && $y2 < $zoomsize_y*1.1));

	return ($x,$y, $x2,$y2, $x3,$y3, $x4,$y4, $inrange, $prevx,$prevy, $prevx2,$prevy2, $prevx3,$prevy3, $prevx4,$prevy4, $overlay_x,$overlay_y, $overlay_prevx,$overlay_prevy);
}
sub colorFormatted {
	return "rgb(".join(',',@_).")";
}
sub scaledColor {
	my ($r,$g,$b,$scale) = @_;

	$r = int(($color_streak[0]-$r)*$scale+$r);
	$g = int(($color_streak[1]-$g)*$scale+$g);
	$b = int(($color_streak[2]-$b)*$scale+$b);

	return colorFormatted($r,$g,$b);
}

my $countdown = $fadejumps;

my $r = undef;

if (!@rows) {
	error_die('No log entries found.');
}


print "Looping.\n";

$cmdrName = '';
my $startCount = int(@rows)+$fadejumps;
my $startEpoch = time;


for (my $i=0; $i<=$cmdrMax; $i++) {
	my $c = "rgb(".join(',',@{$cmdrColor[$i]}).")";
	my $cmdr_y = ($i+2)*$pointsize*1.2-int($pointsize*0.8)-1;
	$image->Draw( primitive=>'circle', stroke=>$c, fill=>$c, strokewidth=>1, 
		points=>sprintf("%u,%u %u,%u",$size_y+$pointsize,$cmdr_y,$size_y+$pointsize+$pointsize/6,$cmdr_y)) if ($make_video);
}

my $currentTimeBucket = ${$rows[0]}{timebucket};

my $jumpsThisFrame = 0;

while (@rows || $countdown) {

	if (@rows) {
		$r = shift @rows;
	} else {
		$countdown--;
	}

	my $ok = 0;
	$j++;

	my ($x,$y, $x2,$y2, $x3,$y3, $x4,$y4, $inrange, $prevx,$prevy, $prevx2,$prevy2, $prevx3,$prevy3, $prevx4,$prevy4, 
		$overlay_x,$overlay_y, $overlay_prevx,$overlay_prevy) = image_coords($r);

	$jumpsThisFrame++;

	$jumps[$framespersec-1]++;

	$cmdrJumps{$$r{cmdr}}++;
	
	if (!$skip_tiny || ($x != $prevx || $y != $prevy) || ($showEdges && ($x4 != $prevx4 || $y3 != $prevy3)) || ($inrange && ($x2 != $prevx2 || $y2 != $prevy2)) || 
		!@rows || (keys(%overlays) && ($overlay_x != $overlay_prevx || $overlay_y != $overlay_prevy))) {

		my $date = $$r{date};
		$date = epoch2date(date2epoch($$r{date}),@tz) if (@tz);
		$date =~ s/\s+.+//;
		my $date1 = $date;

		if ($date =~ /^(\d{4})/) {
			my $year = $1 + 1286;
			$date =~ s/^\d{4}/$year/;
		}

		$date = "$date / $date1";

		my $locX = sprintf("%.02f",$$r{coord_x});
		my $locY = sprintf("%.02f",$$r{coord_y});
		my $locZ = sprintf("%.02f",$$r{coord_z});

		#my @colors = @color_old;
		#@colors = @color_new if ($$r{firstDiscover});
		#@colors = @color_main if (!$countdown);
		
		my $cmdrNumber = $cmdrNum{$$r{cmdr}};
		$cmdrNumber = $cmdrMax if (!defined($cmdrNumber) || $cmdrNumber<0 || $cmdrNumber>$cmdrMax);

		print "Commander: \"$$r{cmdr}\" = $cmdrNumber ($x,$y)\n" if ($debug || $verbose);
		output_event($r) if (!$$r{cmdr});

		my @colors = @{$cmdrColor[$cmdrNumber]};

		add_line(1,$x ,$y ,$prevx ,$prevy ,$colors[0],$colors[1],$colors[2],$$r{died});
		add_line(2,$x2,$y2,$prevx2,$prevy2,$colors[0],$colors[1],$colors[2],$$r{died});
		add_line(3,$x3,$y3,$prevx3,$prevy3,$colors[0],$colors[1],$colors[2],$$r{died});
		add_line(4,$x4,$y4,$prevx4,$prevy4,$colors[0],$colors[1],$colors[2],$$r{died});

		$image2->Border(width=>$zoommargin, height=>$zoommargin, color=>'rgb(0,0,0)') if ($make_video && $zoomrad != $zoomchase);

		if (!$$r{died}) {
			my $color = colorFormatted(255,255,255);
			draw_line(0,$image,$color,$x,$y,$prevx,$prevy);
			draw_line(1,$image2,$color,$x2,$y2,$prevx2,$prevy2);

			if ($showEdges) {
			draw_line(0,$image,$color,$x3,$y3,$prevx3,$prevy3);
			draw_line(0,$image,$color,$x4,$y4,$prevx4,$prevy4);
			}
	
			draw_line(0,$overlayImage,$color,$overlay_x,$overlay_y,$overlay_prevx,$overlay_prevy,1,1) if (keys(%overlays));
			
			#print "LINE: $overlay_x,$overlay_y - $overlay_prevx,$overlay_prevy\n";
			#print "LINE: $x2,$y2 - $prevx2,$prevy2\n";
		}

		$image2->Shave(width=>$zoommargin,height=>$zoommargin) if ($make_video && $zoomrad != $zoomchase);

		$cmdrName = $$r{cmdr};
		my $cmdr_y = ($cmdrNumber+2)*$pointsize*1.2-int($pointsize/2);

		if ($make_video && $cmdrName) {
			$image->Draw( primitive=>'rectangle', stroke=>'rgb(0,0,0)', fill=>'rgb(0,0,0)', strokewidth=>1, 
				points=>sprintf("%u,%u %u,%u",$size_y+$pointsize*1.5,$cmdr_y-$pointsize*1.1,$size_x,$cmdr_y+3));

			my $string = "CMDR $cmdrName:  Jump # ".commify($cmdrJumps{$cmdrName})." ($date)";
			$string .= ' '.$$r{ship} if ($$r{ship});

			$image->Annotate(pointsize=>$pointsize,fill=>colorFormatted(@colors),text=>$string, x=>$size_y+$pointsize*1.5+1, y=>$cmdr_y);
		}

		if ($make_video) {
			$image->Draw( primitive=>'rectangle', stroke=>'rgb(0,0,0)', fill=>'rgb(0,0,0)', strokewidth=>1, 
					points=>sprintf("%u,%u %u,%u",$size_y,$pointsize*9.8,$size_x,$size_y-$zoomsize_y));

			$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>"$locX, $locY, $locZ", x=>$size_y+$pointsize*12.5, y=>$pointsize*11);
			$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>$$r{name}, x=>$size_y+$pointsize*28, y=>$pointsize*11);
		}
	
#print "$n\n";

		my $drawFrames = 0;
		my $nextTimeBucket = $currentTimeBucket;

		if (!$vidtype) {

			$drawFrames = 1 if ($frame_int <= 1 || $n % $frame_int == 0);	# Normal jump-based video

		} elsif ($make_video) {

			if (!@rows) {
				$drawFrames = 1;
			} else {
				$nextTimeBucket = ${$rows[0]}{timebucket};

				if ($nextTimeBucket != $currentTimeBucket) {
					my $needed_frames = abs($nextTimeBucket-$currentTimeBucket);
					$needed_frames = $maxGapFrames if ($maxGapFrames>0 && $needed_frames > $maxGapFrames);

					if ($maxGapFrames<0) {
						$drawFrames = $needed_frames;
					} elsif ($maxGapFrames>0) {
						$drawFrames = $needed_frames;
					} else {
						$drawFrames = 1;
					}
				}
			}
		} else {
			# Not making video

			$drawFrames = 0;
			print '.' if ($n % 100 == 0);
		}

		

		my $displayedTimeBucket = $currentTimeBucket;
		$currentTimeBucket = $nextTimeBucket if ($drawFrames);

		for (my $frame_counter=0; $frame_counter<$drawFrames; $frame_counter++) {

			my $jumpcount = 0;
			for (my $i=0; $i<$framespersec; $i++) {
				$jumps[$i] = 0 if (!$jumps[$i]);
				$jumpcount += $jumps[$i] if ($jumps[$i]);
			}
			my $jps = commify($jumpcount);

			if ($vidtype == 1) {
				my $displayTime = epoch2date($displayedTimeBucket*$secPerFrame);
				#$displayTime =~ s/^\d+\-//;
				$displayedTimeBucket++;

				$image->Draw( primitive=>'rectangle', stroke=>'rgb(0,0,0)', fill=>'rgb(0,0,0)', strokewidth=>1, 
						points=>sprintf("%u,%u %u,%u",$size_y,$pointsize*9.8,$size_y+$pointsize*12.5-1,$size_y-$zoomsize_y));

				$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>$displayTime, x=>$size_y+$pointsize, y=>$pointsize*11);
			} else {
				$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>"Jumps/sec: $jps", x=>$size_y+$pointsize, y=>$pointsize*11);
			}

			for (my $i=0; $i<$fadejumps; $i++) {
				my $groups = 2;
				$groups = 4 if ($showEdges);
	
				foreach my $group (1..$groups) {
					next if (ref($lines[$group][$i]) ne 'ARRAY');

					my $lineCount = int(@{$lines[$group][$i]});
	
					next if (!$lineCount);
					$lineCount-- if ($lineCount);
	
					foreach my $l (0..$lineCount) {
	
						my @dat   = @{$lines[$group][$i][$l]};
						my $color = scaledColor($dat[2],$dat[3],$dat[4],$i/$fadejumps);
	
						draw_line(0,$image ,$color,$dat[0],$dat[1],$dat[5],$dat[6]) if ($group!=2 && !$dat[7]);
						draw_line(0,$image2,$color,$dat[0],$dat[1],$dat[5],$dat[6]) if ($group==2 && !$dat[7]);
#print "$n $i $group $l\n";
					}
				}
			}

			dump_lines();
			shift @jumps;

			if ($zoomrad == $zoomchase) {

				my $movespeed = 0;
				my $distance = distance2D($portalx,$portaly,$x2,$y2)-15;
				$movespeed = log10($distance)/7 if ($distance > 0);
				$movespeed = 0 if ($movespeed < 0);
				$movespeed = 0.5 if ($movespeed > 0.50);

				$portalx = ($x2-$portalx)*$movespeed+$portalx;
				$portaly = ($y2-$portaly)*$movespeed+$portaly;

				my $px = int($portalx-$zoomsize_x/2);
				my $py = int($portaly-$zoomsize_y/2);

				my $buffer = $image2->Clone();
				#my $location = int($zoomsize_x/2).','.int($zoomsize_y/2);
				#$buffer->Distort(method=>'SRT','virtual-pixel'=>'black',points=>[($px,$py,1.0,1.0,0,$zoomsize_x/2,$zoomsize_y/2)]);

				#print "Buffer size: ".$buffer->Get('width').'x'.$buffer->Get('height')."\n";
				
				my $crop_geometry = $zoomsize_x.'x'.$zoomsize_y."+$px+$py";
				#print "Portal: $portalx,$portaly --  Crop to: $crop_geometry\n";

				$buffer->Set( page=>'0x0+0+0' );
				my $result = $buffer->Crop(geometry=>$crop_geometry);
				warn "$result\n" if "$result";
				$buffer->Set( page=>'0x0+0+0' );
				#print "Crop size: ".$buffer->Get('width').'x'.$buffer->Get('height')."\n";

				$image->Composite(image=>$buffer, compose=>'over', gravity=>'southeast');

				#$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>"Move Speed: ".sprintf("%0.03f",$movespeed), gravity=>'southeast', x=>$pointsize, y=>$pointsize);

			} else {
				$image->Composite(image=>$image2, compose=>'over', gravity=>'southeast');
			}
			$image->Flatten();
	
			$image->Annotate(pointsize=>$pointsize*2/3,fill=>'white',text=>commify($zoomrad*2).' x '.commify($zoomrad*2).' lightyears', 
				x=>$pointsize, y=>$pointsize/2, gravity=>'southeast') if ($zoomrad <= 10000);

			my $f = sprintf("%s/img-%06u.$format",$imagePath,$img_count);
	
			if ($overwrite || !-e $f) {
				print "> $f ($jps,$jumpsThisFrame)\n";
				my $res = $image->Write( filename => $f);
				if ($res) {
					warn $res;
				}
			} else {
				print "Image $f already exists.\n";
			}

			open DRAWN, ">$drawnFile";
			print DRAWN "$img_count\n".int(@rows)."\n$startCount\n";
			close DRAWN;

			$jumpsThisFrame = 0;

			$img_count++;
			last if ($img_count >= $maxframes);
		}

		$n++;
	}
}
print "\n";

exit if ($debug);

my $drawtime = time - $startEpoch;

info("Frames generated: $img_count with $startCount events in $drawtime seconds, for CMDRs: ".join(', ',sort keys %cmdrNum));

$startEpoch = time;

if ($make_video && $n >= 10) {
	my @t = localtime;
	#my $date = sprintf("%04u%02u%02u",$t[5]+1900,$t[4]+1,$t[3]);
	my $fn = "$workingPath/travelhistory.mp4";
	unlink $fn if (-e $fn);

	my $vsize = '';
	#$vsize = '-s 1440x1080' if ($size_y != 1080);
	
	my $fps = $framespersec;

	info("Video encoding: $fn for CMDRs: ".join(', ',sort keys %cmdrNum));

	my $syscall = "$ffmpeg  -framerate $fps -i $imagePath/img-%06d.$format -c:v libx264 -profile:v high -crf 20 -pix_fmt yuv420p $vsize $fn";

	print "$syscall\n";
	system($syscall);

	$drawtime = time - $startEpoch;
	info("Video created as: $fn with $img_count frames and $startCount events in $drawtime seconds, for CMDRs: ".join(', ',sort keys %cmdrNum));

	system("$rm -f $imagePath/*jpg") if ($overwrite && $delete_img);

	open TXT, ">$workingPath/completed.txt";
	print TXT time."\n";
	close TXT;
} elsif ($make_video) {
	error_die("Not enough images to make a video.");
}

if (keys(%overlays)) {
	print "Generating overlay images.\n";

	open TXT, ">$workingPath/processing-overlays.txt";
	print TXT "1\n";
	close TXT;

	my $f = "$workingPath/overlay.png";
	print "> $f\n";
	my $res = $overlayImage->Write( filename => $f);
	if ($res) {
		warn $res;
	}

	$overlayImage2 = $overlayImage->Clone();
	$overlayImage2->Morphology(method=>"Dilate",kernel=>'Octagon:2');
	$overlayImage2->Negate(channel=>"Default");
	$overlayImage3 = $overlayImage2->Clone();
	$overlayImage3->Composite(image=>$overlayWhite, compose=>'Screen', gravity=>'northwest');

	$logo_img = Image::Magick->new;
	$logo_img->Read("$scriptpath/edastro-550px.png");

	$compass = Image::Magick->new;
	$compass->Read("$scriptpath/thargoid-rose-hydra.png");

	if (0) {
		my $f = "$workingPath/overlay-negative.png";
		print "> $f\n";
		my $res = $overlayImage2->Write( filename => $f);
		if ($res) {
			warn $res;
		}
	}

	make_overlay(0,'galaxy-heatmap.png') if ($overlays{'1'});
	make_overlay(0,'visited-systems-heatmap.png') if ($overlays{'2'});
	make_overlay(0,'visited-systems-sectors.png') if ($overlays{'3'});
	make_overlay(0,'visited-systems-regions.png') if ($overlays{'4'});

	delete($overlays{'1'});
	delete($overlays{'2'});
	delete($overlays{'3'});
	delete($overlays{'4'});

	if (keys(%overlays)) {
		
		$overlayImage->Morphology(method=>"Dilate",kernel=>'Octagon:3');
		$overlayImage->Resize(width=>1800,height=>1800);
		$overlayImage2->Morphology(method=>"Dilate",kernel=>'Octagon:3');
		$overlayImage2->Resize(width=>1800,height=>1800);
		$overlayImage3 = $overlayImage2->Clone();
		$overlayImage3->Composite(image=>$overlayWhite, compose=>'Screen', gravity=>'northwest');
		$logo_img->Resize(width=>250, height=>250);
		$compass->Resize(width=>250, height=>250);
	
		make_overlay(1,'galaxy-map.png',1) if ($overlays{'0'});

		make_overlay(1,'neutrons.png') if ($overlays{'5'});
		make_overlay(1,'boostables.png') if ($overlays{'6'});
		make_overlay(1,'oddballs.png') if ($overlays{'7'});
		make_overlay(1,'star-remnants.png') if ($overlays{'8'});
		make_overlay(1,'black-holes.png') if ($overlays{'9'});
	
		make_overlay(1,'massA.png') if ($overlays{'A'});
		make_overlay(1,'massB.png') if ($overlays{'B'});
		make_overlay(1,'massC.png') if ($overlays{'C'});
		make_overlay(1,'massD.png') if ($overlays{'D'});
		make_overlay(1,'massE.png') if ($overlays{'E'});
		make_overlay(1,'massF.png') if ($overlays{'F'});
		make_overlay(1,'massG.png') if ($overlays{'G'});
		make_overlay(1,'massH.png') if ($overlays{'H'});
	}

	system("cd $workingPath ; /usr/bin/zip travelhistory.zip *png *mp4 stats.csv");

	open TXT, ">$workingPath/done-overlays.txt";
	print TXT "1\n";
	close TXT;

	unlink "$workingPath/processing-overlays.txt";
}

cleanup();
exit;

############################################################################

sub make_overlay {
	my $small = shift;
	my $fn = shift;
	my $add_logos = shift;

	my $mapImage = Image::Magick->new;
	$mapImage->Read("$mappath/$fn");
	
	$mapImage->Composite(image=>$overlayImage3, compose=>'Multiply', gravity=>'northwest');
	$mapImage->Composite(image=>$overlayImage, compose=>'Screen', gravity=>'northwest');

	if ($add_logos) {
		$mapImage->Composite(image=>$logo_img, x=>15, y=>15, gravity=>'northwest', compose=>'over');
		$mapImage->Composite(image=>$compass, x=>15, y=>15, gravity=>'southeast', compose=>'over');
	}

	my $size_y = 9000;
	$size_y = 1800 if ($small);

	my $height = $mapImage->Get('height');
	my $pointsize = int($height/60);
	my $y = $size_y-$pointsize;

	foreach my $n (reverse sort keys %cmdrNum) {
		next if ($cmdrNum{$n}<0);
		$mapImage->Annotate(pointsize=>$pointsize,fill=>colorFormatted(255,255,255),text=>"CMDR $n", x=>$pointsize/2, y=>$y);
		$y -= $pointsize * 1.3;
	}
	

	$mapImage->Flatten();

	my $f = "$workingPath/$fn";

	print "> $f\n";
	my $res = $mapImage->Write( filename => $f);
	if ($res) {
		warn $res;
	}
}

############################################################################

sub draw_line {
	my ($check_zoom, $image, $color, $x1, $y1, $x2, $y2, $linewidth, $draw_anyway) = @_;

	return if (!$make_video && !$draw_anyway);

	$linewidth = $strokewidth if (!$linewidth);

	if ($check_zoom && $zoomrad != $zoomchase) {
		if (($x1 < 0-$zoommargin || $y1 < 0-$zoommargin || $x1 >= $zoomsize_x+$zoommargin || $y1 >= $zoomsize_y+$zoommargin) &&
			($x2 < 0-$zoommargin || $y2 < 0-$zoommargin || $x2 >= $zoomsize_x+$zoommargin || $y2 >= $zoomsize_y+$zoommargin)) {

			return; # One or both of the coordinates for BOTH of the ends are out of range.
		}

		$x1 += $zoommargin;
		$x2 += $zoommargin;
		$y1 += $zoommargin;
		$y2 += $zoommargin;
	}

	$image->Draw( primitive=>'line', stroke=>$color, strokewidth=>$linewidth, points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y2));
}

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}

sub html_error {
	open HTML, ">$workingPath/error.html";
	print HTML @_;
	close HTML;
}

sub error_die {
	my $s = shift;

	html_error("$s<p/>\n");
	printinfo($s);
	exit;
}

sub log10 {
        my $n = shift;
        return 0 if (!$n);
        return log($n)/log(10);
}

sub distance2D {
	my ($x1,$y1,$x2,$y2) = @_;

	return (($x1-$x2)**2 + ($y1-$y2)**2) ** 0.5;
}

sub distance3D {
	my ($x1,$y1,$z1,$x2,$y2,$z2) = @_;

	return (($x1-$x2)**2 + ($y1-$y2)**2 + ($z1-$z2)**2) ** 0.5;
}

sub cleanup {
	undef $image;
	undef $image2;
	undef $galaxymap;
}

sub output_event {
	my $r = shift;

	print "---\n";
	foreach my $k (sort keys %$r) {
		print "\t$k = \"$$r{$k}\"\n";
	}
}

sub get_ship {
	my $s = btrim(shift);
	my $old = btrim(shift);

	# Translate the ones that have non-pretty internal IDs.

	$s = 'Caspian Explorer' if (uc($s) eq uc('explorer_nx'));
	$s = 'Mandalay' if (uc($s) eq uc('mandalay'));
	$s = 'Corsair' if (uc($s) eq uc('corsair'));
	$s = 'Panther Clipper Mk2' if (uc($s) eq uc('panthermkii'));
	$s = 'Apex Taxi' if (uc($s) eq uc('adder_taxi'));
	$s = 'Anaconda' if (uc($s) eq uc('anaconda'));
	$s = 'Sidewinder' if (uc($s) eq uc('sidewinder'));
	$s = 'Python' if (uc($s) eq uc('python'));
	$s = 'Eagle' if (uc($s) eq uc('eagle'));
	$s = 'Adder' if (uc($s) eq uc('adder'));
	$s = 'Hauler' if (uc($s) eq uc('hauler'));
	$s = 'Cobra Mk.III' if (uc($s) eq uc('CobraMkIII'));
	$s = 'Cobra Mk.IV' if (uc($s) eq uc('CobraMkIV'));
	$s = 'Cobra Mk.V' if (uc($s) eq uc('CobraMkV'));
	$s = 'Diamondback Explorer' if (uc($s) eq uc('DiamondBackXL'));
	$s = 'Diamondback Scout' if (uc($s) eq uc('diamondback'));
	$s = 'Asp Explorer' if (uc($s) eq uc('Asp'));
	$s = 'Asp Scout' if (uc($s) eq uc('asp_scout'));
	$s = 'Viper Mk.IV' if (uc($s) eq uc('Viper_MkIV'));
	$s = 'Viper Mk.III' if (uc($s) eq uc('Viper'));
	$s = 'Fer de Lance' if (uc($s) eq uc('FerDeLance'));
	#$s = 'Scarab SRV' if (uc($s) eq uc('TestBuggy'));
	$s = 'Imperial Eagle' if (uc($s) eq uc('Empire_Eagle'));
	$s = 'Imperial Courier' if (uc($s) eq uc('Empire_Courier'));
	$s = 'Imperial Clipper' if (uc($s) eq uc('Empire_Trader'));
	$s = 'Imperial Cutter' if (uc($s) eq uc('Cutter'));
	$s = 'Federal Corvette' if (uc($s) eq uc('Federation_Corvette'));
	$s = 'Federal Dropship' if (uc($s) eq uc('Federation_Dropship'));
	$s = 'Federal Assault ship' if (uc($s) eq uc('federation_dropship_mkii'));
	$s = 'Federal Gunship' if (uc($s) eq uc('Federation_Gunship'));
	$s = 'Beluga Liner' if (uc($s) eq uc('BelugaLiner'));
	$s = 'Orca' if (uc($s) eq uc('orca'));
	$s = 'Dolphin' if (uc($s) eq uc('dolphin'));
	$s = 'Alliance Chieftain' if (uc($s) eq uc('TypeX'));
	$s = 'Alliance Challenger' if (uc($s) eq uc('typex_3'));
	$s = 'Alliance Crusader' if (uc($s) eq uc('typex_2'));
	$s = 'Type-6 Transporter' if (uc($s) eq uc('Type6'));
	$s = 'Type-7 Transporter' if (uc($s) eq uc('Type7'));
	$s = 'Type-8 Transporter' if (uc($s) eq uc('Type8'));
	$s = 'Type-9 Heavy' if (uc($s) eq uc('Type9'));
	$s = 'Type-10 Defender' if (uc($s) eq uc('type9_military'));
	$s = 'Type-11 Prospector' if (uc($s) eq uc('lakonminer'));
	$s = 'Keelback' if (uc($s) eq uc('independant_trader'));
	$s = 'Krait Mk.II' if (uc($s) eq uc('krait_mkii'));
	$s = 'Krait Phantom' if (uc($s) eq uc('krait_light'));
	$s = 'Mamba' if (uc($s) eq uc('mamba'));

	$s = $old if ($s =~ /Fighter/i);
	$s = $old if ($s =~ /Suit/i);
	$s = $old if ($s =~ /Buggy/i);

	return $s;
}

############################################################################




