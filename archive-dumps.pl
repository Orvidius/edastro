#!/usr/bin/perl
use strict;

#############################################################################

use lib "/home/bones/perl";
use ATOMS qw(epoch2date date2epoch);

#############################################################################

my $path		= '/home/bones/elite/archive';
my @t			= localtime;
my $date		= sprintf("%04u%02u%02u",$t[5]+1900,$t[4]+1,$t[3]);

my $mail		= '/usr/bin/mail';
my $echo		= '/usr/bin/echo';
my $gunzip		= '/usr/bin/gunzip';
my $wget		= '/usr/bin/wget';
my $mv			= '/usr/bin/mv';

my $epochDay		= int(time / 86400);
my %action		= ();

foreach my $arg (@ARGV) {
	$action{$arg} = 1;
}

#############################################################################

print "EpochDay: ".($epochDay % 6)."\n";

if ($epochDay % 6 == 0 || @ARGV) {

	get_file('https://www.edsm.net/dump','systemsWithCoordinates7days.json.gz',"systemsWithCoordinates7days-$date.json.gz");
	get_file('https://www.edsm.net/dump','bodies7days.json.gz',"bodies7days-$date.json.gz");

	system("cd $path ; ./push2mediafire.pl bodies7days-$date.json.gz");
}

exit;


#############################################################################

sub get_file {
	my ($url, $file, $rename) = @_;

	my_system("cd $path ; rm -f $file ; $wget $url/$file");

	if (!-e "$path/$file") {
		my_system("$echo \"Could not retrieve $file\" | $mail -s \"EDastro Archive Failure: $file\" ed\@toton.org");
	} else {
		my_system("cd $path ; mv $file $rename");
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


