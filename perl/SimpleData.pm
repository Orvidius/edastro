package SimpleData;

########################################################################
#
# Copyright (C) 2022, Ed Toton (CMDR Orvidius), CC BY-NC-SA 3.0

use strict;
use JSON;
use IO::Handle;
use File::Path qw(make_path);
use File::Find;

########################################################################

sub new {
	my $class = shift;
	my $self = {
		_DBpath => shift,
		_verbose => shift,
		_fh => {},
		_maxFH => 100,		# Postitive integer, expire file handles when going over this number of open files
		_maxAge => 20,		# DEPRECATED Postitive integer, or zero to disable age check for file handle expiration
		_pruneSec => 600,	# Postitive integer, minimum seconds between empty directory prunings
		_lastPrune => 0,
		_version => '0.02',
		_FHqueue => (),
	};

	$self->{_DBpath} =~ s/\/*\s*$//s;
	
	warn "Using storage path: $self->{_DBpath}\n" if ($self->{_verbose});

	if (!-d $self->{_DBpath}) {
		warn "Path \"$self->{_DBpath}\" does not exist\n" if ($self->{_verbose});;
		return undef;
	}

	$self->{_DBpath} .= '/dbdata';

	warn "Using data path: $self->{_DBpath}\n" if ($self->{_verbose});

	my $pruneFN = "$self->{_DBpath}/.pruneEpoch";
	if (-e $pruneFN) { 
		open PRUNE, "<$pruneFN";
		my $n = <PRUNE>;
		close PRUNE;
		chomp $n;
		$self->{_lastPrune} = $n if ($n =~ /^\d+$/);
		warn "Last Pruned: $self->{_lastPrune}\n" if ($self->{_verbose});
	}

	bless $self, $class;
	return $self;
}

sub setPruneSeconds {
	my ($self, $num) = @_;

	if ($num =~ /^\d+$/ && $num > 0) {
		$self->{_pruneSec} = $num;
	} else {
		warn "Directory minimum seconds between prunings must be a postitive integer. '$num' is not valid.\n" if ($self->{_verbose});
	}

	return $self->{_pruneSec};
}

sub setMaxHandleAge {
	my ($self, $num) = @_;

	if ($num =~ /^\d+$/ && $num >= 0) {
		$self->{_maxAge} = $num;
	} else {
		warn "File handle expiration age  must be a postitive integer, or zero to disable. '$num' is not valid.\n" if ($self->{_verbose});
	}

	return $self->{_maxAge};
}

sub setMaxHandles {
	my ($self, $num) = @_;

	if ($num =~ /^\d+$/ && $num > 0) {
		$self->{_maxFH} = $num;
	} else {
		warn "Max handles must be a postitive integer. '$num' is not valid.\n" if ($self->{_verbose});
	}

	return $self->{_maxFH};
}

sub write {
	my ($self, $key, $value) = @_;
	$self->checkExpire();
	my $fn = $self->key2filename($key);

	if (exists($self->{_fh}{$key}) && $self->{_fh}{$key}{FH}) {
		my $FH = $self->{_fh}{$key}{FH};
		seek $FH, 0, 0;
		truncate $FH, 0;

		if (!defined($value)) {
			warn "WRITE: Null $fn\n" if ($self->{_verbose});
			print $FH 'null';
		} elsif (ref($value) eq 'HASH' || (ref($value) eq 'ARRAY')) {
			warn "WRITE: ".ref($value).": $fn\n" if ($self->{_verbose});
			print $FH ref($value)."\n".JSON->new->utf8->encode($value)."\n";
		} else {
			warn "WRITE: Scalar: $fn\n" if ($self->{_verbose});
			print $FH "scalar\n$value";
		}
		return 1;
			
	} else {
		warn "WRITE: Opening: $fn\n" if ($self->{_verbose});

		$fn =~ /^(.+)\/[^\/]+$/s;
		my $dir = $1;

		if (!-d $dir) {
			warn "Making path: $dir\n" if ($self->{_verbose});
			make_path($dir);
		}

		open my $FH, "+>$fn";
		$FH->autoflush(1);
		$self->{_fh}{$key}{FH} = $FH;
		$self->{_fh}{$key}{epoch} = time;
		push @{$self->{_FHqueue}}, $key;
		return $self->write($key,$value);
	}
	return undef;
}

sub read {
	my ($self, $key) = @_;
	$self->checkExpire();
	my $fn = $self->key2filename($key);

	if (exists($self->{_fh}{$key}) && $self->{_fh}{$key}{FH}) {
		if (-e $fn) {
			my $FH = $self->{_fh}{$key}{FH};
			seek $FH, 0, 0;

			my $type = <$FH>; chomp $type;
			my @lines = <$FH>;

			if (!$type || $type eq 'scalar') {
				warn "READ: Scalar: $fn\n" if ($self->{_verbose});
				return join '', @lines;

			} elsif ($type eq 'ARRAY' || $type eq 'HASH') {
				warn "READ: $type: $fn\n" if ($self->{_verbose});
				my $jref = undef;
				eval {
					$jref = JSON->new->utf8->decode(join '',@lines);
				};
				warn "ERROR: $@" if ($@);

				return $jref;

			} else {
				warn "READ: Null: $fn\n" if ($self->{_verbose});
				return undef;
			}
			
		} else {
			# Handle is open, but file doesn't exist? Shouldn't happen. But handle it.

			warn "READ: Handle already open: $fn\n" if ($self->{_verbose});

			close $self->{_fh}{$key}{FH};
			delete($self->{_fh}{$key});

			return $self->read($key);
		}
	} elsif (-e $fn) {
		warn "READ: Opening: $fn\n" if ($self->{_verbose});
		open my $FH, "+>$fn";
		$FH->autoflush(1);
		$self->{_fh}{$key}{FH} = $FH;
		$self->{_fh}{$key}{epoch} = time;
		push @{$self->{_FHqueue}}, $key;
		return $self->read($key);
	} else {
		warn "READ: doesn't exist: $fn\n" if ($self->{_verbose});
		return undef;
	}
	return undef;
}

sub delete {
	my ($self, $key) = @_;
	$self->checkExpire();
	my $fn = $self->key2filename($key);

	warn "DELETE: $fn\n" if ($self->{_verbose});

	if (exists($self->{_fh}{$key})) {
		if ($self->{_fh}{$key}{FH}) {
			my $FH = $self->{_fh}{$key}{FH};
			close $FH;
		}
		delete $self->{_fh}{$key};
	}

	unlink $fn if (-e $fn);
}

sub getKeys {
	my $self = shift;
	my $pattern = shift;
	my @list = ();

	finddepth(sub { 
		if (-f && /\.dat$/) {
			my $fn = $self->filename2key($File::Find::name);
			push @list, $fn if (!$pattern || $fn =~ /$pattern/) ;
		}
	}, $self->{_DBpath});

	return \@list;
}

sub getData {
	my $self = shift;
	my $pattern = shift;
	my %hash = ();
	
	my $keys = $self->getKeys($pattern);

	foreach my $key (@$keys) {
		$hash{$key} = $self->read($key);
	}

	return \%hash;
}

sub checkExpire {
	my $self = shift;

	my $handles = int(keys %{$self->{_fh}});
	my $expired = 0;
	my $time = time;

	if ($handles > $self->{_maxFH}) {
		my $overage = 1 + $handles - $self->{_maxFH};
		my $n = 0;

		while ($n < $overage && @{$self->{_FHqueue}}) {
			my $key = ${$self->{_FHqueue}}[0];
		
			if (exists($self->{_fh}{$key})) {
				my $FH = $self->{_fh}{$key}{FH};
				close $FH;
				delete $self->{_fh}{$key};
				$expired++;
			}
			shift @{$self->{_FHqueue}};
			$n++;
		}
	}

	warn "Expired $expired file handles. Queue length: ".int(@{$self->{_FHqueue}})."\n" if ($expired and $self->{_verbose});

	$self->prune(1);

	return $expired;
}


sub prune {
	my ($self, $schedule) = @_;
	my $time = time;
	
	if (!$schedule || $time - $self->{_lastPrune} >= $self->{_pruneSec}) {
		warn "Pruning empty directories\n" if ($self->{_verbose});
		$self->{_lastPrune} = $time;

		my $pid = undef;

		if ($pid = fork) {
			#parent
			return 1;

		} elsif (defined $pid) {
			#child

			open PRUNE, ">$self->{_DBpath}/.pruneEpoch";
			print PRUNE "$time\n";
			close PRUNE;

			finddepth(sub { rmdir $_ if -d }, $self->{_DBpath});

			warn "Pruned: ".$self->{_DBpath}."\n" if ($self->{_verbose});
			$self->{_deleteHandlesOnly} = 1;
			exit;
		}

		return 0;
	}

	return undef;
}

sub setVerbose {
	my ($self, $verbose) = @_;
	$self->{_verbose} = $verbose;

	warn "SimpleData Verbose: on\n" if ($self->{_verbose});
	return $self->{_verbose};
}

sub getVerbose {
	my $self = shift;
	return $self->{_verbose};
}

sub key2keysafe {
	my ($self, $string) = @_;

	$string =~ s/_/_5F/gs;

	while ($string =~ m/[^\w\d\_\-]/s) {
		my $hex = sprintf("%02x",ord($&));
		$string = $`.'_'.$hex.$';

		#print "$hex($&) : $string\n"; # debugging
	}

	return $string;
}

sub pathify {
	my ($self, $string) = @_;
	$string =~ s/(..)(?=.)(?!.*\.)/$1\//g;
	return scalar $string
}

sub key2filename {
	my ($self, $string) = @_;
	$string = $self->key2keysafe($string);
	
	return $self->{_DBpath}.'/'.$self->pathify($string).'.dat';
}

sub keysafe2key {
	my ($self, $string) = @_;

	while ($string =~ m/_[a-fA-F0-9]{2}/s) {
		my $h = substr($&,1);
		$string = $`.chr(hex($h)).$';
	}

	return $string;
}

sub filename2key {
	my ($self, $string) = @_;

	my $pathsafe = $self->{_DBpath};
	$pathsafe =~ s/([^\w\d\-\_\.])/\\$1/gs;

	$string =~ s/^.*$pathsafe\///s;
	$string =~ s/\.dat$//s;
	$string =~ s/\///gs;

	return $self->keysafe2key($string);
}

sub DESTROY {
	my $self = shift;

	if (!$self->{_deleteHandlesOnly}) {
		warn "Closing $self->{_DBpath}\n" if ($self->{_verbose});
		my $closed = 0;

		foreach my $f (keys %{$self->{_fh}}) {
			close $self->{_fh}{$f}{FH} if ($self->{_fh}{$f}{FH});
			delete $self->{_fh}{$f};
			$closed++;
		}
		warn "Closed $closed file handles.\n" if ($closed && $self->{_verbose});
	} else {
		delete $self->{_fh};
	}
}


########################################################################
1;
