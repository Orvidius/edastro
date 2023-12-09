#!/usr/bin/perl

use strict;

use lib "/home/bones/perl";
use DB qw(db_mysql);
use ATOMS qw(date2epoch epoch2date);

my $use_forking	= 1;

my $dotcount = 0;

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
		#sleep 1;
		next;
	}

	open DATA, "zcat $fn |" if ($fn =~ /\.gz$/);
        open DATA, "<$fn" if ($fn !~ /\.gz$/);
	$dotcount = 0;
	
	while (my $line = <DATA>) {
		if ($line =~ /"coords"/) {
	
			my $table = 'systems';
			my $IDfield = 'ID';
	
			my $updateTime = undef;
			my $name = '';
			my $edsmID = 0;
			my $id64 = 0;
	
			if ($line =~ /"date"\s*:\s*"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"[,\}]/) {
				$updateTime = $1;
			}
	
			if ($line =~ /"id64"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$id64 = $1;
			}
	
			if ($line =~ /"id"\s*:\s*([\d\.\-\+]+)[,\}]/) {
				$edsmID = $1;
			}
	
#			if ($line =~ /"name"\s*:\s*"([^"]+)"[,\}]/) {
#				$name = $1;
#			}

	
			if ($edsmID && $updateTime) {
				my $where = '';
				my @lookup_params = ();

				if ($id64) {
					$where .= ' or id64=?';
					push @lookup_params, $id64;
				}

				if ($edsmID && !$id64) {
					$where .= ' or edsm_id=?';
					push @lookup_params, $edsmID;
				} 

				if (@lookup_params) {
					$where =~ s/\s*or\s+//;


					my @rows = db_mysql('elite',"select $IDfield,updated,updateTime,edsm_date,date_added,eddn_date ".
								"from $table where $where", \@lookup_params);

					foreach my $r (@rows) {

						my $edsm_updateTime = undef;
						my $edsm_date = undef;
						my $date_added = undef;
						$$r{json_date} = $updateTime;

						foreach my $d (qw(date_added eddn_date edsm_date json_date updateTime)) {
							my $date = $$r{$d};

							next if ($date lt '2014-01-01 00:00:00');
							next if ($date !~ /\d{4}-\d{2}-\d{2}/);


							$edsm_updateTime = $date if ((!$edsm_updateTime || $date gt $edsm_updateTime) && $d !~ /date_added|eddn_date/);
							$edsm_date = $date if ((!$edsm_date || $date lt $edsm_date) && $d !~ /date_added|eddn_date/);
							$date_added = $date if (!$date_added || $date lt $date_added);
						}

						my $later_ok = 0;

						if (0) { eval {
							if ( $$r{json_date} =~ /\d{4}-\d{2}-\d{2}/ && 
								$$r{date_added} =~ /\d{4}-\d{2}-\d{2}/ && 
								$$r{json_date} gt '2014-01-01 00:00:00' && 
								$$r{date_added} =~ /\s+00:00:00/ &&
								$$r{json_date} le $$r{edsm_date} && 
								($$r{json_date} le $$r{eddn_date} || !$$r{eddn_date}) && 
								date2epoch($$r{json_date}) <= date2epoch($$r{date_added})+(86400*7)) {

								$date_added = $$r{json_date};
								$later_ok = 1;
							}

						};}
	
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

							if ($date_added =~ /\d{4}-\d{2}-\d{2}/ && (!$$r{date_added} || $date_added lt $$r{date_added} || $later_ok)) {
								$update .= ",date_added=?,day_added=?";
								push @params, $date_added;
								my $date = $date_added;
								$date =~ s/\s\d{2}:\d{2}:\d{2}//;
								push @params, $date;
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


sub ok_range {
	my $field = shift;
	my $curr = shift;
	my $new = shift;
	my $r = shift;

	return 0 if ($field ne 'json_date');

	if ($new lt $curr) {
		return 1;
	} elsif ($curr =~ /00:00:00/ && date2epoch($new) <= date2epoch($curr) + (86400*2)) {
		return 1;
	}
	return 0;
}


