#!/usr/bin/perl
use strict;

use lib "/home/bones/perl";
use EMAIL qw(sendMail);

my $count = `ls -R /home/bones/elite/eddn-data/queue | wc -l`;
chomp $count;

if ($count > 5000) {
	print "Queue is backing up: $count\n";
	sendMail('ed@toton.org','elite@toton.org',"EDDN Queue is backing up: $count","EDDN Queue is backing up: $count");
} else {
	print "Queue is fine: $count\n";
}
