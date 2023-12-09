#!/usr/bin/perl
use strict; $|=1;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my $zcat 	= '/usr/bin/zcat';
my $grep 	= '/usr/bin/grep';

my $archive	= '/home/bones/elite/archive';
my @files	= ('bodies-20200323.json.gz');

opendir DIR, $archive;
while (my $fn = readdir DIR) {
	if ($fn =~ /^bodies7days-(\d+)\.json.gz/) {
		if ($1 > 20200323) {
			push @files, $fn;
		}
	}
}
closedir DIR;

my $count = 0;

foreach my $fn (@files) {
	open TXT, "$zcat $archive/$fn | $grep id64 |";
	while (<TXT>) {
		my $type = 0;
		my $id64 = 0;
		my $edsmID = 0;

		if (/\"type\"\s*:\s*\"(\w+)\"/) {
			$type = $1;
		}

		if (/\"id64\"\s*:\s*(\d+)/) {
			$id64 = $1;
		}

		if (/\"id\"\s*:\s*(\d+)/) {
			$edsmID = $1;
		}

		if ($edsmID && $id64 && $type) {
			db_mysql('elite',"update stars set bodyId64=? where edsmID=?",[($id64,$edsmID)]) if (lc($type) eq 'star');
			db_mysql('elite',"update planets set bodyId64=? where edsmID=?",[($id64,$edsmID)]) if (lc($type) eq 'planet');
			if (lc($type) =~ /^(star|planet)$/) {
				$count++;
			} else {
				print '!';
			}
			print "." if ($count % 1000 == 0);
			print "\n" if ($count % 100000 == 0);
		}
	}
	close TXT;
}
