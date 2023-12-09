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

show_queries(0);

#Pull the whole thing in a slow join:
#
#my @rows = db_mysql('elite',"select distinct planets.name as moonName,planets.subType as moonType,planets.semiMajorAxis*149597871 as orbitalRadius,".
#	"planets.commanderName,p.innerRadius as ringInnerRadius,p.outerRadius as ringOuterRadius,p.name as parentName,p.subType as parentType from ".
#	"(select planets.name,planets.id,planets.subType,rings.innerRadius,rings.outerRadius from planets,rings where rings.planet_id=planets.id and rings.isStar!=1) as p,planets ".
#	"where planets.name like CONCAT(p.name,' %') and planets.id!=p.id and semiMajorAxis*149597871<outerRadius");

my @table = ();
my %done = ();
my %system = ();

my @rows = db_mysql('elite',"select distinct planets.planetID,planets.systemId64,planets.name as parentName,subType as parentType from planets,rings where ".
			"rings.planet_id=planets.planetID and rings.isStar!=1 and deletionState=0"); 

warn "Found ".int(@rows)." ringed planets.\n";

my $count = 0;
while (@rows) {
	my $r = shift @rows;

	push @{$system{$$r{systemId64}}}, $r;
}

warn "Found ".int(keys %system)." systems.\n";

my $n = 0;

foreach my $sys (keys %system) {
	next if (!$sys);

	my @rows = @{$system{$sys}};

	$n++;
	warn "$n / ".int(keys %system)."\n" if ($n % 10000 == 0);
	#warn "SysID=$sys, rows=".int(@rows)."\n";
	
	my @rows2 = db_mysql('elite',"select planetID,name as moonName,parents,subType as moonType,semiMajorAxis*149597871 as orbitalRadius,commanderName,discoveryDate ".
			"from planets where systemId64='$sys' and semiMajorAxis is not null and semiMajorAxis>0 and (parents is null or parents like 'Planet\%') and deletionState=0");

	foreach my $r (@rows) {

		$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{planetID} = 0 if (!defined($$r{planetID}));

		my @rings = db_mysql('elite',"select * from rings where planet_id='$$r{planetID}' order by outerRadius");

		next if (@rings<=1);	# Only continue if more than one ring.

		my $innerradius = ${$rings[0]}{innerRadius};
		@rings = reverse @rings;
		my $outerradius = ${$rings[0]}{outerRadius};	# outermost radius of outermost remaining ring

		foreach my $r2 (sort {$$a{moonName} cmp $$b{moonName}} @rows2) {

			my $parent = $$r2{moonName};
			$parent =~ s/\s+(\w+)\s*$//s;
			my $moon = $1;

			#warn "Comparing $$r{parentName}, $$r2{moonName} ($parent) [$moon] $$r2{parents}\n";

			next if ($$r2{parents} && ($$r2{parents} =~ /^Null/));
			next if ($done{$$r2{moonName}});
			#next if ($$r2{moonName} !~ /^$$r{parentName}\s+\w+\s*$/i);	# Must be one level of nesting, and moon of current planet
			next if (uc($parent) ne uc($$r{parentName}));			# Must be one level of nesting, and moon of current planet
			next if ($$r2{planetID} == $$r{planetID});			# Cannot be moon of itself
			next if ($$r2{orbitalRadius}>$outerradius);
			next if ($$r2{orbitalRadius}<$innerradius && (!$$r2{parents} || $$r2{parents} =~ /^\s*$/s));

#			if ($moon =~ /^[a-zA-Z]$/ && uc($moon) ne 'A') {
#				foreach my $m ('A'..'Z') {
#					if (!$done{"$parent ".uc($m)} && !$done{"$parent ".lc($m)}) {
#						next;
#					}
#				}
#			} 
	
			my %hash = (%$r, %$r2);

			$hash{orbittype} = 'shepherd';
			$hash{orbittype} = 'inner' if ($$r2{orbitalRadius}<$innerradius);

			$hash{innerRadius} = $innerradius;
			$hash{outerRadius} = $outerradius;

			push @table, \%hash;
			$count++;
			$done{$$r2{moonName}} = 1;
		}

		#last if ($count>=10);
	}
	#last if ($count>=10);
}

print make_csv('Moon','Moon Type','EDSM Discoverer','EDSM Date','Type','Orbital Radius','Ring(s) Inner Radius','Ring(s) Outer Radius','Parent Body','Parent Type')."\r\n";

my $count = 0;
foreach my $r (sort {$$a{moonName} cmp $$b{moonName} || $$a{innerRadius} <=> $$b{innerRadius}} @table) {

	print make_csv($$r{moonName},$$r{moonType},$$r{commanderName},$$r{discoveryDate},$$r{orbittype},sprintf("%.02f",$$r{orbitalRadius}),
		$$r{innerRadius},$$r{outerRadius},$$r{parentName},$$r{parentType})."\r\n";

	$count++;
}
warn "$count found\n";



