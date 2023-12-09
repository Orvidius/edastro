#!/usr/bin/perl
use strict;

############################################################################

use lib "/home/bones/elite";
use EDSM qw(log10);

use lib "/home/bones/perl";
use DB qw(db_mysql rows_mysql columns_mysql show_queries);
use ATOMS qw(epoch2date date2epoch make_csv);

use Image::Magick;
use POSIX qw(floor);

############################################################################

my $chunk_size		= 10000;
my $maxChildren		= 5;

my $galcenter_x         = 0;
my $galcenter_y         = -25;
my $galcenter_z         = 25000;

my $sector_radius       = 35;
my $sector_height       = 4;

my $sectorcenter_x      = -65;
my $sectorcenter_y      = -25;
my $sectorcenter_z      = 25815;

my $sector_file		= ''; #'sector-list.csv';
my $boxel_file		= 'boxel-stats.csv';

my $test = '';
if ($0 =~ /\.pl(\..+)$/) {
	$test = $1;
	$sector_file .= $test if ($sector_file && $test);
	$boxel_file .= $test if ($boxel_file && $test);
}

############################################################################

show_queries(0);

my %system_name = ();

my @list = ();
#my @rows = db_mysql('elite',"select id64 from systems where name like 'Oephail LG-Y e\%'");
#my @rows = db_mysql('elite',"select id64 from systems where name like 'Oephail \%'");
#my @rows = db_mysql('elite',"select id64 from systems where name like 'Scaulua \%'");


my @rows = db_mysql('elite',"select id64 from systems where CAST(name as binary) rlike '[A-Z][A-Z]-[A-Z] [e-h]'");

warn int(@rows)." systems to consider.\n";

while (@rows) {
	my $r = shift @rows;
	push @list, $$r{id64} if ($$r{id64});
}

my %sector  = ();
my %boxel   = ();

