package ISP::CSV;

use strict;

BEGIN { # Export functions first because of possible circular dependancies
   use Exporter;
   use vars qw(@ISA $VERSION @EXPORT_OK);

   $VERSION = 2.01;
   @ISA = qw(Exporter);
   @EXPORT_OK = qw(make_csv parse_csv);
}

sub make_csv {
	my $result = '';

	foreach (@_) {
		my $i = $_;
		$i =~ s/[\n\r]//;
		$i =~ s/\"/\'/;
		$result .= ",\"$i\"";
	}
	$result =~ s/^\,//;
	return $result;
}



sub parse_csv {
    my $text = shift;      # record containing comma-separated values
    my @new  = ();
    push(@new, $+) while $text =~ m{
        # the first part groups the phrase inside the quotes.
        # see explanation of this pattern in MRE
        "([^\"\\]*(?:\\.[^\"\\]*)*)",?
           |  ([^,]+),?
           | ,
       }gx;
       push(@new, undef) if substr($text, -1,1) eq ',';
       return @new;      # list of values that were comma-separated
}


1;


