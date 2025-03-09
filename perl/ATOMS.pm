package ATOMS;
########################################################################
#
# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use strict;
use Time::Local;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Sys::Syslog;
use Sys::Syslog qw(:DEFAULT setlogsock);
use File::Basename;

our $progname;

BEGIN { # Export functions first because of possible circular dependancies
   use Exporter;
   use vars qw(@ISA $VERSION @EXPORT_OK);

   $VERSION = 2.01;
   @ISA = qw(Exporter);
   @EXPORT_OK = qw(timeout make_csv parse_csv trim_csv epoch2maildate epoch2date date2epoch sec2string isDST commify
			getValue btrim ltrim rtrim gmt2local local2gmt epoch2mysql epoch2datenodash switchHash MD5Date
			to_ascii randomize formatteddate2epoch epoch2formatteddate count_instances my_syslog $progname);


	$progname = basename($0);
}


#############################################################################
#
# ATOMS is a module containing low-level miscellaneous functions that are
# not tied to a specific purpose. Date/time manipulations, string 
# reformatting, math functions, timeout code, CSV parsing, etc.
#
#############################################################################

sub to_ascii {
	my $text = shift;

	# Unicode and ISO-8859‑Latin-1, to ASCII.

	$text =~ s/\x{0020}|\x{00A0}|\x{2000}|\x{2001}|\x{2002}|\x{2003}|\x{2004}|\x{2005}|\x{2006}|\x{2007}/ /g;
	$text =~ s/\x{2008}|\x{2009}|\x{200A}|\x{200B}|\x{202F}|\x{205F}|\x{3000}|\x{FEFF}/ /g;
	$text =~ s/\x{02BA}|\x{2033}|\x{201C}|\x{201D}|\x{3003}|\x93|\x94|\x84/"/g;
	$text =~ s/\x{2019}|\x{02B9}|\x{02BC}/'/g;
	$text =~ s/\x{2010}|\x{2011}|\x{2012}|\x{2013}|\x{2212}|\x96|\x97/-/g;
	$text =~ s/\x{266F}/#/g;
	$text =~ s/\x88/^/g;
	$text =~ s/\x8B/</g;
	$text =~ s/\x9C/</g;
	$text =~ s/\x99/~/g;
	$text =~ s/\x91|\x92|\x82/'/g;
	$text =~ s/(\x85)/.../g;
	$text =~ s/(\x97)/x/g;
	$text =~ s/×/x/g;
	$text =~ s/\&#64257;/fi/g;
	$text =~ s/\&#64258;/fl/g;

	return $text;
}


#############################################################################
#
# DATE/TIME manipulation functions

sub epoch2maildate {
	# Returns a mail-header formatted date, based on a given epoch. Current gmtime is used if no epoch is given.

	my @months      = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');

	my $epoch = shift;
	$epoch = time if (!$epoch);
	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = gmtime($epoch);
	return sprintf("%02u %3s %04u %02u:%02u:%02u -0000",$mday,$months[$month],$year+1900,$hour,$min,$sec);
}


sub epoch2mysql {
	my $string = '0000-00-00 00:00:00';
	my $epoch = shift;
	if ($epoch =~ /(\d+)/) {
		if ($1 > 0) {
			my @t = gmtime($1);
			$string = sprintf("%04u-%02u-%02u %02u:%02u:%02u",$t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0]);
		}
	}
	return $string;
}

sub epoch2date {
	# Returns a sql-style date, based on a given epoch. Current gmtime is used if no epoch is given.

	my ($epoch,$timezone,$dst) = @_;

	$epoch = time if (!$epoch);

	# optional timezone shift for local date. Epoch is assumed to always be GMT
	$epoch += 3600 if ($dst && isDST($epoch));
	$epoch += ($timezone * 3600);

	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = gmtime($epoch);
	return sprintf("%04u-%02u-%02u %02u:%02u:%02u",$year+1900,$month+1,$mday,$hour,$min,$sec);
}

