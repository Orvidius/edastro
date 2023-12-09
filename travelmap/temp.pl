
opendir DIR, $journalPath;
while (my $fn = readdir DIR) {
	if ($fn =~ /\.log$/ && $fn !~ /^\./) {

		# Get a CMDR name right away.
		

		$cmdrName = '';
		my $foundJump = 0;

		open TXT, "<$journalPath/$fn";
		while (my $data = <TXT>) {
			if ($data =~ /"+event"+\s*:\s*"+LoadGame"+/) {
				if ($data =~ /"+Commander"+\s*:\s*"+([^"]+)"+/) {
					$cmdrName = btrim($1);
					#print "Commander: $cmdrName\n" if ($verbose || $debug);

					if ($data =~ /"+Ship"+\s*:\s*"+([^"]+)"+/) {
						$cmdrShip{$cmdrName} = get_ship($1,$cmdrShip{$cmdrName});
					}
				}
			}

			if ($data =~ /"+event"+\s*:\s*"+(FSDJump|CarrierJump)"+/) {
				$foundJump = 1;
			}

			last if ($cmdrName && $foundJump);
		}
		close TXT;

		if ($cmdrNum{$cmdrName} < 0) {
			# User requested to skip this commander
			print "\tskipped $fn, commander name skip.\n" if ($verbose);
			next;
		}

		if (!$foundJump) {
			# Probably a tutorial
			print "\tskipped $fn, no jumps.\n" if ($verbose);
			next;
		}

		open TXT, "<$journalPath/$fn";
		my $string = '';

		while (my $data = <TXT>) {
			chomp $data;

			next if ($data =~ /^\s*$/); # contains nothing

			if ($string) {
				$string .= btrim($data);
				if ($data =~ /^\}\"*\s*$/) {
					process_line($string,$fn);
					$string = '';
				}
			} elsif ($data =~ /^\"*\{.+\}\"*\s*$/) {
				process_line($data,$fn);
			} else {
				$string .= btrim($data);
			}
		}
		close TXT;
	}
}
closedir DIR;

sub process_line {
	my $line = shift;
	my $file = shift;

	my %dummy = ();
	my $r = \%dummy;

	#print "< $line\n" if ($line =~ /Commander/i);
	
	if ($line =~ /"+event"+\s*:\s*"+LoadGame"+/) {
		if ($line =~ /"+Commander"+\s*:\s*"+([^"]+)"+/) {
			$cmdrName = btrim($1);

			if ($line =~ /"+Ship"+\s*:\s*"+([^"]+)"+/) {
				$cmdrShip{$cmdrName} = get_ship($1,$cmdrShip{$cmdrName});

				if ($line =~ /"+ShipName"+\s*:\s*"+([^"]+)"+/) {
					$cmdrShipName{$cmdrName} =  btrim($1);
	
					if ($line =~ /"+ShipIdent"+\s*:\s*"+([^"]+)"+/) {
						$cmdrShipName{$cmdrName} .= " ($1)";
					}
				}
			}
		}

	} elsif ($line =~ /"+event"+\s*:\s*"+Embark"+/) {
		if ($line =~ /"+Taxi"+\s*:\s*true/) {
			$cmdrShipName{$cmdrName} = '';
			$cmdrShip{$cmdrName} = get_ship('adder_taxi');
		}
	} elsif ($line =~ /"+event"+\s*:\s*"+ShipyardSwap"+/) {

		if ($cmdrName && $line =~ /"+ShipType"+\s*:\s*"+([^"]+)"+/) {
			$cmdrShip{$cmdrName} = get_ship($1,$cmdrShip{$cmdrName});
			$cmdrShipName{$cmdrName} = '';
		}

	} elsif ($line =~ /"+event"+\s*:\s*"+Loadout"+/) {
		if ($line =~ /"+Ship"+\s*:\s*"+([^"]+)"+/) {
			$cmdrShip{$cmdrName} = get_ship($1,$cmdrShip{$cmdrName});

			if ($line =~ /"+ShipName"+\s*:\s*"+([^"]+)"+/) {
				$cmdrShipName{$cmdrName} = btrim($1);
	
				if ($line =~ /"+ShipIdent"+\s*:\s*"+([^"]+)"+/) {
					$cmdrShipName{$cmdrName} .= " ($1)";
				}
			}
		}

	} elsif ($line =~ /"+event"+\s*:\s*"+(FSDJump|Location|CarrierJump)"+/) {
		$$r{event} = $1;

		my $docked = 0;
		if ($line =~ /"+Docked"+\s*:\s*true/) {
			$docked = 1;
		}

		$$r{cmdr}  = $cmdrName if ($cmdrName);
		$$r{ship}  = $cmdrShip{$cmdrName} if ($cmdrShip{$cmdrName});
		$$r{shipName}  = $cmdrShipName{$cmdrName} if ($cmdrShipName{$cmdrName});

		if ($cmdrName && !defined($cmdrNum{$cmdrName})) {
			$cmdrNum{$cmdrName} = $cmdrCount;
			$cmdrCount++;
			$cmdrCount = $cmdrMax if ($cmdrCount>$cmdrMax);
		}

		if ($line =~ /"+timestamp"+\s*:\s*"+([\w\d\:\-\s]+)"+/) {
			$$r{date} = $1;
			$$r{date} =~ s/[^\d\s\:\-]/ /gs;
			$$r{date} = btrim($$r{date});
		}
		if ($line =~ /"+StarSystem"+\s*:\s*"+([^"]+)"+/) {
			$$r{name} = btrim($1);
		}
		if ($line =~ /"+StarPos"+\s*:\s*\[\s*([\d\.\-]+)\s*,\s*([\d\.\-]+)\s*,\s*([\d\.\-]+)\s*\]/) {
			$$r{coord_x} = $1;
			$$r{coord_y} = $2;
			$$r{coord_z} = $3;
		}


		$$r{f} = $file;

		#print "LOG: $cmdrName $$r{date}: $$r{coord_x}, $$r{coord_y}, $$r{coord_z} ($$r{name})\n";
		if ($$r{event} ne 'CarrierJump' || $docked == 1) {
			push @events, $r;
		}
	}
}


