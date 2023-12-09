#!/usr/bin/perl
use strict;
$|=1;

my $name = $ARGV[0];
die "Usage: $0 <systemName>\n" if (!$name);


my $path	= '/home/bones/convert';
my %seen	= ();


print "$path -- $name\n";
opendir DIR, $path;
foreach my $fn (sort readdir DIR) {
	#print "$path/$fn\n";

	if ($fn =~ /\.bmp$/) {
		do_file("$path/$fn");
	}
}
closedir DIR;

exit;


sub do_file {
	my $fn = shift;

	my @t = gmtime((stat($fn))[9]);

	my $new = sprintf("%04u-%02u-%02u %02u-%02u-%02u %s.png",$t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0],$name);

	$seen{$new}++;

	$new =~ s/\.png$/\_$seen{$new}.png/;
	$new = "$path/$new";

	my $conv = "convert '$fn' '$new'";
	print "# $conv\n";
	system($conv);
	unlink $fn;
}



