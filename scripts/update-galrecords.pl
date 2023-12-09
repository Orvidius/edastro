#!/usr/bin/perl
use strict;

###########################################################################

#use lib "/var/www/edastro.com/scripts";
use lib "/home/bones/perl";
use ATOMS qw(parse_csv);
use DB qw(db_mysql);
use POSIX qw(floor ceil);


my $debug	= 0;
my $do_lookups	= 0;
my $allow_scp	= 1;

#my $csv1 = '/www/edastro.com/mapcharts/files/galactic-records-keys.csv';
#my $csv2 = '/www/edastro.com/mapcharts/files/galactic-records.csv';
my $path	= '/home/bones/elite/scripts';
my $records	= "$path/records";
my $csv1	= "$path/galactic-records-keys.csv";
my $csv2	= "$path/galactic-records.csv";
my $topsfile	= "$path/galactic-records-tops.csv";

my $scp                 = '/usr/bin/scp -P222';
my $ssh                 = '/usr/bin/ssh -p222';
my $remote_server       = 'www@services:/www/edastro.com/records';

my %data = ();
my %varnames = ();

my %vardisplay = ('absoluteMagnitude'=>'Absolute Magnitude', 'age'=>'Age', 'axialTilt'=>'Axial Tilt', 'distanceToArrivalLS'=>'Distance From Arrival', 
		'earthMasses'=>'Earth Masses', 'gravity'=>'Gravity', 'orbitalEccentricity'=>'Orbital Eccentricity', 'orbitalInclination'=>'Orbital Inclination', 
		'orbitalPeriod'=>'Orbital Period', 'radius'=>'Radius', 'rotationalPeriod'=>'Rotational Period', 'semiMajorAxis'=>'Semi-Major Axis', 
		'meanAnomaly'=>'Mean Anomaly', 'ascendingNode'=>'Longitude of Ascending Node',
		'solarMasses'=>'Solar Masses', 'solarRadius'=>'Solar Radius', 'surfacePressure'=>'Surface Pressure', 'surfaceTemperature'=>'Surface Temperature',
		'coord_x'=>'Coord-X','coord_y'=>'Coord-Y','coord_z'=>'Coord-Z','sol_dist'=>'Sol Distance',
		'area'=>'Area','mass'=>'Mass','outerRadius'=>'Outer Radius','innerRadius'=>'Inner Radius','density'=>'Density','width'=>'Width',
		'periapsis'=>'Periapsis / Closest Approach',
		'periapsis5Y'=>'Periapsis (next pass < 5 years)',
		'rings'=>'Rings','belts'=>'Belts',
		'sagittariusA_dist'=>'Sagittarius A* Distance',
		'rings_max_mass'=>'Outermost Ring - Mass','rings_max_area'=>'Outermost Ring - Area','rings_max_density'=>'Outermost Ring - Density',
		'rings_max_width'=>'Outermost Ring - Width','rings_max_innerRadius'=>'Outermost Ring - Inner Radius','rings_max_outerRadius'=>'Outermost Ring - Outer Radius',
		'rings_min_mass'=>'Innermost Ring - Mass','rings_min_area'=>'Innermost Ring - Area','rings_min_density'=>'Innermost Ring - Density',
		'rings_min_width'=>'Innermost Ring - Width','rings_min_innerRadius'=>'Innermost Ring - Inner Radius','rings_min_outerRadius'=>'Innermost Ring - Outer Radius',
		'belts_max_mass'=>'Outermost Belt - Mass','belts_max_area'=>'Outermost Belt - Area','belts_max_density'=>'Outermost Belt - Density',
		'belts_max_width'=>'Outermost Belt - Width','belts_max_innerRadius'=>'Outermost Belt - Inner Radius','belts_max_outerRadius'=>'Outermost Belt - Outer Radius',
		'belts_min_mass'=>'Innermost Belt - Mass','belts_min_area'=>'Innermost Belt - Area','belts_min_density'=>'Innermost Belt - Density',
		'belts_min_width'=>'Innermost Belt - Width','belts_min_innerRadius'=>'Innermost Belt - Inner Radius','belts_min_outerRadius'=>'Innermost Belt - Outer Radius',
		'bodyCount'=>'Body Count (Discovery Scan)',nonbodyCount=>'Non-Body Count',systems=>'Systems',
		'numStars'=>'Number of Stars (Reported)','numPlanets'=>'Number of Planets (Reported)',numBodies=>'Number of Bodies (Total Reported)',
		'numELW'=>'Number of Earth-like worlds','numAW'=>'Number of Ammonia worlds','numWW'=>'Number of Water Worlds','numTerra'=>'Number of Terraforming Candidates',
		);