sub epoch2datenodash {
	# Returns a sql-style date, based on a given epoch. Current gmtime is used if no epoch is given.

	my ($epoch,$timezone,$dst) = @_;

	$epoch = time if (!$epoch);

	# optional timezone shift for local date. Epoch is assumed to always be GMT
	$epoch += 3600 if ($dst && isDST($epoch));
	$epoch += ($timezone * 3600);

	my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday,$isdst) = gmtime($epoch);
	return sprintf("%04u%02u%02u%02u%02u%02u",$year+1900,$month+1,$mday,$hour,$min,$sec);
}

sub date2epoch {
	my ($date,$timezone,$dst) = @_;

	return 0 if (!$date || ($date eq '0000-00-00 00:00:00') || $date eq '0000-00-00');
	my $epoch = 0;

	my $ok = 0;
	eval {
		if ($date =~ /(\d+)[\\\/\-]+(\d+)[\\\/\-]+(\d+)(\s+(\d+)\:(\d+)\:(\d+))?/) {
			if ($1 < 1900) {
				return 0;
			} else {
				$epoch = timegm($7,$6,$5,$3,$2-1,$1-1900);
			}
	
		} elsif ($date =~ /(\d{4})[\\\/\-]*(\d{2})[\\\/\-]*(\d{2})(\s*(\d{2})\:?(\d{2})\:?(\d{2}))?/) {
			if ($1 < 1900) {
				return 0;
			} else {
				$epoch = timegm($7,$6,$5,$3,$2-1,$1-1900);
			}
		}
		$ok = 1;
	};

	if (!$ok) {
		my $s = "Invalid date2epoch: ".join(',',@_);
		warn "$s\n";
		return 0;
	}

	# optional timezone shift for local date. Epoch is assumed to always be GMT
	$epoch -= ($timezone * 3600);
	$epoch -= 3600 if ($dst && isDST($epoch));

	return $epoch;
}

sub epoch2formatteddate {
	my $string = epoch2date(@_);

	$string =~ /(\d+)-(\d+)-(\d+)\s+(\d+):(\d+):(\d+)/;
	my ($year, $month, $day, $hour, $min, $sec) = ($1,$2,$3,$4,$5,$6);

	my $monthname = '';
	$monthname = 'Jan' if ($month == 1);
	$monthname = 'Feb' if ($month == 2);
	$monthname = 'Mar' if ($month == 3);
	$monthname = 'Apr' if ($month == 4);
	$monthname = 'May' if ($month == 5);
	$monthname = 'Jun' if ($month == 6);
	$monthname = 'Jul' if ($month == 7);
	$monthname = 'Aug' if ($month == 8);
	$monthname = 'Sep' if ($month == 9);
	$monthname = 'Oct' if ($month == 10);
	$monthname = 'Nov' if ($month == 11);
	$monthname = 'Dec' if ($month == 12);

	my $ampm = 'am';
	if ($hour > 12) {
		$hour -= 12;
		$ampm = 'pm';
	} elsif ($hour == 0) {
		$hour = 12;
		$ampm = 'am';
	}

	return sprintf("%s %2s, %04u %02u:%02u %s",$monthname,int($day),$year,$hour,$min,$ampm);
}

sub formatteddate2epoch {
	# Date comes in format:  "Jan 23, 2011 11:55 pm"
	my ($date,$timezone,$dst) = @_;

	$date =~ /(\S+)\s+(\d+),\s+(\d+)\s+(\d+):(\d+)\s+(\S+)/;

	my ($monthname, $day, $year, $hour, $min, $ampm) = ($1,$2,$3,$4,$5,$6);

	$hour += 12 if ($ampm =~ /pm/i);
	$hour = 0 if ($hour >= 24);


	my $month = 0;
	$month =  1 if ($monthname eq 'Jan');
	$month =  2 if ($monthname eq 'Feb');
	$month =  3 if ($monthname eq 'Mar');
	$month =  4 if ($monthname eq 'Apr');
	$month =  5 if ($monthname eq 'May');
	$month =  6 if ($monthname eq 'Jun');
	$month =  7 if ($monthname eq 'Jul');
	$month =  8 if ($monthname eq 'Aug');
	$month =  9 if ($monthname eq 'Sep');
	$month = 10 if ($monthname eq 'Oct');
	$month = 11 if ($monthname eq 'Nov');
	$month = 12 if ($monthname eq 'Dec');

	return date2epoch(sprintf("%04u-%02u-%02u %02u:%02u:%02u",$year,$month,$day,$hour,$min,0),$timezone,$dst);
}


