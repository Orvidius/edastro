#!/usr/bin/perl
use strict;

##########################################################################

#use CGI::Carp qw(fatalsToBrowser);

use utf8;
#use utf8::all;
use feature qw( unicode_strings );

use HTML::Entities;
use Encode;
use CGI;
use JSON;
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Headers;
use POSIX qw(floor strftime);
use Tie::IxHash;
use MIME::Base64;
use File::Copy;
use Data::Dumper;
#use Text::Unidecode;

use lib "/home/bones/perl";
use ATOMS qw(make_csv parse_csv btrim epoch2date date2epoch);
use DB qw(rows_mysql db_mysql $print_queries show_queries);
use EMAIL qw(sendMultipart);


die "Usage: $0 <poiID>\n" if (!@ARGV);

foreach my $poiID (@ARGV) {

        my @rows = db_mysql('elite','select * from POI where gec_id=?',[($poiID)]);

        foreach my $r (@rows) {
                foreach my $var (qw(summary descriptionHtml)) {

                        print "\n".uc($var).":\n";
                        my @array = ( $$r{$var} =~ m/./g );
                        foreach my $c (@array) {
                                printf("%s -- %4x\n",$c,ord($c));
                        }
                }
        }
}
