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

my $chunk_size		= 1000;

############################################################################

show_queries(0);

my %system_name = ();

my @list = ();
my @rows = db_mysql('elite',"select distinct id64 from systems where deletionState=0");

warn int(@rows)." systems to consider.\n";

while (@rows) {
	my $r = shift @rows;
	push @list, $$r{id64} if ($$r{id64});
}

my %total  = ();
my %single = ();

while (@list) {
	my @ids = splice @list,0,$chunk_size;

	last if (!@ids);

	$total{systems} += int(@ids);

	my $planet_select = "select systemId64,count(*) as num from planets where systemId64 in (".join(',',@ids).") group by systemId64";
	my $star_select = "select systemId64,count(*) as num from stars where systemId64 in (".join(',',@ids).") group by systemId64";

	my %sys = ();

	my @rows = db_mysql('elite',$planet_select);
	while (@rows) {
		my $r = shift @rows;

		$total{planet_systems}++;
		$total{planet_counts}{$$r{num}}++;
		$total{body_counts}{$$r{num}}++;
		$total{planets} += $$r{num};
		$sys{$$r{systemId64}}++;

		if ($single{planet}{$$r{num}} && $total{planet_counts}{$$r{num}}>1) {
			delete($single{planet}{$$r{num}});
		} elsif (!$single{planet}{$$r{num}} && $total{planet_counts}{$$r{num}}==1) {
			$single{planet}{$$r{num}} = get_system_name($$r{systemId64});
		}
		if ($single{body}{$$r{num}} && $total{body_counts}{$$r{num}}>1) {
			delete($single{body}{$$r{num}});
		} elsif (!$single{body}{$$r{num}} && $total{body_counts}{$$r{num}}==1) {
			$single{body}{$$r{num}} = get_system_name($$r{systemId64});
		}
	}

	my @rows = db_mysql('elite',$star_select);
	while (@rows) {
		my $r = shift @rows;

		$total{star_systems}++;
		$total{star_counts}{$$r{num}}++;
		$total{body_counts}{$$r{num}}++;
		$total{stars} += $$r{num};
		$sys{$$r{systemId64}}++;

		if ($single{star}{$$r{num}} && $total{star_counts}{$$r{num}}>1) {
			delete($single{star}{$$r{num}});
		} elsif (!$single{star}{$$r{num}} && $total{star_counts}{$$r{num}}==1) {
			$single{star}{$$r{num}} = get_system_name($$r{systemId64});
		}
		if ($single{body}{$$r{num}} && $total{body_counts}{$$r{num}}>1) {
			delete($single{body}{$$r{num}});
		} elsif (!$single{body}{$$r{num}} && $total{body_counts}{$$r{num}}==1) {
			$single{body}{$$r{num}} = get_system_name($$r{systemId64});
		}
	}

	foreach my $id (@ids) {
		if (!$sys{$id}) {
			$total{body_counts}{0}++;
			$total{star_counts}{0}++;
			$total{planet_counts}{0}++;
		}
	}

	$total{body_systems} += int(keys %sys);

}


print make_csv('Bodies in System','System Count')."\r\n";
foreach my $n (sort {$a <=> $b} keys %{$total{body_counts}}) {
	print make_csv($n,$total{body_counts}{$n})."\r\n";
}
printf("Average Bodies per System:,%.02f\r\n",($total{stars}+$total{planets})/$total{systems});
print "\r\n";


print make_csv('Stars in System','System Count')."\r\n";
foreach my $n (sort {$a <=> $b} keys %{$total{star_counts}}) {
	print make_csv($n,$total{star_counts}{$n})."\r\n";
}
printf("Average Stars per System:,%.02f\r\n",$total{stars}/$total{systems});
print "\r\n";


print make_csv('Planets in System','System Count')."\r\n";
foreach my $n (sort {$a <=> $b} keys %{$total{planet_counts}}) {
	print make_csv($n,$total{planet_counts}{$n})."\r\n";
}
printf("Average Planets per System:,%.02f\r\n",$total{planets}/$total{systems});
print "\r\n";


print make_csv('Systems with planets:',$total{planet_systems})."\r\n";
print make_csv('Systems with stars:',$total{star_systems})."\r\n";
print make_csv('Total Systems:',$total{systems})."\r\n";
print "\r\n";

print make_csv('Systems with unique star counts','Star Count')."\r\n";
foreach my $n (sort keys %{$single{star}}) {
	print make_csv($single{star}{$n},$n)."\r\n";
}
print "\r\n";

print make_csv('Systems with unique planet counts','Planet Count')."\r\n";
foreach my $n (sort {$a <=> $b} keys %{$single{planet}}) {
	print make_csv($single{planet}{$n},$n)."\r\n";
}
print "\r\n";

print make_csv('Systems with unique body counts','Body Count')."\r\n";
foreach my $n (sort {$a <=> $b} keys %{$single{body}}) {
	print make_csv($single{body}{$n},$n)."\r\n";
}
print "\r\n";



exit;
############################################################################

sub get_system_name {
	my $id = shift;
	return undef if (!defined($id));
	return $system_name{$id} if ($system_name{$id});

	my @rows = db_mysql('elite',"select name from systems where id64=?",[($id)]);
	if (@rows) {
		my $r = shift @rows;
		$system_name{$id} = $$r{name};
		return $system_name{$id};
	} else {
		return undef;
	}
}

############################################################################




