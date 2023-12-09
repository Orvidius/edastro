#!/usr/bin/perl
use strict; $|=1;

use Net::Dropbox::API;

my $box = Net::Dropbox::API->new({key => 'ipb2ut2f3kbkkvu', secret => '9msehe398he27tp'});
my $login_link = $box->login;  # user needs to click this link and login
print $login_link."\n";

$box->auth;                    # oauth keys get exchanged
my $info = $box->account_info; # and here we have our account info


