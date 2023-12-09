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
use POSIX qw(floor);

############################################################################

show_queries(0);

my $debug               = 0;
my $allow_scp		= 1;

my $chunk_size		= 50000;

my $scp			= '/usr/bin/scp -P222';
my $ssh			= '/usr/bin/ssh -p222';
my $remote_server	= 'www@services:/www/edastro.com/mapcharts/files';

############################################################################


my $dot_count = 0;

my $cols = columns_mysql('elite',"select planetID,p.edsmID,p.name,p.subType,p.rotationalPeriod,p.orbitalPeriod ".
				"from planets p where p.rotationalPeriodTidallyLocked=1 and ".
				"p.rotationalPeriod>0 and p.orbitalPeriod>0 and p.rotationalPeriod is not null and p.orbitalPeriod is not null and ".
				"abs(p.rotationalPeriod-p.orbitalPeriod)<0.0001 and p.deletionState=0 ".
				"order by p.name");

print make_csv('EDSM ID','Name','Type','Rotational Period','Orbital Period','Difference')."\r\n";

if (ref($cols) ne 'HASH' || ref($$cols{planetID}) ne 'ARRAY') {
	warn "None found.\n";
	exit;
}

for(my $i=0; $i<@{$$cols{planetID}}; $i++) {
	my $diff = abs(${$$cols{rotationalPeriod}}[$i] - ${$$cols{orbitalPeriod}}[$i]);

	print make_csv(${$$cols{edsmID}}[$i],${$$cols{name}}[$i],${$$cols{subType}}[$i],${$$cols{rotationalPeriod}}[$i],${$$cols{orbitalPeriod}}[$i])."\r\n";
}

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

sub findRatio {
	my ($a, $b) = @_;

	my $pa = 0;
	my $pb = 0;

	if ($a =~ /\.(\d+)/) {
		$pa = length($1);
	}
	if ($b =~ /\.(\d+)/) {
		$pb = length($1);
	}

	my $magnitude = $pa;
	$magnitude = $pb if ($pb > $magnitude);

	$a *= 10**$magnitude;
	$b *= 10**$magnitude;

	my $gcd = GCD($a,$b);

	return ($a/$gcd) . ':' . ($b/$gcd);
}

sub GCD {
	# Based on: https://www.geeksforgeeks.org/program-find-gcd-floating-point-numbers/

	my ($a,$b) = @_;

	return GCD($b, $a) if ($a < $b);

	if (abs($b) < 0.001) {
		return $a;
	} else {
		return (GCD($b, $a - floor($a/$b) * $b));
	}
}

sub print_dot {
        $dot_count++;
        print '.' if ($dot_count % 10000 == 0);
        print "\n" if ($dot_count % 1000000 == 0);
}

############################################################################



