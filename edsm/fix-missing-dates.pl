#!/usr/bin/perl

use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my $use_forking	= 1;
my $dotcount = 0;

my %id64 = ();


foreach my $table (qw(planets stars)) {
	my $IDfield = 'planetID';
	$IDfield = 'starID' if ($table eq 'stars');

	print "\n$table\n";

	my @rows = db_mysql('elite',"select $IDfield,systemId64,updated,updateTime,edsm_date,discoveryDate,commanderName,date_added,eddn_date from $table where ".
					"edsm_date is null or date_added is null or edsm_date<'2014-01-01 00:00:00' || date_added<'2014-01-01 00:00:00'");

	print "$table: ".int(@rows)."\n";
	$dotcount = 0;

	foreach my $r (@rows) {

		$id64{$$r{systemId64}} = 1 if ($$r{systemId64});

		my $edsm_date = $$r{edsm_date};
		my $date_added = $$r{date_added};

		$edsm_date = undef if ($edsm_date lt '2014-01-01 00:00:00');
		$date_added = undef if ($date_added lt '2014-01-01 00:00:00');

		foreach my $d (qw(updateTime edsm_date discoveryDate date_added updated)) {
			next if ($$r{$d} lt '2014-01-01 00:00:00');
			next if ($$r{$d} !~ /\d{4}-\d{2}-\d{2}/);

			$date_added = $$r{$d} if (!$date_added || $$r{$d} lt $date_added);
			$edsm_date = $$r{$d} if ((!$edsm_date || $$r{$d} lt $edsm_date) && $d !~ /date_added|eddn_date|updated/);
		}

		eval {
			my $update = '';
			my @params = ();

			if ($edsm_date =~ /\d{4}-\d{2}-\d{2}/ && (!$$r{edsm_date} || $edsm_date lt $$r{edsm_date} || $$r{edsm_date} lt '2014-01-01 00:00:00')) {
				$update .= ",edsm_date=?";
				push @params, $edsm_date;
			}

			if ($date_added =~ /\d{4}-\d{2}-\d{2}/ && (!$$r{date_added} || $date_added lt $$r{date_added} || $$r{date_added} lt '2014-01-01 00:00:00')) {
				$update .= ",date_added=?";
				push @params, $date_added;
			}

			$update =~ s/^,//;

			if (@params) {
				push @params, $$r{updated};
				push @params, $$r{$IDfield};
				my $sql = "update $table set $update,updated=? where $IDfield=?";
				#print "MYSQL: $sql [".join(', ',@params)."]\n";
				db_mysql('elite',$sql,\@params);
			}
		};
		

		$dotcount++;
		print '.' if ($dotcount % 10000 == 0);
		print "\n" if ($dotcount % 1000000 == 0 && !$use_forking);
		if ($dotcount % 1000 == 0 && $use_forking) {
			$0 =~ s/.+\///;
			$0 =~ s/\s+.*$//;
			$0 .= " $dotcount";
		}
	}
}

open TXT, ">>retrieve-ids.txt";
foreach my $id (sort keys %id64) {
	print TXT "$id\n";
}
close TXT;

