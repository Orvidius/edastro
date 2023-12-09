#!/usr/bin/perl
use strict;
use lib "/home/bones/perl";
use DB qw(db_mysql);

db_mysql('elite',"update codex_edsm set isBrainTree=1 where isBrainTree is null and (type like '\%brain\%tree\%' or name like '\%brain\%tree\%')");
db_mysql('elite',"update codex_edsm set isBrainTree=0 where isBrainTree is null and type not like '\%brain\%tree\%' and name not like '\%brain\%tree\%'");
db_mysql('elite',"update codex_edsm set deletionState=0 where deletionState is null");

my @rows = db_mysql('elite',"select codexname.id,codexname.name from codexname,codexname_local where codexname_local.name like '%brain%tree%' and codexnameID=codexname.id");
my %braintrees = ();
foreach my $r (@rows) {
	$braintrees{$$r{id}} = 1;
}
my $btlist = join(',',sort keys %braintrees);

if (keys(%braintrees) && $btlist) {
	db_mysql('elite',"update codex set isBrainTree=0 where isBrainTree is null and nameID not in ($btlist)");
	db_mysql('elite',"update codex set isBrainTree=1 where nameID in ($btlist) and (isBrainTree is null or isBrainTree!=1)");
}

