#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

use POSIX qw(floor);
use POSIX ":sys_wait_h";

############################################################################

my $debug		= 0;
my $allow_scp		= 1;
my $scp			= '/usr/bin/scp -P222';
my $ssh			= '/usr/bin/ssh -p222';
my $remote_server       = 'www@services:/www/edastro.com/mapcharts/files';

my $radius		= 16; # lightyears
my $one			= 1;
my $use_forking		= 1;
my $maxChildren		= 20;
my $fork_verbose	= 0;
my $chunk_size		= 10;

my %child    = ();
my @kids     = ();
my @childpid = ();

my %seen = ();
my %data = ();

my $outfile		= 'colony-candidates.csv';

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
my $systems = 0;
my $no_more_data = 0;

open CSV, ">$outfile";
print CSV make_csv('id64','Name','Main Star Type','Sol Distance','Planet Score','Stars','Planets','Terraformables',
			'Earth-like Worlds','Ammonia Worlds','Water Worlds','regionID','X','Y','Z')."\r\n";

while (@new && !$no_more_data) {

	last if ($no_more_data && no_kids(\@kids));

	if ($use_forking) {

		foreach my $childNum (0..$maxChildren-1) {

			if ($kids[$childNum] && $childpid[$childNum]) {
				my $fh = $kids[$childNum];
				my @lines = <$fh>;

				foreach my $line (@lines) {
					my @v = parse_csv($line);
					next if ($seen{$v[0]} || $data{$v[0]});
					${$data{$v[0]}} = \$one;
					print CSV $line;
				}
				waitpid $childpid[$childNum], 0;
				$kids[$childNum]	= undef;
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
		
						my @sys = db_mysql('elite',"select id64,coord_x x,coord_y y,coord_z z,name,mainStarType,sol_dist,planetscore,".
							"numStars,numPlanets,numTerra,numELW,numAW,numWW,region from systems where ".
							"coord_z>=? and coord_z<=? and coord_x is not null and coord_x!=0 and coord_y is not null and coord_y!=0 ".
							"and coord_z is not null and coord_z!=0 and sqrt(pow(coord_x-?,2)+pow(coord_y-?,2)+pow(coord_z-?,2))<? and ".
							"deletionState=0 and (SystemGovernment is null or SystemGovernment=3 or SystemGovernment=2) and ".
							"(SystemEconomy is null or SystemEconomy=5 or SystemEconomy=2)",
							[($$r{z}-$radius,$$r{z}+$radius,$$r{x},$$r{y},$$r{z},$radius)]);
		
						foreach my $s (@sys) {
							#print "$$s{id64},$$s{x},$$s{y},$$s{z}\n";
							print make_csv($$s{id64},$$s{name},$$s{mainStarType},$$s{sol_dist},$$s{planetscore},$$s{numStars},$$s{numPlanets},
								$$s{numTerra},$$s{numELW},$$s{numAW},$$s{numWW},$$s{region},$$s{x},$$s{y},$$s{z})."\r\n";
						}
					}

					exit;
				}
			}
		}
	}
}
print "\n".int(keys %data)." candidate systems.\n";

close CSV;

compress_send($outfile,int(keys %data),1) if (!$debug);


############################################################################

sub no_kids {
	my $ref = shift;

	foreach my $kid (@$ref) {
		return 0 if (defined($kid));
	}

	return 1;
}

sub compress_send {
	my $fn = shift;
	my $wc = shift;
	my $compress = shift;

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

	if ($compress) {
		my $exec = "/usr/bin/zip temp-$$-$zipf $fn ; /bin/mv temp-$$-$zipf $zipf ";
		print "# $exec\n";
		system($exec);
		my_system("$scp $zipf $meta $remote_server/") if (!$debug && $allow_scp);
	} else {
		my_system("$scp $fn $meta $remote_server/") if (!$debug && $allow_scp);
	}
}


sub my_system {
	my $string = shift;
	print "# $string\n";
	#print TXT "$string\n";
	system($string);
}

############################################################################

