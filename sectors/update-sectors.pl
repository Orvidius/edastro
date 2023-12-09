#!/usr/bin/perl
use strict; $|=1;
###########################################################################

use Image::Magick;
use Time::HiRes qw(sleep);
use POSIX qw(floor);
use POSIX ":sys_wait_h";
use JSON;

use lib '/home/bones/perl';
use ATOMS qw(btrim date2epoch epoch2date);
use DB qw(db_mysql rows_mysql disconnect_all);

use lib '/home/bones/elite';
use EDSM qw(id64_sectorcoords);

###########################################################################

my $debug		= 0;
my $verbose		= 0;

my $send_updates	= 1;
my $html_only		= 0;
my $backfilling		= 0;
my $overwrite_current	= 0;
my $overwrite_all	= 0;
my $delete_old		= 1;
#$send_updates = 0 if ($debug);

my $max_periods		= 26;
my $days_per_period	= 7;
my $interval		= $days_per_period*86400;



my %override_periods	= ();
$override_periods{'Graea Hypue'}	= $max_periods * 10;
$override_periods{'Flyoo Prao'}		= $max_periods * 6;
$override_periods{'Eishoqs'}		= $max_periods * 6;

foreach my $s (keys %override_periods) {
	my $new = $s;
	$new =~ s/\s+/_/g;
	$override_periods{$new} = $override_periods{$s};
}

if (@ARGV) {
	$send_updates = 1;
	$overwrite_current = 1;
	$delete_old = 1;
}

my $debug_limit		= '';
my $debug_where		= '';
my $debug_html		= '';
my $debug_image		= '';
my $debug_sector	= ''; #'Graea Hypue';
#$debug_limit		= 'limit 5' if ($debug);
#$debug_where		= "where ID in (8,9,17,19,21,3787)" if ($debug);	# Eol Prou
#$debug_where		= "where ID in (3787)" if ($debug);	# Eol Prou
#$debug_html		= 'Eol Prou' if ($debug);
#$debug_html		= 'Soijua' if ($debug);
#$debug_html		= 'Eos Auscs' if ($debug);
$debug_html		= 'Treque' if ($debug);
#$debug_html		= 'Synuefe' if ($debug);
#$debug_image		= 'Soijua' if ($debug);


my $use_forking         = 1;
my $max_children        = 6;
my $fork_verbose        = 0;
#$use_forking = 0 if ($debug);
$use_forking = 0 if ($html_only);

my $pixel_lightyears	= 2.5;
my $image_scaling	= 1;	# Must be 1 or 2.
$pixel_lightyears	*= $image_scaling;
my $sector_pixels	= int(1280/$pixel_lightyears);
my $size_x		= 720;
my $size_y		= 600;
my $pointsize		= 15;
my $titlesize		= 18;
my $image_size		= $size_x.'x'.$size_y;
my $datapath		= '/home/bones/elite/sectors/sectordata';
my $convert		= '/usr/bin/convert';
my $rm			= '/usr/bin/rm';
my $db  		= 'elite';
my $template		= '/home/bones/elite/sectors/template.html';
my $index_template	= '/home/bones/elite/sectors/formtemplate.html';
my $rsync_target	= 'www@services:/www/edastro.com/sectordata/';
my $sector_target	= 'www@services:/www/edastro.com/sector/';

my $sol_mapsector_x	= -65;
my $sol_mapsector_y	= -25;
my $sol_mapsector_z	= -1065;
my $sol_sector_x	= 39;
my $sol_sector_y	= 32;
my $sol_sector_z	= 18;

my %heatindex = ();
@{$heatindex{0}}	= (0,0,0);
@{$heatindex{1}}	= (64,64,255);
@{$heatindex{4}}	= (0,255,255);
@{$heatindex{7}}	= (0,255,0);
@{$heatindex{10}}	= (255,255,0);
@{$heatindex{20}}	= (255,255,255);
@{$heatindex{50}}	= (255,0,0);
@{$heatindex{100}}	= (255,0,255);
@{$heatindex{250}}	= (128,0,255);
@{$heatindex{999999999}}= (128,0,255);

my $amChild   = 0;
my %child      = ();
$SIG{CHLD} = \&REAPER;

###########################################################################

my $start_epoch = time;
my $fork_count = 0;

my %sector = ();
my %coords = ();

