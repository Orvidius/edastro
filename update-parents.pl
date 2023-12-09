#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);

############################################################################

my $db	= 'elite';

############################################################################

my $outer_chunk_size	= 20000;
my $inner_chunk_size	= 1000;
my $max_time		= 3600;
my $verbose		= 0;

my $count		= 0;
my $done		= 0;

my %seen		= ();

my $order = '';

$order = 'order by sys.id64' if ($ARGV[0] == 1);
$order = 'order by sys.id64 desc' if ($ARGV[0] == 2);
$order = 'order by sys.ID' if ($ARGV[0] == 3);
$order = 'order by sys.ID desc' if ($ARGV[0] == 4);
$order = 'order by sys.edsm_id' if ($ARGV[0] == 5);
$order = 'order by sys.edsm_id desc' if ($ARGV[0] == 6);

while (!$done) {

	my $nothing_new = 1;

	print "Pulling systems list (max $outer_chunk_size)...\n" if ($verbose);
	
	my @sys = db_mysql($db,"select sys.id64 id,count(distinct s.id) ns,count(distinct p.id) np from systems sys ".
		"left join stars s on sys.id64 = s.systemId64 and s.deletionState=0 ".
			"and (s.parentStar is null or s.parentPlanet is null or s.parentStarID is null or s.parentPlanetID is null) ".
		"left join planets p on sys.id64 = p.systemId64 and p.deletionState=0 ".
			"and (p.parentStar is null or p.parentPlanet is null or p.parentStarID is null or p.parentPlanetID is null) ".
		"group by sys.id64 having count(distinct s.id)>0 or count(distinct p.id)>0 $order limit $outer_chunk_size");
	
	my @systems = ();
	foreach my $s (@sys) {
		#print "$$s{id}: $$s{ns}, $$s{np}\n";

		next if ($seen{$$s{id}});

		push @systems, $$s{id} if ($$s{ns}>0 || $$s{np}>0);
		$seen{$$s{id}} = 1;
		$nothing_new = 0;
	}
	@sys = ();

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
	
		my @rows =  db_mysql($db,"select edsmID,starID BODY,name,systemId64,subType,1 as isStar from stars where systemId64 in ($list) and deletionState=0");
		push @rows, db_mysql($db,"select edsmID,planetID BODY,name,systemId64,subType,0 as isStar from planets where systemId64 in ($list) and deletionState=0");
	
		#my %body    = ();
		#my %bodyID  = ();

		my %data = ();
	
		foreach my $r (@rows) {
			#$bodyID{$$r{systemId64}}{$$r{name}} = $$r{edsmID};
			#$body{$$r{systemId64}}{$$r{edsmID}} = $r;

			$data{$$r{systemId64}}{$$r{name}} = $r;
		}
	
		foreach my $id64 (@sys) {
	
			foreach my $name (keys %{$data{$id64}}) {
				my $parent = $name;
				$parent =~ s/\s+\S+$//;

				my $parentEDSM = $data{$id64}{$parent}{edsmID};
				my $parentID   = $data{$id64}{$parent}{BODY};
	
				my $parentType = '';
				my $parentStar = 0;
				my $parentPlanet = 0;
				my $parentStarID = 0;
				my $parentPlanetID = 0;
	
				if ($parentID && $data{$id64}{$parent}{isStar}) {
					$parentStar   = $parentEDSM;
					$parentStarID = $parentID;
					$parentType   = 'star';
				}
				if ($parentID && !$data{$id64}{$parent}{isStar}) {
					$parentPlanet   = $parentEDSM;
					$parentPlanetID = $parentID;
					$parentType     = 'planet';
				}
	
				my $table = 'planets';
				$table = 'stars' if ($data{$id64}{$name}{isStar});
				my $IDfield = 'planetID';
				$IDfield = 'starID' if ($data{$id64}{$name}{isStar});
	
				print "$name ($data{$id64}{$name}{edsmID}/$data{$id64}{$name}{BODY}/$data{$id64}{$name}{subType}): ".
					"$parentStar/$parentPlanet [$parentType] $data{$id64}{$parent}{subType}\n" 
					if ($verbose);

				db_mysql($db,"update $table set parentStar=?,parentPlanet=?,parentStarID=?,parentPlanetID=? where $IDfield=?",
						[($parentStar,$parentPlanet,$parentStarID,$parentPlanetID,$data{$id64}{$name}{BODY})]);
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
	
############################################################################
	
