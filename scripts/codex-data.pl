#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

############################################################################

show_queries(0);

my %codexname = ();
my %codextype = ();

my @rows = db_mysql('elite',"select id,name from codexname");
foreach my $r (@rows) {
	my @rows2 = db_mysql('elite',"select name from codexname_local where codexnameID=? order by preferred desc limit 1",[($$r{id})]);
	if (@rows2) {
		$codexname{$$r{id}} = ${$rows2[0]}{name};
	}
	$codextype{$$r{id}} = $$r{name};
}

my %region = ();

my @rows = db_mysql('elite',"select id,name from regions");
foreach my $r (@rows) {
	$region{$$r{id}} = $$r{name};
}

my %data = ();
my @rows = db_mysql('elite',"select systems.name sysname,coord_x,coord_y,coord_z,MainStarType,id64,region,
		nameID,regionID,reportedOn,odyssey from systems,codex where id64=systemId64 and systems.deletionState=0 and codex.deletionState=0");

#print make_csv("System","X","Y","Z","Main Star Type","System Address / ID64","Region","Codex Entry","Codex ID","First Reported")."\r\n";
print make_csv("Codex Entry","Codex ID","First Reported","Odyssey","Region","System","X","Y","Z","Main Star Type","System Address / ID64")."\r\n";

foreach my $r (@rows) {
	my $local = $codexname{$$r{nameID}};

	my $reg = '';
	$reg = $region{$$r{regionID}} if ($$r{regionID} && $region{$$r{regionID}});
	$reg = $region{$$r{region}} if (!$reg && $$r{region} && $region{$$r{region}});

	#$data{$$r{local}}{$$r{sysname}} = make_csv($$r{sysname},$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{MainStarType},$$r{id64},$reg,$local,$codextype{$$r{nameID}},$$r{reportedOn});

	$data{$local}{$$r{sysname}} = make_csv($local,$codextype{$$r{nameID}},$$r{reportedOn},$$r{odyssey},$reg,$$r{sysname},
			$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{MainStarType},$$r{id64});
}

foreach my $name (sort keys %data) {
	foreach my $system (sort keys %{$data{$name}}) {
		print $data{$name}{$system}."\r\n";
	}
}



