#!/usr/bin/perl
use strict; $|=1;
###########################################################################

#use lib "/www/EDtravelhistory/perl";
use lib "/home/bones/perl";
use ATOMS qw(btrim parse_csv);
use DB qw(db_mysql);

use JSON;
use POSIX qw(floor);

###########################################################################

#my $path	= '/www/edastro.com/galmap';
my $path	= '/home/bones/elite/POIstuff';
my %list	= ();
my %list1	= ();
my %list2	= ();
my @jsonlist	= ();
my %json_added	= ();
my %done	= ();
my %edsm_skip	= ();
my %edsm_force	= ();
my %coordsdone	= ();

#print "Content-Type: text/plain\n\n";

my %pinOverride = ();

my @rows = db_mysql('elite',"select edsm_id,gec_id,pinOverride from POI where pinOverride is not null and pinOverride!=''");
foreach my $r (@rows) {
	$pinOverride{edsm}{$$r{edsm_id}} = $$r{pinOverride} if ($$r{edsm_id});
	$pinOverride{gec}{$$r{gec_id}} = $$r{pinOverride} if ($$r{gec_id});
}

add_EDSM();
make_list('AB');	# Asteroid Bases
make_list('AS');	# Abondoned Settlements
make_list('N');		# Nebulae
make_list('X');		# Permit locked regions
make_list('P');		# Planetary Bases
make_list('S');		# Starbases
#make_list('M');		# Meridians
make_list('meridians');		# Meridians
make_list();		# Misc

open TXT, ">$path/POI-include.html";
foreach my $s (sort { $list{$a} <=> $list{$b} } keys %list) {
	print TXT $s;
}
close TXT;

open TXT, ">$path/POI-include1.html";
foreach my $s (sort { $list1{$a} <=> $list1{$b} } keys %list1) {
	print TXT $s;
}
close TXT;

open TXT, ">$path/POI-include2.html";
foreach my $s (sort { $list2{$a} <=> $list2{$b} } keys %list2) {
	print TXT $s;
}
close TXT;

my %outlist = ();
@jsonlist = sort { $$a[0] <=> $$b[0] || $$a[4] cmp $$b[4] } @jsonlist;

my $i = 0;
foreach my $ref (@jsonlist) {
	push @{$outlist{$i}}, $ref;
	$i++;
	$i = 0 if ($i>=4);
}

