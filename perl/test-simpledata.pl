#!/usr/bin/perl
use strict; $|=1;

use Data::Dumper;

use lib "/home/bones/perl";
use SimpleData;

print "\n---------\n";

my $db = new SimpleData('/tmp/simpledata',0)	# 1 = verbose, 0 = quiet, or omit for quiet
	or die "Could not open data path\n";

#$db->setMaxHandles(5000);	# Number of file handles that triggers an expiration. Oldest are expired first to get back beneath this number.
#$db->setMaxHandleAge(600);	# Any file handles older than 10 minutes will also expire when an expiration is triggered.
#$db->setPruneSeconds(300);	# Minimum seconds between prunings of empty directories. Scans entire heirarchy, forked process.


if (0) {
	# Testing the key/filename conversions

	my $string = "This is a TEST! \$1234 + 1.00\%";

	my $safe = $db->key2keysafe($string);
	my $key  = $db->keysafe2key($safe);
	my $path = $db->key2filename($string);

	print "$string\n$safe\n$key\n$path\n";

	print "\n";
}


# Testing the actual data storage and retrieval:

my $n=0;
print "Creating\n";
while ($n<100000) {
	$db->write("example$n","data$n");
	$n++;
}



my $n=0;
print "Deleting\n";
while ($n<100000) {
	$db->delete("example$n","data$n");
	$n++;
}

$db->prune();
