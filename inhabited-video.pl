#!/usr/bin/perl
use strict; $|=1;

use Cwd qw(getcwd abs_path realpath);
use File::Basename;

##########################################################################

my $path	= '/home/bones/elite/inhabited-history';
my $seq_path	= "$path/sequence";

my $debug	= 0;
my $allow_scp	= 1;

my $fps		= 4;
my $format	= 'png';

my $filename	= 'inhabited-video.mp4';
my $output	= '/home/bones/elite/'.$filename;

my $scp		= '/usr/bin/scp';
my $rm		= '/bin/rm';
my $ffmpeg	= '/usr/bin/ffmpeg';
my $ln		= '/usr/bin/ln';
my $convert	= '/usr/bin/convert';

my $cdn_url	= 'https://edastro.b-cdn.net/mapcharts/';
my $scriptpath	= "/home/bones/elite";
my $cdn_purge	= "$scriptpath/cdn-purge.sh";

##########################################################################

my $pwd = getcwd();


	
foreach my $regioncode ('','-regions') {

	my %files = ();
	
	opendir DIR, $path;
	while (my $fn = readdir DIR) {
		if ($fn =~ /^inhabited$regioncode-\d+.png$/) {
			$files{"$path/$fn"} = 1;
		}
	}
	closedir DIR;
	
	my %links = ();
	my $max = 0;
	
	opendir DIR, $seq_path;
	while (my $fn = readdir DIR) {
		if ($fn =~ /^inhabitedmap$regioncode-(\d+).png$/) {
			$links{"$seq_path/$fn"} = realpath("$seq_path/$fn");
			delete($files{$links{"$seq_path/$fn"}});
			$max = $1+0 if ($1 > $max);
			print "FOUND: $seq_path/$fn -> ".$links{"$seq_path/$fn"}."\n";
		}
	}
	closedir DIR;
	
	chdir $seq_path;
	
	foreach my $fn (sort keys %files) {
		$max++;
		my $n = sprintf("%06u",$max);
		my $lnf = "$seq_path/inhabitedmap$regioncode-$n.png";
		$links{$lnf} = $fn;
		print "ADDING: $fn -> $lnf\n";
		system($ln,'-s',$fn,$lnf);
	}

	my $fn = $output;
	$fn =~ s/\.mp4$/$regioncode.mp4/ if ($regioncode);
	
	my $last_frame = $fn;
	$last_frame =~ s/mp4$/jpg/;
	
	my $final_frame = $links{(reverse sort keys %links)[0]};
	system($convert,$final_frame,'-resize','1280x640',$last_frame);
	
	my $syscall = "$ffmpeg -y -framerate $fps -i $seq_path/inhabitedmap$regioncode-%06d.$format -c:v libx264 -profile:v high -crf 20 -pix_fmt yuv420p -vf scale=2560x1280 $fn";
	print "$syscall\n";
	system($syscall) if (!$debug);
	
	system($scp,$last_frame,$fn,'www@services:/www/edastro.com/mapcharts/') if ($allow_scp && !$debug);
	system($cdn_purge,$cdn_url.basename($fn));
}

exit;

##########################################################################



