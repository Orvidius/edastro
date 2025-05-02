#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch make_csv);

use POSIX qw(floor);
use POSIX ":sys_wait_h";

############################################################################

my $radius		= 16; # lightyears
my $one			= 1;
my $use_forking         = 1;
my $maxChildren         = 20;
my $fork_verbose        = 0;
my $chunk_size		= 10;

my %child    = ();
my @kids     = ();
my @childpid = ();

my %seen = ();
my %data = ();


############################################################################

my @rows = db_mysql('elite',"select id64,coord_x x,coord_y y,coord_z z from stations,systems where haveColonization=1 and systemId64>0 and systemId64=id64 and type is not NULL and type!='Mega ship' and type!='Fleet Carrier' and type!='GameplayPOI' and type!='PlanetaryConstructionDepot' and type !='SpaceConstructionDepot' and stations.deletionState=0 and systems.deletionState=0 and coord_x is not null and coord_y is not null and coord_z is not null");

print int(@rows)." stations pulled.\n";

my @new = ();
while (@rows) {
	my $r = shift @rows;
	push @new, $r if (!$seen{$$r{id64}});
	${$seen{$$r{id64}}} = \$one;
}

print int(@new)." systems to search from.\n";

my %seen = ();
my $count = 0;
my $no_more_data = 0;

while (@new && !$no_more_data) {

	last if ($no_more_data && no_kids(\@kids));

        if ($use_forking) {

		foreach my $childNum (0..$maxChildren-1) {

			if ($kids[$childNum] && $childpid[$childNum]) {
				my $fh = $kids[$childNum];
				my @lines = <$fh>;

				foreach my $line (@lines) {
					chomp $line;
					my @v = split /,/, $line;
					next if ($seen{$v[0]} || $data{$v[0]});
					$data{$v[0]}{x} = $v[1];
					$data{$v[0]}{y} = $v[2];
					$data{$v[0]}{z} = $v[3];
					#print "$line\n";
				}
				waitpid $childpid[$childNum], 0;
				$kids[$childNum]        = undef;
				$childpid[$childNum]    = undef;
				$count++;
				print "." if ($count % 10 == 0);
				print " ".int($count*$chunk_size)."\n" if ($count % 1000 == 0);
			}

			if (!$no_more_data) {
				my @rows = splice @new, 0, $chunk_size;
				if (!@rows) {
					$no_more_data = 1;
					last;
				}

				my $pid = open $kids[$childNum] => "-|";

				if ($pid) {
                                        # Parent.

                                        $childpid[$childNum] = $pid;
				} else {
					# Child
					disconnect_all();

					while (@rows) {
						my $r = shift @rows;
						my $id64 = $$r{id64};
						next if ($seen{$id64} || $data{$id64});
						${$seen{$id64}} = \$one;
		
						my @sys = db_mysql('elite',"select id64,coord_x x,coord_y y,coord_z z from systems where coord_z>=? and coord_z<=? and sqrt(pow(coord_x-?,2)+pow(coord_y-?,2)+pow(coord_z-?,2))<? and deletionState=0 and (SystemGovernment is null or SystemGovernment=3) and (SystemEconomy is null or SystemEconomy=5)",[($$r{z}-$radius,$$r{z}+$radius,$$r{x},$$r{y},$$r{z},$radius)]);
		
						foreach my $s (@sys) {
							print "$$s{id64},$$s{x},$$s{y},$$s{z}\n";
						}
					}

					exit;
				}
			}
		}
	}
}
print "\n".int(keys %data)." candidate systems.\n";



############################################################################

sub no_kids {
        my $ref = shift;

        foreach my $kid (@$ref) {
                return 0 if (defined($kid));
        }

        return 1;
}


############################################################################

