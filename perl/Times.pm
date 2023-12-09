package Times;

use strict;

BEGIN { # Export functions first because of possible circular dependancies
   use Exporter;
   use vars qw(@ISA $VERSION @EXPORT_OK);

   $VERSION = 2.01;
   @ISA = qw(Exporter);
   @EXPORT_OK = qw(epoch2maildate epoch2date sec2string);
}

my @months      = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
my %monthHash = ();
$monthHash{Jan} = 0; $monthHash{Feb} = 1; $monthHash{Mar} = 2; $monthHash{Apr} = 3;
$monthHash{May} = 4; $monthHash{Jun} = 5; $monthHash{Jul} = 6; $monthHash{Aug} = 7;
$monthHash{Sep} = 8; $monthHash{Oct} = 9; $monthHash{Nov} = 10; $monthHash{Dec} = 11;


sub epoch2maildate {
	# Returns a mail-header formatted date, based on a given epoch. Current gmtime is used if no epoch is given.

	my $epoch = shift;
	$epoch = time if (!$epoch);
	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = gmtime($epoch);
	my $maildate = sprintf("%02u %3s %04u %02u:%02u:%02u -0000",$mday,$months[$month],$year+1900,$hour,$min,$sec);
}


sub epoch2date {
	# Returns a sql-style date, based on a given epoch. Current gmtime is used if no epoch is given.

	my $epoch = shift;
	$epoch = time if (!$epoch);
	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = gmtime($epoch);
	my $maildate = sprintf("%04u-%02u-%02u %02u:%02u:%02u",$year+1900,$month+1,$mday,$hour,$min,$sec);
}


sub sec2string {
	# Returns human-readable times, from a given integer number of seconds:

	my $sec = shift;
	my $outstr = '';
	my ($days,$hours,$mins) = (0,0,0);

	if ($sec > 86400) {
		$days = int($sec / 86400);
		$outstr .= "$days days, " if ($days != 1);
		$outstr .= "$days day, " if ($days == 1);
		$sec %= 86400;
	}
	if ($sec > 3600) {
		$hours = int($sec / 3600);
		$outstr .= "$hours hours, " if ($hours != 1);
		$outstr .= "$hours hour, " if ($hours == 1);
		$sec %= 3600;
	}
	if ($sec > 60) {
		$mins = int($sec / 60);
		$outstr .= "$mins minutes, " if ($mins != 1);
		$outstr .= "$mins minute, " if ($mins == 1);
		$sec %= 60;
	}
	$outstr .= "$sec seconds" if ($sec > 1);
	$outstr .= "$sec second" if ($sec == 1);
	$outstr =~ s/\,\s*$//;
	return $outstr;
}


1;


