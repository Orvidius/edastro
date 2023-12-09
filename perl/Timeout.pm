package ISP::Timeout;

use strict;

BEGIN { # Export functions first because of possible circular dependancies
   use Exporter;
   use vars qw(@ISA $VERSION @EXPORT_OK);

   $VERSION = 2.01;
   @ISA = qw(Exporter);
   @EXPORT_OK = qw(timeout);
}


sub timeout (&$) {

	my ($code, $duration) = @_;

	alarm 0;
	local $SIG{ALRM} = sub { die "timeout\n"; };
	eval {
		alarm $duration;
		$code->();
		alarm 0;
	};
	alarm 0;

	return $@ if $@ && $@ !~ /timeout/;
	return '';
	
}


# Use like this (5 second timeout in this example):
#
# timeout {
#	# Do something here
# } 5;


1;