sub sec2string {
	# Returns human-readable times, from a given integer number of seconds:

	my $sec = shift;
	my $abbreviated = shift;

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
	$outstr .= "$sec seconds" if ($sec != 1);
	$outstr .= "$sec second" if ($sec == 1);

	if ($abbreviated) {
		$outstr =~ s/seconds?/sec/g;
		$outstr =~ s/minutes?/min/g;
		$outstr =~ s/hours?/hr/g;
		$outstr =~ s/,\s+/ /g;
	}


	$outstr =~ s/\,\s*$//;
	return $outstr;
}

sub local2gmt {
	my ($date,$timezone,$dst) = @_;
	return $date if (!$timezone && !$dst);

	my $epoch = date2epoch($date);
	$epoch -= ($timezone*3600);
	$epoch -= 3600 if ($dst && isDST($epoch));

	return epoch2date($epoch);
}

sub gmt2local {
	my ($date,$timezone,$dst) = @_;
	return $date if (!$timezone && !$dst);

	my $epoch = date2epoch($date);
	$epoch += 3600 if ($dst && isDST($epoch));
	$epoch += ($timezone*3600);

	return epoch2date($epoch);
}

sub isDST {
   my $epoch = shift;
   $epoch = time  if (!$epoch);
   my ($sec,$min,$hour,$day,$month,$year,$wday,$yday,undef) = gmtime($epoch);
   my (undef,undef,undef,undef,undef,undef,undef,undef,$isdst) = localtime($epoch);

	# ED: (2015-11-10) return perl/linux isDST because we can trust it better now.
	return $isdst;

	# Orig below, with fix for DST ocurring Halloween night.

   $wday++; $month++; $year += 1900;
   my @monthlen = (undef,31,28,31,30,31,30,31,31,30,31,30,31);

   # Leap-Years. We're ignoring the once-per-century skip of the leap year
   # since in 2000, we also had the once-per-millenium skip of the skipping.
   #$monthlen[2]++ if (($year % 4) == 0);
   # not using this currently... honoring historical way of doing 2006 and earlier for now

   if ($year <= 2006) {
      if ((($month > 4) && ($month < 10)) || (($month == 4) && (($wday-$day) < 0)) || (($month == 10) && (($day+$wday) < 30))) {
	 $isdst = 1;
      }
   } else { # 2007+
	my $fix = 0;

	my $firstweekday = (gmtime($epoch-($day-1)*86400))[6];
	$fix = -1 if ($firstweekday == 0);
	#print "$year-$month-$day = $firstweekday $fix\n";

      if ((($month > 3) && ($month < 11)) || (($month == 3) && (($wday-$day) < -7)) || (($month == 11) && (($wday-$day+$fix) >= 0 ))) {
	 $isdst = 1;
      }
   }
   return $isdst;
}



#############################################################################
#
# CSV functions

sub make_csv {
	my $result = '';

	foreach (@_) {
		my $i = btrim($_);
		$i =~ s/[\n\r]+/ /gs;
		$i =~ s/\"/""/gs;
		#$i =~ s/\'/''/gs;

		if ($i !~ /,/ && ($i eq '' || $i =~ /^[\w\d\.\-\_\+]+$/ || $i =~ /^[\w\d\.\-\_\+]+(\s+[\w\d\.\-\_\+]+)*$/)) {
			$result .= ",$i";
		} else {
			$result .= ",\"$i\"";
		}
	}
	$result =~ s/^\,//;
	return $result;
}



