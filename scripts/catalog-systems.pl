#!/usr/bin/perl
use strict;

############################################################################
# Copyright (C) 2018, Ed Toton (CMDR Orvidius), All Rights Reserved.

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

use IO::Handle;

############################################################################

show_queries(0);

my $debug		= 0;
my $allow_scp		= 1;

#$allow_scp = 0 if ($0 =~ /\.pl\.\S+/);

my $scp			 = '/usr/bin/scp -P222';
my $ssh			 = '/usr/bin/ssh -p222';
my $remote_server       = 'www@services:/www/edastro.com/mapcharts/files';

my $outer_chunk_size    = 50000;
my $inner_chunk_size    = 1000;

my $nonproc_fn		= 'systems-nonproc.csv';
my $catalog_fn		= 'systems-catalog.csv';

############################################################################

my %regionname = ();

my @rows = db_mysql('elite',"select * from regions");
foreach my $r (@rows) {
	$regionname{$$r{id}} = $$r{name};
}

open NONPROC, ">$nonproc_fn";
print NONPROC "EDSM_ID,id64,Name,Coord_X,Coord_Y,Coord_Z,SOL Distance,timestamp,Region,RegionID\r\n";

open CATALOG, ">$catalog_fn";
print CATALOG "EDSM_ID,id64,Name,Coord_X,Coord_Y,Coord_Z,SOL Distance,timestamp,Region,RegionID\r\n";

my @rows = db_mysql('elite',"select max(id) as maxid from systems");
die "Failed to get max system ID\n" if (!@rows);
my $max_sys_id = ${$rows[0]}{maxid};

warn "Max system ID: $max_sys_id\n";

my $id_chunk = 0;
my $loopcount = 0;
my $count = 0;
my $count_nonproc = 0;
my $count_catalog = 0;

my %data = ();

print "Looping...\n";

while ($id_chunk < $max_sys_id) {
	my @rows = db_mysql('elite',"select edsm_id,id64,name,coord_x,coord_y,coord_z,updateTime,sol_dist,region from systems where ".
				"deletionState=0 and id>=? and id<? order by id64",[($id_chunk,$id_chunk+$outer_chunk_size)]);

	$loopcount++;
	print '.'  if ($loopcount % 10 == 0);
	print "\n" if ($loopcount % 1000 == 0);


	while (@rows) {
		my $r = shift @rows;
		if ($$r{name} !~ /^(\S+\s+)+[A-Z][A-Z]-[A-Z]\s+[a-z](\d+-)?\d+$/) {

			$data{nonproc}{$$r{name}} = make_csv($$r{edsm_id},$$r{id64},$$r{name},$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{sol_dist},$$r{updateTime},$regionname{$$r{region}},$$r{region})."\r\n";
			$count_nonproc++;

			if ($$r{name} =~ /^(HR|HD|HIP|GRS|PSR|OGLE|CD|BD|V|SLX|GHJ|2MASS|0ES|1ES|1FGL|2FGL|BDS|Gliese|WISE|LTT|LHS|WD|NLTT|Wolf|Ross|LFT|LP|BPM|CQ|EZ|EK|ED|GCRV|GL|L|NGC|NN|S171|StKM|CPD|KOI|UGP|UGPS|AD|ADS|AGKR|DE|CSI|FP|G|GMB|LAWD|LB|Lalande|LDS|CFBDSIR|PW2010|OJV2009|CCDM|XTE|GHJ2008|SSTGLMC|OTS2008|G2|IC|TYC|BSM2011|DM99|SPOCS|Brs0|MCC|GCRV|GJ|OJV2009|G|Cl\*|PCYC|Lan|LPM|CPC|GD|EGM|Den|GSC|DX|AG|LkHA|GAT|MWC|WASP|UGCS|CFHT|MLLA|MLLA|BrsO|PMD2009|H97b|ALS|MCW|BRT|COO|HG|SNM2009|SSTgbs|Kepler|IRAS|KAG2008|IHA2007|WBG2011|2MASX|BBG2010|JVD2011|IGR|MMS2011|BB2009|BBS2011|CPO2009|CXOONC|CXONGC1333|CXOU|DBP2006|EES2009|EM\*|GFT2002|GMM2008|GZB2006|HAT|HFR2007|HGM2009b|Haffner|IHA2008|IfAHA|LAL96|LF|LOrionis-SOC|MKS2009|MJD95|MAXI|MOA-2007|MSJ2009|Melotte|NOMAD1|PCB2009|PMSC|PSPF|S87b|SBC9|SDSS|SHB2004|SHD2009|SO4-|SPF|SWIFT|Trumpler|UCAC2|USNO\-A2|WMW2010|WDS|WBBe|WRAY|YSD2013|\d[A-Z])[\s\-\+\=\.\d][\w\d\-\.\+\,\:\;\=\_\s\'\"]+/i || $$r{name} =~ /^[A-Z]{1,5}\s+\d+[a-z]*\s*$/) {

				$data{catalog}{$$r{name}} = make_csv($$r{edsm_id},$$r{id64},$$r{name},$$r{coord_x},$$r{coord_y},$$r{coord_z},
					$$r{sol_dist},$$r{updateTime},$regionname{$$r{region}},$$r{region})."\r\n" if ($$r{name} =~ /\d/);
				$count_catalog++;
			}
		}
		$count++;
	}

	$id_chunk += $outer_chunk_size;
	last if ($debug && $count);
}

print "\n";

foreach my $name (sort {$a cmp $b} keys %{$data{nonproc}}) {
	print NONPROC $data{nonproc}{$name};
}

foreach my $name (sort {$a cmp $b} keys %{$data{catalog}}) {
	print CATALOG $data{catalog}{$name};
}

close NONPROC;
close CATALOG;
compress_send($nonproc_fn,$count_nonproc,1) if (!$debug);
compress_send($catalog_fn,$count_catalog,1) if (!$debug);

#my_system("$ssh www\@services 'cd /www/edastro.com/mapcharts ; ./update-spreadsheets.pl'") if (!$debug && $allow_scp);

exit;


############################################################################
sub compress_send {
	my $fn = shift;
	my $wc = shift;
	my $compress = shift;

	my $zipf = $fn; $zipf =~ s/\.\w+$/.zip/;
	my $meta = "$fn.meta";

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

	if ($compress) {
		my $exec = "/usr/bin/zip temp-$$-$zipf $fn ; /bin/mv temp-$$-$zipf $zipf ";
		print "# $exec\n";
		system($exec);
		my_system("$scp $zipf $meta $remote_server/") if (!$debug && $allow_scp);
	} else {
		my_system("$scp $fn $meta $remote_server/") if (!$debug && $allow_scp);
	}
}


sub my_system {
	my $string = shift;
	print "# $string\n";
	#print TXT "$string\n";
	system($string);
}

############################################################################





