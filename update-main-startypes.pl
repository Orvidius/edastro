#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);

############################################################################

my $db	= 'elite';

############################################################################

my $outer_chunk_size	= 50000;
my $inner_chunk_size	= 1000;
my $max_time		= 3600;
my $verbose		= 0;

my $count		= 0;
my $done		= 0;

my %seen		= ();
my %mainstar		= ();

my $fix_missing		= '';
$fix_missing = " or mainStarType='' or mainStarID=0" if ($ARGV[0]);

$done = 1 if ($ARGV[1]);

while (!$done) {

	my $nothing_new = 1;

	print "Pulling systems list (max $outer_chunk_size)...\n" if ($verbose);
	
	my @sys = db_mysql($db,"select distinct id64,name,mainStarID from systems where mainStarType is null or mainStarID is null $fix_missing limit $outer_chunk_size");
	
	my %name = ();
	foreach my $s (@sys) {
		next if ($seen{$$s{id64}});
		next if (!$$s{id64});

		$name{$$s{id64}} = $$s{name};
		$seen{$$s{id64}} = 1;
		$mainstar{$$s{id64}} = $$s{mainStarID};
		$nothing_new = 0;
	}
	@sys = ();
	my @systems = keys %name;

	if (!@systems || $nothing_new) {
		print "\nDone.\n";
		$done = 1;
		last;
	}

	
	print int(@systems)." systems to look at.\n" if ($verbose);
	
	print "Processing...\n" if ($verbose);
	
	while (@systems) {
		my @sys = splice @systems, 0, $inner_chunk_size;
		my $list = join(',',@sys);
	
		#my @rows =  db_mysql($db,"select starID,systemId64,systemId,name,subType from stars where (isPrimary=1 or isMainStar=1) and subType is not null and subType!='' and systemId64 in ($list)");
		my @rows =  db_mysql($db,"select starID,systemId64,systemId,name,subType from stars where systemId64 in ($list) and subType is not null and subType!=''");
		my %type = ();
		my %found = ();

		foreach my $r (@rows) {
			my $sysname = uc($name{$$r{systemId64}});

			if (uc($$r{name}) eq $sysname || uc($$r{name}) eq "$sysname A") {
				$type{$$r{subType}}{$$r{systemId64}} = 1;
				$found{$$r{systemId64}} = $$r{starID};
			}
		}

		$list = '';
		my $lookup = '';
		foreach my $s (@sys) {
			if (!$found{$s}) {
				my $n = $name{$s};
				$n =~ s/'/\\'/gs;
				$lookup .= ",'$n'";
				$lookup .= ",'$n A'";
				$list .= ",$s";
			}
		}
		$list =~ s/^,//;
		$lookup =~ s/^,//;

		@rows = ();
		@rows = db_mysql($db,"select starID,systemId64,systemId,subType from stars where systemId64 in ($list) and name in ($lookup)") if ($list && $lookup);
		foreach my $r (@rows) {
			$type{$$r{subType}}{$$r{systemId64}} = 1;
			$found{$$r{systemId64}} = $$r{starID};
		}
		foreach my $s (@sys) {
			if (!$found{$s}) {
				$type{''}{$s} = 1;
			}
		}

		foreach my $t (keys %type) {
			my $updatelist = join(',',keys %{$type{$t}});
			db_mysql($db,"update systems set mainStarType=? where id64 in ($updatelist)",[($t)]) if ($updatelist);
		}

		foreach my $id (@sys) {
			if (!defined($mainstar{$id}) || $mainstar{$id} != $found{$id}) {
				$found{$id} = 0 if (!$found{$id});
				db_mysql($db,"update systems set mainStarID=? where id64=?",[($found{$id},$id)]);
			} else {
				delete($mainstar{$id});
			}
		}
	
		$count++;

		if (!$verbose) {
			print '.';
			print "\n" if ($count % 100 == 0);
		}

	}
	#last if ($count);
}

print "Phase 2, fix remaining...\n";

my $limit = 'limit 100000';
$limit = '' if ($ARGV[1]);

my $rows = rows_mysql('elite',"select ID,id64,bodyId,stars.name as starname,starID,subType from systems,stars where mainStarID=0 and systemId64=id64 ".
			"and stars.deletionState=0 and systems.deletionState=0 and (stars.name=systems.name or concat(systems.name,' A')=stars.name) ".
			"and subType is not null and subType!='' $limit");
			#"and systems.name rlike ' [A-Z][A-Z]-[A-Z] [a-z]' and subType is not null and subType!='' $limit");

foreach my $r (@$rows) {
	print "$$r{starname} ($$r{starID}) $$r{subType} -> $$r{id64} ($$r{ID})\n";

	db_mysql('elite',"update systems set mainStarID=?,mainStarType=? where ID=?",[($$r{starID},$$r{subType},$$r{ID})]);
}

	
############################################################################




