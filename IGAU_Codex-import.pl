#!/usr/bin/perl
use strict; $|=1;

use EDSM qw(codex_entry);
use lib "/home/bones/perl";
use ATOMS qw(parse_csv make_csv btrim);
use DB qw(db_mysql);


my %codexname = ();
my @rows = db_mysql('elite',"select codexname.name cname,codexname_local.name lname from codexname,codexname_local where codexname.id=codexname_local.codexnameID");
foreach my $r (@rows) {
	$codexname{$$r{lname}} = $$r{cname};
}


my $fn = "IGAU_Codex.csv";
$fn = $ARGV[0] if (@ARGV);

open TXT, "<$fn";

my $line = <TXT>;
my %col  = ();
my @cols = parse_csv($line);
for(my $i=0; $i<@cols; $i++) {
	$col{ref}  = $i if (!$col{ref} && $cols[$i] =~ /^\s*System\s*$/i);
	$col{name} = $i if (!$col{name} && $cols[$i] =~ /^\s*Name\s*$/i);
	$col{local} = $i if (!$col{local} && $cols[$i] =~ /Name_Localised/i);
	$col{id64} = $i if (!$col{id64} && $cols[$i] =~ /SystemAddress/i);
	$col{date} = $i if (!$col{date} && $cols[$i] =~ /timestamp/i);
}

print "\nREAD: $fn (System = $col{ref} ($col{id64}), Name = $col{name} [$col{local}], timestamp = $col{date})\n";

die "Missing columns!\n" if (!defined($col{ref}) || !defined($col{local}) || !defined($col{id64}) || !defined($col{date}));

while (<TXT>) {
	chomp;
	next if (!/,/);
	my @v = parse_csv($_);
	my %hash = ();

	$hash{reportedOn} = $v[$col{date}] if (defined($col{date}));
	$hash{Name} = btrim($v[$col{name}]) if (defined($col{name}));
	$hash{Name_Localised} = btrim($v[$col{local}]) if (defined($col{local}));
	$hash{System} = btrim($v[$col{ref}]) if (defined($col{ref}));
	$hash{SystemAddress} = $v[$col{id64}]+0 if (defined($col{id64}));

	if (!$hash{Name}) {
		$hash{Name} = $codexname{$hash{Name_Localised}};
	}

	$hash{Name} =~ s/^\$//;
	$hash{Name} =~ s/_name;?$//i;
	$hash{Name} = lc($hash{Name});

	if ($hash{Name} !~ /^codex_ent/i || !$hash{reportedOn} || !$hash{Name_Localised} || !$hash{System} || !$hash{SystemAddress}) {
		print "SKIPPED: $hash{reportedOn}: \"$hash{Name}\" ($hash{Name_Localised}) $hash{System} ($hash{SystemAddress})\n";
		next;
	}

	print "CODEX: $hash{reportedOn}: \"$hash{Name}\" ($hash{Name_Localised}) $hash{System} ($hash{SystemAddress})\n";
	codex_entry(\%hash,1);
}
close TXT;


