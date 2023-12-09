package DB;
########################################################################
#
# DB - MySQL API layer.
#

use strict;
use DBI;
use DBD::mysql;

my %dbh;
our $default_db;
our $last_used_db;
our $raiseerror;
our $print_queries;
our $AutoReconnect;
our $show_reconnect;

our $host;
our $port;
our $user;
our $pass;

BEGIN { # Export functions first because of possible circular dependancies
	use Exporter;
	use vars qw(@ISA $VERSION @EXPORT_OK);

	$VERSION = 2.01;
	@ISA = qw(Exporter);
	@EXPORT_OK = qw(db_mysql rows_mysql columns_mysql disconnect_all $default_db $last_used_db set_database $raiseerror set_raiseerror
			$print_queries show_queries $AutoReconnect $show_reconnect);

	%dbh = ();

	$default_db = 'www';
	$last_used_db = '';
	$raiseerror = 1;
	$print_queries = 0;

	$AutoReconnect  = 1;
	$show_reconnect = 0;

	$host = 'localhost';
	$port = 3306;
	$user = '';
	$pass = '';

	sub btrim {
		my $s = shift;
		$s =~ s/^\s+//s;
		$s =~ s/\s+$//s;
		return $s;
	}

	open DBCONF, "</home/bones/credentials/DB.conf";
	my @lines = <DBCONF>;
	close DBCONF;

	$host = btrim($lines[0]) if ($lines[0] =~ /\S/);
	$port = btrim($lines[1]) if ($lines[1] =~ /\S/);
	$user = btrim($lines[2]) if ($lines[2] =~ /\S/);
	$pass = btrim($lines[3]) if ($lines[3] =~ /\S/);

	$| = 1;
}

END {
	disconnect_all();
}


sub set_raiseerror {
	$raiseerror = shift;
}

sub set_database {
	$default_db = shift;
}


#############################################################################
#
# DB interface

sub show_queries {
	$print_queries = shift;
}

#############################################################################
#
# MySQL Atoms

sub mysql {
	return db_mysql($default_db,@_);
}

sub rows_mysql {
	return master_mysql(0,@_);
}

sub columns_mysql {
	return master_mysql(1,@_);
}

sub db_mysql {
	my $rows = master_mysql(0,@_);;

	if (ref($rows) eq 'ARRAY') {
		return @$rows;
	} elsif (ref($rows) eq 'HASH') {
		return %$rows;
	} else {
		return $rows;
	}
}

