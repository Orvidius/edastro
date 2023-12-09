#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries disconnect_all);
use ATOMS qw(epoch2date date2epoch make_csv parse_csv);

use CGI 2.47 qw(:standard);
use JSON;

############################################################################

my %okIP = ();
$okIP{'45.79.209.247'} = 1;
$okIP{'64.22.71.252'} = 1;
$okIP{'74.207.224.66'} = 1;
$okIP{'45.33.72.225'} = 1;

############################################################################

print "Content-type: text/plain\n\n";

my $json = JSON->new->allow_nonref;
my $query = new CGI;
my $id64 = $query->param('id64');
my $name = $query->param('name');
my $edsm_id = $query->param('edsmID');

exit if (!$id64 && !$name && !$edsm_id);

my $ip = $ENV{REMOTE_ADDR};

if (!$okIP{$ip} && $ip !~ /^(10\.99\.50\.\d+|127\.0\.0\.\d+)$/) {
	print "Not authorized ($ip).\n";
	exit;
}

my @rows = ();

@rows = db_mysql('elite',"select name,edsm_id,id64,coord_x,coord_y,coord_z from systems where name=?",[($name)]) if ($name);
@rows = db_mysql('elite',"select name,edsm_id,id64,coord_x,coord_y,coord_z from systems where id64=?",[($id64)]) if ($id64 && !@rows);
@rows = db_mysql('elite',"select name,edsm_id,id64,coord_x,coord_y,coord_z from systems where edsm_id=?",[($edsm_id)]) if ($edsm_id && !@rows);

if (@rows) {
	my $r = shift @rows;
	#print "$$r{name}\n$$r{edsm_id}\n$$r{id64}\n$$r{coord_x}\n$$r{coord_y}\n$$r{coord_z}\n";
	print $json->pretty->encode( $r )."\n";
}

exit 0;


