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
my $upload_only		= 0;
my $allow_scp		= 1;

my $chunk_size		= 50000;

my $rings_fn		= 'dump-rings.csv';
my $belts_fn		= 'dump-belts.csv';
my $atmos_fn		= 'dump-atmospheres.csv';
my $mats_fn		= 'dump-surface-materials.csv';

my $scp			= '/usr/bin/scp -P222';
my $ssh			= '/usr/bin/ssh -p222';
my $remote_server	= 'www@services:/www/edastro.com/mapcharts/files';

############################################################################

if ($upload_only) {
	compress_send($rings_fn);
	compress_send($belts_fn);
	compress_send($atmos_fn);
	compress_send($mats_fn);
        exit;
}


my @do_list = ('rings','belts','atmospheres','materials');

@do_list = @ARGV if (@ARGV);

my $dot_count = 0;


foreach my $do (@do_list) {

	print epoch2date(time,-5,1).' '.uc($do)."\n";

	if ($do eq 'rings_old') {

		my @rows = ();
		
		foreach my $type (qw(planets stars)) {
			my $isStar = 0;
			$isStar = 1 if ($type eq 'stars');
			my $IDfield = 'planetID';
			$IDfield = 'starID' if ($type eq 'stars');
		
			push @rows, db_mysql('elite',"select planet_id pid,b.name body,isStar ISt,b.subType bt,r.name ring,type t,mass m,innerRadius IR,outerRadius ORd ".
					"from rings r,$type b where planet_id=b.$IDfield and isStar=$isStar and deletionState=0");
		}
		
		my $count = int(@rows);
		
		open CSV, ">$rings_fn";
		print CSV make_csv('Body ID','Body Name','isStar','Body Type','Ring Name','Ring Type','Ring Mass','Inner Radius','Outer Radius')."\r\n";
		
		foreach my $r (sort {$$a{body} cmp $$b{body} || $$a{ring} cmp $$b{ring}} @rows) {
			print CSV make_csv($$r{pid},$$r{body},$$r{ISt},$$r{bt},$$r{ring},$$r{t},$$r{m},$$r{IR},$$r{ORd})."\r\n";
			print_dot();
		}
		close CSV;
		
		compress_send($rings_fn,$count);

	} 
	if ($do eq 'rings' || $do eq 'belts') {

		my $count = 0;

		my $nametype = 'Belt';
		my $singular = 'belt';
		my $fn = $belts_fn;

		if ($do eq 'rings') {
			$nametype = 'Ring';
			$singular = 'ring';
			$fn = $rings_fn;
		}

		open CSV, ">$fn";
		print CSV make_csv('PlanetID','StarID','Body Name','Body Type',
				"$nametype Name","$nametype Type","$nametype Mass",'Inner Radius','Outer Radius')."\r\n";

		my $maxID = 0;
		my @rows = db_mysql('elite',"select max(planet_id) maxID from $do where planet_id is not null");

		if (@rows) {
			$maxID = ${$rows[0]}{maxID};
		} else {
			warn "No maxID found for $do\n";
		}

		print "MaxID = $maxID\n";

		my $count = 0;

		if ($maxID) {

			my $last_id = 0;

			while ($last_id < $maxID) {
				my $top_id = $last_id + $chunk_size;

				my @rows = ();

				my @check =  db_mysql('elite',"select count(*) as count from $do where planet_id>=$last_id and planet_id<$top_id");
				if (@check) {
					if (!${$check[0]}{count}) {
						print ",";
						$last_id += $chunk_size;
						next;
					}
				}
				
				foreach my $type (qw(planets stars)) {
					my $isStar = 0;
					$isStar = 1 if ($type eq 'stars');

					my $IDfield = 'planetID';
					$IDfield = 'starID' if ($type eq 'stars');

					push @rows, db_mysql('elite',"select b.$IDfield,planet_id pid,b.name body,isStar ISt,b.subType bt,r.name name,type t,mass m,".
							"innerRadius IR,outerRadius ORd from $do r,$type b where planet_id>=$last_id and planet_id<$top_id and ".
							"planet_id=b.$IDfield and isStar=$isStar and deletionState=0");
				}
				
				foreach my $r (sort {$$a{pid} <=> $$b{pid} || $$a{name} cmp $$b{name}} @rows) {
					next if (!$$r{pid});

					print CSV make_csv($$r{planetID},$$r{starID},$$r{body},$$r{bt},$$r{name},$$r{t},$$r{m},$$r{IR},$$r{ORd})."\r\n";
					print_dot();
					$count++;
				}

				$last_id += $chunk_size;
				last if ($debug);
			}
		}
		close CSV;
		
		compress_send($fn,$count);

	} elsif ($do eq 'atmospheres' || $do eq 'materials') {

		# Do this as column-arrays to avoid duplicating the hash keys millions of times.

		my $maxID = 0;
		my @rows = db_mysql('elite',"select max(planet_id) maxID from $do");

		if (@rows) {
			$maxID = ${$rows[0]}{maxID};
		} else {
			warn "No maxID found for $do\n";
		}

		my $fn = $atmos_fn;
		$fn = $mats_fn if ($do eq 'materials');

		my $count = 0;

		if ($maxID) {

			my @elements = ();
			my @rows = db_mysql('elite',"describe $do");
			foreach my $r (@rows) {
				push @elements, $$r{Field} if ($$r{Field} !~ /^(PID|PNAME|planet_id|id)$/);
			}
			@elements = sort {$a cmp $b} @elements;
		
			open CSV, ">$fn";
			print CSV make_csv('PlanetID','Planet Name',@elements)."\r\n";
				
			my $last_id = 0;

			while ($last_id < $maxID) {
				my $top_id = $last_id + $chunk_size;

				my @check =  db_mysql('elite',"select count(*) as count from $do where planet_id>=$last_id and planet_id<$top_id");
				if (@check) {
					if (!${$check[0]}{count}) {
						print ",";
						next;
					}
				}
				
				my $cols = columns_mysql('elite',"select planets.edsmID PID,planets.name PNAME,$do.* from $do,planets where planet_id=planets.planetID and ".
							"deletionState=0 and planets.planetID>=$last_id and planets.planetID<$top_id order by planets.edsmID");
		
				if (ref($cols) ne 'HASH' && ref($$cols{PID}) ne 'ARRAY') {
					next;
				}
		
				for (my $i=0; $i<@{$$cols{PID}}; $i++) {
		
					my @list = ();
		
					foreach my $e (@elements) {
						push @list, ${$$cols{$e}}[$i];
					}

					next if (!${$$cols{PID}}[$i]);
		
					print CSV make_csv(${$$cols{PID}}[$i],${$$cols{PNAME}}[$i],@list)."\r\n";
					print_dot();
					$count++;
				}

				$last_id += $chunk_size;
				last if ($debug);
			}
		}
		close CSV;
		
		print "\n";
		compress_send($fn,$count);

	} else {
		print "Unknown type: '$do'\n";
	}
}


