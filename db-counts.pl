#!/usr/bin/perl
use strict;
use lib "/home/bones/perl";
use DB qw(db_mysql);

my $fn = '/home/bones/elite/db-counts.txt';

open TXT, ">$fn";

my %data = ();

foreach my $table (qw(systems navsystems stars planets barycenters)) {
	my $where = $table =~ /navsystems|barycenters/ ? '' : 'where deletionState=0';

	my @rows = db_mysql('elite',"select count(*) as num from $table $where");
	if (@rows) {
		my $num = ${$rows[0]}{num};

#		if ($table eq 'systems') {
#			my @also = db_mysql('elite',"select count(*) as num from navsystems");
#			if (@also) {
#				$num += ${$also[0]}{num};
#			}
#		}

		print "$table: ".commify($num)." \n";
		$data{$table} = $num;
	}
}

print TXT commify($data{systems} + $data{navsystems})." systems (".commify($data{systems})." visited, ".commify($data{navsystems})." route only); \n";
foreach my $table (qw(stars planets barycenters)) {
	print TXT commify($data{$table})." $table; \n";
}
close TXT;

system("/usr/bin/scp $fn www\@services:/www/edastro.com/");

exit;

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}
