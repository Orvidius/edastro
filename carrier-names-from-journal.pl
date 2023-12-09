#!/usr/bin/perl
use strict;
$|=1;

use lib '/home/bones/perl';
use DB qw(db_mysql);
use ATOMS qw(btrim epoch2date date2epoch);
use JSON;

my $debug	= 0;
my $jpath	= '/home/bones/elite/journals';
my $spath	= '/mnt/EliteDangerousJournals';

# { "timestamp":"2021-03-10T01:34:11Z", "event":"FSSSignalDiscovered", "SystemAddress":24860210308521, "SignalName":"AIME'S DEN QHZ-W1V", "IsStation":true 

my $startdate = epoch2date(time-86400);
$startdate =~ s/\d{2}:\d{2}:\d{2}/00:00:00/s;

my %sys = ();
my @files = ();
my %done = ();

scan_folder($jpath);

if (!-e "$spath/status.json") {
	# Not mounting here
}

if (-e "$spath/status.json") {
	# If mounted, scan it
	scan_folder($spath);
}


sub scan_folder {
	my $path = shift;

	print "PATH: $path\n";

	opendir DIR, $path;
	while (my $fn = readdir DIR) {
		#Journal.210309191633.01.log
		#print "- $fn\n";
		if ($fn =~ /^Journal\.(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)\.\d+\.log/) {
			my ($y,$m,$d,$h,$min,$sec) = (2000+$1,$2,$3,$4,$5,$6);
			if (sprintf("%04u-%02u-%02u %02u:%02u:%02u",$y,$m,$d,$h,$min,$sec) gt $startdate) {
				push @files, $fn;
			}
		}
	}
	closedir DIR;

	foreach my $fn (sort @files) {
		scan_file($path,$fn);
	}
}


sub scan_file {
	my $path = shift;
	my $fn = shift;

	return if ($done{$fn});
	$done{$fn} = 1;

	print "FILE: $path/$fn\n";

	open TXT, "<$path/$fn";
	while (my $line = <TXT>) {

		if ($line =~ /"event":"(Location|FSDJump)"/) {
			eval {
				my $href = JSON->new->utf8->decode($_);
				my $id64 = $$href{SystemAddress};
				$sys{$id64}{name} = $$href{StarSystem};
				$sys{$id64}{x} = ${$$href{StarPos}}[0];
				$sys{$id64}{y} = ${$$href{StarPos}}[1];
				$sys{$id64}{z} = ${$$href{StarPos}}[2];
			};
		} elsif ($line =~ /"event":"FSSSignalDiscovered"/ && $line =~ /"IsStation":true/ && $line =~ /"SignalName":"([^"]+\S)\s+([A-Z0-9]{3}\-[A-Z0-9]{3})"/) {
			my ($name, $callsign, $id64) = ($1,$2,undef);

			eval {
				my $href = JSON->new->utf8->decode($line);
				if ($$href{SignalName} =~ /([^"]+\S)\s+([A-Z0-9]{3}\-[A-Z0-9]{3})/) {
					($name, $callsign) = ($1,$2);
				}
				$id64 = $$href{SystemAddress} if ($$href{SystemAddress});
			};

			$name = btrim($name);
			$callsign = btrim($callsign);

			print "CARRIER: $name [$callsign] ($id64) - ";

			my @rows = db_mysql('elite',"select name from carriers where callsign=?",[($callsign)]);
			if (@rows) {
				if (uc(${$rows[0]}{name}) ne uc($name)) {
					db_mysql('elite',"update carriers set name=? where callsign=?",[($name,$callsign)]) if (!$debug);
					print "UPDATED\n";
				} else {
					print "No change.\n";
				}
			} else {

				my ($loc_name, $x, $y, $z) = (undef,undef,undef,undef);

				if (!$sys{$id64} && $id64) {
					my @data = db_mysql('elite',"select name,coord_x,coord_y,coord_z from systems where id64=?",[($id64)]);
					foreach my $d (@data) {
						$loc_name = $$d{name};
						$x = $$d{coord_x};
						$y = $$d{coord_y};
						$z = $$d{coord_z};

						$sys{$id64}{name} = $$d{name};
						$sys{$id64}{x} = $$d{coord_x};
						$sys{$id64}{y} = $$d{coord_y};
						$sys{$id64}{z} = $$d{coord_z};
					}
				} elsif ($sys{$id64}) {
					$loc_name = $sys{$id64}{name};
					$x = $sys{$id64}{x};
					$y = $sys{$id64}{y};
					$z = $sys{$id64}{z};
				}

				print "Not found, adding: $name, $callsign, $loc_name, $id64, $x, $y, $z\n";
				db_mysql('elite',"insert into carriers (name,callsign,systemId64,systemName,coord_x,coord_y,coord_z) values (?,?,?,?,?,?,?)",
					[($name,$callsign,$id64,$loc_name,$x,$y,$z)]) if (!$debug);
			}
		}
	}
	close TXT;
}

