#!/usr/bin/perl
use strict; $|=1;
use lib "/home/bones/perl";
use DB qw(rows_mysql db_mysql show_queries);
use EDSM qw(log_mysql);
use ATOMS qw(epoch2date date2epoch);

###########################################################################

my $debug	= 0;
my $chunk_size	= 5000;

show_queries($debug);

###########################################################################

my %IDvector = ();
my %maxID = ();

#    {"id":149335628,"id64":288230460675232090,"bodyId":8,"name":"Oochorrs XC-M c10-0 A 1","type":"Planet","subType":"Icy body","parents":[{"Star":1},{"Null":0}],"distanceToArrival":2295,"isLandable":false,"gravity":0.7578959767121055,"earthMasses":1.348939,"radius":8508.948,"surfaceTemperature":49,"surfacePressure":0.2714983692672095,"volcanismType":"Major Water Geysers","atmosphereType":"Neon-rich","atmosphereComposition":{"Helium":97.56,"Neon":2.44},"solidComposition":{"Ice":68.44,"Rock":21.21,"Metal":10.35},"terraformingState":"Not terraformable","orbitalPeriod":5336.166666666667,"semiMajorAxis":4.577509869169548,"orbitalEccentricity":0.026326,"orbitalInclination":0.040098,"argOfPeriapsis":151.768936,"rotationalPeriod":1.122653175636574,"rotationalPeriodTidallyLocked":false,"axialTilt":0.168964,"updateTime":"2019-10-21 00:07:43","systemId":15411176,"systemId64":84523520346,"systemName":"Oochorrs XC-M c10-0"},

my $fn = shift @ARGV;
my $one_type = '';

if ($fn =~ /^\-(\w+)/) {
	$one_type = $1;
	$fn = shift @ARGV;
}

die "Unknown type: $one_type\n" if ($one_type && $one_type !~ /^(planets|stars|systems)$/);

if ($fn !~ /\.jsonl?$/) {
	die "$fn not a JSON file.\n";
} 

my %data = ();
my %date = ();

warn "Reading $fn\n";

open TXT, "<$fn";

while (my $line = <TXT>) {
	my ($id,$type,$updated) = (undef,undef,undef);

	if ($line =~ /"id":(\d+),/) {
		$id = $1;
	}

	if ($fn =~ /bodies/ && $line =~ /"type":"(\w+)"[,\}]/) {
		$type = 'planets' if ($1 =~ /Planet/i);
		$type = 'stars' if ($1 =~ /Star/i);

	} elsif ($fn =~ /systems/) {
		$type = 'systems';
	} elsif ($fn =~ /stations/) {
		$type = 'stations';
	}

	if ($id && $type && (!$one_type || $type eq $one_type)) {
		#@{$data{$type}} = () if (ref($data{$type}) ne 'ARRAY');
		#push @{$data{$type}}, $id;
		vec($IDvector{$type}, $id, 1) = 1;
		$maxID{$type} = $id if ($id > $maxID{$type});
	}
}

close TXT;

my @tables = keys %IDvector;

die "Nothing found.\n" if (!@tables);

warn "Checking DB for ".join(',',@tables)."\n";

my $count = 0;

foreach my $table (@tables) {

	my $idfield = 'id';
	$idfield = 'edsm_id' if ($table eq 'systems');

	warn "[$table] Looping through ID ranges from 0 - $maxID{$table}\n";

	my $chunk_start = 0;

	while ($chunk_start < $maxID{$table}) {

		warn "[$table] Chunk $chunk_start\n" if ($debug);

		my $chunk_end = $chunk_start + $chunk_size - 1;
		$chunk_end = $maxID{$table} if ($chunk_end > $maxID{$table});

		my @good = ();
		my @bad = ();

		foreach my $id ($chunk_start..$chunk_end) {
			if ($id && vec($IDvector{$table}, $id, 1)) {
				push @good, $id;
			} else {
				push @bad, $id;
			}
		}
		warn "Marking BAD:  ".int(@bad)."\n" if ($debug);
		log_mysql('elite',"update $table set deletionState=1 where $idfield in (".join(',',@bad).") and $idfield is not null and $idfield>0") if (@bad);
		warn "Marking GOOD: ".int(@good)."\n" if ($debug);
		log_mysql('elite',"update $table set deletionState=0 where $idfield in (".join(',',@good).") and $idfield is not null and $idfield>0") if (@bad);

		$chunk_start += $chunk_size;

		if (!$debug) {
			print "."  if ($chunk_start % 10000 == 0);
			print "\n" if ($chunk_start % 1000000 == 0);
		}
	}
	print "\n";

	warn "[$table] Pulling list of removal candidates.\n";

	my @rows = db_mysql('elite',"select $idfield as ID,name from $table where deletionState=1");

	warn "[$table] ".int(@rows)." deletion candidates found.\n";

	open TXT, ">removals-$table.txt";
	while (@rows) {
		my $r = shift @rows;
		print TXT "$$r{ID},$$r{name}\r\n";
	}
	close TXT;
}



###########################################################################


