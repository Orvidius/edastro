#!/usr/bin/perl
use strict; $|=1;

#########################################################################

use Image::Magick;
use File::Path;

use lib "/home/bones/perl";
use ATOMS qw(epoch2date date2epoch btrim ltrim rtrim sec2string);

my $debug	= 0;

my $convert	= '/usr/bin/convert';

#########################################################################

foreach my $fn (@ARGV) {
	my $tga = $fn;
	$tga =~ s/\.(jpg|png|bmp)$/\.tga/;

	my $newfile = $fn;
	$newfile =~ s/^(.+)\.(jpg|png|bmp)$/$1-resized\.$2/ if ($debug);

	print "$fn -> $tga\n";
	system("$convert $fn $tga");

	my $image = Image::Magick->new;
	$image->Read($tga);

	my $old = $image->Clone();

	print "\tOld Size: (".$image->Get('width').")\n";

	my $newsize = int($image->Get('width')/2);

	$image->Resize(geometry=>$newsize.'x'.$newsize.'+0+0');
	print "\tNew Size: (".$image->Get('width').")\n";

	my $count = 0;
	my $dots = 0;

	PIXELLOOP: for (my $x=0; $x<$newsize; $x++) {
		for (my $y=0; $y<$newsize; $y++) {

			$count++;
			if ($count >= 10000) {
				print '.';
				$count=0;
				$dots++;
				print "\n" if ($dots % 100 == 0);
			}

			my @pixels = ();
			eval {
			@{$pixels[0]} = $old->GetPixel(x=>$x*2,y=>$y*2);
			@{$pixels[1]} = $old->GetPixel(x=>$x*2+1,y=>$y*2);
			@{$pixels[2]} = $old->GetPixel(x=>$x*2,y=>$y*2+1);
			@{$pixels[3]} = $old->GetPixel(x=>$x*2+1,y=>$y*2+1);
			};

			next if (!$pixels[0][0] && !$pixels[0][1] && !$pixels[0][2] &&
				 !$pixels[1][0] && !$pixels[1][1] && !$pixels[1][2] &&
				 !$pixels[2][0] && !$pixels[2][1] && !$pixels[2][2] &&
				 !$pixels[3][0] && !$pixels[3][1] && !$pixels[3][2]);

			# [4] is overall average, [5] is non-zeroes average

			my $has_grayscale = 0;
			my $divnum = 0;

			for (my $i=0; $i<4; $i++) {
				my ($r, $g, $b) = (int($pixels[$i][0]*255),int($pixels[$i][1]*255),int($pixels[$i][2]*255));

				if ($r==$g and $b==$g and $r>0 and $r<255) {
					$has_grayscale = 1;
				}

				$pixels[4][0] += $pixels[$i][0];
				$pixels[4][1] += $pixels[$i][1];
				$pixels[4][2] += $pixels[$i][2];

				if ($pixels[$i][0] || $pixels[$i][1] || $pixels[$i][2]) {
					$pixels[5][0] += $pixels[$i][0];
					$pixels[5][1] += $pixels[$i][1];
					$pixels[5][2] += $pixels[$i][2];
					$divnum++;

				} else {
					# Commented out, black pixels are ignored:
					#$divnum += 0.10; # Make black pixels worth 1/10 as much.
				}
			}

			my @newpixel = ();

			if ($has_grayscale) {
				$newpixel[0] = $pixels[4][0]/4;
				$newpixel[1] = $pixels[4][1]/4;
				$newpixel[2] = $pixels[4][2]/4;
			} elsif ($divnum) {
				$newpixel[0] = $pixels[5][0]/$divnum;
				$newpixel[1] = $pixels[5][1]/$divnum;
				$newpixel[2] = $pixels[5][2]/$divnum;
			}

			if ($newpixel[0] || $newpixel[1] || $newpixel[2]) {
				$image->SetPixel(x=>$x,y=>$y,color=>\@newpixel);
			}
		}
	}
	print "\n";

	print "Writing $newfile\n";
	check_warn($image->Crop(x=>0,y=>0,width=>$newsize,height=>$newsize));
	check_warn($image->Write($newfile));
	print "\n";
}

#########################################################################

sub check_warn {
	return;
	if ($@) {
		foreach (@_) {
			print "$_\n";
		}
	}
}

#########################################################################


