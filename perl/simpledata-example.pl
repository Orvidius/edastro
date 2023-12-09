#!/usr/bin/perl
use strict; $|=1;
use Data::Dumper;
use SimpleData;

###########
# Open an object, using an existing path. Will create a DB directory within it.
# This should use a full path from the root level, not a relative directory.

my $db = new SimpleData('/tmp/simpledata',0)	# 1 = verbose, 0 = quiet, or omit for quiet
	or die "Could not open data path\n";

###########
# These are the defaults, but defined here so you can change them:

$db->setMaxHandles(100);	# Number of file handles that triggers an expiration. Oldest are expired first to get back beneath this number.
$db->setPruneSeconds(600);	# Minimum seconds between prunings of empty directories. Scans entire heirarchy, forked process.


###########
# Testing the data storage and retrieval:


my %hash = ();
$hash{test} = 'something';
$hash{sample} = 'example';
$hash{nested}{data}{example} = "some string";

my $key = 'A TEST KEY';			# Keys can be arbitrary strings
#my $value = 'This is a test value.';	# Value can be a scalar (string, number, etc)
my $value = \%hash;			# Value can also be a hash or array reference, and data will be JSON-encoded on disk.


###########
# Read/write/delete methods:

$db->write($key,$value);
print "KEY: $key\n".Dumper($db->read($key))."\n";

$db->write('key1','value1');
$db->write('key2','value2');
$db->write('key3','temp value');
$db->write('key3','value3');	# overwrite

print "key3: ".$db->read('key3')."\n";


###########
# Returns all stored keys, as array-reference:

my $keys = $db->getKeys();
print "Keys: \"".join('", "',@$keys)."\"\n" if (@$keys);


###########
# Returns stored keys with optional regex pattern, as array-reference:

my $keys = $db->getKeys('key\d');	# Contains case-senstive "key" in key name followed by digit

print "Keys: \"".join('", "',@$keys)."\"\n" if (@$keys);


###########
# Returns data with keys following pattern (or no pattern to return all data), as hash reference:

my $hashref = $db->getData('key\d+');

print "Data: ".Dumper($hashref)."\n";


###########
# Delete entry:

$db->delete($key);


###########
# Force a directory pruning (optional)

$db->prune();

print "\n";

