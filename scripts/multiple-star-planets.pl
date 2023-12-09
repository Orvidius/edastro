#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

use Image::Magick;

############################################################################

my %count   = ();
my %planet  = ();
my $pattern = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

show_queries(0);

my $limit = ''; 
#$limit = 'limit 100000';

my @sysIDs = ();
my $count = 0;

my @rows = db_mysql('elite',"select distinct systemId64 as id64 from planets where deletionState=0");
while (@rows) {
	my $r = shift @rows;
	push @sysIDs, $$r{id64} if ($$r{id64});
}
warn int(@sysIDs)." systems to consider.\n";

while (@sysIDs) {
	my @ids = splice(@sysIDs,0,1000);
	last if (!@ids);

	my $list = join(',',@ids);

	my @rows = db_mysql('elite',"select planetID,systemId64,name from planets where systemId64 in ($list) and deletionState=0 $limit");

	#warn int(@rows)." planets to investigate.\n";

	while (my $r = shift @rows) {
		if ($$r{name} =~ /\s([A-Z]{5,})\s+\d+\s*$/) {
			my $p = $1;
			next if ($pattern !~ /$p/);
			my $n = length($p);
			$count{$p}{systems}{$$r{systemId64}} = 1;
			$count{$p}{planets}++;
			$count{$n}{systems}{$$r{systemId64}} = 1;
			$count{$n}{planets}++;
			$planet{$$r{planetID}} = $p;
			warn "$$r{name} ($$r{systemId64}) = $p\n" if ($p =~ /^E/);
			$count++;
		}
	}
}
warn "$count found\n";

print "Pattern or Star Count,Systems,Planets\r\n";
foreach my $p (sort { ($a =~ /\d/ && $b =~ /\d/ && $a <=> $b) || $a cmp $b } keys %count) {
	print "$p,".int(keys(%{$count{$p}{systems}})).",$count{$p}{planets}\r\n";
}

$count = 0;

print "\r\n".make_csv('System','Planet','Type','Stars orbited','Pattern','RegionID')."\r\n";
foreach my $id (sort { length($planet{$b}) <=> length($planet{$a}) || $planet{$a} cmp $planet{$b} || $a <=> $b} keys %planet) {
	next if (!$id);

	my @rows = db_mysql('elite',"select systems.name sysname,planets.name planetname,subType,region regionID from ".
			"systems,planets where systems.id64=planets.systemId64 and planetID=$id");
	if (@rows) {
		my $r = shift @rows;
		print make_csv($$r{sysname},$$r{planetname},$$r{subType},length($planet{$id}),$planet{$id},$$r{regionID})."\r\n";
		$count++;
	}
}

warn "$count posted.\n";