while (@events) {
	my $r = shift @events;
	my $c = $$r{cmdr};

	$$r{timebucket} = int(date2epoch($$r{date})/$secPerFrame);

	if (!defined($loc{$c}{x}) && !defined($loc{$c}{y}) && !defined($loc{$c}{z})) {
		$loc{$c}{x} = $$r{coord_x};
		$loc{$c}{y} = $$r{coord_y};
		$loc{$c}{z} = $$r{coord_z};
		$loc{$c}{src} = $$r{name};
	}

	if ($$r{event} eq 'FSDJump' || $$r{event} eq 'CarrierJump') {
		my $jumpdist = ( ($$r{coord_x}-$loc{$c}{x})**2 + ($$r{coord_y}-$loc{$c}{y})**2 + ($$r{coord_z}-$loc{$c}{z})**2) ** 0.5;

		$$r{died} = 1 if ($jumpdist > 350 && $$r{event} eq 'FSDJump');		# Had to have been a teleport/spawn event that we missed.
		$$r{died} = 1 if ($jumpdist > 510 && $$r{event} eq 'CarrierJump');	# Had to have been a teleport/spawn event that we missed.
		print "Died(jump). $jumpdist\n" if ($$r{died} && ($debug || $verbose));

		$$r{from_x} = $loc{$c}{x};
		$$r{from_y} = $loc{$c}{y};
		$$r{from_z} = $loc{$c}{z};
		$$r{from_name} = $loc{$c}{src};
		$$r{distance} = $jumpdist;

		if (!$$r{died}) {
			$stats{$$r{cmdr}}{all}{jumps}++;
			$stats{$$r{cmdr}}{all}{ly}+=$jumpdist;
			$stats{$$r{cmdr}}{$$r{ship}}{jumps}++;
			$stats{$$r{cmdr}}{$$r{ship}}{ly}+=$jumpdist;
		}

		push @rows, $r;
		($loc{$c}{x},$loc{$c}{y},$loc{$c}{z}) = ($$r{coord_x},$$r{coord_y},$$r{coord_z});
	} else {
		my ($dx,$dy,$dz) = ($$r{coord_x}-$loc{$c}{x},$$r{coord_y}-$loc{$c}{y},$$r{coord_z}-$loc{$c}{z});
		my $jumpdist = ( ($$r{coord_x}-$loc{$c}{x})**2 + ($$r{coord_y}-$loc{$c}{y})**2 + ($$r{coord_z}-$loc{$c}{z})**2) ** 0.5;

		$$r{from_x} = $loc{$c}{x};
		$$r{from_y} = $loc{$c}{y};
		$$r{from_z} = $loc{$c}{z};
		$$r{from_name} = $loc{$c}{src};
		$$r{distance} = $jumpdist;

		if ($dx < -1 || $dx > 1 || $dy < -1 || $dy > 1 || $dz < -1 || $dz > 1) {
			# Teleported, died, etc
			$$r{died} = 1;
			print "Died(loc). $jumpdist\n" if ($$r{died} && ($debug || $verbose));
			push @rows, $r;
			($loc{$c}{x},$loc{$c}{y},$loc{$c}{z}) = ($$r{coord_x},$$r{coord_y},$$r{coord_z});
		}
	}
}