while (@list) {
	my @ids = splice @list,0,$chunk_size;

	last if (!@ids);

	my $select = "select name,coord_x,coord_y,coord_z,id64 from systems where id64 in (".join(',',@ids).")";
	my @rows = db_mysql('elite',$select);

	while (@rows) {
		my $r = shift @rows;

		if ($$r{name} =~ /^(.+\S)\s+([A-Z][A-Z]\-[A-Z]\s+([a-z]))([\d+\-]+)\s*$/) {
			my ($sect,$box,$masscode,$boxnum) = ($1,"$1 $2",$3,$4);
			$boxnum = '' if ($boxnum !~ /\-/);
			$boxnum =~ s/\-\d+$//;
			$boxnum =0 if (!$boxnum);
			$box = "$box $boxnum" if ($boxnum);

			#next if ($masscode =~ /[a-c]/);

			$sector{$sect}{c}++;
			$boxel{$box}{c}++;

			my @stars = db_mysql('elite',"select id,starID,name,subType,age from stars where systemId64=?",[($$r{id64})]);
			my @planets = db_mysql('elite',"select id,planetID,name,subType from planets where systemId64=?",[($$r{id64})]);

			my ($num_planets, $num_stars) = (int(@planets),int(@stars));
			my $num_bodies = $num_planets + $num_stars;

			$boxel{$box}{p_total} += $num_planets;
			$boxel{$box}{s_total} += $num_stars;
			$boxel{$box}{b_total} += $num_bodies;

			my %atmo = ();
			my @ids = ();
			foreach my $p (@planets) {
				push @ids,$$p{planetID} if (defined($$p{planetID}));
			}
			if (@ids) {
				my @at = db_mysql('elite',"select * from atmospheres where planet_id in (".join(',',@ids).")");
				foreach my $a (@at) {
					foreach my $k (keys %$a) {
						if ($k ne 'planet_id' && defined($$a{$k})) {
							$atmo{$$a{planet_id}}{$k} = $$a{$k};
						}
					}
				}
			}


			my $i=0;
			foreach my $s (@stars) {
				if ($$s{age}) {
					$boxel{$box}{age_total} += $$s{age};
					$boxel{$box}{age_num}++;
					$boxel{$box}{age_avg} = $boxel{$box}{age_total} / $boxel{$box}{age_num};

					$boxel{$box}{age_min} = $$s{age} if (!defined($boxel{$box}{age_min}) || $$s{age} < $boxel{$box}{age_min});
					$boxel{$box}{age_max} = $$s{age} if (!defined($boxel{$box}{age_max}) || $$s{age} > $boxel{$box}{age_max});
				}
			}
			my $giants = 0;
			my $terrestrials = 0;
			foreach my $p (@planets) {
				if ($$p{subType} =~ /giant/i) {
					$giants++;

					my $atm = {};
					$atm = $atmo{$$p{planetID}} if (exists($atmo{$$p{planetID}}));

					if (defined($$atm{helium})) {
						$boxel{$box}{helium_total} += $$atm{helium};
						$boxel{$box}{helium_num} ++;
						$boxel{$box}{helium_avg} = $boxel{$box}{helium_total}/$boxel{$box}{helium_num};
						$boxel{$box}{helium_min} = $$atm{helium} if (!defined($boxel{$box}{helium_min}) || $$atm{helium} < $boxel{$box}{helium_min});
						$boxel{$box}{helium_max} = $$atm{helium} if (!defined($boxel{$box}{helium_max}) || $$atm{helium} > $boxel{$box}{helium_max});
					}

					if (defined($$atm{hydrogen})) {
						$boxel{$box}{hydrogen_total} += $$atm{hydrogen};
						$boxel{$box}{hydrogen_num} ++;
						$boxel{$box}{hydrogen_avg} = $boxel{$box}{hydrogen_total}/$boxel{$box}{hydrogen_num};
						$boxel{$box}{hydrogen_min} = $$atm{hydrogen} if (!defined($boxel{$box}{hydrogen_min}) || $$atm{hydrogen} < $boxel{$box}{hydrogen_min});
						$boxel{$box}{hydrogen_max} = $$atm{hydrogen} if (!defined($boxel{$box}{hydrogen_max}) || $$atm{hydrogen} > $boxel{$box}{hydrogen_max});
					}
				} else {
					$terrestrials++;
				}
			}

			$boxel{$box}{p_min} = $num_planets if (!defined($boxel{$box}{p_min}) || $num_planets < $boxel{$box}{p_min});
			$boxel{$box}{p_max} = $num_planets if (!defined($boxel{$box}{p_max}) || $num_planets > $boxel{$box}{p_max});
			$boxel{$box}{s_min} = $num_stars if (!defined($boxel{$box}{s_min}) || $num_stars < $boxel{$box}{s_min});
			$boxel{$box}{s_max} = $num_stars if (!defined($boxel{$box}{s_max}) || $num_stars > $boxel{$box}{s_max});
			$boxel{$box}{b_min} = $num_bodies if (!defined($boxel{$box}{b_min}) || $num_bodies < $boxel{$box}{b_min});
			$boxel{$box}{b_max} = $num_bodies if (!defined($boxel{$box}{b_max}) || $num_bodies > $boxel{$box}{b_max});

			$boxel{$box}{t_total} += $terrestrials;
			$boxel{$box}{g_total} += $giants;

			$boxel{$box}{t_min} = $terrestrials if (!defined($boxel{$box}{t_min}) || $terrestrials < $boxel{$box}{t_min});
			$boxel{$box}{t_max} = $terrestrials if (!defined($boxel{$box}{t_max}) || $terrestrials > $boxel{$box}{t_max});
			$boxel{$box}{g_min} = $giants if (!defined($boxel{$box}{g_min}) || $giants < $boxel{$box}{g_min});
			$boxel{$box}{g_max} = $giants if (!defined($boxel{$box}{g_max}) || $giants > $boxel{$box}{g_max});
			

			if (defined($$r{coord_x}) && defined($$r{coord_y}) && defined($$r{coord_z})) {
				$boxel{$box}{n}++;
				$boxel{$box}{x} += $$r{coord_x};
				$boxel{$box}{y} += $$r{coord_y};
				$boxel{$box}{z} += $$r{coord_z};

				$boxel{$box}{x1} = $$r{coord_x} if ($$r{coord_x} < $boxel{$box}{x1} || !$boxel{$box}{x1});
				$boxel{$box}{y1} = $$r{coord_y} if ($$r{coord_y} < $boxel{$box}{y1} || !$boxel{$box}{y1});
				$boxel{$box}{z1} = $$r{coord_z} if ($$r{coord_z} < $boxel{$box}{z1} || !$boxel{$box}{z1});
	
				$boxel{$box}{x2} = $$r{coord_x} if ($$r{coord_x} > $boxel{$box}{x2} || !$boxel{$box}{x2});
				$boxel{$box}{y2} = $$r{coord_y} if ($$r{coord_y} > $boxel{$box}{y2} || !$boxel{$box}{y2});
				$boxel{$box}{z2} = $$r{coord_z} if ($$r{coord_z} > $boxel{$box}{z2} || !$boxel{$box}{z2});
			}
			if ($sector_file && defined($$r{coord_x}) && defined($$r{coord_y}) && defined($$r{coord_z})) {
				$sector{$sect}{n}++;
				$sector{$sect}{x} += $$r{coord_x};
				$sector{$sect}{y} += $$r{coord_y};
				$sector{$sect}{z} += $$r{coord_z};

				$sector{$sect}{x1} = $$r{coord_x} if ($$r{coord_x} < $sector{$sect}{x1} || !$sector{$sect}{x1});
				$sector{$sect}{y1} = $$r{coord_y} if ($$r{coord_y} < $sector{$sect}{y1} || !$sector{$sect}{y1});
				$sector{$sect}{z1} = $$r{coord_z} if ($$r{coord_z} < $sector{$sect}{z1} || !$sector{$sect}{z1});
	
				$sector{$sect}{x2} = $$r{coord_x} if ($$r{coord_x} > $sector{$sect}{x2} || !$sector{$sect}{x2});
				$sector{$sect}{y2} = $$r{coord_y} if ($$r{coord_y} > $sector{$sect}{y2} || !$sector{$sect}{y2});
				$sector{$sect}{z2} = $$r{coord_z} if ($$r{coord_z} > $sector{$sect}{z2} || !$sector{$sect}{z2});
			}
		}
	}

}

