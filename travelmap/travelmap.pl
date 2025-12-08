#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(btrim epoch2date date2epoch);

use Image::Magick;

############################################################################

my $debug               = 0;
my $verbose             = 0;
my $allow_scp           = 1;

my $remote_server       = 'www@services:/www/orvidius.com/map/';
my $filepath            = "/home/bones/www/elite";
my $scriptpath          = "/home/bones/elite/travelmap";
my $mainpath            = "/home/bones/elite";

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
$cmdrID = 1 if (!$cmdrID);

my %commanders = ();

my @rows = db_mysql('elite',"select ID,name from commanders");
foreach my $r (@rows) {
	$cmdrName = $$r{name} if ($$r{ID} == $cmdrID);
	$commanders{$$r{ID}} = $$r{name};
	$commanders{lc($$r{name})} = $$r{ID};
}
print "Processing CMDR $cmdrName\n";

my $cmdr_path = "$scriptpath/historydata/$cmdrID";

system('mkdir','-p',$cmdr_path) if (!-d $cmdr_path);

my %boost_state = ();
my %completed = ();
my %files = ();

my @rows = db_mysql('elite',"select filename,cmdrID,processed from journalfiles");
foreach my $r (@rows) {
	if ($$r{processed}) {
		$completed{lc($$r{filename})} = 1;
	}
	$files{$$r{cmdrID}}{$$r{filename}} = 1;
}

get_journals($journal_path);


print "Pulling logs.\n";
my @rows = db_mysql('elite',"select name,eventtype,eventdate as date,coord_x,coord_z,jetcone,distance,calcdistance from journals,systems ".
			"where cmdrID=? and systemId64=id64 order by eventdate",[($cmdrID)]);
print int(@rows)." log entries pulled.\n";

exit if (@rows < 1);

my $last_row = $rows[int(@rows)-1];
my $new_loc = $$last_row{name};
my $events = int(@rows);
my $jumps = 0;
my $jetcones = 0;

print "Current location: $new_loc\n";

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
	#$galaxymap->Read("$mainpath/images/galaxy-3200px-enhanced.jpg");
	$galaxymap->Read("$mainpath/images/gamegalaxy-3200px-plain.bmp");
	$galaxymap->Gamma( gamma=>1.9 );
	$galaxymap->Modulate( saturation=>70 );
	$galaxymap->Modulate( brightness=>90 );
	$galaxymap->Quantize(colorspace=>'RGB');
	$galaxymap->Set(depth => 8);
	$galaxymap->Resize(geometry=>int($size_y).'x'.int($size_y).'+0+0') if ($size_x != 3200);
	
	my $logo_size = int($size_y*0.15);
	
	my $compass = Image::Magick->new;
	$compass->Read("$mainpath/images/thargoid-rose-hydra.bmp");
	$compass->Resize(geometry=>$logo_size.'x'.$logo_size.'+0+0');
	$galaxymap->Composite(image=>$compass, compose=>'over', gravity=>'southeast',x=>$pointsize/2,y=>$pointsize/2);
	
	my $logo = Image::Magick->new;
	$logo->Read("$mainpath/images/edastro-550px.bmp");
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

	$visited{uc($$r{name})}++;

	#my $jump_dist = sqrt(($$r{coord_x}-$last_x)**2 + ($$r{coord_y}-$last_y)**2 + ($$r{coord_z}-$last_z)**2);
	my $jump_dist = $$r{calcdistance}+0;

	$jumps++ if ($$r{eventtype} eq 'FSDJump' || $$r{eventtype} eq 'CarrierJump');
	$jetcones++ if ($$r{eventtype} eq 'FSDJump' && $$r{jetcone});

	if ($n) {
		my $dist = $jump_dist;

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

my $c  = 'rgb(0,180,0)';
$galaxymap->Draw( primitive=>'circle', stroke=>$c, fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$y,$x+$strokewidth*2+2,$y));
my $c  = 'rgb(0,255,0)';
$galaxymap->Draw( primitive=>'circle', stroke=>$c, fill=>$c, strokewidth=>1, points=>sprintf("%u,%u %u,%u",$x,$y,$x+$strokewidth*2,$y));

$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>"CMDR $cmdrName - ".$currentDate, x=>$pointsize*0.5, y=>$pointsize*1.5);
$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>commify($jumps)." jumps, ".commify(int(keys %visited))." total visited systems.", x=>$pointsize*0.5, y=>$size_y-($pointsize*0.5));
$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>commify(int($jumpdistance))." Lightyears", x=>$pointsize*0.5, y=>$size_y-($pointsize*1.8));
$galaxymap->Annotate(pointsize=>$pointsize,fill=>'white',text=>commify(int($jetcones))." Jet Cone Boosts", x=>$pointsize*0.5, y=>$size_y-($pointsize*3.1)) if ($jetcones);