sub get_ship {
	my $s = btrim(shift);
	my $old = btrim(shift);

	# Translate the ones that have non-pretty internal IDs.

	$s = 'Apex Taxi' if (uc($s) eq uc('adder_taxi'));
	$s = 'Anaconda' if (uc($s) eq uc('anaconda'));
	$s = 'Sidewinder' if (uc($s) eq uc('sidewinder'));
	$s = 'Python' if (uc($s) eq uc('python'));
	$s = 'Eagle' if (uc($s) eq uc('eagle'));
	$s = 'Adder' if (uc($s) eq uc('adder'));
	$s = 'Hauler' if (uc($s) eq uc('hauler'));
	$s = 'Cobra Mk.III' if (uc($s) eq uc('CobraMkIII'));
	$s = 'Cobra Mk.IV' if (uc($s) eq uc('CobraMkIV'));
	$s = 'Diamondback Explorer' if (uc($s) eq uc('DiamondBackXL'));
	$s = 'Diamondback Scout' if (uc($s) eq uc('diamondback'));
	$s = 'Asp Explorer' if (uc($s) eq uc('Asp'));
	$s = 'Asp Scout' if (uc($s) eq uc('asp_scout'));
	$s = 'Viper Mk.IV' if (uc($s) eq uc('Viper_MkIV'));
	$s = 'Viper Mk.III' if (uc($s) eq uc('Viper'));
	$s = 'Fer de Lance' if (uc($s) eq uc('FerDeLance'));
	#$s = 'Scarab SRV' if (uc($s) eq uc('TestBuggy'));
	$s = 'Imperial Eagle' if (uc($s) eq uc('Empire_Eagle'));
	$s = 'Imperial Courier' if (uc($s) eq uc('Empire_Courier'));
	$s = 'Imperial Clipper' if (uc($s) eq uc('Empire_Trader'));
	$s = 'Imperial Cutter' if (uc($s) eq uc('Cutter'));
	$s = 'Federal Corvette' if (uc($s) eq uc('Federation_Corvette'));
	$s = 'Federal Dropship' if (uc($s) eq uc('Federation_Dropship'));
	$s = 'Federal Assault ship' if (uc($s) eq uc('federation_dropship_mkii'));
	$s = 'Federal Gunship' if (uc($s) eq uc('Federation_Gunship'));
	$s = 'Beluga Liner' if (uc($s) eq uc('BelugaLiner'));
	$s = 'Orca' if (uc($s) eq uc('orca'));
	$s = 'Dolphin' if (uc($s) eq uc('dolphin'));
	$s = 'Alliance Chieftain' if (uc($s) eq uc('TypeX'));
	$s = 'Alliance Challenger' if (uc($s) eq uc('typex_3'));
	$s = 'Alliance Crusader' if (uc($s) eq uc('typex_2'));
	$s = 'Type-6 Transporter' if (uc($s) eq uc('Type6'));
	$s = 'Type-7 Transporter' if (uc($s) eq uc('Type7'));
	$s = 'Type-9 Heavy' if (uc($s) eq uc('Type9'));
	$s = 'Type-10 Defender' if (uc($s) eq uc('type9_military'));
	$s = 'Keelback' if (uc($s) eq uc('independant_trader'));
	$s = 'Krait Mk.II' if (uc($s) eq uc('krait_mkii'));
	$s = 'Krait Phantom' if (uc($s) eq uc('krait_light'));
	$s = 'Mamba' if (uc($s) eq uc('mamba'));

	$s = $old if ($s =~ /Fighter/i);
	$s = $old if ($s =~ /Suit/i);
	$s = $old if ($s =~ /Buggy/i);

	return $s;
}