if ($boxel_file) {
	open CSV, ">$boxel_file";
	my $header = make_csv('Boxel','Mass Code','Systems','Age Avg','Age Min','Age Max',
			'Hydrogen Avg','Hydrogen Min','Hydrogen Max','Helium Avg','Helium Min','Helium Max',
			'Total Bodies','Avg Bodies','Min Bodies','Max Bodies',
			'Total Stars','Avg Stars','Min Stars','Max Stars',
			'Total Planets','Avg Planets','Min Planets','Max Planets',
			'Total Gas Giants','Avg Gas Giants','Min Gas Giants','Max Gas Giants',
			'Total Terrestrial Bodies','Avg Terrestrial Bodies','Min Terrestrial Bodies','Max Terrestrial Bodies',
			'Avg X','Avg Y','Avg Z','Min X','Min Y','Min Z','Max X','Max Y','Max Z')."\r\n";
	print $header;
	print CSV $header;

	my $count = 0;

	foreach my $b (sort keys %boxel) {
		next if (!$boxel{$b}{c});

		my $masscode = '';
		if ($b =~ /[A-Z][A-Z]-[A-Z]\s+([a-z])/) {
			$masscode = $1;
		}

		#next if ($boxel{$b}{c} < 10);

		my ($x,$y,$z,$x1,$y1,$z1,$x2,$y2,$z2);
	
		if ($boxel{$b}{n}) {
			$x  = sprintf("%.02f",$boxel{$b}{x} / $boxel{$b}{n});
			$y  = sprintf("%.02f",$boxel{$b}{y} / $boxel{$b}{n});
			$z  = sprintf("%.02f",$boxel{$b}{z} / $boxel{$b}{n});
		
			$x1 = sprintf("%.02f",$boxel{$b}{x1});
			$y1 = sprintf("%.02f",$boxel{$b}{y1});
			$z1 = sprintf("%.02f",$boxel{$b}{z1});
		
			$x2 = sprintf("%.02f",$boxel{$b}{x2});
			$y2 = sprintf("%.02f",$boxel{$b}{y2});
			$z2 = sprintf("%.02f",$boxel{$b}{z2});
		}

		my $age_avg = '';
		if (defined($boxel{$b}{age_avg})) {
			$age_avg = sprintf("%.02f",$boxel{$b}{age_avg});
		}
		my $hydro_avg = '';
		if (defined($boxel{$b}{hydrogen_avg})) {
			$hydro_avg = sprintf("%.02f",$boxel{$b}{hydrogen_avg});
		}
		my $helium_avg = '';
		if (defined($boxel{$b}{helium_avg})) {
			$helium_avg = sprintf("%.02f",$boxel{$b}{helium_avg});
		}
	
		my $out = make_csv($b,$masscode,$boxel{$b}{c},$age_avg,$boxel{$b}{age_min},$boxel{$b}{age_max},
			$hydro_avg,$boxel{$b}{hydrogen_min},$boxel{$b}{hydrogen_max},$helium_avg,$boxel{$b}{helium_min},$boxel{$b}{helium_max},
			$boxel{$b}{b_total},sprintf("%.02f",$boxel{$b}{b_total}/$boxel{$b}{c}),$boxel{$b}{b_min},$boxel{$b}{b_max},
			$boxel{$b}{s_total},sprintf("%.02f",$boxel{$b}{s_total}/$boxel{$b}{c}),$boxel{$b}{s_min},$boxel{$b}{s_max},
			$boxel{$b}{p_total},sprintf("%.02f",$boxel{$b}{p_total}/$boxel{$b}{c}),$boxel{$b}{p_min},$boxel{$b}{p_max},
			$boxel{$b}{g_total},sprintf("%.02f",$boxel{$b}{g_total}/$boxel{$b}{c}),$boxel{$b}{g_min},$boxel{$b}{g_max},
			$boxel{$b}{t_total},sprintf("%.02f",$boxel{$b}{t_total}/$boxel{$b}{c}),$boxel{$b}{t_min},$boxel{$b}{t_max},
			$x,$y,$z,$x1,$y1,$z1,$x2,$y2,$z2)."\r\n";
		print $out;
		print CSV $out;
		$count++;
	}
	close CSV;

	warn "$count rows.\n";
}
	
	

