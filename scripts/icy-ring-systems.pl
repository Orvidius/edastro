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



my @rows = db_mysql('elite',"select systems.name,mainStarType,planets.subType from systems,planets,rings where systems.id64=planets.systemId64 and ".
		"planets.planetID=rings.planet_id and rings.type='Icy' and systems.deletionState=0 and planets.deletionState=0");


my %hash = ();
while (@rows) {
	my $r = shift @rows;
	$hash{$$r{name}}{$$r{mainStarType}}{$$r{subType}}++;
}

my $fn = "/home/bones/elite/scripts/icy-ring-systems.csv";

open CSV, ">$fn";
print CSV "System,Main Star Type,Planet Type\r\n";
my $wc = 0;

foreach my $s (sort keys %hash) {
	foreach my $m (sort keys %{$hash{$s}}) {
		foreach my $t (sort keys %{$hash{$s}{$m}}) {
			print CSV make_csv($s,$m,$t)."\r\n";
			$wc++;
		}
	}
}

my $meta = "$fn.meta";
my $zipf = $fn; $zipf =~ s/\.\w+$/.zip/;

my $size  = (stat($fn))[7];
my $epoch = (stat($fn))[9];

$wc = 0 if (!$wc);

if (!$wc) {
        open WC, "/usr/bin/wc -l $fn |";
        my @lines = <WC>;
        close WC;
        $wc = join('',@lines);
        chomp $wc;
        $wc-- if (int($wc));
}

open META, ">$meta";
print META "$epoch\n";
print META "$size\n";
print META "$wc\n";
close META;

unlink $zipf;

my $exec = "/usr/bin/zip $zipf $fn";
print "# $exec\n";
system($exec);
system("/usr/bin/scp $zipf $meta www\@services:/www/edastro.com/mapcharts/files/")