exit;


############################################################################

sub compress_send {
	my $fn = shift;
	my $wc = shift;

	warn "UPLOAD: $fn\n";

	my $zipf = $fn; $zipf =~ s/\.\w+$/.zip/;
	my $meta = "$fn.meta";
	my $stat = "$fn.txt";

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

	open STAT, ">$stat";
	print STAT "File:  $fn\n";
	print STAT "Epoch: $epoch\n";
	print STAT "Bytes: $size\n";
	print STAT "Lines: $wc\n";
	close STAT;

	if (!$upload_only) {
		unlink $zipf;
	
		my $exec = "/usr/bin/zip temp-$$-$zipf $fn ; /bin/mv temp-$$-$zipf $zipf";
		print "\n# $exec\n";
		system($exec);
	}

	my_system("$scp $zipf $meta $remote_server/") if (!$debug && $allow_scp);

	#my_system("./push2mediafire.pl $zipf") if (!$debug && $allow_scp);
	#my_system("./push2mediafire.pl $stat") if (!$debug && $allow_scp);
}

sub my_system {
	my $string = shift;
	print "# $string\n";
	#print TXT "$string\n";
	system($string);
}

############################################################################

sub print_dot {
	$dot_count++;
	print '.' if ($dot_count % 5000 == 0);
	print "\n" if ($dot_count % 500000 == 0);
}

############################################################################



