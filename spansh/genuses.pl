#!/usr/bin/perl
use strict; $|=1;

use JSON;
use POSIX ":sys_wait_h";

use lib "/home/bones/elite";
use EDSM qw(key_findcreate);

use lib "/home/bones/perl";
use DB qw(db_mysql);

my %genusID = ();

my $n = 0;
open TXT, "zgrep genuses galaxy.json.gz |";
while (<TXT>) {
	chomp;
	if (/^\s*(\{.+\})\s*,?\s*$/) {
		my $ref = JSON->new->utf8->decode($1);

		my %hash = ();

		if (exists($$ref{bodies}) && ref($$ref{bodies}) eq 'ARRAY' && @{$$ref{bodies}}) {
			foreach my $b (@{$$ref{bodies}}) {
				my $date = $$b{updateTime};
				$date =~ s/\+00$//;
#print "$$b{name} = ".int(@{$$b{signals}{genuses}})."\n" if (exists($$b{signals}{genuses}));

				if (exists($$b{signals}{genuses}) && ref($$b{signals}{genuses}) eq 'ARRAY' && @{$$b{signals}{genuses}}) {
					foreach my $g (@{$$b{signals}{genuses}}) {
#print "$g\n";
						next if (!$g);
						$genusID{$g} = key_findcreate('genus',$g) if (!$genusID{$g});

						if ($genusID{$g}) {
							do_entry($ref,$b,$g,$genusID{$g},$date);
last;
						}
					}
				}

				$n++;
				print '.'  if ($n % 10000 == 0);
				print "\n" if ($n % 1000000 == 0);
			}
		}
	}
}
close TXT;


sub do_entry {
	my $sys   = shift;
	my $body  = shift;
	my $genus = shift;
	my $gID   = shift;
	my $date  = shift;

	print "$$sys{id64}.$$body{bodyId} $$body{name} : $genus($gID) $date\n";

	my @rows = db_mysql('elite',"select * from organicsignals where systemId64=? and bodyId=? and genusID=?",
		[($$sys{id64},$$body{bodyId},$gID)]);

	if (@rows) {
		foreach my $r (@rows) {
			my $first = $$r{firstReported};
			$first = $date if ($date && $date gt '2021-04-01 00:00:00' && (!$$r{firstReported} || $date lt $$r{firstReported}));
			my $last = $$r{lastSeen};
			$last = $date if ($date && $date gt '2021-04-01 00:00:00' && (!$$r{lastSeen} || $date gt $$r{lastSeen}));

			next if ($first eq $$r{firstReported} && $last eq $$r{lastSeen});

			db_mysql('elite',"update organicsignals set firstReported=?,lastSeen=? where id=?",[($first,$last,$$r{id})]);
		}
	} else {
		db_mysql('elite',"insert into organicsignals (systemId64,bodyId,genusID,firstReported,lastSeen,date_added) values (?,?,?,?,?,NOW())",
				[($$sys{id64},$$body{bodyId},$gID,$date,$date)]);
	}


}


