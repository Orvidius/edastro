#!/usr/bin/perl
use strict; $|=1;

###########################################################################

use lib "/home/bones/perl";
use DB qw(columns_mysql db_mysql show_queries);

###########################################################################

my $debug       = 0;
my $verbose     = 0;

my $db          = 'elite';

###########################################################################

my %systems = ();
my %bodies = ();

#my $ref = columns_mysql($db,"select distinct systemId64 from planets where CAST(name as binary) not rlike ' [A-Z][A-Z]-[A-Z] [a-h]' and deletionState=0 order by planetID");
#my $ref = columns_mysql($db,"select distinct systemId64 from planets where updated>='2021-03-17 00:00:00' and updated<='2021-03-19 00:00:00' and (eddn_date is null || eddn_date<'2021-03-14 00:00:00')");

#my $ref = columns_mysql($db,"select distinct systemId64 from planets where subType='Icy body' and radius is not null and (radius<160 or radius>30783) and deletionState=0 order by planetID");
#my $ref = columns_mysql($db,"select distinct systemId64 from planets where subType in ('Class I gas giant','Class II gas giant','Class III gas giant','Class IV gas giant','Class V gas giant'','Gas giant with ammonia-based life','Gas giant with water-based life') and earthMasses is not null and earthMasses<2 and deletionState=0 order by planetID");

#my $sql = "select distinct systemId64 from planets where subType='Class II gas giant' and earthMassesDec is not null and earthMassesDec<2 and deletionState=0 order by planetID";
#my $sql = "select distinct systemId64 from planets where subType='Class I gas giant' and earthMassesDec is not null and earthMassesDec<0.7 and deletionState=0 order by planetID";
#my $sql = "select distinct systemId64 from planets where subType='Class III gas giant' and earthMassesDec is not null and earthMassesDec<4 and deletionState=0 order by planetID";

#my $sql = "select distinct systemId64 from planets where subType='Class I gas giant' and radiusDec is not null and radiusDec<8000 and deletionState=0 order by planetID";
#my $sql = "select distinct systemId64 from planets where subType='Class II gas giant' and radiusDec is not null and radiusDec<10000 and deletionState=0 order by planetID";

$0 = $0.": $sql";
my $ref = columns_mysql($db,$sql);

print int(@{$$ref{systemId64}})." id64 systems to look at.\n";

while (@{$$ref{systemId64}}) {
	my @list = splice @{$$ref{systemId64}}, 0, 80;
	system('/home/bones/elite/edsm/get-system-bodies.pl',@list);
	sleep 1;
}

