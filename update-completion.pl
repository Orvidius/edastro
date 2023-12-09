#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(btrim);

############################################################################

my $db  = 'elite';

############################################################################

my $debug		= 0;

my $chunk_size		= 10000;
my $verbose             = 0;

my $count               = 0;
my $done                = 0;

############################################################################
#my $where = 'FSSprogress=1 and complete is null';
my $where = '';

my @t = localtime();

if ($t[2] % 2 == 0) {
	$where = '(complete is null and (FSSprogress=1 or (bodyCount is not null and bodyCount=numStars+numPlanets))) or (complete is not null and complete=0 and FSSprogress=1)';
} else {
	$where = 'complete is null and (FSSprogress=1 or (bodyCount is not null and bodyCount=numStars+numPlanets))';
}

if (@ARGV) {
	$where = "id64 in (".join(',',@ARGV).")" if (@ARGV);
	die "ERROR\n" if ($where =~ /\(.+\)/ && $where !~ /\([\d\,]+\)/);
}

print "WHERE: $where\n";
my $rows = rows_mysql($db,"select id64,bodyCount,complete from systems where $where and deletionState=0");

print int(@$rows)." systems to consider.\n";
#exit if ($debug);

my %alerted = ();

while (@$rows) {
	my $r = shift @$rows;

	print "$$r{id64} - ";
	my $bodycount = 0;
	my %bod = ();
	%alerted = ();

	foreach my $table (qw(planets stars barycenters)) {
		my $bodies = rows_mysql($db,"select bodyID,bodyId64,parents,parentID,parentType from $table where systemId64=? and deletionState=0",[($$r{id64})]);

		foreach my $b (@$bodies) {
			next if (!defined($$b{bodyID}) || !$$b{bodyId64});
			$bod{$$b{bodyID}} = $b;
			$bod{$$b{bodyID}}{table} = $table;
			$bodycount++ if ($table =~ /stars|planets/);
		}
	}

	my $complete = 1;

	if ($bodycount != $$r{bodyCount}) {
		alert("Incorrect body count (bodyCount=$$r{bodyCount}, actual=$bodycount)");
		$complete = 0;
	}

	if ($complete) { # Skip if already disqualified

		foreach my $id (sort keys %bod) {
			# Planet:21;Star:3;Null:1;Null:0

			my @parents = split /;/, btrim($bod{$id}{parents});
			# Verify they all exist

			while (@parents) {
				my $p = shift @parents;
				my ($ptype,$pid) = split /:/, $p, 2;

				next if ($p eq 'Null:0');	# Arrival node (main barycenter), not an object

				if (exists($bod{$pid})) {
					my $parent_parents = join(';',@parents);

					if (!$bod{$pid}{parents} && $bod{$pid}{table} eq 'barycenters') {
						# Barycenters don't have this data initially, so we need to fill it in.

						$bod{$pid}{parents} = $parent_parents;

						alert("Updating bodyID $pid barycenter parents '$parent_parents'");

						db_mysql($db,"update $bod{$pid}{table} set parents=?,updated=updated where bodyId64=? and bodyID=? and systemId64=?",
							[($parent_parents,$bod{$pid}{bodyId64},$bod{$pid}{bodyID},$$r{id64})]);

					} elsif ($bod{$pid}{parents} ne $parent_parents) {
						alert("Incorrect parent list for bodyID $pid '$bod{$pid}{parents}' != '$parent_parents'");
						#### $complete = 0; # Don't disqualify this way for now
					}
						
				} else {
					alert("BodyID $pid missing");
					### $complete = 0; # Don't disqualify this way for now
					### $complete = 0 if (defined($$r{complete});
				}
			}
		}
	}


	print "(complete=$complete)\n";
	db_mysql($db,"update systems set complete=?,updated=updated where id64=? and (complete is null or complete!=?)",[($complete,$$r{id64},$complete)]) if (!$debug);
}

sub alert {
	my $alert = shift;
	return if ($alerted{$alert});
	print "$alert, ";
	$alerted{$alert} = 1;
}