my %planetvars = ();
my %starvars = ();
my %ringvars = ();
my %systemvars = ();
my $jsID = 0;

my $one = 1;

$do_lookups = 1 if (@ARGV);

###########################################################################

#print "Content-Type: text/html\n\n" if (!@ARGV);


sub get_edsm {
	my ($href, $minmax, $id64, $table, $body) = @_;

	if ($table eq 'belts' || $table eq 'rings') {
		my @rows = db_mysql('elite',"select isStar,planet_id from $table where id=?",[($body)]);
		if (@rows) {
			my $table2 = 'planets'; 
			my $idfield2 = 'planetID';

			if (${$rows[0]}{isStar}) {
				$table2 = 'stars';
				$idfield2 = 'starID';
			}

			my @rows2 = db_mysql('elite',"select edsmID,systemId from $table2 where $idfield2=?",[(${$rows[0]}{planet_id})]);
			if (@rows2) {
				$$href{$minmax.'EDSMID'} = ${$rows2[0]}{edsmID};
				$$href{$minmax.'SysEDSMID'} = ${$rows2[0]}{systemId};
			}
		}
		return;
	}

	my $key = ($table eq 'stars') ? 'starID' : 'planetID';
	$key = 'ID' if ($table eq 'systems');
	#print "table=$table, key=$key\n";

	my @rows = ();
	@rows = db_mysql('elite',"select edsmID,systemId from $table where $key=?",[($body)]) if ($table ne 'systems');
	@rows = db_mysql('elite',"select edsm_id as edsmID,edsm_id as systemId from $table where $key=?",[($body)]) if ($table eq 'systems');

	if (@rows && ${$rows[0]}{edsmID} && ${$rows[0]}{systemId}) {
		$$href{$minmax.'EDSMID'} = ${$rows[0]}{edsmID};
		$$href{$minmax.'SysEDSMID'} = ${$rows[0]}{systemId};
		return;
	}

	return if (!$do_lookups);

	system('/home/bones/elite/edsm/get-system-bodies.pl',$id64);

	my @rows = ();
	@rows = db_mysql('elite',"select edsmID,systemId from $table where $key=?",[($body)]) if ($table ne 'systems');
	@rows = db_mysql('elite',"select edsm_id as edsmID,edsm_id as systemId from $table where $key=?",[($body)]) if ($table eq 'systems');

	if (@rows) {
		$$href{$minmax.'EDSMID'} = ${$rows[0]}{edsmID};
		$$href{$minmax.'SysEDSMID'} = ${$rows[0]}{systemId};
	}
	return;
}

my %sys64 = ();

