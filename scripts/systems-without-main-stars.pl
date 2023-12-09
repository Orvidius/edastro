#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10 estimated_coords load_sectors);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

############################################################################

my $debug	= 0;
my $allow_scp	= 1;

my $fn		= 'systems-without-main-stars.csv';

my $scp                 = '/usr/bin/scp -P222';
my $ssh                 = '/usr/bin/ssh -p222';
my $remote_server       = 'www@services:/www/edastro.com/mapcharts/files';

show_queries(0);

############################################################################

my $and = '';
$and = "and name like 'Aaeyoea %'" if ($debug);

if (1) {

	my $rows = rows_mysql('elite',"select id64,name from systems where mainStarID=0 and id64 is not null and deletionState=0 $and order by name");
	
	warn int(@$rows)." rows returned.\n";
	
	open OUTFILE, ">$fn";
	
	print OUTFILE make_csv('ID64 SystemAddress','EDSM ID','System Name','Stars','Planets','Sol Distance','X','Y','Z','RegionID')."\r\n";
	
	my $count = 0;
	while (@$rows) {
		my @rowsplice = splice @$rows, 0, 1000;
		my %count = ();
		
		my $list = '';
		foreach my $r (@rowsplice) {
			#Col 285 Sector UJ-Q d5-95
			#next if ($$r{name} !~ /\s[A-Z][A-Z]\-[A-Z]\s[a-z][\d\-]+\s*$/);
	
			$list .= ',' if ($list);
			$list .= $$r{id64};
			$count{$$r{id64}}{stars} = 0;
			$count{$$r{id64}}{planets} = 0;
		}
	
		next if (!$list);
	
		foreach my $table (qw(stars planets)) {
			my $bodies = rows_mysql('elite',"select systemId64,count(*) as num from $table where systemId64 in ($list) group by systemId64");
			foreach my $b (@$bodies) {
				$count{$$b{systemId64}}{$table} = $$b{num};
			}
		}
	
		my $datarows = rows_mysql('elite',"select id64,edsm_id,name,sol_dist,coord_x,coord_y,coord_z,region regionID from systems where id64 in ($list) order by name");
	
		while (@$datarows) {
			my $r = shift @$datarows;
			#next if ($$r{name} !~ /\s[A-Z][A-Z]\-[A-Z]\s[a-z][\d\-]+\s*$/);
	
			print OUTFILE make_csv($$r{id64},$$r{edsm_id},$$r{name},$count{$$r{id64}}{stars},$count{$$r{id64}}{planets},$$r{sol_dist},$$r{coord_x},$$r{coord_y},$$r{coord_z},$$r{regionID})."\r\n";
	
			$count++;
	
			print '.' if ($count % 10000 == 0);
			print "\n" if ($count % 1000000 == 0);
		}
	}
	close OUTFILE;
	warn "$count found\n";
}

compress_send($fn);

exit;

############################################################################

sub compress_send {
	my $fn = shift;
	my $wc = shift;

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

	my $exec = "/usr/bin/zip temp-$$-$zipf $fn ; /bin/mv temp-$$-$zipf $zipf";
	print "# $exec\n";
	system($exec);

	my_system("$scp $zipf $meta $remote_server/") if (!$debug && $allow_scp);
}

sub my_system {
	my $string = shift;
	print "# $string\n";
	#print TXT "$string\n";
	system($string);
}

############################################################################



