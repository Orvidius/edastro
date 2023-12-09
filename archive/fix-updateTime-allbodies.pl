#!/usr/bin/perl

use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);

my $use_vectors	= 0;
my $use_forking	= 1;

my $dotcount = 0;

my $body_vector = 0;
my $disco_vector = 0;

my $amChild = 0;
my $do_anyway = 0;
my $mangle_process = 0;

$0 = "$0 PARENT" if ($mangle_process);

foreach my $fn (@ARGV) {
	
	print "$fn\n";

	my $pid = undef;

	if ($use_forking) {
		if ($pid = fork) {
			# Parent here
			$do_anyway = 0;
		} elsif (defined $pid) {
			# Child here
			$amChild = 1;   # I AM A CHILD!!!
			$0 =~ s/\s+PARENT//s if ($mangle_process);
			$0 .= " $fn" if ($mangle_process);
			$do_anyway = 0;
		} else {
			$do_anyway = 1;
		}
	} else {
		$do_anyway = 1;
	}

	if (!$amChild && !$do_anyway) {
		sleep 2;
		next;
	}

	open DATA, "zcat $fn |" if ($fn =~ /\.gz$/);
	open DATA, "<$fn" if ($fn !~ /\.gz$/);
	$dotcount = 0;
	
	while (my $line = <DATA>) {
		if ($line =~ /"type":"(Planet|Star)"/) {
	
			my $table = 'planets';
			$table = 'stars' if ($1 eq 'Star');
	
			my $updateTime = undef;
			my $commander = undef;
			my $disco_date = undef;
			my $name = '';
			my $edsmID = 0;
			my $body64 = 0;
	
			if ($line =~ /"updateTime"\s*:\s*"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"[,\}]/) {
				$updateTime = $1;
			}
	
			if ($line =~ /"id64"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$body64 = $1;
			}
	
			if ($line =~ /"id"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$edsmID = $1;
			}
	
#			if ($line =~ /"name"\s*:\s*"([^"]+)"[,\}]/) {
#				$name = $1;
#			}

			if ($line =~ /"discovery"\s*:\s*\{([^\}]+)\}/) {
				#"discovery":{"commander":"Arde","date":"2017-10-24 21:48:53"}
				my $discovery = $1;

				if ($discovery =~ /"commander"\s*:\s*"([^"]+)"/) {
					$commander = $1;
				}
				if ($discovery =~ /"date"\s*:\s*"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"/) {
					$disco_date = $1;
				}
			}
	
			if ($edsmID && $updateTime) {
				my $where = '';
				my @lookup_params = ();

				if ($use_vectors && !$use_forking) {
					next if (vec($disco_vector, $edsmID, 1));
					next if (vec($body_vector, $edsmID, 1) && !$disco_date);
	
					vec($body_vector, $edsmID, 1) = 1;
					vec($disco_vector, $edsmID, 1) = 1 if ($disco_date);
				}

				if ($body64) {
					$where .= ' or bodyId64=?';
					push @lookup_params, $body64;
				}

				if ($edsmID && !$body64) {
					$where .= ' or edsmID=?';
					push @lookup_params, $edsmID;
				} 

				if (@lookup_params) {
					$where =~ s/\s*or\s+//;

					my $IDfield = 'planetID';
					$IDfield = 'starID' if ($table eq 'stars');

					my @rows = db_mysql('elite',"select $IDfield,updated,updateTime,edsm_date,discoveryDate,commanderName,date_added,eddn_date ".
								"from $table where $where", \@lookup_params);

					foreach my $r (@rows) {

						my $edsm_date = $updateTime;
						my $edsm_updateTime = $updateTime;
						my $date_added = $$r{date_added};

						$edsm_date = undef if ($edsm_date lt '2014-01-01 00:00:00');
						$edsm_updateTime = undef if ($edsm_date lt '2014-01-01 00:00:00');
						$date_added = undef if ($date_added lt '2014-01-01 00:00:00');

						$edsm_updateTime = $disco_date if ($disco_date =~ /\d{4}-\d{2}-\d{2}/ && $disco_date gt '2014-01-01 00:00:00' && ($disco_date gt $edsm_updateTime || !$edsm_date));
						$edsm_date = $disco_date if ($disco_date =~ /\d{4}-\d{2}-\d{2}/ && $disco_date gt '2014-01-01 00:00:00' && ($disco_date lt $edsm_date || !$edsm_date));
						$date_added = $disco_date if ($disco_date =~ /\d{4}-\d{2}-\d{2}/ && $disco_date gt '2014-01-01 00:00:00' && ($disco_date lt $date_added || !$date_added));

						foreach my $d (qw(updateTime edsm_date discoveryDate date_added)) {
							next if ($$r{$d} lt '2014-01-01 00:00:00');
							next if ($$r{$d} !~ /\d{4}-\d{2}-\d{2}/);

							$edsm_updateTime = $$r{$d} if ((!$edsm_updateTime || $$r{$d} gt $edsm_updateTime) && $d !~ /date_added|eddn_date/);
							$edsm_date = $$r{$d} if ((!$edsm_date || $$r{$d} lt $edsm_date) && $d !~ /date_added|eddn_date/);
							$date_added = $$r{$d} if (!$date_added || $$r{$d} lt $date_added);
						}
	
						eval {
							my $update = '';
							my @params = ();

							if ($edsm_updateTime =~ /\d{4}-\d{2}-\d{2}/ && (!$$r{updateTime} || $edsm_updateTime gt $$r{updateTime})) {
								$update .= ",updateTime=?";
								push @params, $edsm_updateTime;
							}

							if ($edsm_date =~ /\d{4}-\d{2}-\d{2}/ && (!$$r{edsm_date} || $edsm_date lt $$r{edsm_date})) {
								$update .= ",edsm_date=?";
								push @params, $edsm_date;
							}

							if ($date_added =~ /\d{4}-\d{2}-\d{2}/ && (!$$r{date_added} || $date_added lt $$r{date_added})) {
								$update .= ",date_added=?";
								push @params, $date_added;
							}
	
							if ($disco_date =~ /\d{4}-\d{2}-\d{2}/ && (!$$r{discoveryDate} || $disco_date lt $$r{discoveryDate})) {
								$update .= ",discoveryDate=?,commanderName=?";
								push @params, $disco_date;
								push @params, $commander;
							}

							$update =~ s/^,//;

							if (@params) {
								push @params, $$r{updated};
								push @params, $$r{$IDfield};
								my $sql = "update $table set $update,updated=? where $IDfield=?";
								#print "MYSQL: $sql [".join(', ',@params)."]\n";
								db_mysql('elite',$sql,\@params);
							}
						};
					}
				}
			}

			$dotcount++;
			print '.' if ($dotcount % 10000 == 0);
			print "\n" if ($dotcount % 1000000 == 0 && !$use_forking);
			if ($dotcount % 1000 == 0 && $use_forking) {
				$0 =~ s/.+\///;
				$0 =~ s/\s+.*$//;
				$0 .= " $fn $dotcount";
			}
		}
	}
	
	close DATA;
	print "\n";

	exit if ($amChild);
}