open CSV, "<$csv1";
my $header = <CSV>;
while (<CSV>) {
	chomp;
	next if (!$_);
	my @v = parse_csv($_);
	my ($type,$var) = ($v[0],$v[1]);
	next if (!$type || !$var);

	$type =~ s/\\\//\//gs;

	$varnames{$var}=1;
	$planetvars{$var}=1 if ($type =~ /Water/i);
	$starvars{$var}=1   if ($type =~ /Star|Hole/i && $type !~ /System/i);
	$ringvars{$var}=1   if ($type =~ /Ring|Belt/i);
	$systemvars{$var}=1 if ($type =~ /System/i);

	my $table = 'planets';
	$table = 'stars' if ($type =~ /Star|Hole/i);
	$table = 'belts' if ($type =~ /Belt/);
	$table = 'rings' if ($type =~ /Ring/);
	$table = 'systems' if ($type =~ /Systems/i);

	$data{$type}{$var}{maxID} = $v[2];
	$data{$type}{$var}{maxName} = $v[3];
	$data{$type}{$var}{maxEDSMID} = $v[4];
	$data{$type}{$var}{maxSysEDSMID} = $v[5];
	$data{$type}{$var}{maxSysID64} = $v[6];
	$data{$type}{$var}{maxSysName} = $v[7];

	$data{$type}{$var}{minID} = $v[8];
	$data{$type}{$var}{minName} = $v[9];
	$data{$type}{$var}{minEDSMID} = $v[10];
	$data{$type}{$var}{minSysEDSMID} = $v[11];
	$data{$type}{$var}{minSysID64} = $v[12];
	$data{$type}{$var}{minSysName} = $v[13];

	$sys64{$data{$type}{$var}{maxSysID64}} = 1 if ($data{$type}{$var}{maxSysID64});
	$sys64{$data{$type}{$var}{minSysID64}} = 1 if ($data{$type}{$var}{minSysID64});

	#$table = $v[14] if ($v[14]);

	get_edsm(\%{$data{$type}{$var}},'max',$data{$type}{$var}{maxSysID64},$table,$data{$type}{$var}{maxID}) 
			if (!$data{$type}{$var}{maxEDSMID} || !$data{$type}{$var}{maxSysEDSMID});

	get_edsm(\%{$data{$type}{$var}},'min',$data{$type}{$var}{minSysID64},$table,$data{$type}{$var}{minID}) 
			if (!$data{$type}{$var}{minEDSMID} || !$data{$type}{$var}{minSysEDSMID});
}
close CSV;



open CSV, "<$csv2";
my $header = <CSV>;
while (<CSV>) {
	chomp;
	next if (!$_);
	my @v = parse_csv($_);
	my ($type,$var) = ($v[0],$v[1]);
	next if (!$type || !$var);

	$type =~ s/\\\//\//gs;

	$varnames{$var}=1;
	$planetvars{$var}=1 if ($type =~ /Water/i);
	$starvars{$var}=1   if ($type =~ /Star|Hole/i && $type !~ /System/i);
	$ringvars{$var}=1   if ($type =~ /Ring|Belt/i);
	$systemvars{$var}=1   if ($type =~ /System/i);

	$data{$type}{$var}{maxcount} = $v[2];
	$data{$type}{$var}{maxVal} = $v[3];
	$data{$type}{$var}{maxName} = $v[4];
	$data{$type}{$var}{mincount} = $v[5];
	$data{$type}{$var}{minVal} = $v[6];
	$data{$type}{$var}{minName} = $v[7];
	$data{$type}{$var}{average} = $v[8];
	$data{$type}{$var}{deviation} = $v[9];
	$data{$type}{$var}{count} = $v[10];

	$data{$type}{$var}{average} = sprintf("%.04f",$data{$type}{$var}{average}) if ($data{$type}{$var}{average} =~ /\.\d{5,}/);
	$data{$type}{$var}{deviation} = sprintf("%.04f",$data{$type}{$var}{deviation}) if ($data{$type}{$var}{deviation} =~ /\.\d{5,}/);
}
close CSV;


open CSV, "<$topsfile";
my $header = <CSV>;
while (<CSV>) {
	chomp;
	next if (!$_);
	my @v = parse_csv($_);
	my ($table,$list,$type,$var) = ($v[0],$v[1],$v[2],$v[3]);
	next if (!$type || !$var);

	next if (!exists($data{$type}{$var}));

	push @{$data{$type}{$var}{lists}{$list}}, {v=>$v[4],n=>$v[6]};
}
close CSV;


my $file_epoch = (stat($csv2))[9];
my @t = gmtime($file_epoch);
my $updated = sprintf("%04u-%02u-%02u %02u:%02u:%02u",$t[5]+1900,$t[4]+1,$t[3],$t[2],$t[1],$t[0]);

my $index = "Galactic Records <span class=\"textyellow\"><b><i>BETA</i></b></span> | Last update: $updated<p/>\n\n";


###########################################################################

$index .= "<div class=\"recordsnav\" align=\"left\">\n";