sub master_mysql {
	my $columns  = shift;
	my $dbname   = shift;
	my $sql      = shift;
	my $arrayref = shift;
	my $nolock   = shift;
	my $disable_constraints = shift;

	my @params = ();
	if ($arrayref && ref($arrayref) eq 'ARRAY') {
		@params = @$arrayref;
	}

	$dbname = $default_db if (!$dbname);

	if ($print_queries) {
		my $par = ''; $par = ' ('.join(',',@params).')' if (@params);
		print "MYSQL: $dbname: $sql$par\n";
	}

	die "Need both username and password for database connection.\n" if (!$user || !$pass);

	my $sql_show = $sql; $sql_show =~ s/\s+/ /g;	# Condense all whitespace and newlines into single spaces
	$sql_show =~ s/^\s+//; $sql_show =~ s/\s+$//;	# Remove leading and trailing whitespace


	if ($dbname eq 'elite') {
		$host = '10.99.50.40';
	} elsif ($dbname eq 'elite_old') {
		$host = 'localhost';
		$dbname = 'elite';
	}


	my @connectparams = ();

	@connectparams = ("DBI:mysql:database=$dbname;host=$host:$port",$user, $pass, {'RaiseError'=>$raiseerror});
	
	my $db = "$host:$port/$dbname";

	if (!$AutoReconnect && $dbh{$db} && !$dbh{$db}->ping()) {
		eval {
			$dbh{$db}->disconnect;
		};
		info("MSQL DATABASE CONNECTION LOST: ($db) \"".join('","',@connectparams)."\" [$sql_show]-- $@");
		delete($dbh{$db});
	}

	my $connected = 0;
	my $count = 0;
	if (!$dbh{$db}) {
		while (!$dbh{$db} && $count < 5) {
			eval {
				$dbh{$db} = DBI->connect(@connectparams) if (!$dbh{$db});
				$connected = 1;
			};
			$count++;
			info("CONNECT FAILED: Retrying [$count] ($db) \"".join('","',@connectparams)."\" [$sql_show]-- $@") if (!$dbh{$db});
		}
	} else {
		$connected = 1;
	}

	info("CONNECT FAILED: Giving Up! [$count attempts] ($db) \"".join('","',@connectparams)."\" [$sql_show]-- $@") if (!$connected);
	die "CONNECT FAILED: Giving Up! [$count attempts] ($db) \"".join('","',@connectparams)."\" [$sql_show]-- $@\n" if (!$connected);

	#info("CONNECT SUCCEDED: [$count attempts] ($db) \"".join('","',@connectparams)."\" [$sql_show]") if ($connected && $count);

	$last_used_db = $db;

	if (!$dbh{$db}) {
		warn "Could not connect to database '$host'!\n" ;
		return;
	}

	$dbh{$db}->{'mysql_auto_reconnect'} = $AutoReconnect;

	my $sth    = undef;
	my $failed = 1;

	eval {
		if ($nolock) {
			$sth = $dbh{$db}->prepare("SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED");
			$sth->execute();
		}

		if ($disable_constraints) {
			my $sth_c = $dbh{$db}->prepare("SET foreign_key_checks=0");
			$sth_c->execute();
		}

		$sth = $dbh{$db}->prepare($sql);
		$sth->execute(@params);
		$failed = 0;

		if ($disable_constraints) {
			my $sth_c = $dbh{$db}->prepare("SET foreign_key_checks=1");
			$sth_c->execute();
		}

	};

	if (!defined($sth) || $failed) {

		my $s = int(defined($sth)).'/'.int($failed);
		my $e = $@; $e = 'EMPTY ERR' if (!$e);

		info("FAILED MYSQL QUERY: ($db) [$s] \"$sql_show\" -- $e");
		die "FAILED MYSQL QUERY: ($db) [$s] $sql_show -- $e\n";
	}

	if ($sql =~ /^\s*(SELECT|SHOW|DESCRIBE)\s/i) {

		if ($columns) {
			my %cols = ();
			my $i = 0;

			while (my $row = $sth->fetchrow_hashref()) {

				foreach my $key (keys %$row) {

					${$cols{$key}}[$i] = $$row{$key};
				}
				$i++;
			}

			$sth->finish();
			return \%cols;
		} else {
			my @rv = ();
			while (my $row = $sth->fetchrow_hashref()) {

				push(@rv,$row);
			}
			$sth->finish();
			#$dbh{$db}->disconnect;
			return \@rv;
		}

	} elsif ($sql =~ /^\s*INSERT/i) {
		my $seq = $dbh{$db}->{mysql_insertid};
		$sth->finish();
		return 1 if (!$seq);
		return $seq;
	} else {
		$sth->finish();
		#$dbh{$db}->disconnect;
		return 1;
	}
}

sub disconnect_all {
	foreach my $i (keys %dbh) {
		eval {
			if ($show_reconnect) {
				my $ref = $dbh{$i}->{mysql_dbd_stats};
	
				if ($$ref{auto_reconnects_ok} || $$ref{auto_reconnects_failed}) {
					info("MSQL AUTO-RECONNECT TOTALs: auto_reconnects_ok=$$ref{auto_reconnects_ok}, auto_reconnects_failed=$$ref{auto_reconnects_failed}");
				}
			}

			$dbh{$i}->disconnect;
		};
		delete($dbh{$i});
	}
}


sub info {
	foreach (@_) {
		warn "$_\n";
	}
}

#############################################################################

1;


