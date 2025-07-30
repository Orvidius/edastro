#!/usr/bin/perl
use strict;

#############################################################################

use lib "/home/bones/perl";
use ATOMS qw(epoch2date date2epoch);

# Some archived dumps are here: https://edgalaxydata.space/

#############################################################################

my $path		= '/home/bones/elite';
my @t			= localtime;
my $date		= sprintf("%04u%02u%02u",$t[5]+1900,$t[4]+1,$t[3]);

my $mail		= '/usr/bin/mail';
my $echo		= '/usr/bin/echo';
my $gunzip		= '/usr/bin/gunzip';
my $wget		= '/usr/bin/wget';
my $mv			= '/usr/bin/mv';

my $day_interval	= 2;

my $epochDay		= int(time / 86400);

my %planets		= ();
my %stars		= ();
my %moons		= ();

my %action		= ();

foreach my $arg (@ARGV) {
	$action{$arg} = 1;
}


#############################################################################

print "Epoch Day: $epochDay\n";
print "\t$day_interval-Day: ".($epochDay % $day_interval)."\n";

my_system("cd ~bones/elite ; ./inhabited-space-overlay.pl > inhabited-space-overlay.pl.out 2>\&1");
#my_system("/usr/bin/ssh -p222 www\@services 'cd /www/EDtravelhistory ; nohup nice ./tiles.pl inhabited >tiles.pl.out.inhabited 2>\&1 \&'");

if ((!keys(%action) && $t[6]==0) || $action{saturation}) {
	my_system("cd ~bones/elite ; ./exploration-saturation-map.pl cron > exploration-saturation-map.pl.out 2>\&1");
	my_system("/usr/bin/ssh -p222 www\@services 'cd /www/EDtravelhistory ; nohup nice ./tiles.pl saturation >tiles.pl.out2 2>\&1 \&'");
}

if ((!keys(%action) && $epochDay % $day_interval == 0) || $action{maps}) {
	#my_system("cd ~bones/elite ; ./make-starmaps.pl 1 > make-starmaps.pl.out 2>\&1");
	#my_system("cd ~bones/elite ; ./make-starmaps.pl 2 > make-starmaps.pl.out2 2>\&1");
	my_system("cd ~bones/elite ; ./make-starmaps.pl > make-starmaps.pl.out 2>\&1");
	my_system("/usr/bin/ssh -p222 www\@services 'cd /www/EDtravelhistory ; nohup nice ./tiles.pl >tiles.pl.out 2>\&1 \&'");
}

exit;

#############################################################################

sub background_script {
	my ($script,$outfile) = @_;
	my_system(1,"cd ~bones/elite/scripts ; ./$script > $outfile ; scp $outfile www\@services:/www/edastro.com/mapcharts/files/");
}

sub redirect_script {
	my ($script,$outfile) = @_;
	my_system("cd ~bones/elite/scripts ; ./$script > $outfile ; scp $outfile www\@services:/www/edastro.com/mapcharts/files/");
}

sub execute_script {
	my $script = shift;
	my $datafiles = join(' ',@_);
	my_system("cd ~bones/elite/scripts ; ./$script > $script.out ; scp $datafiles www\@services:/www/edastro.com/mapcharts/files/");
}

sub get_file {
	my ($parse_now, $param, $url, $file) = @_;

	#my_system("cd $path ; rm -f $file ; $wget $url/$file");

	#if (!-e $file) {
		my_system("cd $path ; rm -f $file ; rm -f $file.gz ; $wget $url/$file.gz");
		my_system("cd $path ; $gunzip $file.gz ; sync");
	#}

	if (!-e "$path/$file") {
		my_system("$echo \"Could not retrieve $file\" | $mail -s \"EDastro Pull Failure: $file\" ed\@toton.org");
	}

	if (!$parse_now) {
		print "MV $file -> $date-$file\n";
		my_system("$mv $path/$file $path/$date-$file");
		#my_system("$path/parse-data.pl $param $path/$date-$file > $path/$date-$file.out 2>\&1") if ($parse_now);
	} else {
		my_system("$path/parse-data.pl $param $path/$file > $path/$file.out 2>\&1") if ($parse_now);
	}
}

sub my_system {
	my $do_fork = 0;

	if ($_[0] =~ /^\d+$/) {
		$do_fork = shift @_;
	}

	my @list = @_;

	my $s = join(' ',@list);
	my $d = epoch2date(time);
	print "[$d] $s\n";

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

#############################################################################


