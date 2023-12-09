#!/usr/bin/perl
use strict;

###########################################################################

#use lib "/var/www/edastro.com/scripts";
use lib "/home/bones/perl";
use ATOMS qw(parse_csv make_csv date2epoch epoch2date);
use DB qw(db_mysql);
use POSIX qw(floor ceil);

my $debug       = 0;
my $path	= '/home/bones/elite/GEC/carriers';

###########################################################################

my %systems = ();
my %carriers = ();
my %prev = ();

my @rows = db_mysql('elite',"select carriers.* from carriers,POI where gec_id is not null and carriers.systemId64=POI.systemId64 and carriers.invisible=0");

foreach my $r (@rows) {
	$systems{"$$r{systemId64}"}++;
	$carriers{$$r{systemId64}}{$$r{callsign}} = $r;
}

opendir DIR, $path;
while (my $fn = readdir DIR) {
	next if ($fn =~ /^\./);

	if ($fn =~ /^(\d+)\.csv$/) {
		open CSV, '<:encoding(UTF-8)', "$path/$fn";
		$prev{$fn} = join '', (<CSV>);
		close CSV;
	}
}

foreach my $id64 (sort {$a <=> $b} keys %carriers) {
	my $out = '';
	foreach my $callsign (sort {$a cmp $b} keys %{$carriers{$id64}}) {	

		my $name = $carriers{$id64}{$callsign}{name};
		my $date = $carriers{$id64}{$callsign}{lastEvent};

		foreach my $key (qw(lastEvent lastMoved FSSdate created)) {
			$date = $carriers{$id64}{$callsign}{$key} if ($carriers{$id64}{$callsign}{$key} && (!$date || $carriers{$id64}{$callsign}{$key} gt $date));
		}

		next if ($date && date2epoch($date) < time-(86400*365.25));

		print "$id64: $date [$callsign] $name\n";

		$name =~ s/"/\{QUOT\}/gs;

		$out .= make_csv($callsign,$name,$date)."\r\n";
	}

	my $fn = "$id64.csv";

	if ($out ne $prev{$fn}) {
		print "WRITING $fn\n";
		open CSV, '>:encoding(UTF-8)', "$path/$fn";
		binmode(CSV, ":utf8");
		print CSV $out;
		close CSV;
	} else {
		print "NO CHANGES: $fn\n";
	}
}

opendir DIR, $path;
while (my $fn = readdir DIR) {
	next if ($fn =~ /^\./);

	if ($fn =~ /^(\d+)\.csv$/) {
		if (!$systems{$1}) {
			print "DELETE: $path/$fn\n";
			unlink "$path/$fn" 
		}
	}
}
closedir DIR;

system("/usr/bin/rsync -Wuva --delete $path/* www\@services:/www/edastro.com/catalog/carriers/");