sub parse_csv {
	my $text = shift;      # record containing comma-separated values
	my @new  = ();
	push(@new, $+) while $text =~ m{

	# the first part groups the phrase inside the quotes.
	# see explanation of this pattern in MRE
	"([^\"\\]*(?:\\.[^\"\\]*)*)",?
	   |  ([^,]+),?
	   | ,
	}gx;

	push(@new, undef) if substr($text, -1,1) eq ',';
	return @new;      # list of values that were comma-separated
}

sub trim_csv {
	my $text = shift;
	my @v = parse_csv($text);

	for (my $i=0; $i<@v; $i++) {
		$v[$i] =~ s/^\s+//;
		$v[$i] =~ s/\s+$//;
	}

	return @v;
}

sub switchHash {
	my %hash = @_;
	my %newHash;

	foreach (keys %hash) {
		$newHash{$hash{$_}} = $_;
	}

	return(%newHash);
}

sub MD5Date {
	my $epoch = shift;
	my @time = localtime(time);
	@time = localtime($epoch) if ($epoch);
	$time[4]++;

	if ($time[4] < 10) {
		$time[4] = "0".$time[4];
	}

	if ($time[3] < 10) {
		$time[3] = "0".$time[3];
	}

	my $localDate = "$time[4]/$time[3]/" . ($time[5] + 1900);

	return(md5_hex($localDate));
}



#############################################################################
#
# timeout	Wrapper for putting a timeout around some code. Usage:
#
# (5 second timeout in this example):
#
# timeout {
#	# Do something here
# } 5;



sub timeout (&$) {

	my ($code, $duration) = @_;

	alarm 0;
	local $SIG{ALRM} = sub { die "timeout\n"; };
	eval {
		alarm $duration;
		$code->();
		alarm 0;
	};
	alarm 0;

	return $@ if ($@ && $@ !~ /timeout/);
	return '';
	
}


#############################################################################


sub getValue {
   my ($key,$type,$char) = @_;
   $type = "" if (!$type); $char = "" if (!$char);

   $type = "SCALAR" if ($type ne "ARRAY");
   $char = " " if (($type eq "SCALAR") && (!$char));
   my $scalar = "";
   my @array = ();
   if ($type eq "SCALAR") {
      $scalar = $key if (ref($key) ne "ARRAY");
      $scalar = join("$char", @$key) if (ref($key) eq "ARRAY");
      return($scalar);
   }
   if ($type eq "ARRAY") {
      push(@array, $key)  if (ref($key) ne "ARRAY");
      push(@array, @$key) if (ref($key) eq "ARRAY");
      return(@array);
   }
}



#############################################################################

sub btrim {
	my $string = shift;

	$string =~ s/^\s+//;
	$string =~ s/\s+$//;

	return $string;
}

sub ltrim {
	my $string = shift;
	$string =~ s/^\s+//;
	return $string;
}

sub rtrim {
	my $string = shift;
	$string =~ s/\s+$//;
	return $string;
}


#############################################################################

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}

#############################################################################

sub randomize {
	srand(time()^($$+($$ << 15)));
}


#############################################################################


sub count_instances {
	my $count = 0;
	my $kill = shift;
	my $my_progname = shift;

	$my_progname = $progname if (!$my_progname);

	open PS, "/bin/ps awx |";
	while (<PS>) {
		if (/^\s*(\d+)\s+.+perl.+$my_progname/) {
			if ($1 != $$) {
				$count++;
				if ($kill) {
					my_syslog("$progname: killing old instance [$1]");
					kill 'KILL', $1;
				}
			}
		}
		if (/^\s*(\d+)\s+.+\d+\s+$my_progname\s+\d+/) {
			if ($1 != $$) {
				$count++;
				if ($kill) {
					my_syslog("$progname: killing old instance [$1]");
					kill 'KILL', $1;
				}
			}
		}
	}
	close PS;
	return $count;
}

sub my_syslog {
	while (@_) {
		my $message = shift;
		chomp $message;
		next if (!$message);
		$message =~ s/(\^M)?\s*$//;
		setlogsock('unix');
		openlog($progname,"pid","user");
		syslog("info","$message");
		closelog();
	}
}

#############################################################################

1;
