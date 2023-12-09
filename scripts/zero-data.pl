#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

use POSIX qw(floor);

############################################################################

my $debug_limit = ''; #'limit 10';

my @what = ();

die "Usage: <1/2/3> <column>\n" if ($ARGV[0] !~ /^([123])$/ && $ARGV[1] !~ /^[\w\d]+$/);

push @what, 'planets' if (@ARGV[0] & 1 == 1);	# 0 = nothing (why?), 1 = planets, 2 = stars, 3 = both
push @what, 'stars'   if (@ARGV[0] & 2 == 1);

my $column = $ARGV[1];
$column =~ s/[^\w\d]+//gs;

show_queries(0);

my %hash = ();
my @rows = ();

foreach my $type (@what) {
	push @rows, db_mysql('elite',"select systemId64,systemId,systems.name,$type.name body,sol_dist,coord_x,coord_z,$type.id as bodyID from systems,$type where id64=systemId64 ".
		"and ($column is null or $column=0) and systems.deletionState=0 and $type.deletionState=0 $debug_limit");
}

print "ID64 SystemAddress,EDSM ID,Region,Name,Sol Distance,Bodies\r\n";

foreach my $r (sort {${$a}{body} cmp ${$b}{body}} @rows) {

	#next if (exists($hash{$$r{systemId64}}));

	my $regex =  $$r{name};
	my $body = $$r{body};
	$regex =~ s/\-/\\-/gs;
	$body =~ s/$regex\s*//gs;

	$hash{$$r{systemId64}}{name} = $$r{name};
	$hash{$$r{systemId64}}{sol_dist} = $$r{sol_dist};
	$hash{$$r{systemId64}}{bodies} .= ", $body";
	$hash{$$r{systemId64}}{bodyIDs} .= ",$$r{bodyID}";

	if (!$hash{$$r{systemId64}}{region}) {
		my @reg = db_mysql('elite',"select name from regions,regionmap where region=id and coord_x=? and coord_z=?",[(floor($$r{coord_x}/10),floor($$r{coord_z}/10))]);
	
		if (@reg) {
			$hash{$$r{systemId64}}{region} = ${$reg[0]}{name};
		}
	}
}

foreach my $sid (sort {$hash{$a}{region} cmp $hash{$b}{region} || $hash{$a}{sol_dist} cmp $hash{$b}{sol_dist}} keys %hash) {
	my $r = $hash{$sid};
	$$r{bodies} =~ s/^[,\s]+//s;
	$$r{bodyIDs} =~ s/^[,\s]+//s;
	print make_csv($sid,$$r{systemId},$$r{region},$$r{name},$$r{sol_dist},$$r{bodies},$$r{bodyIDs})."\r\n";
}
	

