#!/usr/bin/perl
use strict;

############################################################################

use POSIX qw(floor);
use Math::Trig;
use Data::Dumper;

use lib "/home/bones/elite";
use EDSM qw(log10 update_systemcounts);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

#############################################################################

show_queries(0);

#exit;

$0 =~ s/^.*\///s;
my $progname = $0;

my $debug               = 0;
my $minutes		= 35;
my $db			= 'elite';
my $chunk_size		= 10000;

#############################################################################

my %sys = ();

if ($ARGV[0] =~ /^\d+$/) {
	if ($ARGV[0] <= 10) {
		my $rows = rows_mysql($db,"select distinct systemId64 from logs where cmdrID=?",[($ARGV[0])]);
		if (ref($rows) eq 'ARRAY') {
			foreach my $r (@$rows) {
				$sys{$$r{systemId64}} = 1;
			}
		}
	} else {
		foreach my $id (@ARGV) {
			$sys{$id} = 1;
		}
	}
} elsif ($ARGV[0] eq 'poi') {
	my $rows = rows_mysql($db,"select distinct systemId64 from POI");
	if (ref($rows) eq 'ARRAY') {
		foreach my $r (@$rows) {
			$sys{$$r{systemId64}} = 1;
		}
	}
} elsif ($ARGV[0] eq 'missing') {
	my $limit = '';

	if ($ARGV[1] =~ /^\d+$/) {
		$limit = "limit $ARGV[1]";
	}

	my $rows = rows_mysql($db,"select distinct id64 from systems where (numStars is null or numPlanets is null or numTerra is null or numLandables is null or numELW is null or numAW is null or numWW is null) and deletionState=0 $limit");
	if (ref($rows) eq 'ARRAY') {
		foreach my $r (@$rows) {
			$sys{$$r{id64}} = 1;
		}
	}
} elsif ($ARGV[0] eq 'all') {

	my $done = 0;
	my $n = 0;

	my @rows = db_mysql($db,"select max(ID) as maxID from systems");
	my $maxID = ${$rows[0]}{maxID};

	my $id = 00000000;

	while ($id < $maxID) {


	    if (0) {
		my @rows = db_mysql($db,"select id64,IFNULL(planetnum,0) planetnum,IFNULL(starnum,0) starnum,IFNULL(elwnum,0) elwnum,IFNULL(awnum,0) awnum,IFNULL(wwnum,0) wwnum from systems ".
		"left join (select systemId64,count(*) as planetnum from planets where deletionState=0 group by systemId64) as p on p.systemId64=systems.id64 ".
		"left join (select systemId64,count(*) as starnum from stars where deletionState=0 group by systemId64) as s on s.systemId64=systems.id64 ".
		"left join (select systemId64,count(*) as elwnum from planets where subType='Earth-like world' and deletionState=0 group by systemId64) as e on e.systemId64=systems.id64 ".
		"left join (select systemId64,count(*) as awnum from planets where subType='Ammonia world' and deletionState=0 group by systemId64) as a on a.systemId64=systems.id64 ".
		"left join (select systemId64,count(*) as wwnum from planets where subType='Water world' and deletionState=0 group by systemId64) as w on w.systemId64=systems.id64 ".
		"left join (select systemId64,count(*) as terranum from planets where terraformingState='Candidate for terraforming' and deletionState=0 group by systemId64) as t on t.systemId64=systems.id64 ".
		"left join (select systemId64,count(*) as landables from planets where isLandable=1 and deletionState=0 group by systemId64) as t on t.systemId64=systems.id64 ".
		"where ID>=? and ID<? and (numStars is null or numPlanets is null or numTerra is null or numELW is null or numAW is null or numWW is null)",[($id,$id+$chunk_size)]);

		foreach my $r (@rows) {
			db_mysql($db,"update systems set numStars=?,numPlanets=?,numELW=?,numAW=?,numWW=?,numTerra=?,numLandables=?,updated=updated where id64=? and ".
				"(numstars is null or numplanets is null or numstars!=? or numplanets!=? or numTerra is null or ".
				"numELW!=? or numELW is null or numAW!=? or numAW is null or numWW!=? or numWW is null or numTerra!=? or numLandalbes is null or numLandables!=?)",
				[($$r{starnum},$$r{planetnum},$$r{elwnum},$$r{awnum},$$r{wwnum},$$r{terranum},$$r{landables},$$r{id64},
				  $$r{starnum},$$r{planetnum},$$r{elwnum},$$r{awnum},$$r{wwnum},$$r{terranum},$$r{landables})]);
			}


	    } else {
			%sys = ();
			my @rows = db_mysql($db,"select id64 from systems where ID>=? and ID<? and deletionState=0",[($id,$id+$chunk_size)]);
			while (@rows) {
				my $r = shift @rows;
				$sys{$$r{id64}}++;
			}
			
			do_update(0) if (keys %sys);
	    }

		$id += $chunk_size;
		$n++;
		print '.';
		print " [".int($id)."]\n" if ($n % 100 == 0);
	}
	exit;

} else {

	foreach my $table (qw(stars planets)) {
		my $rows = rows_mysql($db,"select distinct systemId64 from $table where date_added>=date_sub(NOW(),interval $minutes minute)");

		if (ref($rows) eq 'ARRAY') {
			foreach my $r (@$rows) {
				$sys{$$r{systemId64}} = 1;
			}
		}
	}
}