$galaxymap->Resize(geometry=>int($save_x).'x'.int($save_y).'+0+0');

my $f = sprintf("%s/%s.jpg",$filepath,lc($cmdrName));
print "Writing to: $f\n";
my $res = $galaxymap->Write( filename => $f );
if ($res) {
	warn $res;
}

$galaxymap->Resize(geometry=>int($thumb_x).'x'.int($thumb_y).'+0+0');

my $f2 = sprintf("%s/%s-thumb.jpg",$filepath,lc($cmdrName));
print "Writing to: $f2\n";
my $res = $galaxymap->Write( filename => $f2 );
if ($res) {
	warn $res;
}

my_system("$scp $f $f2 $remote_server/") if (!$debug && $allow_scp);


print "Jet Cone Bosts: $jetcones\n";
print "Total distance: ".commify(sprintf("%.02f",$totaldistance))."\n";
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

sub process_line {
	my $events = shift;
	my $line = shift;
	my $file = shift;
	my $id   = shift;
	my $name = shift;

	my %dummy = ();
	my $r = \%dummy;

	#print "< $line\n" if ($line =~ /Commander/i);
	
	if ($line =~ /"+event"+\s*:\s*"+(FSDJump|Location|CarrierJump)"+/) {
		$$r{event} = $1;

		my $docked = 0;
		if ($line =~ /"+Docked"+\s*:\s*true/) {
			$docked = 1;
		}

		if ($line =~ /"+timestamp"+\s*:\s*"+([\w\d\:\-\s]+)"+/) {
			$$r{date} = $1;
			$$r{date} =~ s/[^\d\s\:\-]/ /gs;
			$$r{date} = btrim($$r{date});
		}
		if ($line =~ /"+SystemAddress"+\s*:\s*"?(\d+)"?/) {
			$$r{id64} = btrim($1) + 0;
		}
		if ($line =~ /"+StarSystem"+\s*:\s*"+([^"]+)"+/) {
			$$r{name} = btrim($1);
		}
		if ($line =~ /"+StarPos"+\s*:\s*\[\s*([\d\.\-]+)\s*,\s*([\d\.\-]+)\s*,\s*([\d\.\-]+)\s*\]/) {
			$$r{coord_x} = $1;
			$$r{coord_y} = $2;
			$$r{coord_z} = $3;
		}
		if ($line =~ /"+JumpDist"+\s*:\s*"?([\d\.]+)"?/) {
			$$r{distance} = $1;
		}


		if ($$r{name} && !$$r{id64} && defined($$r{coord_x}) && defined($$r{coord_y}) && defined($$r{coord_z})) {
			my @rows = db_mysql('elite',"select id64 from systems where name=? and coord_x>=? and coord_x<=? and coord_y>=? and coord_y<=? and coord_z>=? and coord_z<=?",
				[($$r{name},$$r{coord_x}-1,$$r{coord_x}+1,$$r{coord_y}-1,$$r{coord_y}+1,$$r{coord_z}-1,$$r{coord_z}+1)]);

			if (@rows) {
				$$r{id64} = ${$rows[0]}{id64};
			}
		}

		$$r{jetcone} = $boost_state{$id} ? 1 : 0;

		if ($$r{event} eq 'FSDJump') {
			$boost_state{$id} = 0;
		}

		#print "LOG: $cmdrName $$r{date}: $$r{coord_x}, $$r{coord_y}, $$r{coord_z} ($$r{name})\n";
		push @$events, $r;
	} elsif ($line =~ /"event"\s*:\s*"JetConeBoost"/) {
		$boost_state{$id} = 1;
	}
	
}


sub get_journals {
	my $path = shift;
	my @files = ();

	opendir DIR, $path;
	while (my $fn = readdir DIR) {
		if ($fn =~ /^Journal\..+\.log$/) {
			push @files, $fn;
		}
	}
	closedir DIR;

	foreach my $fn (sort {$a cmp $b} @files) {
		my @events = ();

		if ($completed{lc($fn)}) {
			print "$fn SKIP - PREVIOUSLY PROCESSED\n";
			next;
		}

		print "$fn START READ\n";

		# Get a CMDR name right away.

		my $name = '';
		my $foundJump = 0;

		my $filesize = (stat("$path/$fn"))[7];

		open TXT, "<$path/$fn";
		while (my $data = <TXT>) {
			if ($data =~ /"+event"+\s*:\s*"+LoadGame"+/) {
				if ($data =~ /"+Commander"+\s*:\s*"+([^"]+)"+/) {
					$name = btrim($1);
					print "$fn: Commander: $name\n" if ($verbose || $debug);
				}
			}

			if ($data =~ /"+event"+\s*:\s*"+(FSDJump|CarrierJump)"+/) {
				$foundJump = 1;
			}

			last if ($name && $foundJump);
		}
		close TXT;

