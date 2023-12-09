#!/usr/bin/perl

use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql columns_mysql);

my $dotcount = 0;
my $found = 0;

my %missing = ();
my %missingname = ();
my $one = 1;

print "Getting planet list\n";
my $ref = columns_mysql('elite',"select bodyId64,name from planets where edsmID is null and bodyId64 is not null and bodyId64>0");
print "Processing planet list\n";
while (@{$$ref{bodyId64}}) {
	my $id = shift @{$$ref{bodyId64}};
	${$missing{$id}} = \$one if ($id);

	my $name = shift @{$$ref{name}};
	${$missingname{$name}} = \$one if ($name);
}

print "Getting star list\n";
my $ref = columns_mysql('elite',"select bodyId64,name from stars where edsmID is null and bodyId64 is not null and bodyId64>0");
print "Processing star list\n";
while (@{$$ref{bodyId64}}) {
	my $id = shift @{$$ref{bodyId64}};
	${$missing{$id}} = \$one if ($id);

	my $name = shift @{$$ref{name}};
	${$missingname{$name}} = \$one if ($name);
}

print "Parsing files\n";

foreach my $fn (@ARGV) {
	
	print "\n$fn\n";
	
	open DATA, "zcat $fn |";
	$dotcount = 0;
	
	while (my $line = <DATA>) {
		if ($line =~ /"type":"(Planet|Star)"/) {
	
			my $table = 'planets';
			$table = 'stars' if ($1 eq 'Star');
			my $idfield = 'planetID';
			$idfield = 'starID' if ($table eq 'stars');
	
			my $name = '';
			my $edsmID = 0;
			my $body64 = 0;

			$line =~ s/"rings"\s*:\s*\[[^\]]*\]\s*,?//;
			$line =~ s/"belts"\s*:\s*\[[^\]]*\]\s*,?//;
			$line =~ s/"stations"\s*:\s*\[[^\]]*\]\s*,?//;
	
			if ($line =~ /"id64"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$body64 = $1;
			}
	
			if ($line =~ /"id"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$edsmID = $1;
			}
	
			if ($line =~ /"name"\s*:\s*"([^"]+)"[,\}]/) {
				$name = $1;
			}
	
			if ($body64 && $edsmID && exists($missing{$body64})) {
				eval {
					db_mysql('elite',"update $table set edsmID=? where bodyId64=? and edsmID is null",[($edsmID,$body64)]);
				};
				delete($missing{$body64});
				delete($missingname{$name});
				$found++;
			} elsif ($name && $edsmID && exists($missingname{$name})) {
				eval {
					my @check = db_mysql('elite',"select $idfield as ID from $table where name=? and deletionState=0",[($name)]);
					if (@check==1) {
						db_mysql('elite',"update $table set edsmID=? where $idfield=? and edsmID is null",[($edsmID,${$check[0]}{ID})]);
						$found++;
					}
				};
				delete($missing{$body64}) if ($body64);
				delete($missingname{$name});
			}

			$dotcount++;
			if ($dotcount % 10000 == 0) {
				print '.' if (!$found);
				print ':' if ($found);
				$found = 0;
			}
			print "\n" if ($dotcount % 1000000 == 0);
		}
	}
	
	close DATA;
}



