#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);

use Image::Magick;
use POSIX qw(floor);
use POSIX ":sys_wait_h";
use Time::HiRes qw(sleep);



############################################################################

my $db	= 'elite';

my $debug		= 0;
my $verbose		= 0;

my $use_forking		= 1;
my $max_children	= 24;
my $fork_verbose	= 0;

$use_forking = 0 if ($debug);

############################################################################

my $amChild   = 0;
my %child      = ();
$SIG{CHLD} = \&REAPER;

print "Reading code map...\n";

my $image = Image::Magick->new;
$image->Read("/home/bones/elite/region-coding.bmp");

print "Looping...\n";

my $count = 0;

foreach my $x (-4500..4500) {
#foreach my $x (3000..4500) { # correction for tenebrae
	foreach my $zRange (-2..6) {

		my $pid = 0;
		my $do_anyway = 0;

		while ($use_forking && int(keys %child) >= $max_children) {
			#sleep 1;
			sleep 0.001;
		}

		my $z = $zRange*1000;

		if ($use_forking) {
			FORK: {
				if ($pid = fork) {
					# Parent here
					$child{$pid}{start} = time;
					info("FORK: Child spawned on PID $pid, for $x, $z\n") if ($fork_verbose);
					next;
				} elsif (defined $pid) {
					# Child here
					$amChild = 1;   # I AM A CHILD!!!
					info("FORK: $$ ready, for $x, $z\n") if ($fork_verbose);
					$0 =~ s/^.*\s+(\S+\.pl)\s+.*$/$1/;
					$0 .= " -- $x, $z";
				} elsif ($! =~ /No more process/) {
					info("FORK: Could not fork a child for $x, $z, retrying in 3 seconds\n");
					sleep 3;
					redo FORK;
				} else {
					info("FORK: Could not fork a child for $x, $z\n");
					$do_anyway = 1;
				}
			}
		} else {
			$do_anyway = 1;
		}


		if ($amChild || $do_anyway) {
			disconnect_all() if ($amChild);

			foreach my $i (0..999) {
				my $r = get_region($x*10,$z*10);
				$r = 0 if (!$r);
		
				if (!$debug) {
					#db_mysql('elite',"insert into regionmap (coord_x,coord_z,region) values ($x,$z,$r) on duplicate key update region=$r");
					#db_mysql('elite',"insert into regionmap (coord_x,coord_z,region) values (?,?,?)",[($x,$z,$r)]);
			
					db_mysql('elite',"insert into regionmap (coord_x,coord_z,region) values (?,?,?) on duplicate key update region=?",[($x,$z,$r,$r)]);
				}
	
				$z++;
			}
		}

		if (!$amChild) {
			$count++;
			print '.' if ($count % 9 == 0);
			print "\n" if ($count % 900 == 0);
		}

		exit 0 if ($amChild);
	}
}
	
############################################################################
	