my $this_period = int(time/$interval)+1;
my $this_epoch = $this_period*$interval;
my $this_date = epoch2date($this_epoch);
my $today = epoch2date(time);
$today =~ s/\s+[\d\:]+\s*//s;
my $delete_period = $this_period - $max_periods;

print "This period $this_period ($this_epoch) $this_date\n";
print "DELETE: * < $delete_period\n" if ($delete_old);

if ($delete_old) {

	my @dirs = ();
	opendir DIR, $datapath;
	while (my $dir = readdir DIR) {
		if ($dir !~ /^\./ && -d "$datapath/$dir") {
			push @dirs, $dir;
		}
	}
	closedir DIR;
	
	foreach my $dir (sort @dirs) {

		$delete_period = $this_period - $max_periods;
		$delete_period = $this_period - $override_periods{$dir} if ($override_periods{$dir} > 0);
	
		opendir DIR, "$datapath/$dir";
		while (my $fn = readdir DIR) {
			if ($fn =~ /^(\d+)\.png/) {
				if ($1 < $delete_period) { 
					print "DELETING $dir/$fn\n";
					unlink "$dir/$fn";
				}
			}
		}
		closedir DIR;
	}
}


open HTML, "<$template";
my @lines = <HTML>;
my $template_html = join '', @lines;
@lines = ();
close HTML;

my @sectornames = ();
my @fakesectors = ();

my @rows = db_mysql($db,"select ID,name,sector_x,sector_y,sector_z from sectors $debug_where order by ID $debug_limit");
while (@rows) {
	my $r = shift @rows;

	$sector{$$r{sector_x}}{$$r{sector_y}}{$$r{sector_z}}{$$r{ID}} = $$r{name};
	push @sectornames, $$r{name};
}

open HTML1, ">$datapath/fakesectors.json";
open HTML2, ">$datapath/targetsectors.json";
my $i=0;
my @rows = db_mysql($db,"select fakesectors.name fakename,sectors.name realname from sectors,fakesectors where sectors.ID=fakesectors.sectorID");
print HTML1 "[";
print HTML2 "[";
while (@rows) {
	my $r = shift @rows;
	print HTML1 ',' if ($i);
	print HTML2 ',' if ($i);
	print HTML1 '"'.$$r{fakename}.'"';
	print HTML2 '"'.$$r{realname}.'"';
	push @fakesectors,$$r{fakename};
	$i++;
}
print HTML1 "]\n";
print HTML2 "]\n";
close HTML1;
close HTML2;

my @rows = db_mysql($db,"select * from fakesectors");
foreach my $r (@rows) {
	$coords{$$r{name}} = [($$r{avgX}+0,$$r{avgY}+0,$$r{avgZ}+0)];
}