$index .= "<h2>Records by Body Type</hr><p/>\n";
$index .= "<table class=\"galrecords recordsnav\">\n";
#$index .= "<tr style=\"text-align:left;\"><td style=\"text-align:left;\" colspan=2><B>Body Type</B></td></tr>\n";
$index .= "<tr style=\"text-align:left; vertical-align:top;\"><td><ul>\n";
my $num_types = int(keys %data);
my $third = ceil($num_types/3);
my $i = 0;
foreach my $t (sort keys %data) {
	next if ($t =~ /^(Ring|Belt)$/);
	my $disp = $t;
	$disp = ucfirst($t) if ($t =~ /^(landables|moons|planets|stars|main stars|rings|belts|systems)$/i);
	$disp =~ s/\s+/\&nbsp;/gs;
	$disp =~ s/-+/\&#8209;/gs;
	my $fn = '/records/'.make_filename($t);
	$index .= "<li><a href=\"$fn#details\">$disp</a></li>\n";
	$i++;
	$index .= "</ul></td><td><ul>\n" if ($i % $third == 0);
}
$index .= "</ul></td></tr></table>\n";

my %both = ();
$index .= "<h2>Records by Attribute</hr><p/>\n";
$index .= "<table class=\"galrecords recordsnav\"><tr>\n";

$index .= "<td valign=\"top\" style=\"text-align:left;\"><B>System Attributes</B><p/><ul>\n";
foreach my $v (sort keys %systemvars) {
	next if (!$v || $v=~/^\s*$/);
	my $fn = '/records/'.make_filename($v);
	$index .= "<li><a href=\"$fn#details\">$vardisplay{$v}</a></li>\n";
}
$index .= "</ul></td>\n";
$index .= "<td>\&nbsp;\&nbsp;\&nbsp;</td>\n";
$index .= "<td valign=\"top\" style=\"text-align:left;\"><B>Planet Attributes</B><p/><ul>\n";
foreach my $v (sort keys %planetvars) {
	next if (!$v || $v=~/^\s*$/);
	my $fn = '/records/'.make_filename($v);
	$both{$v} = 1 if (exists($starvars{$v}));
	$index .= "<li><a href=\"$fn#details\">$vardisplay{$v}</a></li>\n" if (!$both{$v});
}
$index .= "</ul></td>\n";
$index .= "<td>\&nbsp;\&nbsp;\&nbsp;</td>\n";
$index .= "<td valign=\"top\" style=\"text-align:left;\"><B>Star Attributes</B><p/><ul>\n";
foreach my $v (sort keys %starvars) {
	next if (!$v || $v=~/^\s*$/);
	my $fn = '/records/'.make_filename($v);
	$both{$v} = 1 if (exists($planetvars{$v}));
	$index .= "<li><a href=\"$fn#details\">$vardisplay{$v}</a></li>\n" if (!$both{$v});
}
$index .= "</ul></td>\n";
$index .= "<td>\&nbsp;\&nbsp;\&nbsp;</td>\n";
$index .= "<td valign=\"top\" style=\"text-align:left;\"><B>Star/Planet Attributes</B><p/><ul>\n";
foreach my $v (sort keys %both) {
	next if (!$v || $v=~/^\s*$/);
	my $fn = '/records/'.make_filename($v);
	$index .= "<li><a href=\"$fn#details\">$vardisplay{$v}</a></li>\n";
}
$index .= "</ul></td>\n";
$index .= "<td>\&nbsp;\&nbsp;\&nbsp;</td>\n";
$index .= "<td valign=\"top\" style=\"text-align:left;\"><B>Ring/Belt Attributes</B><p/><ul>\n";
foreach my $v (sort keys %ringvars) {
	next if (!$v || $v=~/^\s*$/);
	my $fn = '/records/'.make_filename($v);
	$index .= "<li><a href=\"$fn#details\">$vardisplay{$v}</a></li>\n";
}
$index .= "</ul></td>\n";
$index .= "</tr></table>\n";

$index .= "</div>\n\n";

if (!$debug && $allow_scp) {
        my_system("/usr/bin/rm -f $records/*html");
}

open HTML, ">$records/index.html";
print HTML header();
print HTML $index;
print HTML footer();
close HTML;