open JSON, ">$path/POI.json";
my %jsonhash = ('markers' => [(@jsonlist)]);
my $jsonstring = encode_json(\%jsonhash);
$jsonstring =~ s/\],\[/\],\r\n\[/gs;
print JSON $jsonstring;
close JSON;

foreach my $i (0..3) {
	open JSON, ">$path/POI$i.json";
	my %jsonhash = ('markers' => [(@{$outlist{$i}})]);
	my $jsonstring = encode_json(\%jsonhash);
	$jsonstring =~ s/\],\[/\],\r\n\[/gs;
	print JSON $jsonstring;
	close JSON;
}

exit;

###########################################################################

sub make_list {
	my $type = shift;
	my $fn   = 'POI-misc.csv';	# Misc
	
	$fn = 'POI-nebulae.csv' if ($type eq 'N');
	$fn = 'POI-asteroidbases.csv' if ($type eq 'A' || $type eq 'AB');
	$fn = 'POI-abandoned.csv' if ($type eq 'AS');
	$fn = 'POI-permitlocks.csv' if ($type eq 'X');
	$fn = 'POI-planetarybases.csv' if ($type eq 'P');
	$fn = 'POI-starbases.csv' if ($type eq 'S');
	$fn = 'POI-meridians.csv' if ($type eq 'M' || $type eq 'meridians');
	
	if ($fn && -e "$path/$fn") {
		open TXT, "<$path/$fn";
		while (<TXT>) {
			chomp;
	
			next if (/^\s*\// || /^\s*#/);
	
			my $string = $_;
			$string =~ s/ \/ /,/gs;
	
			my @v = parse_csv($string);
	
			if ($v[0] =~ /^\s*[\d\;]+\s*$/ && $v[3] =~ /^\s*[\-\d\.]+\s*$/) {
				my @ids = split /;/,shift(@v);
				foreach my $i (@ids) {
					$done{$i} = $type if ($i);
				}
			}
	

			my $c = '';
			$c = ",$v[4]" if ($v[4]);
	
			my $d = sqrt($v[0]**2 + $v[1]**2 + $v[2]**2);
	
			my $type_add = '';
			$type_add = ",'$type'" if ($type);

			my @params = ();
			push @params, $type if ($type);
			my $second = $v[4]; $second =~ s/'(.+)'/$1/s;
			push @params, $second if ($second);
	
			print "Using \"$v[3]\" ($v[0],$v[1],$v[2]) ".join(',',@params)."\n";

			if (!$coordsdone{floor($v[0])}{floor($v[2])}) {

				addMarker(\%list, $d,$v[0],$v[1],$v[2],$v[3],@params);
				addMarker(\%list1,$d,$v[0],$v[1],$v[2],$v[3],@params);
				
				#$list{"\t\tcreateGalmapMarker3D(map,$v[0],$v[1],$v[2],\"$v[3]\"$type_add$c);\n"} = $d;
				#$list1{"\t\tcreateGalmapMarker3D(map,$v[0],$v[1],$v[2],\"$v[3]\"$type_add$c);\n"} = $d;
			} else {
				print "\t^ Skipped \"$v[3]\" ($v[0],$v[1],$v[2]) ".join(',',@params)."\n";

				foreach my $ref (@{$coordsdone{floor($v[0])}{floor($v[2])}}) {
					#if ($$ref[5] !~ /^(N|PN|AB|megaship)$/i) {
					if ($$ref[5] eq 'O') {
						$$ref[5] = $params[0];
						$$ref[6] = $params[1] if ($params[1]);
					}
				}
			}
		}
		close TXT;
	}
}

sub add_EDSM {

	my %override = ();

	open TXT, "<$path/POI-edsm-name-overrides.csv";
	while (my $s = <TXT>) {
		chomp $s;
		$s =~ s/\s*#.*$//;
		next if (!$s);

		my @list = split /\s+/,$s,2;
		if ($list[0]) {
			$override{$list[0]} = $list[1] if ($list[0] && $list[1]);
		}
	}
	close

	open TXT, "<$path/POI-edsm-force.csv";
	while (my $s = <TXT>) {
		chomp $s;
		$s =~ s/\s*#.*$//;
		next if (!$s);

		my @list = split /\s*,\s*/,$s;
		foreach my $n (@list) {
			$edsm_force{$n}=1 if ($n);
		}
	}
	close

	open TXT, "<$path/POI-edsm-skip.csv";
	while (my $s = <TXT>) {
		chomp;
		$s =~ s/\s*#.*$//;
		next if (!$s);
		
		my @list = split /\s*,\s*/,$s;
		foreach my $n (@list) {
			$edsm_skip{btrim($n)}=1 if ($n =~ /\d/);
		}
	}
	close

	open TXT, "<$path/edsmPOI.data";
	while (<TXT>) {
		chomp;
		next if (!$_);
		my @v = split /\t\|\t/, $_;
		my %hash = ();

		#print "Checking: ".join(';',@v)."\n";

		if (@v>1) {
			$hash{type}	= $v[0];
			$hash{id}	= $v[1];
			$hash{name}	= $v[2];
			$hash{x}	= $v[3];
			$hash{y}	= $v[4];
			$hash{z}	= $v[5];
			$hash{mapref}	= $v[6];
			$hash{pin}	= $v[7];
			$hash{extra}	= $v[8];

			$hash{name}	= $override{$hash{id}} if ($override{$hash{id}});

			#next if ($done{$v[1]} && $done{$v[1]} eq 'GGG');
			next if ($done{$v[1]});
		} else {
			next;
		}

		#print "Checking: ".join(';',@v)."\n";

		if ($edsm_skip{$hash{id}}) {
			print "Skipping (via edsm_skip) $hash{type}($hash{pin}) \"$hash{mapref}\ ($hash{name}) #$hash{id}\n";
			next;
		}

		if ($edsm_force{$hash{id}} || $hash{id}=~ /^GEC/ || $hash{type} =~ /^(GGG|nebula|planetaryNebula|deepSpaceOutpost|restrictedSectors|stellarRemnant|planetFeatures|surfacePOI|historicalLocation|minorPOI|carrier|DSSA|carrierseen|carrierunknown|carriertmp|carriersuspend|carrierundeploy|carrierIGAU|edastrocarrier|tritium|raxxla|canonn|megaship|megaship2|STARsell|STARbuy|STARcarrier|STARunknown|STARred|STARgreen|STARyellow|STARcyan|STARpurple|PIONEERcarrier|PIONEERtmp|PIONEERunknown|DSSAcarrier|DSSArefit|DSSAtmp|DSSAsuspend|DSSAseen|DSSAundeploy|DSSAunknown|guardian|IGAUcarrier)$/) {
			my $skip = 0;

			if ($hash{type} !~ /^(edastrocarrier|carrier|DSSA|carrierseen|carrierunknown|carriertmp|carriersuspend|carrierundeploy|carrierIGAU|GGG|tritium|raxxla|canonn|megaship|megaship2|STARsell|STARbuy|STARcarrier|STARunknown|STARred|STARgreen|STARyellow|STARcyan|STARpurple|PIONEERcarrier|PIONEERtmp|PIONEERunknown|DSSAcarrier|DSSArefit|DSSAtmp|DSSAsuspend|DSSAseen|DSSAundeploy|DSSAunknown|guardian|IGAUcarrier)$/) { 
					# && $hash{pin} !~ /^(DSSA|carriertmp|carrierIGAU|GGG)$/) {

				my $namecheck = $hash{name};	$namecheck =~ s/([-\[\]\(\)\^\$\*\+\&])/\\$1/gs;
				my $mrefcheck = $hash{mapref};	$mrefcheck =~ s/([-\[\]\(\)\^\$\*\+\&])/\\$1/gs;

				foreach my $k (keys %list) {
					$skip = 1 if ($k =~ /"$namecheck"/i || $k =~ /"$mrefcheck"/i);
					$skip = 0 if (($hash{type} =~ /GGG/ || $hash{pin} =~ /GGG/) && $k =~ /GGG/);
				}
			}

			if ($skip) {
				print "Skipping (via namecheck) $hash{type}($hash{pin}) \"$hash{mapref}\ ($hash{name}) #$hash{id}\n";
				next;
			}

			next if ($hash{name} =~ /^\s*Archived:\s+/);

			my $pin = '';
			$pin = "'N'"  if ($hash{type} eq 'nebula');
			$pin = "'O'"  if ($hash{type} eq 'deepSpaceOutpost' || $hash{type} =~ /Deep Space/);
			$pin = "'X'"  if ($hash{type} eq 'restrictedSectors');
			#$pin = "'M'"  if ($edsm_force{$hash{id}} || $hash{type} eq 'minorPOI');
			$pin = "'M'"  if ($edsm_force{$hash{id}});
			$pin = "'archived'"  if (!$edsm_force{$hash{id}} && $hash{type} eq 'minorPOI');
			$pin = "'H'"  if ($edsm_force{$hash{id}} || $hash{type} eq 'historicalLocation' || $hash{type} =~ /historical/i);
			$pin = "'Pl'"  if ($hash{type} =~ /^(planetFeatures|surfacePOI)$/ || $hash{type} =~ /Planetary/);
			$pin = "'St'"  if ($hash{type} =~ /^(blackHole|pulsar|stellarRemnant)$/i || $hash{type} =~ /Stellar/);
			$pin = "'PN'" if ($hash{type} eq 'planetaryNebula' || $hash{name} =~ /Jade Ghost/i);
			$pin = "'GGG'" if ($hash{type} eq 'GGG');
			$pin = "'carrier'" if ($hash{type} =~ /carrier/i || ($hash{type} =~ /outpost/i && $hash{name} =~ /DSSA/));
			$pin = "'carriertmp'" if ($hash{type} =~ /carriertmp/i);
			$pin = "'carrierunknown'" if ($hash{type} =~ /carrierunknown/i);
			$pin = "'carrierseen'" if ($hash{type} =~ /carrierseen/i);
			$pin = "'carriersuspend'" if ($hash{type} =~ /carriersuspend/i);
			$pin = "'carrierundeploy'" if ($hash{type} =~ /carrierundeploy/i);
			$pin = "'carrierPin'" if ($hash{type} =~ /outpost/i && $hash{name} =~ /DSSA/);
			$pin = "'DSSAcarrier'" if ($hash{type} =~ /DSSA/);
			$pin = "'DSSAtmp'" if ($hash{type} =~ /DSSAtmp|DSSArefit/i);
			$pin = "'DSSAunknown'" if ($hash{type} =~ /DSSAunknown/i);
			$pin = "'DSSAseen'" if ($hash{type} =~ /DSSAseen/i);
			$pin = "'DSSAsuspend'" if ($hash{type} =~ /DSSAsuspend/i);
			$pin = "'DSSAundeploy'" if ($hash{type} =~ /DSSAundeploy/i);
			$pin = "'carrierIGAU'" if ($hash{type} =~ /carrierIGAU/i);
			$pin = "'IGAUcarrier'" if ($hash{type} =~ /IGAUcarrier/);
			$pin = "'STARbuy'" if ($hash{type} =~ /STARbuy/i);
			$pin = "'STARsell'" if ($hash{type} =~ /STARsell/i);
			$pin = "'STARcarrier'" if ($hash{type} =~ /STARcarrier/i);
			$pin = "'STARunknown'" if ($hash{type} =~ /STARunknown/i);
			$pin = "'STARred'" if ($hash{type} =~ /STARred/i);
			$pin = "'STARgreen'" if ($hash{type} =~ /STARgreen/i);
			$pin = "'STARyellow'" if ($hash{type} =~ /STARyellow/i);
			$pin = "'STARcyan'" if ($hash{type} =~ /STARcyan/i);
			$pin = "'STARpurple'" if ($hash{type} =~ /STARpurple/i);
			$pin = "'PIONEERcarrier'" if ($hash{type} =~ /PIONEERcarrier/i);
			$pin = "'PIONEERunknown'" if ($hash{type} =~ /PIONEERunknown/i);
			$pin = "'PIONEERtmp'" if ($hash{type} =~ /PIONEERtmp/i);
			$pin = "'edastrocarrier'" if ($hash{type} =~ /edastrocarrier/i);
			$pin = "'guardian'" if ($hash{type} =~ /guardian/i);
			$pin = "'tritium'" if ($hash{type} =~ /tritium/i);
			$pin = "'raxxla'" if ($hash{type} =~ /raxxla/i);
			$pin = "'canonn'" if ($hash{type} =~ /canonn/i);
			$pin = "'$hash{type}'" if ($hash{type} =~ /megaship/i);
			$pin = "'$hash{pin}'" if ($hash{pin});

			if ($hash{id} =~ /^\d+$/ && $pinOverride{edsm}{$hash{id}}) {
				#$pin = '';
				foreach my $s (split ',',$pinOverride{edsm}{$hash{id}}) {
					$pin .= ",'$s'";
					#$pin = "'$s'";
				}
				$pin =~ s/^,+//s;
			}

			if ($hash{id} =~ /^GEC(\d+)$/ && $pinOverride{gec}{$1}) {
				#$pin = '';
				foreach my $s (split ',',$pinOverride{gec}{$1}) {
					$pin .= ",'$s'";
					#$pin = "'$s'";
				}
				$pin =~ s/^,+//s;
			}

			my $d = sqrt( $hash{x}**2 + $hash{y}**2 + $hash{z}**2 );
			print "Adding $hash{type}/$hash{id} [$pin] \"$hash{name}\" ($hash{x},$hash{y},$hash{z}) $hash{mapref}\n";

			my $add = '';
			$add = 'Location: ' if ($hash{type} =~ /carrierunknown/);

			my $ref = "\\n$add$hash{mapref}";
			$ref = '' if (uc($hash{mapref}) eq uc($hash{name}));
			$ref = '' if ($hash{type} eq 'restrictedSectors');

			if ($hash{extra}) {
				my $string = $hash{extra};
				$string =~ s/\+\|\+/\\n/gs;
				$ref .= "\\n$string";
			}

			$ref .= "\\n(Canonn Challenge)" if ($hash{type} eq 'canonn');
			$ref .= "\\n(Planetary Nebula)" if ($hash{type} eq 'planetaryNebula');
			$ref .= "\\n(Nebula)" if ($hash{type} eq 'nebula');
			$ref .= "\\n(Deep Space Outpost)" if ($hash{type} eq 'deepSpaceOutpost');
			$ref .= "\\n(Stellar Remnant)" if ($hash{type} eq 'stellarRemnant');
			$ref .= "\\n(Planetary Features)" if ($hash{type} eq 'planetFeatures');
			$ref .= "\\n(Surface POI)" if ($hash{type} eq 'surfacePOI');
			$ref .= "\\n(Historical Location)" if ($hash{type} eq 'historicalLocation');
			$ref .= "\\n(Archived POI)" if ($hash{type} eq 'minorPOI');
			$ref .= "\\n(Black Hole)" if ($hash{type} eq 'blackHole');
			$ref .= "\\n(Glowing Green Gas Giant)" if ($hash{type} eq 'GGG' || $pin =~ /GGG/);
			$ref .= "\\n(DSSA Fleet Carrier)" if (($hash{type} =~ /carrier|DSSA/ || $pin =~ /carrier/) && $hash{type} =~ /^DSSA/);
			$ref .= "\\n(STAR Fleet Carrier)" if ($hash{type} =~ /^STAR/);
			$ref .= "\\n(Pioneer Project Fleet Carrier)" if ($hash{type} =~ /^PIONEER/);
			$ref .= "\\n(IGAU Fleet Carrier)" if ($hash{type} eq 'carrierIGAU');
			$ref .= "\\n(NOT DEPLOYED - DSSA Fleet Carrier)" if ($hash{type} =~ /DSSAtmp/);
			$ref .= "\\n(NOT DEPLOYED - DSSA Refit)" if ($hash{type} =~ /DSSArefit/);
			$ref .= "\\n(SUSPENDED - DSSA Fleet Carrier)" if ($hash{type} =~ /DSSAsuspend/);
			$ref .= "\\n(LAST SEEN POSITION - DSSA Fleet Carrier)" if ($hash{type} =~ /DSSAseen/);
			$ref .= "\\n(UNKNOWN LOCATION - DSSA Fleet Carrier)" if ($hash{type} =~ /DSSAunknown/);
			$ref .= "\\n(UNKNOWN LOCATION - STAR Fleet Carrier)" if ($hash{type} =~ /STARunknown/);
			$ref .= "\\n(UNKNOWN LOCATION - Pioneer Project Fleet Carrier)" if ($hash{type} =~ /PIONEERunknown/);
			$ref .= "\\n(Past Deployed-Until Date - DSSA Fleet Carrier)" if ($hash{type} =~ /DSSAundeploy/);
			$ref .= "\\n(Double Tritium Hotspot Overlap)" if ($hash{type} =~ /tritium/ && $hash{name} =~ /\(Tri2\)/i);
			$ref .= "\\n(Triple Tritium Hotspot Overlap)" if ($hash{type} =~ /tritium/ && $hash{name} =~ /\(Tri3\)/i);
			$ref .= "\\n(Quadruple Tritium Hotspot Overlap)" if ($hash{type} =~ /tritium/ && $hash{name} =~ /\(Tri4\)/i);
			$ref .= "\\n(Tritium Hotspot Overlap)" if ($hash{type} =~ /tritium/ && $hash{name} !~ /\(Tri(2|3|4)\)/i);
			$ref .= "\\n(Mysterious Location)" if ($hash{type} =~ /raxxla/);
			$ref .= "\\n(Megaship)" if ($hash{type} =~ /megaship/);

			my $note = '';
			$note = "Restricted: " if ($hash{type} eq 'restrictedSectors');

			next if (!defined($hash{x}) || !defined($hash{y}) || !defined($hash{z}));
			next if ($hash{x} eq '' || $hash{y} eq ''  || $hash{z} eq '');

			push @{$coordsdone{floor($hash{x})}{floor($hash{z})}},
				addMarker(\%list, $d, $hash{x},$hash{y},$hash{z},"$note$hash{name}$ref",split(',',$pin));

			if ($pin =~ /'PN'|'M'/) {
					addMarker(\%list2, $d, $hash{x},$hash{y},$hash{z},"$note$hash{name}$ref",split(',',$pin));
			} else {
					addMarker(\%list1, $d, $hash{x},$hash{y},$hash{z},"$note$hash{name}$ref",split(',',$pin));
			}
		} else {
			print "Skipping (via type) $hash{type}($hash{pin}) \"$hash{mapref}\ ($hash{name}) #$hash{id}\n";
		}
	}
	close TXT;
}

sub addMarker {
	my ($href,$dist) = (shift,shift);
	my @p = @_;

	for (my $i=0;$i<@p;$i++) {
		if (length($p[$i]) && $p[$i] =~ /^[\d\.\-]+$/) {
			$p[$i] += 0; # Force numeric 
		} else {
			$p[$i] =~ s/\\n/\n/gs;
			#$p[$i] =~ s/\n{2,}/\n/gs;
			$p[$i] =~ s/\n{3,}/\n\n/gs;
			$p[$i] =~ s/\n{2,}$/\n/gs;
		}
		$p[$i] =~ s/^'(.+)'$/$1/s;
	}
	$dist = sprintf("%.02f",$dist) if ($dist);

	my $add_string = join('|',@p);

	push @jsonlist, [($dist,@p)] if (!$json_added{$add_string} && defined($p[0]) && defined($p[1]) && defined($p[2]));
	$json_added{$add_string}=1;

	if (@p > 3) {
		for (my $i=3;$i<@p;$i++) {
			$p[$i] = "\"$p[$i]\"" if ($p[$i] =~ /[^\d\.\-\+]/ && $p[$i] !~ /^'.+'$/);
		}
	}

	$$href{"\t\tcreateGalmapMarker3D(map,".join(',',@p).");\n"} = $dist;

	return $jsonlist[int(@jsonlist)-1];
}

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}

###########################################################################