open HTML, "<$index_template";
my @lines = <HTML>;
my $template_form_html = join '', @lines;
my $form_html = '';
foreach my $line (@lines) {
	$form_html .= $line if ($line !~ /<!--#include\s+virtual=/);
}
@lines = ();
close HTML;

my $arraystring = '["'.join('","',sort(@sectornames,@fakesectors)).'"]'."\n";

open HTML, ">$datapath/realsectors.json";
print HTML '["'.join('","',sort(@sectornames)).'"]'."\n";
close HTML;

open HTML, ">$datapath/sectorlist.json";
print HTML $arraystring;
close HTML;

open HTML, ">$datapath/form.html";
$form_html =~ s/<!!SECTORARRAY!!>/var sectorArray = $arraystring;/gs;
print HTML $form_html;
close HTML;

open HTML, ">$datapath/index.html";
my $temp = $template_form_html;
$temp =~ s/<!!SECTORARRAY!!>/var sectorArray = $arraystring;/gs;
print HTML $temp;
close HTML;


foreach my $sx (sort keys %sector) {
	foreach my $sy (sort keys %{$sector{$sx}}) {
		foreach my $sz (sort keys %{$sector{$sx}{$sy}}) {

			my $pid = 0;
			my $do_anyway = 0;
		
			my @ids = keys %{$sector{$sx}{$sy}{$sz}};
			if (@ids>1) {
				warn "[$sx,$sy,$sz] contains multiple IDs: ".join(',',@ids)."\n";
			}

			my $sector_name = btrim($sector{$sx}{$sy}{$sz}{$ids[0]});
			my $dir_name = $sector_name;
			$dir_name =~ s/\s+/_/gs;

			next if (!$sector_name);

			next if ($debug_sector && $debug_sector ne $sector_name);

			print "$sector_name = $datapath/$dir_name\n";

			if (!-d "$datapath/$dir_name") {
				mkdir "$datapath/$dir_name", 0755;
			}

			if ($html_only && $debug_html && $sector_name ne $debug_html) {
				next;
			}

			my $html = $template_html;
			my %token = ();
			my %needed = ();
			my %avail = ();

			my @period_numbers = ();
			my @period_dates = ();
			my @period_files = ();

			my $maxP = $max_periods;
			$maxP = $override_periods{$sector_name} if ($override_periods{$sector_name} > 0);

			for (my $i=0; $i<=$maxP; $i++) {
				my $period = $this_period - $i;
				my $fn = "$datapath/$dir_name/$period.png";
#print "$sector_name CHECKING: $fn\n";

				$needed{$period} = $fn if ((($period == $this_period || $period == $this_period-1) && $overwrite_current)
								|| ($period == $this_period && $debug_image eq $sector_name) || $overwrite_all || !-e $fn);
				#$needed{$period} = $fn if (!-e $fn && $backfilling);
				$avail{$period} = "$period.png";

#print "$sector_name NEEDED: $needed{$period}\n" if ($needed{$period});

				my $period_date = epoch2date($period*$interval);
				$period_date =~ s/\s+[\d\:]+\s*$//;
				$period_date = $today if ($period_date gt $today);
				$token{PERIODDATES} .= "\t\tif (period == $period) { output.innerHTML = '$period_date'; }\n";

				if (-e $fn || $needed{$period}) {
					# include if: 1) exists, or 2) is scheduled to create:

					push @period_numbers, $period;
					push @period_dates, $period_date;
					push @period_files, "$period.png";
				}
			}

			my $sec_x = $sol_mapsector_x + ($sx-$sol_sector_x)*1280;
			my $sec_y = $sol_mapsector_y + ($sy-$sol_sector_y)*1280;
			my $sec_z = $sol_mapsector_z + ($sz-$sol_sector_z)*1280;

			$coords{$sector_name} = [($sec_x+640,$sec_y+640,$sec_z+640)];

			my $num_dates = int(@period_dates);
			if ($period_dates[0] eq $period_dates[1]) {
				shift @period_numbers;
				shift @period_dates;
				shift @period_files;
			}

			my $fork_allowed = 1;
			$fork_allowed = 0 if (!%needed);

			while ($use_forking && int(keys %child) >= $max_children) {
				#sleep 1;
				sleep 0.001;
			}

			if ($fork_allowed && $use_forking && $fork_count>500 && time - $start_epoch <= 5) {
				print "!!!! Exceeding 100 threads per second, switching modes !!!!\n";
				$use_forking = 0;
			}

			if ($fork_allowed && $use_forking) {
				FORK: {
					if ($pid = fork) {
						# Parent here
						$child{$pid}{start} = time;
						info("FORK: Child spawned on PID $pid, for $sx, $sy, $sz\n") if ($fork_verbose);
						$fork_count++;
						next;
					} elsif (defined $pid) {
						# Child here
						$amChild = 1;   # I AM A CHILD!!!
						info("FORK: $$ ready, for $sx, $sy, $sz\n") if ($fork_verbose);
						$0 =~ s/^.*\s+(\S+\.pl)\s+.*$/$1/;
						$0 .= " -- $sx, $sy, $sz";
					} elsif ($! =~ /No more process/) {
						info("FORK: Could not fork a child for $sx, $sy, $sz, retrying in 3 seconds\n");
						sleep 3;
						redo FORK;
					} else {
						info("FORK: Could not fork a child for $sx, $sy, $sz\n");
						$do_anyway = 1;
					}
				}
			} else {
				$do_anyway = 1;
			}
	
	
			if ($amChild || $do_anyway) {
				disconnect_all() if ($amChild);
		
				$token{SECTORDATE} = $this_date;
				$token{SECTORDATE} =~ s/\s+[\d\:]+\s*$//;
				$token{SECTORDATE} = $today if ($token{SECTORDATE} gt $today);
				$token{SECTORNAME} = $sector_name;
				$token{MAXPERIOD} = int(@period_numbers); #$max_periods;
				$token{UP} = nav_button('UP',$sx,$sy+1,$sz,\%sector);
				$token{DOWN} = nav_button('DOWN',$sx,$sy-1,$sz,\%sector);
				$token{NORTH} = nav_button('NORTH',$sx,$sy,$sz+1,\%sector);
				$token{SOUTH} = nav_button('SOUTH',$sx,$sy,$sz-1,\%sector);
				$token{WEST} = nav_button('WEST',$sx-1,$sy,$sz,\%sector);
				$token{EAST} = nav_button('EAST',$sx+1,$sy,$sz,\%sector);

				$token{MAPLINK} = "\&nbsp;<a href=\"/galmap?pins=sectorlines#".($sec_x+640).','.($sec_y+640).','.($sec_z+640).",8\">\&#10148;</a>";

				for (my $i=0; $i<70; $i++) {
					my $gz = 73-$i;
					for (my $gx=4; $gx<74; $gx++) {
						my $class = 'gsBlank';
						$class = 'gsCurr' if ($gx==$sx && $gz==$sz);

						if ($class ne 'gsCurr' && exists($sector{$gx}{$sy}{$gz}) && keys(%{$sector{$gx}{$sy}{$gz}})) {
							my $sname = $sector{$gx}{$sy}{$gz}{(keys(%{$sector{$gx}{$sy}{$gz}}))[0]};
							$token{GALAXYTOP} .= "<div class=\"gsAvail\" onClick=\"replace_sector('$sname');\"></div>";
						} else {
							$token{GALAXYTOP} .= "<div class=\"$class\"></div>";
						}
					}
					$token{GALAXYTOP} .= "\n";
				}

				for (my $gy=35; $gy>=28; $gy--) {
					for (my $gx=4; $gx<74; $gx++) {
						my $class = 'gsBlank';
						$class = 'gsCurr' if ($gx==$sx && $gy==$sy);

						if ($class ne 'gsCurr' && exists($sector{$gx}{$gy}{$sz}) && keys(%{$sector{$gx}{$gy}{$sz}})) {
							my $sname = $sector{$gx}{$gy}{$sz}{(keys(%{$sector{$gx}{$gy}{$sz}}))[0]};
							$token{GALAXYSIDE} .= "<div class=\"gsAvail\" onClick=\"replace_sector('$sname');\"></div>";
						} else {
							$token{GALAXYSIDE} .= "<div class=\"$class\"></div>";
						}
					}
					$token{GALAXYSIDE} .= "\n";
				}

				foreach my $direction (qw(UP DOWN NORTH SOUTH EAST WEST BLANK)) {
					open HTML, ">$datapath/$dir_name/nav$direction.html";
					print HTML $token{$direction}."\n";
					close HTML;
				}

				open HTML, ">$datapath/$dir_name/galaxytop.html";
				print HTML $token{GALAXYTOP};
				close HTML;

				open HTML, ">$datapath/$dir_name/galaxyside.html";
				print HTML $token{GALAXYSIDE};
				close HTML;

				open DATA, ">$datapath/$dir_name/dates.json";
				print DATA '["'.join('","',reverse(@period_dates)).'"]'."\n";
				close DATA;

				open DATA, ">$datapath/$dir_name/images.json";
				print DATA '["'.join('","',reverse(@period_files)).'"]'."\n";
				close DATA;

				#open DATA, ">$datapath/$dir_name/periods.json";
				#print DATA '["'.join('","',reverse(@period_numbers)).'"]'."\n";
				#close DATA;

				%needed = () if ($html_only);
	
				open DATA, ">$datapath/$dir_name/coordinates.json";
				print DATA '['.join(',',$sec_x,$sec_y,$sec_z).']'."\n";
				close DATA;

				#open DATA, ">$datapath/$dir_name/coordinates.html";
				#print DATA "var sector_x = $sec_x;\n";
				#print DATA "var sector_y = $sec_y;\n";
				#print DATA "var sector_z = $sec_z;\n";
				#close DATA;

				my %systems = ();
	
				if (keys %needed) {
					my $ref = undef;
					$ref = rows_mysql($db,"select coord_x,coord_y,coord_z,date_added from systems where sectorID=? and deletionState=0",[($ids[0])]) if (@ids==1);
					$ref = rows_mysql($db,"select coord_x,coord_y,coord_z,date_added from systems where sectorID in (".join(',',@ids).") and deletionState=0") if (@ids>1);
					
					if ($ref && ref($ref) eq 'ARRAY') {
						print "$sector_name: ".commify(int(@$ref))."\n";
						while (@$ref) {
							my $r = shift @$ref;
							my $added_epoch = date2epoch($$r{date_added});
	
							foreach my $period (sort keys %needed) {
								my $epoch = $period*$interval;
								if ($added_epoch < $epoch) {
									my $x = floor(($$r{coord_x}-$sec_x)/$pixel_lightyears);
									my $z = floor(($$r{coord_z}-$sec_z)/$pixel_lightyears);
									$systems{$period}{$x}{$z}++ if ($x>=0 && $x<=$sector_pixels && $z>=0 && $z<=$sector_pixels);
								}
							}
						}
					}
				} else {
					exit 0 if ($amChild);
					next;
				}
	
				foreach my $period (sort keys %needed) {
					my $epoch = $period*$interval;
					my $date = epoch2date($epoch);
					my $day = $date;
					$day =~ s/\s+[\d\:]+\s*$//s;
					$day = $today if ($day gt $today);
					my $fn = $needed{$period};
	
					print "! $fn\n";
	
					my $image = Image::Magick->new(
						size  => $image_size,
						type  => 'TrueColor',
						depth => 8
					);
					show_result($image->ReadImage('canvas:black'));
					show_result($image->Quantize(colorspace=>'RGB'));
	
					my $viewsize = $sector_pixels*$image_scaling;
	
					my $start_x = int(($size_x - $viewsize)/2);
					my $start_y = int(($size_y - $viewsize)/2);
	
					my $count = 0;
	
					foreach my $x (sort keys %{$systems{$period}}) {
						foreach my $z (sort keys %{$systems{$period}{$x}}) {
							my $y = $sector_pixels-$z;
	
							my $color = float_colors(index_colors($systems{$period}{$x}{$z},\%heatindex));
	
							if ($image_scaling>1) {
								$image->SetPixel( x => $start_x+$x*2, y => $start_y+$y*2, color => $color);
								$image->SetPixel( x => $start_x+$x*2+1, y => $start_y+$y*2, color => $color);
								$image->SetPixel( x => $start_x+$x*2, y => $start_y+$y*2+1, color => $color);
								$image->SetPixel( x => $start_x+$x*2+1, y => $start_y+$y*2+1, color => $color);
							} else {
								$image->SetPixel( x => $start_x+$x, y => $start_y+$y, color => $color);
							}
	
							$count += $systems{$period}{$x}{$z};
						}
					}
	
					my $divs = 4;
	
					foreach my $n (0..$divs) {
						my $x = $start_x + int($n*($viewsize+2)/$divs)-1;
						my $y = $start_y + $viewsize + 1;
						my $label = commify($sec_x+int(1280*$n/$divs));
	
						$image->Draw( primitive=>'line', stroke=>'#777', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$y,$x,$y+8));
						$image->Annotate(pointsize=>$pointsize, fill=>'white',text=>$label, x=>$x - int(length($label)*$pointsize/4), y=>$y+$pointsize+10);
	
						$x = $start_x + $viewsize + 1;
						$y = $start_y + int($n*($viewsize+2)/$divs)-1;
						$label = commify($sec_z+int(1280*($divs-$n)/$divs));
	
						$image->Draw( primitive=>'line', stroke=>'#777', strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$y,$x+8,$y));
						$image->Annotate(pointsize=>$pointsize, fill=>'white',text=>$label, x=>$x+15, y=>$y+($pointsize/2)-2);
					}

					$image->Annotate(pointsize=>$pointsize, fill=>'white',text=>commify($sec_y), gravity=>'southeast', 
								x=>$viewsize+($pointsize*1.5)+($size_x-$viewsize)/2, y=>80);
					$image->Annotate(pointsize=>$pointsize, fill=>'white',text=>'Y', gravity=>'southeast', 
								x=>$viewsize+($pointsize*3.1)+($size_x-$viewsize)/2, y=>80+$pointsize*1.5);
					$image->Annotate(pointsize=>$pointsize, fill=>'white',text=>commify($sec_y+1280), gravity=>'southeast', 
								x=>$viewsize+($pointsize*1.5)+($size_x-$viewsize)/2, y=>80+$pointsize*3);

					# Y-axis arrow:
					my ($x1,$y1) = (64,482);
					my ($x2,$y2) = (64,501);
					$image->Draw( primitive=>'line', stroke=>'white', strokewidth=>1,points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y2));
					$image->Draw( primitive=>'line', stroke=>'white', strokewidth=>1,points=>sprintf("%u,%u %u,%u",$x1,$y1,$x1+4,$y1+4));
					$image->Draw( primitive=>'line', stroke=>'white', strokewidth=>1,points=>sprintf("%u,%u %u,%u",$x1,$y1,$x1-4,$y1+4));
					$image->Draw( primitive=>'line', stroke=>'white', strokewidth=>1,points=>sprintf("%u,%u %u,%u",$x2,$y2,$x2+4,$y2-4));
					$image->Draw( primitive=>'line', stroke=>'white', strokewidth=>1,points=>sprintf("%u,%u %u,%u",$x2,$y2,$x2-4,$y2-4));
	
					my_rectangle($image,$start_x-1,$start_y-1,$start_x+$viewsize+1,$start_y+$viewsize+1,1,'#777');
	
					$image->Annotate(pointsize=>$titlesize,fill=>'white',text=>"Systems: ".commify($count),gravity=>'northwest',
								x=>$pointsize/2,y=>$pointsize*1.5+2);
	
					$image->Annotate(pointsize=>$titlesize,fill=>'white',text=>$day,gravity=>'northeast',x=>$pointsize/2,y=>$pointsize*1.5+2);
					$image->Annotate(pointsize=>$titlesize,fill=>'white',text=>$sector_name,gravity=>'north',x=>0,y=>$pointsize*1.5+2);
	
					my @list = sort {$a<=>$b} keys %heatindex;
					my $x = int($pointsize/2);
					my $y = $start_y + $pointsize;
	
					$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>'Color Index:',x=>$x,y=>$y);
					for(my $i=0; $i<@list-1; $i++) {
						my $s = "$list[$i]";
						#$s .= "-".int($list[$i+1]-1) if ($list[$i+1]-1 > $list[$i] && $i+1<@list-1);
						$s .= "+" if ($i+1 >= @list-1);
	
						$y += int($pointsize*1.3);
						my $color = "rgb(".join(',',@{$heatindex{$list[$i]}}).")";
	
						$image->Annotate(pointsize=>$pointsize,fill=>'white',text=>$s,x=>$x+$pointsize*2,y=>$y+$pointsize-1);
	
						my_rectangle($image,$x+$pointsize*0.5,$y,$x+$pointsize*1.5-1,$y+$pointsize-1,1,'#777',$color);
					}
	
					delete($systems{$period});
	
					my $tmp = $fn;
					$tmp =~ s/\.png$/\.bmp/;
					show_result($image->Write( filename => $tmp ));
					my_system(1,"$convert $tmp $fn ; $rm -f $tmp");
				}
			}
	
			exit 0 if ($amChild);
		}
	}
}

