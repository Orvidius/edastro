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

print make_csv('Region','System','ID64','Star type','Earth-like world','Rings','Moons','Gas giants','Bodies (excluding star)','RegionID')."\r\n";

my $ref = rows_mysql('elite',"select planetID,systemId64,name from planets where subType='Earth-like world' and deletionState=0 and name like '\% 3' order by name");

foreach my $r (@$ref) {
	my $out = "$$r{planetID}: $$r{name} [$$r{systemId64}]";
	my $startype = '';

	my @stars = db_mysql('elite',"select starID,subType from stars,systems where systemId64=? and stars.deletionState=0 and systems.deletionState=0 and ".
			"subType='G (White-Yellow) Star' and systemId64=id64 and stars.name=systems.name",[($$r{systemId64})]);
	if (@stars!=1) {
		warn "$out - No qualifying star\n";
		next;
	} else {
		$startype = ${$stars[0]}{subType};
	}

	my @system = db_mysql('elite',"select systems.name,regions.name regionname,coord_x,coord_y,coord_z,region from systems,regions where id64=? and ".
			"deletionState=0 and region=regions.id",[($$r{systemId64})]);
	if (!@system) {
		warn "$out - No System\n";
		next;
	}

	my $sys = shift @system;
	if ($$r{name} ne "$$sys{name} 3") {
		warn "$out - Planet name not system+3: $$r{name} ($$sys{name})\n";
		next;
	}

	my $safename = $$r{name};
	$safename =~ s/(['"\\_])/\\$1/gs;

	#my @moons = db_mysql('elite',"select name from planets where systemId64=? and deletionState=0 and CAST(name as binary) rlike ' 3( [a-z])+\$'");
	my @moons = db_mysql('elite',"select planetID from planets where systemId64=? and deletionState=0 and name like '$safename \%'",[($$r{systemId64})]);
	if (!int(@moons)) {
		warn "$out - No moons\n";
		next;
	}
	if (int(@moons)>1) {
		warn "$out - Too many moons (".int(@moons).")\n";
		next;
	}


	my @rings = db_mysql('elite',"select id from rings where isStar=0 and planet_id=?",[($$r{planetID})]);
	if (@rings) {
		warn "$out - Has rings\n";
		next;
	}

	my @giants = db_mysql('elite',"select planetID,subType,name from planets where systemId64=? and deletionState=0 and subType like '\%giant\%'",[($$r{systemId64})]);
	if (!@giants) {
		#warn "$out - No gas giants\n";
		#next;
	}
	my $bad = 0;
	foreach my $g (@giants) {
		$bad++ if ($$g{name} =~ /^$$sys{name} [12]\s*$/);
	}
	if ($bad) {
		warn "$out - Inner gas giants\n";
		next;
	}

	my @bodies = db_mysql('elite',"select count(*) num from planets where systemId64=? and deletionState=0",[($$r{systemId64})]);
	my $bodycount = ${$bodies[0]}{num};

	# If we get this far, it's a candidate
	warn "$out - GOOD\n";
	print make_csv($$sys{regionname},$$sys{name},$$r{systemId64},$startype,$$r{name},int(@rings),int(@moons),int(@giants),$bodycount,$$sys{region})."\r\n";
}


