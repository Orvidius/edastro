#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(make_csv);

############################################################################

print make_csv('Body Type','Count','With rings','With belts','Single Stars','Main/Entry Stars','Primary Stars','Planetary Stars','Stars as Moons')."\r\n";

my %startype = ();

my @rows = db_mysql('elite',"select distinct subType,count(*) as num from stars,systems where id64=systemId64 and systems.name=stars.name group by subType order by subType");
foreach my $r (@rows) {
	my $type = $$r{subType};
	$type = 'NULL' if (!$type);
	$startype{single}{$type} = $$r{num};
}

my @rows = db_mysql('elite',"select distinct subType,count(*) as num from stars where CAST(name as binary) rlike ' A\$' group by subType order by subType");
foreach my $r (@rows) {
	my $type = $$r{subType};
	$type = 'NULL' if (!$type);
	$startype{main}{$type} = $$r{num} + $startype{single}{$type};
}

my @rows = db_mysql('elite',"select distinct subType,count(*) as num from stars where CAST(name as binary) rlike ' [A-Z]\$' group by subType order by subType");
foreach my $r (@rows) {
	my $type = $$r{subType};
	$type = 'NULL' if (!$type);
	$startype{primary}{$type} = $$r{num};
}

my @rows = db_mysql('elite',"select distinct subType,count(*) as num from stars where CAST(name as binary) rlike ' [A-Z]+ [0-9]+\$' group by subType order by subType");
foreach my $r (@rows) {
	my $type = $$r{subType};
	$type = 'NULL' if (!$type);
	$startype{planetary}{$type} = $$r{num};
}

my @rows = db_mysql('elite',"select distinct subType,count(*) as num from stars where CAST(name as binary) rlike ' [0-9]+( [a-z])+\$' group by subType order by subType");
foreach my $r (@rows) {
	my $type = $$r{subType};
	$type = 'NULL' if (!$type);
	$startype{moon}{$type} = $$r{num};
}

my @rows = db_mysql('elite',"select distinct subType,count(*) as num from stars group by subType order by subType");
my $total = 0;
foreach my $r (@rows) {
	my $type = $$r{subType};
	$type = 'NULL' if (!$type);

	my ($belts,$rings) = (undef,undef);

	my @count = ();

	@count = db_mysql('elite',"select count(distinct stars.starID) as num from stars,belts where planet_id=stars.starID and subType=?",[($$r{subType})]) if ($$r{subType});
	@count = db_mysql('elite',"select count(distinct stars.starID) as num from stars,belts where planet_id=stars.starID and (subType='' or subType is null)") if (!$$r{subType});

	if (@count ) { $belts =  ${$count[0]}{num}; }

	@count = ();

	@count = db_mysql('elite',"select count(distinct stars.starID) as num from stars,rings where isStar=1 and planet_id=stars.starID and subType=?",[($$r{subType})]) if ($$r{subType});
	@count = db_mysql('elite',"select count(distinct stars.starID) as num from stars,rings where isStar=1 and planet_id=stars.starID and (subType='' or subType is null)") if (!$$r{subType});

	if (@count ) { $rings  = ${$count[0]}{num}; }

	print make_csv($type,$$r{num},$rings,$belts,$startype{single}{$type},$startype{main}{$type},$startype{primary}{$type},$startype{planetary}{$type},$startype{moon}{$type})."\r\n";
	$total += $$r{num};
}
print "\r\n";

my @rows = db_mysql('elite',"select count(*) as num from stars where CAST(name as BINARY) ".
		"rlike '[A-Z][A-Z]\\\\-[A-Z] [a-h]([[:digit:]]+\\\\-)?[[:digit:]]+ [[:digit:]]+[[:space:]]*\$'");
print make_csv('Stars as planets',${$rows[0]}{num})."\r\n";

my @rows = db_mysql('elite',"select count(distinct planet_id) as num from belts where isStar=1");
print make_csv('Stars with belts',${$rows[0]}{num})."\r\n";

my @rows = db_mysql('elite',"select count(distinct planet_id) as num from rings where isStar=1");
print make_csv('Stars with rings',${$rows[0]}{num})."\r\n";

print make_csv('Total Stars',$total)."\r\n\r\n";

############################################################################

print make_csv('Body Type','Count','With rings','Planets','Moons')."\r\n";

my %planettype = ();

my @rows = db_mysql('elite',"select distinct subType,count(*) as num from planets where CAST(name as binary) rlike ' [A-Z]+ [0-9]+\$' group by subType order by subType");
foreach my $r (@rows) {
	my $type = $$r{subType};
	$type = 'NULL' if (!$type);
	$planettype{planetary}{$type} = $$r{num};
}

my @rows = db_mysql('elite',"select distinct subType,count(*) as num from planets where CAST(name as binary) rlike ' [0-9]+( [a-z])+\$' group by subType order by subType");
foreach my $r (@rows) {
	my $type = $$r{subType};
	$type = 'NULL' if (!$type);
	$planettype{moon}{$type} = $$r{num};
}

my @rows = db_mysql('elite',"select distinct subType,count(*) as num from planets group by subType order by subType");
my $total = 0;
foreach my $r (@rows) {
	my $type = $$r{subType};
	$type = 'NULL' if (!$type);

	my ($belts,$rings) = (undef,undef);

	my @count = ();

	@count = db_mysql('elite',"select count(distinct planets.planetID) as num from planets,rings where planet_id=planets.planetID ".
			"and isStar=0  and subType=?",[($$r{subType})]) if ($$r{subType});
	@count = db_mysql('elite',"select count(distinct planets.planetID) as num from planets,rings where planet_id=planets.planetID ".
			"and isStar=0 and (subType='' or subType is null)") if (!$$r{subType});

	if (@count) { $rings = ${$count[0]}{num}; }

	print make_csv($type,$$r{num},$rings,$planettype{planetary}{$type},$planettype{moon}{$type})."\r\n";
	$total += $$r{num};
}
print "\r\n";

my @rows = db_mysql('elite',"select count(*) as num from planets where CAST(name as BINARY) ".
		"rlike '[A-Z][A-Z]\\\\-[A-Z] [a-h]([[:digit:]]+\\\\-)?[[:digit:]]+ [[:digit:]]+[[:space:]]*\$'");
print make_csv('Planets as planets',${$rows[0]}{num})."\r\n";

my @rows = db_mysql('elite',"select count(*) as num from planets where CAST(name as BINARY) ".
		"rlike '[A-Z][A-Z]\\\\-[A-Z] [a-h]([[:digit:]]+\\\\-)?[[:digit:]]+ [[:digit:]]+( [a-z])+[[:space:]]*\$'");
print make_csv('Planets as moons',${$rows[0]}{num})."\r\n";

my @rows = db_mysql('elite',"select count(distinct planet_id) as num from rings where isStar=0");
print make_csv('Planets with rings',${$rows[0]}{num})."\r\n";

print make_csv('Total Planets',$total)."\r\n\r\n";

############################################################################

my @rows = db_mysql('elite',"select count(*) as num from systems");
my $num_systems = ${$rows[0]}{num};
my @rows = db_mysql('elite',"select count(distinct systemId64) as num from stars");
my $star_systems = ${$rows[0]}{num};
my @rows = db_mysql('elite',"select count(distinct systemId64) as num from planets");
my $planet_systems = ${$rows[0]}{num};

print make_csv('Systems with Stars',$star_systems)."\r\n";
print make_csv('Systems with Planets',$planet_systems)."\r\n";
print make_csv('Total Systems',$num_systems)."\r\n\r\n";

############################################################################