do_update(1) if (keys %sys);

exit;

#############################################################################

sub do_update {
	my $verbose = shift;

	foreach my $id64 (keys %sys) {


		update_systemcounts($id64,$verbose);

		if (0) {
		my @rows = db_mysql($db,"select count(*) as num from stars where systemId64=? and deletionState=0",[($id64)]);
		my $numstars = ${$rows[0]}{num};

		my @rows = db_mysql($db,"select count(*) as num from planets where systemId64=? and terraformingState='Candidate for terraforming' and deletionState=0",[($id64)]);
		my $numterra = ${$rows[0]}{num};

		my @rows = db_mysql($db,"select count(*) as num from planets where systemId64=? and isLandable=1 and deletionState=0",[($id64)]);
		my $numlandables = ${$rows[0]}{num};

#		my @rows = db_mysql($db,"select count(*) as num from planets where systemId64=? and deletionState=0",[($id64)]);
#		my $numplanets = ${$rows[0]}{num};
#
#		my @rows = db_mysql($db,"select count(*) as num from planets where systemId64=? and subType='Earth-like world' and deletionState=0",[($id64)]);
#		my $numELW = ${$rows[0]}{num};
#
#		my @rows = db_mysql($db,"select count(*) as num from planets where systemId64=? and subType='Ammonia world' and deletionState=0",[($id64)]);
#		my $numAW = ${$rows[0]}{num};
#
#		my @rows = db_mysql($db,"select count(*) as num from planets where systemId64=? and subType='Water world' and deletionState=0",[($id64)]);
#		my $numWW = ${$rows[0]}{num};

		my $rows = rows_mysql($db,"select distinct subType,count(*) as num from planets where systemId64=? and deletionState=0 group by subType",[($id64)]);
		my ($numplanets,$numELW,$numAW,$numWW) = (0,0,0,0);

		if (ref($rows) eq 'ARRAY' && int(@$rows)) {
			foreach my $r (@$rows) {
				$numplanets += $$r{num};
				$numELW += $$r{num} if ($$r{subType} =~ /Earth-like world/i);
				$numAW += $$r{num}  if ($$r{subType} =~ /Ammonia world/i);
				$numWW += $$r{num}  if ($$r{subType} =~ /Water world/i);
			}
		}

		print "$id64: Stars=$numstars, Planets=$numplanets, ELW=$numELW, AW=$numAW, WW=$numWW, Terra=$numterra\n" if ($verbose);

		db_mysql($db,"update systems set numStars=?,numPlanets=?,numELW=?,numAW=?,numWW=?,numTerra=?,numLandables=?,updated=updated where id64=? and ".
			"(numstars is null or numplanets is null or numELW is null or numAW is null or numWW is null or numTerra is null or numLandables is null or ".
			"numstars!=? or numplanets!=? or numELW!=? or numAW!=? or numWW!=? or numTerra!=? or numLandables!=?)",
				[($numstars,$numplanets,$numELW,$numAW,$numWW,$numterra,$numlandables,$id64,$numstars,$numplanets,$numELW,$numAW,$numWW,$numterra,$numlandables)]);
		}

		delete($sys{$id64});
	}

	#print "." if (!$verbose);

}

#############################################################################




