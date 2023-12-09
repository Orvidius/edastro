#!/usr/bin/perl
use strict; $|=1;

use Data::Dumper;

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);

use lib "/home/bones/elite";
use EDSM qw(completion_report);

die "Usage: $0 <system/boxel>\n" if (!@ARGV);

foreach my $sys (@ARGV) {
	print "$sys:\n";
	my %hash = completion_report($sys);

	print Dumper(\%hash)."\n\n";
}
