#!/usr/bin/perl
use strict;
use lib "/home/bones/perl";
use DB qw(db_mysql);

db_mysql('elite',"update POI set hidden=1");

