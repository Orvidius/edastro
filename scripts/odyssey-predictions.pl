#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

use Image::Magick;

#############################################################################

show_queries(0);

my $debug_limit		= ''; #'limit 10000';
my $gravity_MAX		= 2;
my $pressure_MAX	= '0.05';

my %gravity_band = ();
$gravity_band{'0'} = 1;
$gravity_band{'1'} = 1;
$gravity_band{'1.5'} = 1;
$gravity_band{'2'} = 1;

my %pressure_band= ();
$pressure_band{'0'} = 1;
$pressure_band{'0.00001'} = 1;
$pressure_band{'0.00005'} = 1;
$pressure_band{'0.0001'} = 1;
$pressure_band{'0.0001'} = 1;
$pressure_band{'0.0002'} = 1;
$pressure_band{'0.0003'} = 1;
$pressure_band{'0.0005'} = 1;
$pressure_band{'0.001'} = 1;
$pressure_band{'0.003'} = 1;
$pressure_band{'0.006'} = 1;
$pressure_band{'0.01'} = 1;
$pressure_band{'0.02'} = 1;
$pressure_band{'0.03'} = 1;
$pressure_band{'0.04'} = 1;
$pressure_band{'0.05'} = 1;
$pressure_band{'1'} = 1;

#############################################################################

my @pressure_list = sort {$a+0 <=> $b+0} keys %pressure_band;
my @gravity_list = sort {$a+0 <=> $b+0} keys %gravity_band;

my $current_landables = 0;
my $current_landable_systems = 0;

my %region_name = ();

my @rows = db_mysql('elite',"select * from regions");
foreach my $r (@rows) {
	$region_name{$$r{id}} = $$r{name};
}


if (1) {
	my @rows = db_mysql('elite',"select count(*) as num from planets where deletionState=0 and isLandable=1");
	$current_landables = ${$rows[0]}{num};

	my @rows = db_mysql('elite',"select count(distinct systemId) as num from planets where deletionState=0 and isLandable=1");
	$current_landable_systems = ${$rows[0]}{num};

	print "Currently ".commify($current_landables)." landable planets exist in ".commify($current_landable_systems)." unique star systems.\n";
}

#my @rows = db_mysql('elite',"select region,planetID,subType,atmosphereType,surfacePressure,gravity ".
#			"from planets,systems where systemId64=id64 and systems.deletionState=0 and planets.deletionState=0 ".
#			"and isLandable=0 and gravity is not null and gravity>0 and gravity<=$gravity_MAX and ".
#			"surfacePressure is not null and surfacePressure>0 and surfacePressure<=0.01 and ".
#			"subType not like '\%giant\%' and subType not like '\%earth-like\%' and subType not like '\%ammonia\%' and subType not like '\%water\%' $debug_limit");

my @rows = db_mysql('elite',"select planetID,subType,atmosphereType,surfacePressure,gravity from planets where deletionState=0 ".
			"and isLandable=0 and gravity is not null and gravity>0 and gravity<=$gravity_MAX and ".
			"surfacePressure is not null and surfacePressure>0 and surfacePressure<=$pressure_MAX and ".
			"subType not like '\%giant\%' and subType not like '\%earth-like\%' and subType not like '\%ammonia\%' and subType not like '\%water\%' $debug_limit");

print commify(int(@rows))." non-landables detected with gravity <= $gravity_MAX and surface pressure <= 0.01 atmospheres.\n";

#############################################################################

my %atmo = ();
my %type = ();
my %atmo_type = ();
my %type_atmo = ();

open CSV, ">odyssey-predictions.csv";
print_header();