my $json = JSON->new->allow_nonref;
open DATA, ">$datapath/sectorcoords.json";
print DATA $json->pretty->encode(\%coords)."\r\n";
close DATA;

while ($use_forking && int(keys %child) >= $max_children) {
	#sleep 1;
	sleep 0.1;
}

if ($send_updates && $use_forking) {
	sleep 10;
}

print "Done\n";

if ($send_updates) {
	open TXT, ">epoch.dat";
	print TXT time."\n";
	close TXT;
	system("/usr/bin/scp epoch.dat $sector_target");
	system("/usr/bin/rsync -Wuvax --delete sectordata/* $rsync_target");
}



###########################################################################

sub nav_button {
	my ($button, $x, $y, $z, $href) = @_;
	my @ids = sort keys %{$$href{$x}{$y}{$z}};
	my $class = ' class="sectorNormalButton"';
	$class = ' class="sectorLeftButton"' if ($button =~ /WEST/i);
	$class = ' class="sectorRightButton"' if ($button =~ /EAST/i);
	my $plus = '';
	$plus = 'sectorButtonSide' if ($button =~ /EAST|WEST/i);
	my $plus2 = '';
	$plus2 = 'sectorButtonVertical' if ($button =~ /EAST|WEST/i);

	return "<div class=\"sectorButtonDisabled $plus\"><div class=\"$plus2\"><div$class>&#8212;</div></div></div>" if (!@ids);
	
	my $sector_name = btrim($$href{$x}{$y}{$z}{$ids[0]});
	my $dir_name = $sector_name;
	$dir_name =~ s/\s+/_/gs;

	$sector_name =~ s/\s+/\&nbsp;/gs;

	my $arrow = '';

	$arrow = '&#9650;' if ($button =~ /UP|NORTH|EAST|WEST/i);
	$arrow = '&#9660;' if ($button =~ /DOWN|SOUTH/i);

	my $html = "<div class=\"sectorButton $plus\" onClick=\"replace_sector('$dir_name');\">".
			"<div class=\"$plus2\"><div$class>$arrow\&nbsp;\&nbsp;$button:\&nbsp;\&nbsp;$sector_name\&nbsp;\&nbsp;$arrow</div></div></div>";

	return $html;
}