#		if (!$foundJump) {
#			# Probably a tutorial
#			print "\tskipped $fn, no jumps.\n" if ($verbose);
#			next;
#		}

		my ($id,$id64,$system,$x,$y,$z) = ($commanders{lc($name)},undef,undef,undef,undef,undef);

		if ($name && $id) {
	
			my @rows = db_mysql('elite',"select systemId64,systemName,coord_x,coord_y,coord_z,jetcone from journalfiles where filename<? and cmdrID=? ".
						" and processed is not null order by filename desc limit 1",[($fn,$id)]);
			if (@rows) {
				my $r = shift @rows;
				($id64,$system,$x,$y,$z,$boost_state{$id}) = ($$r{systemId64},$$r{systemName},$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{jetcone});
			}

			open TXT, "<$path/$fn";
			my $string = '';
	
			while (my $data = <TXT>) {
				chomp $data;
	
				next if ($data =~ /^\s*$/); # contains nothing
	
				if ($string) {
					$string .= btrim($data);
					if ($data =~ /^\}\"*\s*$/) {
						process_line(\@events,$string,$fn,$id,$name);
						$string = '';
					}
				} elsif ($data =~ /^\"*\{.+\}\"*\s*$/) {
					process_line(\@events,$data,$fn,$id,$name);
				} else {
					$string .= btrim($data);
				}
			}
			close TXT;
		}

		my @filecheck = db_mysql('elite',"select * from journalfiles where filename=?",[($fn)]);

		db_mysql('elite',"insert into journalfiles (filename,size,cmdrID,processed) values (?,?,?,null)",[($fn,$filesize,$id)]) if (!@filecheck);

		my $last_date  = undef;
		my $first_date = undef;
		my $count = 0;

		while (@events) {
			my $r = shift @events;

			next if ($$r{name} eq 'Training');
		
			if (!defined($x) && !defined($y) && !defined($z)) {
				$x = $$r{coord_x};
				$y = $$r{coord_y};
				$z = $$r{coord_z};
			}
			my $jumpdist = 0;

			$jumpdist = sprintf("%.06f", ( ($$r{coord_x}-$x)**2 + ($$r{coord_y}-$y)**2 + ($$r{coord_z}-$z)**2 ) ** 0.5)
				if ($x != $$r{coord_x} || $y != $$r{coord_y} || $z != $$r{coord_z});
		

			my @check = db_mysql('elite',"select ID from journals where cmdrID=? and eventtype=? and eventdate=? limit 1",[($id,$$r{event},$$r{date})]);
			my $exists = int(@check);

			my $warn = '';
			$warn = " !!!" if ($$r{distance} && ($$r{distance} < $jumpdist-1 || $$r{distance} > $jumpdist+1));

			print "$fn: $name($id) [$exists] $$r{event}($$r{date}) \"$$r{name}\"($$r{id64}) $$r{coord_x}, $$r{coord_y}, $$r{coord_z} ($$r{distance}, $jumpdist)$warn\n";

			if (!$exists) {
				db_mysql('elite',"insert into journals (systemId64,systemName,cmdrID,eventtype,eventdate,distance,calcdistance,jetcone) values ".
					"(?,?,?,?,?,?,?,?)",[($$r{id64},$$r{name},$id,$$r{event},$$r{date},$$r{distance},$jumpdist,$$r{jetcone})]);
			}

			$system = $$r{name};
			$id64 = $$r{id64};
			$x = $$r{coord_x};
			$y = $$r{coord_y};
			$z = $$r{coord_z};

			$first_date = $$r{date} if ($$r{date} && (!$first_date || $$r{date} lt $first_date));
			$last_date  = $$r{date} if ($$r{date} && (!$last_date  || $$r{date} gt $last_date));

			$count++;
		}

		$files{$id}{$fn} = 1 if ($id);

		db_mysql('elite',"update journalfiles set processed=NOW(),cmdrID=?,events=?,firstdate=?,lastdate=?,systemId64=?,systemName=?,coord_x=?,coord_y=?,coord_z=?,jetcone=? ".
				"where filename=?",[($id,$count,$first_date,$last_date,$id64,$system,$x,$y,$z,$boost_state{$id},$fn)]);
	}
}


############################################################################