sub get_region {
	my ($x, $z) = @_;

	my $mapx = floor($x/10+4500);
	my $mapy = floor((25000-$z)/10+4500);
	
	my @pixels = $image->GetPixel(x=>$mapx,y=>$mapy);

	my $color = 0; # black / unknown
	my $region = 0; # unknown

	if (0) {
		$color = 1 if ($pixels[0]<0.5 && $pixels[1]<0.5 && $pixels[2]>0.5); # blue
		$color = 2 if ($pixels[0]<0.5 && $pixels[1]>0.5 && $pixels[2]<0.5); # green
		$color = 3 if ($pixels[0]<0.5 && $pixels[1]>0.5 && $pixels[2]>0.5); # cyan
		$color = 4 if ($pixels[0]>0.5 && $pixels[1]<0.5 && $pixels[2]<0.5); # red
		$color = 5 if ($pixels[0]>0.5 && $pixels[1]<0.5 && $pixels[2]>0.5); # magenta
		$color = 6 if ($pixels[0]>0.5 && $pixels[1]>0.5 && $pixels[2]<0.5); # yellow
		$color = 7 if ($pixels[0]>0.5 && $pixels[1]>0.5 && $pixels[2]>0.5); # white
	} else {

		my $r = $pixels[0] >= 0.5 ? 1 : 0;
		my $g = $pixels[1] >= 0.5 ? 1 : 0;
		my $b = $pixels[2] >= 0.5 ? 1 : 0;

		$color = $r << 2 | $g << 1 | $b;
	}

	#print "$mapx,$mapy [$color]\n" if ($debug);

	return 0 if (!$color);

	if ($color == 1) { # blue
		$region = 37 if ($mapx > 6265 && $mapy > 5768);
		$region = 20 if ($mapx > 6493 && $mapx < 8542 && $mapy > 3759 && $mapy < 5708);
		$region = 22 if ($mapx > 6285 && $mapx < 9000 && $mapy >= 0 && $mapy < 3261);
		$region = 25 if ($mapx > 1980 && $mapx < 3760 && $mapy >= 0 && $mapy < 2516);
		$region = 15 if ($mapx > 2138 && $mapx < 3920 && $mapy > 2645 && $mapy < 4500);
		$region =  3 if ($mapx > 3920 && $mapx < 5400 && $mapy > 2645 && $mapy < 4500);
		$region =  9 if ($mapx > 2940 && $mapx < 4630 && $mapy > 4500 && $mapy < 6400);
		$region = 29 if ($mapx >= 0 && $mapx < 3150 && $mapy > 4970 && $mapy < 9000);
	}

	if ($color == 2) { # green
		$region = 31 if ($mapx > 560 && $mapx < 4500 && $mapy > 7190 && $mapy < 9000);
		$region = 18 if ($mapx > 3300 && $mapx < 5080 && $mapy > 5910 && $mapy < 7190);
		$region =  5 if ($mapx > 3750 && $mapx < 5210 && $mapy > 4900 && $mapy < 5910);
		$region =  1 if ($mapx > 3750 && $mapx < 5210 && $mapy > 3935 && $mapy < 4900);
		$region =  7 if ($mapx > 3040 && $mapx < 5210 && $mapy > 2665 && $mapy < 3935);
		$region = 24 if ($mapx > 3040 && $mapx < 6000 && $mapy > 520 && $mapy < 2665);
	}

	if ($color == 3) { # cyan
		$region = 26 if ($mapx >= 0 && $mapx < 3250 && $mapy >= 0 && $mapy < 3080);
		$region = 23 if ($mapx > 5000 && $mapx < 9000 && $mapy >= 0 && $mapy < 2350);
		$region = 39 if ($mapx > 7600 && $mapx < 9000 && $mapy > 2350 && $mapy < 6360);
		$region =  4 if ($mapx > 3290 && $mapx < 4500 && $mapy > 3520 && $mapy < 5500);
		$region = 32 if ($mapx > 1600 && $mapx < 3200 && $mapy > 5200 && $mapy < 7130);
		$region = 34 if ($mapx > 4160 && $mapx < 6444 && $mapy > 7000 && $mapy < 8150);
	}

	if ($color == 4) { # red
		$region = 41 if ($mapx > 4000 && $mapx < 8000 && $mapy > 7480 && $mapy < 9000);
		$region = 35 if ($mapx > 4000 && $mapx < 8000 && $mapy > 6335 && $mapy < 7480);
		$region = 10 if ($mapx > 4000 && $mapx < 8000 && $mapy > 4335 && $mapy < 6335);
		$region = 12 if ($mapx > 4000 && $mapx < 8000 && $mapy > 1530 && $mapy < 4335);
		$region = 40 if ($mapx > 2600 && $mapx < 6100 && $mapy > 0 && $mapy < 1530);
		$region = 30 if ($mapx > 1500 && $mapx < 2600 && $mapy > 3200 && $mapy < 5500);
	}

	if ($color == 5) { # magenta
		$region = 28 if ($mapx >= 0 && $mapx < 1200 && $mapy > 3520 && $mapy < 6400);
		$region = 14 if ($mapx > 1400 && $mapx < 3500 && $mapy > 1600 && $mapy < 3520);
		$region =  6 if ($mapx > 4600 && $mapx < 6290 && $mapy > 2400 && $mapy < 5600);
		$region = 17 if ($mapx > 2650 && $mapx < 3800 && $mapy > 5500 && $mapy < 6670);
		$region = 36 if ($mapx > 5550 && $mapx < 7700 && $mapy > 6250 && $mapy < 8000);
	}

	if ($color == 6) { # yellow
		$region = 21 if ($mapx > 6600 && $mapx < 8600 && $mapy > 2500 && $mapy < 4800);
		$region = 38 if ($mapx > 6600 && $mapx < 8600 && $mapy > 4800 && $mapy < 7300);
		$region = 13 if ($mapx > 2600 && $mapx < 5100 && $mapy > 1700 && $mapy < 3150);
		$region = 42 if ($mapx >= 0 && $mapx < 1500 && $mapy > 2000 && $mapy < 4050);
		$region = 16 if ($mapx > 2200 && $mapx < 3480 && $mapy > 4000 && $mapy < 6050);
		$region = 33 if ($mapx > 2500 && $mapx < 4700 && $mapy > 6250 && $mapy < 8000);
	}

	if ($color == 7) { # white
		$region = 27 if ($mapx > 450 && $mapx < 2550 && $mapy > 2650 && $mapy < 5500);
		$region =  8 if ($mapx > 2550 && $mapx < 4000 && $mapy > 3350 && $mapy < 5220);
		$region =  2 if ($mapx > 4000 && $mapx < 5600 && $mapy > 3350 && $mapy < 5220);
		$region = 11 if ($mapx > 5800 && $mapx < 7150 && $mapy > 2950 && $mapy < 4700);
		$region = 19 if ($mapx > 4600 && $mapx < 7700 && $mapy > 5000 && $mapy < 6800);
	}

	return $region;
}

sub REAPER {
	while ((my $pid = waitpid(-1, &WNOHANG)) > 0) {
		info("FORK: Child on PID $pid terminated.\n") if ($fork_verbose);
		delete($child{$pid});
	}
	$SIG{CHLD} = \&REAPER;
}

sub info {
        warn @_;
}


############################################################################