if ($sector_file) {
	open CSV, ">$sector_file";
	print CSV make_csv('Sector','Systems','Avg X','Avg Y','Avg Z','Min X','Min Y','Min Z','Max X','Max Y','Max Z','MapSector X','MapSector Y')."\r\n";
	foreach my $s (sort keys %sector) {
		next if (!$sector{$s}{n});
		next if (!$sector{$s}{c});
	
		my $x  = sprintf("%.02f",$sector{$s}{x} / $sector{$s}{n});
		my $y  = sprintf("%.02f",$sector{$s}{y} / $sector{$s}{n});
		my $z  = sprintf("%.02f",$sector{$s}{z} / $sector{$s}{n});
	
		my $x1 = sprintf("%.02f",$sector{$s}{x1});
		my $y1 = sprintf("%.02f",$sector{$s}{y1});
		my $z1 = sprintf("%.02f",$sector{$s}{z1});
	
		my $x2 = sprintf("%.02f",$sector{$s}{x2});
		my $y2 = sprintf("%.02f",$sector{$s}{y2});
		my $z2 = sprintf("%.02f",$sector{$s}{z2});
	
		my $bx = floor(($x-$sectorcenter_x)/1280)+$sector_radius;
		my $bz = floor(($z-$sectorcenter_z)/1280)+$sector_radius;
	 
		print CSV make_csv($s,$sector{$s}{c},$x,$y,$z,$x1,$y1,$z1,$x2,$y2,$z2,$bx,$bz)."\r\n";
	}
	close CSV;
}
	
	