foreach my $var (sort keys %varnames) {
	my $display = $vardisplay{$var};
	$display = $var if (!$display);

	next if ($var eq 'ring' || $var eq 'belt');

	my $fn = "$records/".make_filename($var);
	open HTML, ">$fn";
	print HTML header();

	print HTML "<div>\n";
	print HTML "<a name=\"details\"/><a name=\"$var\"/><p align=\"right\"><a href=\"./\">Index</a></p><h2>$display</h2><p/>\n";
	print HTML "<table class=\"galrecords\" id=\"galrecords\"><tr><th style=\"text-align:left;\">\&nbsp;\&nbsp;Type</th><th colspan=3>Data</th><th colspan=2>\&nbsp;</th></tr>\n";
	print HTML "<tr><td>\&nbsp;</td></tr>\n";

	foreach my $type (sort keys %data) {
		next if (!keys %{$data{$type}{$var}});

		my $typedisp = ucfirst($type);
		$typedisp =~ s/\s+/\&nbsp;/gs;
		$typedisp =~ s/-+/\&#8209;/gs;

		print HTML print_data(0,$var,$display,$type,$typedisp);

	}

	print HTML "</table>\n";
	print HTML "</div>\n\n";

	print HTML "<hr/>\n$index\n\n";
	print HTML footer();
	close HTML;
}

foreach my $type (sort keys %data) {

	my $typedisp = ucfirst($type);
	$typedisp =~ s/\s+/\&nbsp;/gs;
	$typedisp =~ s/-+/\&#8209;/gs;

	my $fn = "$records/".make_filename($type);
	open HTML, ">$fn";
	print HTML header();

	print HTML "<div>\n";
	print HTML "<a name=\"details\"/><a name=\"$type\"><p align=\"right\"><a href=\"./\">Index</a></p><h2>$typedisp</h2></a><p/>\n";
	print HTML "<table class=\"galrecords\" id=\"galrecords\"><tr><th style=\"text-align:left;\">\&nbsp;\&nbsp;Type</th><th colspan=3>Data</th><th colspan=2>\&nbsp;</th></tr>\n";
	print HTML "<tr><td>\&nbsp;</td></tr>\n";

	foreach my $var (sort keys %{$data{$type}}) {
		next if (!keys %{$data{$type}{$var}});
		next if ($var eq 'ring' || $var eq 'belt');

		my $display = $vardisplay{$var};
		$display = $var if (!$display);

		print HTML print_data(1,$var,$display,$type,$typedisp);

	}

	print HTML "</table>\n";
	print HTML "</div>\n\n";

	print HTML "<hr/>\n$index\n\n";
	print HTML footer();
	close HTML;
}


if (!$debug && $allow_scp) {
        my_system("$scp $records/* $remote_server/");
}

if (0) {
	my @id64list = keys %sys64;

	print int(@id64list)." system id64s to compare to EDSM\n";

	while (@id64list) {
		my @list = splice @id64list, 0, 80;

		print '#> /home/bones/elite/edsm/get-system-bodies.pl '.join(' ',sort @list)."\n";
	        system('/home/bones/elite/edsm/get-system-bodies.pl',@list) if (!$debug);
	}
}

exit;


#############################################################################

sub my_system {
        my $string = shift;
        print "# $string\n";
        #print TXT "$string\n";
        system($string);
}


sub header {
	return "<!--#include  virtual=\"/header.html\" -->


<div class=\"row\">
        <div class=\"col-2\"></div>

        <div class=\"col-8\">
        <H1>Galactic Records</H1>
        <H4>(updated weekly)</H4>
        <p/>
        <hr/>
        <p/>
";
}

sub footer {
	return "<p/>
        </div>

        <div class=\"col-2\"></div>
</div>


<!--#include  virtual=\"/footer.html\" -->
";
}

sub make_filename {
	my $fn = shift;
	$fn =~ s/[^a-zA-Z0-9]+/_/gs;
	$fn =~ s/^\_+//s;
	$fn =~ s/\_+$//s;
	return "$fn.html";
}

