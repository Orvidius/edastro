#!/usr/bin/perl
use strict; $|=1;

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);
use ATOMS qw(date2epoch epoch2date);

use LWP::Simple;
use HTML::TableExtract;
use POSIX qw(floor);

###########################################################################

my $path	= '/home/bones/elite/inara';

###########################################################################

show_queries(0);

my $url  = 'https://inara.cz/galaxy-fleetcarriers/';
my $pagemax = 1;
my $page = 1;
my %carrier = ();

if ($ARGV[0]) {
	opendir DIR, $path;
	while (my $fn = readdir DIR) {
		if ($fn =~ /^inara-carrier.+\.html$/) {
			unlink "$path/$fn";
		}
	}
	closedir DIR;
}

while ($page <= $pagemax) {

	my $getURL = "$url\?page=$page";
	my $fn = "$path/inara-carriers-$page.html";
	my $html = '';

	if (-e $fn) {
		print "READ $fn\n";
		open HTML, "<$fn";
		my @lines = <HTML>;
		close HTML;
		$html = join '', @lines;
	} else {
		print "GET $getURL\n";
		$html = get $getURL;
		open HTML, ">$fn";
		print HTML $html;
		close HTML;
	}


	$html =~ s/<span class="[\w\d\s]+" data-clipboard-text=".*?" title="Copy to clipboard">.*?<\/span>//gs;

	if ($html =~ /<li class="page_info">Page \d+ of (\d+)/) {
		$pagemax = $1;
		warn "Pages: $1 ($pagemax)\n";
	}
	
	my $te = HTML::TableExtract->new( headers => [qw(Station System Owner)] );
	$te->parse($html);
	
	# Examine all matching tables
	foreach my $ts ($te->tables) {
		foreach my $row ($ts->rows) {
			for (my $i=0; $i<@$row; $i++) {
				${$row}[$i] =~ s/\s+/ /gs;
				${$row}[$i] =~ s/[^\x00-\x7f]//g;
			}

			my $callsign = '';
			my $name = '';

			if ($$row[0] =~ /^\s*(.+\S)\s+\(([\w\d]{3,4}\-[\w\d]{3,4})\)/) {
				$callsign = $2;
				$name = $1;
			}

			next if (!$callsign);

			print "$callsign: ".join(',', @$row), "\n";
	
			$carrier{$callsign}{name} = uc($name);
			$carrier{$callsign}{system} = $$row[1];
			$carrier{$callsign}{commander} = $$row[2];
		}
	}
	$page++;
}

print int(keys %carrier)." carriers found\n";

my $delete_date = epoch2date(time-86400);

foreach my $callsign (sort keys %carrier) {
	my ($x,$y,$z,$sys,$id64) = get_coords($carrier{$callsign}{system});
	print "$carrier{$callsign}{name} [$callsign] $sys ($x, $y, $z)\n";

	my $updated = 0;

	my @check = db_mysql('elite',"select ID,name,commander,lastEvent from carriers where callsign=?",[($callsign)]);
	if (!@check) {
		db_mysql('elite',"insert into carriers (callsign,name,commander,systemName,systemId64,coord_x,coord_y,coord_z,created,updated) values (?,?,?,?,?,?,?,?,NOW(),NOW())",
			[($callsign,$carrier{$callsign}{name},$carrier{$callsign}{commander},$carrier{$callsign}{system},$id64,$x,$y,$z)]);
		$updated = 1;
	} 
	if (@check && $carrier{$callsign}{name} && ${$check[0]}{name} ne $carrier{$callsign}{name}) {
		db_mysql('elite',"update carriers set name=? where callsign=? and (isIGAU!=1 or isIGAU is null)",[($carrier{$callsign}{name},$callsign)]);
		$updated = 1;
	} 
	if (@check && $carrier{$callsign}{commander} && ${$check[0]}{commander} ne $carrier{$callsign}{commander}) {
		db_mysql('elite',"update carriers set commander=? where callsign=? and (isIGAU!=1 or isIGAU is null)",[($carrier{$callsign}{commander},$callsign)]);
		$updated = 1;
	} 
	if (@check && !${$check[0]}{lastEvent} && ${$check[0]}{systemName} ne $carrier{$callsign}{system}) {
		db_mysql('elite',"update carriers set systemName=?,systemId64=?,coord_x=?,coord_y=?,coord_z=? where callsign=?",
			[($carrier{$callsign}{system},$id64,$x,$y,$z,$callsign)]);
		$updated = 1;
	}
	if (!$updated) {
		db_mysql('elite',"update carriers set updated=NOW() where callsign=?",[($callsign)]);
	}
}

#db_mysql('elite',"delete from carriers where marketID is null and name is null and updated<?",[($delete_date)]) if (keys(%carrier)>5000);


exit;

###########################################################################

sub get_coords {
	my $sys = shift;
	my $sector = shift;
	my $next = '';
	my @rows = ();

	while ($sys && !@rows) {
		$sys = $next if ($next);
		@rows = db_mysql('elite',"select name,coord_x,coord_y,coord_z,id64 from systems where deletionState=0 and name=?",[($sys)]);

		if (!@rows) {
			my @s = split /\s+/,$sys;
			last if (@s == 1);
			pop @s;
			$next = join(' ',@s);
		}
	}

	if (@rows) {
		return (${$rows[0]}{coord_x}, ${$rows[0]}{coord_y}, ${$rows[0]}{coord_z}, ${$rows[0]}{name}, ${$rows[0]}{id64});
	} else {
		if ($sector) {
			my ($ax, $ay, $az, $num);
			my $sec = $sector;
			$sec =~ s/[^\w\d\_\-\.]+//gs;

			my @rows = db_mysql('elite',"select coord_x,coord_y,coord_z from systems where deletionState=0 and name like '$sec\%'");
			foreach my $r (@rows) {
				$num++;
				$ax += $$r{coord_x};
				$ay += $$r{coord_y};
				$az += $$r{coord_z};
			}

			if ($num && (sqrt($ax**2 + $az**2)>500)) {
				return (floor($ax/$num),floor($ay/$num),floor($az/$num),$sec,undef);
			}
		}

		return (undef,undef,undef,$sys,undef);
	}
}

###########################################################################