for (my $gi = 0; $gi<@gravity_list; $gi++) {
	next if (!$gi);
	my $gravity_limit = $gravity_list[$gi];

	my $count = 0;
	foreach my $r (@rows) {
		next if ($$r{subType} =~ /giant/);
		next if ($$r{gravity} > $gravity_limit);
		$count++;
	
		my %hash = ();
	
		$hash{p} = $$r{surfacePressure};
		$hash{g} = $$r{gravity};
		#$hash{r} = $$r{region};
		$hash{a} = $$r{atmosphereType};
		$hash{t} = $$r{subType};
	
		if ($hash{a}) {
			add_data($$r{planetID}, \%hash, \%{$atmo{$hash{a}}});
		}
		if ($hash{t}) {
			add_data($$r{planetID}, \%hash, \%{$type{$hash{t}}});
		}
		if ($hash{a} && $hash{t}) {
			add_data($$r{planetID}, \%hash, \%{$atmo_type{$hash{a}}{$hash{t}}});
			add_data($$r{planetID}, \%hash, \%{$type_atmo{$hash{t}}{$hash{a}}});
		}
	}
	print "$count found\n";
	
	
	print CSV "(Max $gravity_limit G) Potential future landables by Atmosphere Type:\r\n\r\n";
	
	foreach my $aa (sort keys %atmo) {
		print_entry("$aa (all)",$atmo{$aa});
		foreach my $pt (sort keys %{$atmo_type{$aa}}) {
			print_entry("$aa / $pt",\%{$atmo_type{$aa}{$pt}});
		}
	}
	
	print CSV "\r\n(Max $gravity_limit G) Potential future landables by Planet Type:\r\n\r\n";
	
	foreach my $pt (sort keys %type) {
		print_entry("$pt (all)",$type{$pt});
		foreach my $aa (sort keys %{$type_atmo{$pt}}) {
			print_entry("$pt / $aa",\%{$type_atmo{$pt}{$aa}});
		}
	}
	
	print CSV "\r\n\"Above represents ".commify($count)." unique planets that may eventually become landable depending on gravity and surface pressure limits.\"\r\n\r\n";
	

}

print CSV "\"Currently ".commify($current_landables)." landable planets exist in ".commify($current_landable_systems)." unique star systems.\"\r\n";

close CSV;

exit;


#############################################################################

sub print_header {
	my $header = "Atmosphere Type,Total planets,Average Gravity,Average Pressure";

	my $totals = '';
	my $groups = '';

	for (my $i=0; $i<@pressure_list-2; $i++) {
		#next if (!$i);
		my $p1 = $pressure_list[$i];
		my $p2 = $pressure_list[$i+1];
		$totals .= ",Planets (Pressure<=$p2)";
		$groups .= ",Planets (Pressure $p1 - $p2)";
	}
	$header .= $groups.$totals;
	print CSV "$header\r\n\r\n";
}

sub print_entry {
	my ($name, $href) = @_;

	warn "$name [$$href{count}]\n";

	return if (!$$href{count});

	my $num = $$href{count};
	my $avg_press = $$href{p}/$num;
	my $avg_grav  = $$href{g}/$num;
	my $count = 0;

	my $totals = '';
	my $groups = '';

	my $line = make_csv($name,$num,$avg_grav,$avg_press);

	for (my $i=0; $i<@pressure_list-1; $i++) {
		next if (!$i);

		$count += $$href{pr}{$pressure_list[$i]};
		$totals .= ",$count";
		$groups .= ",".int($$href{pr}{$pressure_list[$i]});
	}

	$line .= $groups.$totals;

	print CSV "$line\r\n";
}

sub add_data {
	my ($id, $href, $dataref) = @_;
	$$dataref{planets}{$id} = $href;
	$$dataref{count}++;
	$$dataref{p} += $$href{p};
	$$dataref{g} += $$href{g};

	for (my $i=0; $i<@pressure_list-1; $i++) {
		if ($$href{p} > $pressure_list[$i] && $$href{p} <= $pressure_list[$i+1]) {
			$$dataref{pr}{$pressure_list[$i+1]}++;
			last;
		}
	}
}

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}



#############################################################################
