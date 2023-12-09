#!/usr/bin/perl
use strict; $|=1;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(date2epoch epoch2date btrim);

############################################################################

show_queries(0);

my $path	= '/DATA/myDocuments/Saved Games/Frontier Developments/Elite Dangerous';
my $esc_path	= $path; $esc_path =~ s/ /\\ /gs;

my $scan_grep	= "grep '\"event\":\"Scan\"' $esc_path/Journal.* |  grep 'Earthlike' |";
my $explo_grep	= "egrep '\"event\":\"(SellExplorationData|MultiSellExplorationData)\"' $esc_path/Journal.* |";

my %bodies	= ();
my %mine	= ();

my $epoch 	= 0;

if ($ARGV[0]) {
	my $date = $ARGV[0];
	$date =~ s/[TZ]/ /gs;
	$epoch = date2epoch($date);
	warn "Using '$date' ($epoch)\n";
}

open TXT, $scan_grep;
while (<TXT>) {
	if (/"BodyName":"([^"]+)"/) {
		#warn "Found ELW: $1\n";
		$bodies{uc($1)}++;
	}
}
close TXT;

warn "Scanned: ".int(keys %bodies)."\n";

open TXT, $explo_grep;
while (my $line = <TXT>) {
	my @list = ();

	my $timestamp = 0;
	my $date = '';
	if ($line =~ /"timestamp":"([\d\-]+)T([\d\:]+)Z"/) {
		$date = "$1 $2";
		$timestamp = date2epoch($date);
	}

	if ($epoch && $timestamp < $epoch) {
		#warn "Skipping entry '$date' ($timestamp)\n";
		next;
	}

	if ($line =~ /"Discovered":\s*\[\s*"([^\]]+)"\s*]/) {
		my $string = $1;

		$string =~ s/^\s+//;
		$string =~ s/\s+$//;

		@list = split /"\s*,\s*"/, $string;
	}

	if ($line =~ /"Discovered":\s*\[\s*\{([^\]]+)\}\s*]/) {
		my $string = $1;
		$string =~ s/\s*,\s*"NumBodies":\d+\s*//gs;
		$string =~ s/\s*"SystemName"://gs;
		$string =~ s/^\s*"//;
		$string =~ s/\s*"\s*$//;
		@list = split /\"\},\s*\{\"/, $string;

		#warn "$string\n\n";
		#warn join(', ',@list)."\n\n";
	}

	if (@list) {
		#warn "Checking: $line\n\n";

		foreach my $name (@list) {
			#warn "Checking: $name\n";
			if ($bodies{uc($name)}) {
				$mine{$name}=1;
			}
			foreach my $body (keys %bodies) {
				if ($body =~ /^$name/i) {
					$mine{$body}=1;
				}
			}
		}

		#warn "\n\n";
	}

	if (keys %mine) {
		print "First: ".join(', ',keys %mine)."\n";
		exit;
	}
}
close TXT;

warn "Discovered (maybe): ".int(keys %mine)."\n";

my $name_list = "('".join("','",keys %mine)."')";

my @rows = db_mysql('elite',"select planets.id,planetID,systems.name sysname,planets.name,systemId64,coord_x,coord_y,coord_z from systems,planets where ".
		"systems.id64=planets.systemId64 and planets.name in $name_list and deletionState=0 order by planets.name");

warn "Rows: ".int(@rows)."\n";

my $out = "\n\n[TABLE=\"class: grid, width: 1500\"]
[TR]
[TD=\"align: center\"][B]System name[/B][/TD]
[TD=\"align: center\"][B]Planet ID[/B][/TD]
[TD=\"align: center\"][B]Dist. from Sol (ly)[/B][/TD]
[TD=\"align: center\"][B]First discovered by[/B][/TD]
[TD=\"align: center\"][B]Contributed by[/B][/TD]
[TD=\"align: center\"][B]System star(s) type[/B][/TD]
[TD=\"align: center\"][B]Ringed EL?[/B][/TD]
[TD=\"align: center\"][B]Moons[/B][/TD]
[TD=\"align: center\"][B]Screenshot URL[/B][/TD]
[TD=\"align: center\"][B]Notes[/B][/TD]
[TD=\"align: center\"][B]Additional screenshots - moons, parent planets, etc[/B][/TD]
[TD=\"align: center\"][B]X[/B][/TD]
[TD=\"align: center\"][B]Y[/B][/TD]
[TD=\"align: center\"][B]Z[/B][/TD]
[/TR]\n";

foreach my $r (@rows) {
	$$r{edsmID} = 0 if (!defined($$r{edsmID})); $$r{planetID} = 0 if (!defined($$r{planetID}));
	
	my @rings = db_mysql('elite',"select id from rings where planet_id='$$r{planetID}' and isStar=0");
	my $num_rings = int(@rings);
	my $has_rings = 'FALSE';
	$has_rings = 'TRUE' if ($num_rings);

	my $sol_dist = sqrt($$r{coord_x}**2+$$r{coord_y}**2+$$r{coord_z}**2);

	my $planet_id = $$r{name};
	$planet_id =~ s/$$r{sysname}\s+//gsi;

	my $star_type = '';

	my @moons = db_mysql('elite',"select name from planets where systemId64=$$r{systemId64} and planetID!=$$r{planetID} and deletionState=0");
	my $num_moons = 0;
	foreach my $m (@moons) {
		$num_moons++ if ($$m{name} =~ /^$$r{name}/i);
	}

	warn "$$r{sysname},$planet_id,$sol_dist,Orvidius,,$star_type,$has_rings,$num_moons,,,,$$r{coord_x},$$r{coord_y},$$r{coord_z}\n";
	$out .= "[TR]\n[TD]".join("[/TD]\n[TD]",$$r{sysname},$planet_id,$sol_dist,'Orvidius','Orvidius',$star_type,$has_rings,$num_moons,
		'','','',$$r{coord_x},$$r{coord_y},$$r{coord_z})."[/TD]\n[/TR]\n";

}
$out .= "[/TABLE]\n\n";

$out =~ s/\n/\r\n/gs;

print $out;


