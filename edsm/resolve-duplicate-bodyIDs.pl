#!/usr/bin/perl
use strict;
$|=1;

use lib "/home/bones/perl";
use DB qw(columns_mysql db_mysql show_queries);

my $debug	= 1;
my $debug_limit	= '';
$debug_limit	= 'limit 1' if ($debug);

show_queries($debug);

my %obj = ();
my %sys_id64 = ();

foreach my $table (qw(planets stars)) {
	my $idfield = 'planetID';
	$idfield = 'starID' if ($table eq 'stars');

	my @rows = db_mysql('elite',"select bodyId64,count(*) num from $table where deletionState=0 group by bodyId64 having count(*)>2 $debug_limit");

	foreach my $r (@rows) {
		print "bodyId64($$r{bodyId64}) = $$r{num}\n";

		my @bodies = db_mysql('elite',"select name,$idfield id,systemId64 from $table where bodyId64=?",[($$r{bodyId64})]);
		foreach my $b (@bodies) {
			$obj{$$r{bodyId64}}{$$b{name}}{$table.':'.$$b{id}} = $$b{systemId64};
		}
	}
}

foreach my $body64 (keys %obj) {
	foreach my $name (keys %{$obj{$body64}}) {

		if (int(keys(%{$obj{$body64}{$name}})) >= 2) {
			# 2+ of the same bodyId64 rows have the same name too. 

			foreach my $tableid (keys %{$obj{$body64}{$name}}) {
				my ($table,$id) = split ':', $tableid;

				$sys_id64{$obj{$body64}{$name}{$tableid}}{$table}{$name}{$id} = 1;
			}
		}
	}
}

my @getlist = ();
my %delete = ();

foreach my $id64 (keys %sys_id64) {
	@{$delete{$id64}{planets}} = ();
	@{$delete{$id64}{stars}} = ();
	foreach my $table (keys %{$sys_id64{$id64}}) {
		foreach my $name (keys %{$sys_id64{$id64}{$table}}) {
			my $idfield = 'planetID';
			$idfield = 'starID' if ($table eq 'stars');
	
			my @ids = ();
			foreach my $id (keys %{$sys_id64{$id64}{$table}{$name}}) {
				#push @{$delete{$id64}{$table}}, $id;
				push @ids, $id;
			}
			@ids = sort @ids;
			my @flaglist = ();
	
			if (@ids>=3) {
				for (my $i=1; $i<@ids-1; $i++) {
					push @flaglist;
				}
			}
	
			print "$id64 soft-delete: [$table] \"$name\" ".join(',',@flaglist)."\n";
			db_mysql('elite',"update $table set deletionState=1 where $idfield in (".join(',',@flaglist).")") if (!$debug);
		}
	}
	#print "$id64: DELETE planets: ".join(',',sort @{$delete{$id64}{planets}})."\n" if (@{$delete{$id64}{planets}});
	#print "$id64: DELETE stars:   ".join(',',sort @{$delete{$id64}{stars}})."\n" if (@{$delete{$id64}{stars}});
	push @getlist, $id64;

	last if ($debug);
}

while (@getlist) {
	my @list = splice @getlist, 0, 80;

	# Pull them here

	print '#> /home/bones/elite/edsm/get-system-bodies.pl '.join(' ',sort @list)."\n";
	system('/home/bones/elite/edsm/get-system-bodies.pl',@list) if (!$debug);
}



