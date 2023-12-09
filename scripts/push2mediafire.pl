#!/usr/bin/perl
use strict;
$|=1;

my $remote_dir = 'tehvb96bla20q'; # Elite-EDAstro
my $fn = $ARGV[0];

die "Usage: $0 <filename>\n" if (!$fn);

my %file = ();

open DATA, "/usr/bin/printf \"cd $remote_dir\\nls\\nquit\" | /usr/local/bin/mediafire-shell 2>\&1 |";
while (<DATA>) {
	#print "> $_";
	chomp;
	if (/^\s*([\w\d]+)\s+(\S+)\s*$/) {
		#print "$1 = $2\n";
		$file{$2} = $1;
	}
}
close DATA;

if ($file{$fn}) {
	print "Removing $file{$fn} ($fn)\n";
	system("/usr/bin/printf \"cd $remote_dir\\nrm $file{$fn}\\nquit\" | /usr/local/bin/mediafire-shell");
}

print "!! Uploading $fn\n";
system("/usr/bin/printf \"cd $remote_dir\\nput $fn\\nquit\" | /usr/local/bin/mediafire-shell");



#   direct url:       http://download1584.mediafire.com/mo5txxhbiaag/0hijp7q4gqem1ue/dump-wolf-rayet.zip

