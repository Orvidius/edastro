#!/usr/bin/perl
use strict; $|=1;

use lib "/home/bones/perl";
use DB qw(db_mysql);
use ATOMS qw(date2epoch epoch2date);


my $read_old	= 0;
my $where	= "name like 'GMB2010\%'";


open my $fh, '<:raw', 'VSC-templates.dat';

my $bytes_read = read $fh, my $header, 48;

my $header_start = substr($header,0,24);
my $header_end = substr($header,28,20);
my $count = unpack 'L', substr($header,24,4);

print "$count previous entries.\n";

my %system = ();
my %date = ();
my @order = ();

for (my $i=0; $i<$count; $i++) {
	my $bytes_read = read $fh, my $entry, 16;
	
	if ($read_old) {
		my $id64 =  unpack('Q', substr($entry,0,8));
	
		push @order, $id64 if (!exists($system{$id64}));
	
		$system{$id64} = 0; #unpack 'L', substr($entry,8,4);
		$date{$id64} = unpack 'L', substr($entry,12,4);
	}
}

my $bytes_read = read $fh, my $footer, 8;

close $fh;

#TESTING
# | Sol  | 10477373803 | 27080096B |
#foreach my $id64 (sort keys %system) {
#	print "$id64 = $system{$id64}\n";
#}

my @rows = db_mysql('elite',"select id64,date_added as date from systems where id64 is not null and $where order by date_added");

my $today = get_date(time);

foreach my $r (@rows) {
	my $id64 = $$r{id64};

	push @order, $id64 if (!exists($system{$id64}));
	$system{$id64}++;

	$$r{date} = epoch2date(time) if (!$$r{date} || $$r{date} =~ /0000-00-00/ || $$r{date} lt '2000-01-01 00:00:00');

	my $d = get_date(date2epoch($$r{date}));
	$date{$id64} = $d if (!$date{$id64} || $d > $date{$id64});
}

print "Writing ".int(keys %system)." total entries.\n";

open $fh, '>:raw', 'VisitedStarsCache.dat';
print $fh $header_start;
print $fh pack 'L', int(keys %system);
print $fh $header_end;

foreach my $id64 (@order) {
	print $fh pack('Q', $id64);
	print $fh pack('L', $system{$id64});
	print $fh pack('L', $date{$id64});
}

print $fh $footer;
close $fh;

print "done.\n";

exit;


sub get_date {
	my $epoch = shift;
	return 153199 + ($epoch-date2epoch("2020-06-12 12:00:00"))/86400
}
