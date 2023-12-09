#!/usr/bin/perl
use strict;



###########################################################################

use LWP 5.64;
use Data::Dumper;
use WWW::Mechanize ();
use HTTP::Cookies;

use lib "/home/bones/perl";
use DB qw(db_mysql show_queries);
use ATOMS qw(date2epoch epoch2date make_csv parse_csv btrim);

###########################################################################

my $url_base = 'https://www.edsm.net';
my $codex_url = "$url_base/en/codex";

my $browser = LWP::UserAgent->new;

###########################################################################

my %codex = ();

my $mech = WWW::Mechanize->new();
$mech->agent('Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:79.0) Gecko/20100101 Firefox/79.0');
$mech->max_redirect(10);

get_codex($codex_url);

foreach my $n (sort keys %codex) {
	foreach my $s (sort keys %{$codex{$n}}) {
		print make_csv($n,$s)."\r\n";
	}
}

exit;


###########################################################################

sub get_codex {
	my $url = shift;
	my @regions = get_links($url,'categories');
	my @categories = ();
	my @entries = ();

	foreach my $r (@regions) {
		push @categories, get_links($r,'Geology|Organic');
last;
	}
	foreach my $c (@categories) {
		print "CATEGORY: $c\n";
		push @entries, get_links($c,'Geology|Organic');
last;
	}

	foreach my $e (@entries) {
		my $page = get_page($e);

		my @sections = split /<div\s+class="card">/, $page;

		foreach my $html (@sections) {
			my $name = undef;
			my $link = undef;
			my $system = undef;
	
			#<div class="col-md-6"> Sulphur Dioxide Gas Vent </div>
			if ($html =~ /<div\s+class="card-header">\s*<div\s+class="row">\s*<div\s+class="[\w\d\-]+">\s*(\S[\w\d\s\-]+\S)\s*<\/div>/is) {
				 $name = btrim($1);
			}
				
			#Reported location <span class="text-right"> <a href="/en/system/id/35155012/name/Byoomao+JC-B+d1-3681">Byoomao JC-B d1-3681</a>
			if ($html =~ /Reported location\s+<span[^>]*>\s+<a href="[^"]*">([\w\s\d\-]+)<\/a>/is) {
				 $system = btrim($1);
			}
				
			# <a href="/en/search/systems/index/codexEntry/21220/codexRegion/1/onlyPopulated/0" class="btn btn-sm btn-primary w-100"> Find K10-Type Anomaly in Galactic Centre </a>
			if ($html =~ /<a href="([^"]+)"[^>]*>\s*Find [\w\d\s\-]+ in ([\w\d\s\-]+)\s*<\/a>/is) {
				$link = btrim($1) if (lc($2) ne 'galaxy');
				
			}
	
			#print "> $name  /  $system  /  $link\n";
	
			if ($name && $system && $link) {
				edsm_form($name,$system,$link);
			}
		}

last;
	}
}

sub edsm_form {
	my ($name,$system,$url) = @_;
	$url = $url_base.$url if ($url =~ /^\//);
	$url = $codex_url.$url if ($url !~ /^\// && $url !~ /^http/i);

	print "### $name ($system) search: $url\n";

	$codex{$name}{$system} = 1;

	$mech->get($url);

	#print $mech->content."\n\n";
	#exit;

	if (!$mech->success) {
		warn "GET FAIL: $url\n";
		return;
	}

	$mech->submit_form(
		form_number => 1,
		fields      => {
			cmdrPosition=>$system,
			radius=>5000,
		}
	);

	if (!$mech->success) {
		warn "FORM FAIL: $url\n";
		return;
	}

	my $page = $mech->content;
	#print "$page\n";

	#while ($page =~ /<td>\s*<a\s+href="\/en\/system\/id\/\d+\/name\/[\w\d\s\_\-\+]+">\s*<strong>\s*([\w\d\s\_\-\+]+)\s*<\/strong>\s*<\/a>/gsi) {
	while ($page =~ /<td>\s*<a\s+href="\/en\/system\/[^"]+">\s*<strong>\s*([\w\d\s\_\-\+]+)\s*<\/strong>\s*<\/a>/gsi) {
		$codex{$name}{btrim($1)} = 1;
		warn "CODEX: $name: $1\n";
	}
	exit;
}

sub get_links {
	my $url = shift;
	my $pattern = shift;

	my $data = get_page($url);
	my %linklist = ();

#print "$data\n" if ($pattern);

	while ($data =~ /href="([^"]*\/en\/codex\/[^"]+)"/g) {
		my $u = $1;
		$linklist{$u}++ if (!$pattern || $u =~ /$pattern/i);
#print "FOUND BAD $u\n" if (!$linklist{$u});
#print "FOUND URL: $u\n" if ($linklist{$u});
	}

	return (sort keys %linklist);
}

sub get_page {
	my $url = shift;
	$url = $url_base.$url if ($url =~ /^\//);
	$url = $codex_url.$url if ($url !~ /^\// && $url !~ /^http/i);

	print "GET $url\n";

	if (0) {
		my $response = $mech->get($codex_url);

		if (!$response->is_success) {
			warn "Could not retrieve $url [".$response->status_line()."]\n";
			return undef;
		} else {
			return $mech->content;
		}
	} else {
		$url =~ s/[^\w\d \-\+\/\\:.,;]//gs;

		open HTML, "/usr/bin/curl '$url' 2>/dev/null |";
		my @lines = <HTML>;
		close HTML;
		return join('',@lines);
	}
}

###########################################################################




