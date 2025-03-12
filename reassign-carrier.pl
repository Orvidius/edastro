#!/usr/bin/perl
use strict; $|=1;

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);

show_queries(0);

if (!$ARGV[0] || !$ARGV[1]) {
	die "Usage: $0 <oldCallsign> <newCallsign> [force]\n";
}

my $old = $ARGV[0];
my $new = $ARGV[1];
my $force = $ARGV[2];


##### Don't reassign anmore
exit;
##### Don't reassign anmore

sleep 1;

my @c1c = db_mysql('elite',"select count(*) from carriers where callsign=?",[($old)]);
my @c2c = db_mysql('elite',"select count(*) from carriers where callsign=?",[($new)]);

my @c1l = db_mysql('elite',"select count(*) from carrierlog where callsign=?",[($old)]);
my @c2l = db_mysql('elite',"select count(*) from carrierlog where callsign=?",[($new)]);

die "'$ARGV[0]' not found.\n" if (!@c1c);
die "'$ARGV[1]' already exists.\n" if (@c2c && !$force);
warn "WARNING '$ARGV[1]' already exists.\n" if (@c2c && $force);

my @preserve = db_mysql('elite',"select * from carriers where callsign=?",[($old)]);
my @compare = db_mysql('elite',"select * from carriers where callsign=?",[($new)]);

eval { db_mysql('elite',"delete from carriers where callsign=?",[($old)]); };
eval { db_mysql('elite',"update carrierlog set callsign=?,converted=1 where callsign=?",[($new,$old)]); };
eval { db_mysql('elite',"update carrierdockings set callsign=? where callsign=?",[($new,$old)]); };
eval { db_mysql('elite',"update carriers set converted=1,callsign_old=? where callsign=?", [($old,$new)]); };

foreach my $field (qw(created name services isDSSA isIGAU commander)) {
	#print "\t$field: ${$preserve[0]}{$field}\n";
	db_mysql('elite',"update carriers set $field=? where callsign=?", [(${$preserve[0]}{$field},$new)]) 
		if ((${$preserve[0]}{$field} && !${$compare[0]}{$field}) || ($field eq 'created' && ${$preserve[0]}{$field} lt ${$compare[0]}{$field}));
}

print "Updated '$old' -> '$new'\n";