sub print_data {
	my ($var_first,$var,$display,$type,$typedisp) = @_;

	my $out = '';

	$out .= "<tr class=\"recordrow\"><td class=\"recordname\" rowspan=4><b>$typedisp</b><br/>($display)</td>\n" if (!$var_first);
	$out .= "<tr class=\"recordrow\"><td class=\"recordname\" rowspan=4><b>$display</b><br/>$typedisp</td>\n" if ($var_first);

	my $minlink = $data{$type}{$var}{minName};
	$minlink =~ s/\s+/\&nbsp;/gs;

	if ($data{$type}{$var}{minEDSMID} && $data{$type}{$var}{minSysEDSMID}) {
		my $linksys = $data{$type}{$var}{minSysName};
		$linksys =~ s/\s+/\+/;
		my $linkbody = $data{$type}{$var}{minName};
		$linkbody =~ s/\s+/\+/;

		my $url = "https://www.edsm.net/en/system/bodies/id/$data{$type}{$var}{minSysEDSMID}/name/$linksys/details/".
				"idB/$data{$type}{$var}{minEDSMID}/nameB/$linkbody";

		$url = "https://www.edsm.net/en/system/id/$data{$type}{$var}{minSysEDSMID}/name/$linksys" if ($type =~ /Systems/i);

		$minlink = "<a href=\"$url\">$minlink</a>\n";
	}
	
	my $maxlink = $data{$type}{$var}{maxName};
	$maxlink =~ s/\s+/\&nbsp;/gs;

	if ($data{$type}{$var}{maxEDSMID} && $data{$type}{$var}{maxSysEDSMID}) {
		my $linksys = $data{$type}{$var}{maxSysName};
		$linksys =~ s/\s+/\+/;
		my $linkbody = $data{$type}{$var}{maxName};
		$linkbody =~ s/\s+/\+/;

		my $url = "https://www.edsm.net/en/system/bodies/id/$data{$type}{$var}{maxSysEDSMID}/name/$linksys/details/".
				"idB/$data{$type}{$var}{maxEDSMID}/nameB/$linkbody";

		$url = "https://www.edsm.net/en/system/id/$data{$type}{$var}{maxSysEDSMID}/name/$linksys" if ($type =~ /Systems/i);

		$maxlink = "<a href=\"$url\">$maxlink</a>\n";
	}

	my $maxshare = '';
	my $minshare = '';

	if ($data{$type}{$var}{maxcount}>1) {
		$maxshare = '&nbsp;&nbsp;'.commify($data{$type}{$var}{maxcount}).'&nbsp;*';
	}
	if ($data{$type}{$var}{mincount}>1) {
		$minshare = '&nbsp;&nbsp;'.commify($data{$type}{$var}{mincount}).'&nbsp;*';
	}

	my $units = '';

	$units = '&nbsp;km' if ($var =~ /(inner|outer)Radius/ || $var =~ /^periapsis(KM|5Y)?$/i);
	$units = '&nbsp;AU' if ($var =~ /^semiMajorAxis/ || $var =~ /^periapsisAU$/i);

	my $rightarrow = '&#x25B6;';
	my $downarrow = '&#x25BC;';

	my $toptoggle = '';
	my $tophtml = '';
	my $id = $jsID++;

	if (keys %{$data{$type}{$var}{lists}}) {
		my @lists = reverse sort keys %{$data{$type}{$var}{lists}};

		my $js = "
let divID = 'details$id';
let tableID = 'table$id';
let buttonID = 'toggle$id';
if (document.getElementById(divID).style.visibility == 'hidden') {
	document.getElementById(divID).style.visibility = 'visible';
	document.getElementById(divID).style.display = 'block';
	document.getElementById(tableID).style.visibility = 'visible';
	document.getElementById(tableID).style.display = 'block';
	document.getElementById(buttonID).innerHTML = '$downarrow';
} else {
	document.getElementById(divID).style.visibility = 'hidden';
	document.getElementById(divID).style.display = 'none';
	document.getElementById(tableID).style.visibility = 'hidden';
	document.getElementById(tableID).style.display = 'none';
	document.getElementById(buttonID).innerHTML = '$rightarrow';
}
";

		$js =~ s/[\r\n]+/ /gs;

		$toptoggle = "<span onclick=\"$js\" style=\"cursor: pointer;\"><span id=\"toggle$id\">$rightarrow</span>\&thinsp;".join('/',@lists)."</span>";

		$tophtml .= "<tr class=\"recorddata\"><td colspan=7 class=\"recorddata\" align=\"right\">\n";
		$tophtml .= "<div align=\"right\" id=\"details$id\" style=\"display:none;visibility:hidden;\">".
			"<table id=\"table$id\" class=\"galrecords\" style=\"display:none;visibility:hidden;\" id=\"detailtable$id\" align=\"right\">\n";

		my $maxlength = 0;

		$tophtml .= "<tr>";
		foreach my $list (@lists) {
			$maxlength = int(@{$data{$type}{$var}{lists}{$list}}) if (@{$data{$type}{$var}{lists}{$list}} > $maxlength);
			$tophtml .= "<th colspan=4><center>$list</center></th>";
		}
		$tophtml .= "</tr>\n";

		my $column = $type =~ /Systems/i ? 'System' : 'Body';
		
		$tophtml .= "<tr>";
		foreach my $list (@lists) {
			$tophtml .= "<td>\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;</td>";
			$tophtml .= "<td align=\"right\"><b>Value</b></td>";
			$tophtml .= "<td>\&nbsp;\&nbsp;\&nbsp;\&nbsp;</td>";
			$tophtml .= "<td align=\"left\"><b>$column</b></td>";
		}
		$tophtml .= "</tr>\n";

		for (my $i=0; $i<$maxlength; $i++) {
			$tophtml .= "<tr>";
			foreach my $list (@lists) {

				if (defined(${${$data{$type}{$var}{lists}{$list}}[$i]}{v})) {
					$tophtml .= "<td>\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;</td>";
					$tophtml .= "<td align=\"right\">".commify(${${$data{$type}{$var}{lists}{$list}}[$i]}{v})."</td>";
					$tophtml .= "<td>\&nbsp;\&nbsp;\&nbsp;\&nbsp;</td>";
					$tophtml .= "<td align=\"left\">${${$data{$type}{$var}{lists}{$list}}[$i]}{n}</td>";
				} else {
					$tophtml .= "<td colspan=4></td>";
				}
			}
			$tophtml .= "</tr>\n";
		}
		
		$tophtml .= "</table></div>\n";
		$tophtml .= "</td></tr>\n";
	}
	
	$out .= "\t<td class=\"recorddata\" align=\"right\">Highest:</td><td>\&nbsp;</td><td align=\"right\">".commify($data{$type}{$var}{maxVal})."$units</td>".
			"<td class=\"recordlink\">\&nbsp;:\&nbsp;$maxlink</td><td align=\"right\">$maxshare</td></tr>\n";

	$out .= "\t<tr class=\"recorddata\"><td class=\"recorddata\" align=\"right\">Lowest:</td><td>\&nbsp;</td><td align=\"right\">".commify($data{$type}{$var}{minVal})."$units</td>".
			"<td class=\"recordlink\">\&nbsp;:\&nbsp;$minlink</td><td align=\"right\">$minshare</td></tr>\n";

	$out .= "\t<tr class=\"recorddata\"><td class=\"recordblank\" colspan=4></td><td></td></tr>\n";

	$out .= "\t<tr class=\"recorddata\"><td class=\"recorddata\" align=\"right\">Average:</td><td>\&nbsp;</td>".
			"<td class=\"recorddata\" align=\"right\">".commify($data{$type}{$var}{average})."$units</td><td></td><td></td></tr>\n";

	$out .= "\t<tr class=\"recorddata\"><td class=\"recordname\">Count: ".commify($data{$type}{$var}{count})."</td>".
		"<td class=\"recorddata\" align=\"right\">Standard Deviation:</td><td>\&nbsp;</td>".
		"<td class=\"recorddata\" align=\"right\">".commify($data{$type}{$var}{deviation})."</td><td colspan=2 style=\"text-align:right;\">$toptoggle</td></tr>\n";

	$out .= $tophtml if ($tophtml);

	$out .= "\t<tr><td colspan=6 class=\"mediumtext\" align=\"right\">\* Total bodies in this category sharing this value.</td></tr>\n" if ($maxshare || $minshare);
	$out .= "\t<tr><td>\&nbsp;</td></tr>\n";


	return $out;

}


sub showdecimal {
        my $text = shift;
        if ($text =~ /^\s*[\+\-\d]\.(\d+)+e[\+\-]?(\d+)\s*$/i) {
                my $digits = length($1) + $2;
                $text = sprintf("%.".$digits."f",$text);
        } elsif ($text =~ /^\s*[\+\-\d]\.(\d+)+e\+?(\d+)\s*$/i) {
		$text = sprintf("%f",$text);
	}
	$text =~ s/\.0+$//;
	$text =~ s/(\.\d*?)0+$/$1/;
        return $text;
}

sub commify {
    my $text = reverse showdecimal($_[0]);
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text
}

###########################################################################




