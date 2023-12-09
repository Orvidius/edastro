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


my @table = ();
my %done = ();
my %system = ();

my @rows = db_mysql('elite',"select systemId64 from planets where name like '\% a' and deletionState=0");

while (@rows) {
	my $r = shift @rows;
	$system{$$r{systemId64}}=1;
}

warn "Found ".int(keys %system)." systems.\n";

my $hmc_ww = 0;
my $binaries = 0;
my $bins_with_moons = 0;
my $hmc_ww_with_moons = 0;

print make_csv('System','X','Y','Z','Planet 1','Planet 1 Type','Planet 1 CMDR','Planet 2','Planet 2 Type','Planet 2 CMDR','Moons')."\r\n";

foreach my $id64 (keys %system) {
	next if (!$id64);

	my %body = ();
	my %done = ();

	my @rows = db_mysql('elite',"select name,subType,orbitalPeriod,bodyId,parents,commanderName from planets where systemId64=? and (orbitalPeriod is not null or parents is not null) ".
			"and name rlike '[[:space:]][[:digit:]]+\$' and deletionState=0",[($id64)]);
	foreach my $r (@rows) {
		$body{$$r{name}} = $r;
	}

	foreach my $name (keys %body) {
		my $match = '';
		next if ($done{$name});

		if ($name =~ /^(.+\S)\s+(\d+)\s*$/) {
			my $base= $1;
			my $n = $2;

			foreach my $other (keys %body) {
				next if ($other eq $name);
				next if ($done{$other});

				if ($other =~ /^$base\s+(\d+)\s*$/) {
					my $n2 = $1;

					my $bcenter1 = undef;
					my $bcenter2 = undef;

					if ($body{$name}{parents} =~ /^Null:(\d+)/) {
						$bcenter1 = $1;
					}
					if ($body{$other}{parents} =~ /^Null:(\d+)/) {
						$bcenter2 = $1;
					}

					next if (abs($n-$n2)>1);
					#$match = $other if ($body{$name}{orbitalPeriod}==$body{$other}{orbitalPeriod} && (!$body{$name}{parents} || !$body{$other}{parents}));
					#$match = $other if (defined($bcenter1) && defined($bcenter2) && $bcenter1==$bcenter2);
					$match = $other if (abs($body{$name}{orbitalPeriod}-$body{$other}{orbitalPeriod})<=0.01);
				}
			}
		}

		if ($match) {
			$done{$name} = 1;
			$done{$match} = 1;
			$binaries++;
			my $is_HMC_WWW = 0;
			$is_HMC_WWW = 1 if (($body{$name}{subType} eq 'High metal content world' && $body{$match}{subType} eq 'Water world') ||
						($body{$match}{subType} eq 'High metal content world' && $body{$name}{subType} eq 'Water world'));
			$hmc_ww++ if ($is_HMC_WWW);


			my $name_esc  = $name;  $name_esc  =~ s/'/\\'/gs;
			my $match_esc = $match; $match_esc =~ s/'/\\'/gs;


			my @rows = db_mysql('elite',"select ID from planets where systemId64=? and (name rlike '$name_esc [a-z]\$' || name rlike '$match_esc [a-z]\$') and deletionState=0",[($id64)]);
			my $moons = int(@rows);

			$bins_with_moons++ if ($moons);
			$hmc_ww_with_moons++ if ($moons && $is_HMC_WWW);

			if ($moons && $is_HMC_WWW) {
			#if ($is_HMC_WWW) {

				my %sys = ();
				my @data = db_mysql('elite',"select * from systems where id64=? and deletionState=0",[($id64)]);
				if (@data) {
					%sys = %{$data[0]};
				}

				print make_csv($sys{name},$sys{coord_x},$sys{coord_y},$sys{coord_z},$name,$body{$name}{subType},$body{$name}{commanderName},$match,$body{$match}{subType},$body{$match}{commanderName},$moons)."\r\n";
			}
		}
	}
}

warn "$binaries total binaries\n";
warn "$bins_with_moons total binaries with moons\n";
warn "\n";
warn "$hmc_ww HMC/WW binaries\n";
warn "$hmc_ww_with_moons HMC/WW binaries with moons\n";

exit;