sub my_rectangle {
	my ($image,$x1,$y1,$x2,$y2,$strokewidth,$color,$fill) = @_;

	#print "Rectangle for $maptype: $x1,$y1,$x2,$y2,$strokewidth,$color\n";

	return if ($x1 < 0 || $y1 < 0 || $x2 < 0 || $y2 < 0);

	if ($fill) {

		$image->Draw( primitive=>'rectangle', stroke=>$color, fill=>$fill, strokewidth=>$strokewidth,
			points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y2));

	} else {

		$image->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
			points=>sprintf("%u,%u %u,%u",$x1,$y1,$x2,$y1));

		$image->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
			points=>sprintf("%u,%u %u,%u",$x1,$y2,$x2,$y2));

		$image->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
			points=>sprintf("%u,%u %u,%u",$x1,$y1,$x1,$y2));

		$image->Draw( primitive=>'line', stroke=>$color, strokewidth=>$strokewidth,
			points=>sprintf("%u,%u %u,%u",$x2,$y1,$x2,$y2));
	}
}

sub index_colors {
	my ($heat,$index,$floor1) = @_;
	return (0,0,0) if (!$heat || !$index);

	my $bottomIndex = 0;
	my $topIndex = 0;

	my @list = sort {$a<=>$b} keys %$index;
	my $maxVal = $list[@list-1];

	my $i = 0;
	while ($i<@list-1 && !$topIndex) {
		$i++;
		if ($heat >= $list[$i] && $heat < $list[$i+1]) {
			$bottomIndex = $i; $topIndex = $i+1;
			last;
		}
	}
	return (@{$$index{$maxVal}}) if ($heat >= $maxVal);
	return (0,0,0) if (!$topIndex || $list[$topIndex]-$list[$bottomIndex] == 0);

	my $decimal = ($heat-$list[$bottomIndex]) / ($list[$topIndex]-$list[$bottomIndex]);

	$decimal = 0.99 if ($floor1 && $heat<1);

	my @bottomColor = @{$$index{$list[$bottomIndex]}};
	my @topColor    = @{$$index{$list[$topIndex]}};

	my @pixels = scaledColorRange($bottomColor[0],$bottomColor[1],$bottomColor[2],$decimal,$topColor[0],$topColor[1],$topColor[2]);

	return @pixels;
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
sub float_colors {
	my $r = shift(@_)/255;
	my $g = shift(@_)/255;
	my $b = shift(@_)/255;
	return [($r,$g,$b)];
}

sub show_result {
	foreach (@_) {
		warn "WARN: $_\n" if ($_);
	}
}

sub my_system {
	my $do_fork = 0;

	if ($_[0] =~ /^\d+$/) {
		$do_fork = shift @_;
	}

	my @list = @_;

	my $s = join(' ',@list);
	my $d = epoch2date(time,-5,1);

	print "[$d] $s\n" if ($verbose);

	my $pid = undef;

	if (!$do_fork) {
		system(@list);
	} else {
		if ($pid = fork) {
			#parent
			return;
		} elsif (defined $pid) {
			#child
			exec(@list);
		} else {
			system(@list);
		}

	}
}


sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
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


###########################################################################




