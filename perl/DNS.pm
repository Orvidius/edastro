package ISP::DNS;

use strict;
use Net::DNS;

BEGIN { # Export functions first because of possible circular dependancies
   use Exporter;
   use vars qw(@ISA $VERSION @EXPORT_OK);

   $VERSION = 2.01;
   @ISA = qw(Exporter);
   @EXPORT_OK = qw(dns_resolve);
}



sub dns_resolve {
   my $name = shift;
   my $timeout = shift;
   my $found = '';

   $SIG{ALRM} = sub { die "timeout" };
   eval {
      alarm($timeout); # Set a timeout
      my $res = Net::DNS::Resolver->new;
      my $query = $res->search($name);      # check to see if we get an answer other then NXDOMAIN 
      if ($res->errorstring ne "NXDOMAIN") {    # if we don't get an NXDOMAIN, try to get what it resolves to
         foreach my $rr ($query->answer) {
             if ($rr->type eq "A") {
                $found = $rr->address; last;
             } elsif ($rr->type eq "PTR") {
                $found = $rr->ptrdname; last;
             }
         }
      }
      alarm(0);
   };
   alarm(0);

   return($found);
}


1;


