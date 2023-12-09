#!/usr/bin/perl
use strict; $|=1;

###########################################################################

use Data::Dumper;

use lib "/home/bones/perl";
use DB qw(columns_mysql db_mysql show_queries);

###########################################################################

my $debug	= 0;
my $debug_where	= 'where systemId64=1487828683475';

my $where = '';

$where = "where systemId64 in (".join(',',@ARGV).")" if (@ARGV);

$where = $debug_where if ($debug && !$where);

###########################################################################

foreach my $table (qw(planets stars)) {
	my $IDfield = 'planetID';
	$IDfield = 'starID' if ($table eq 'stars');
	print "$table($IDfield)\n";

	my @names = db_mysql('elite',"select distinct name from $table $where group by name having count(*)>1 order by name");

	foreach my $n (@names) {
		my $name = $$n{name};

		my @rows = db_mysql('elite',"select * from $table where name=?",[($name)]);

		if (@rows == 2) {
			my $r1 = shift @rows;
			my $r2 = shift @rows;

			my %data = ();
			$data{$$r1{$IDfield}} = $r1;
			$data{$$r2{$IDfield}} = $r2;

			my $newID = undef;
			my $oldID = undef;

			if ($$r1{$IDfield} < $$r2{$IDfield}) {
				$oldID = $$r1{$IDfield};
				$newID = $$r2{$IDfield};
			} else {
				$newID = $$r1{$IDfield};
				$oldID = $$r2{$IDfield};
			}

			next if ((!$data{$oldID}{bodyId64} && !$data{$newID}{bodyId64}) || ($data{$oldID}{bodyId64} && $data{$newID}{bodyId64} && $data{$newID}{bodyId64}!=$data{$oldID}{bodyId64}));
			next if ($data{$oldID}{systemId64} != $data{$newID}{systemId64});

			my %hash = %{$data{$newID}};

			foreach my $key (qw(commanderName discoveryDate)) {
				$hash{$key} = $data{$oldID}{$key} if ($data{$oldID}{$key});
			}

			my $oldest = $data{$oldID}{updateTime};
			foreach my $id ($newID,$oldID) {
				foreach my $key (qw(date_added discoveryDate updateTime eddn_date)) {
					$oldest = $data{$oldID}{$key} if ((!$oldest || $data{$oldID}{$key} lt $oldest) && $data{$oldID}{$key} =~ /^\d{4}-\d{2}-\d{2}/);
					$oldest = $data{$newID}{$key} if ((!$oldest || $data{$newID}{$key} lt $oldest) && $data{$newID}{$key} =~ /^\d{4}-\d{2}-\d{2}/);
				}

				# We just need a value if it's missing and one of the records has it:
				foreach my $key (qw(bodyId parents parentStar parentStarID parentPlanet parentPlanetID commanderName discoveryDate 
							adj_date bodyId64 edsmID systemId offset)) {

					$hash{$key} = $data{$oldID}{$key} if ($data{$oldID}{$key} && !$hash{$key});
					$hash{$key} = $data{$newID}{$key} if ($data{$newID}{$key} && !$hash{$key});
					$hash{$key} = $data{$oldID}{$key} if (defined($data{$oldID}{$key}) && !$hash{$key});
					$hash{$key} = $data{$newID}{$key} if (defined($data{$newID}{$key}) && !$hash{$key});
				}
			}
	
			# Oldest date_added and updateTime:
			$hash{date_added} = $oldest;
			$hash{adj_date} = $oldest;
			$hash{updateTime} = $data{$oldID}{updateTime} if ($data{$oldID}{updateTime} =~ /^\d{4}-\d{2}-\d{2}/  && (!$hash{updateTime} || $data{$newID}{updateTime} lt $hash{updateTime}));
			$hash{updateTime} = $data{$newID}{updateTime} if ($data{$newID}{updateTime} =~ /^\d{4}-\d{2}-\d{2}/  && (!$hash{updateTime} || $data{$newID}{updateTime} lt $hash{updateTime}));

			# Newest EDDN date
			$hash{eddn_date} = $data{$oldID}{eddn_date} if ($data{$oldID}{eddn_date} =~ /^\d{4}-\d{2}-\d{2}/ && (!$hash{eddn_date} || $data{$oldID}{eddn_date} gt $data{$newID}{eddn_date}));
			$hash{eddn_date} = $data{$newID}{eddn_date} if ($data{$newID}{eddn_date} =~ /^\d{4}-\d{2}-\d{2}/ && (!$hash{eddn_date} || $data{$newID}{eddn_date} gt $data{$oldID}{eddn_date}));

			delete($hash{$IDfield});

			#print "Old: ".Dumper($data{$oldID})."\n";
			#print "New ".Dumper($data{$newID})."\n";
			#print "Hash ".Dumper(\%hash)."\n";

			print "$hash{name} $oldID/$newID ($hash{bodyId64})\n";

			my $vars = '';
			my @vals = ();

			foreach my $key (keys %hash) {
				$vars .= ','.$key.'=?';
				push @vals, $hash{$key};
			}
			$vars =~ s/^,//;

			push @vals, $oldID;

			if (!$debug) {
				db_mysql('elite',"update $table set $vars where $IDfield=?",\@vals);
				db_mysql('elite',"delete from $table where $IDfield=?",[($newID)]);
			}

		} else {
			print "$name = ".int(@rows)." !!!!\n";
		}
	}
}


