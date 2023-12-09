#!/usr/bin/perl
use strict;
$|-1;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my @rows = db_mysql('elite',"select max(ID) maxID from systems");
my $maxID = ${$rows[0]}{maxID};

my $chunk_size = 50000;

my $chunk = 0;

while ($chunk < $maxID) {
	print commify($chunk)."\n";
	db_mysql('elite',"update systems set updateTime=edsm_date where ID>=? and ID<? and updateTime is null",[($chunk,$chunk+$chunk_size)]);
	$chunk += $chunk_size;
}

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}
