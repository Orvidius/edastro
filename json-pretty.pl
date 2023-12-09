#!/usr/bin/perl
use strict;

use JSON;

use utf8;
use feature qw( unicode_strings );


my $json = JSON->new->allow_nonref;

if (!@ARGV) {
	my $txt = '';
	foreach my $line (<STDIN>) {
		$txt .= $line;
	}

	$txt =~ s/,\s*$//gs;
	$txt =~ s/^[^\{\[]+//s;

	my $hashref = $json->decode( $txt );
	print $json->pretty->encode( $hashref );
	print "\n";
	exit;
}

foreach my $fn (@ARGV) {

	if ($fn =~ /\.jsonl$/) {
		open DATA, '<:encoding(UTF-8)', $fn;
		while (my $txt = <DATA>) {
			next if ($txt =~ /^\s*[\[\]]+\s*$/);

			$txt =~ s/^[^\{\[]+//s;
			$txt =~ s/,+\s*$//s;
			my $hashref = $json->decode( $txt );
	
			print $json->pretty->encode( $hashref );
			print "\n";
		}
		close DATA;
	} else {
		open DATA, '<:encoding(UTF-8)', $fn;
		my @lines = <DATA>;
		close DATA;
	
		my $txt = join '', @lines;
		$txt =~ s/^[^\{\[]+//s;

		my $hashref = $json->decode( $txt );

		print $json->pretty->encode( $hashref );
		print "\n\n";
	}
}
