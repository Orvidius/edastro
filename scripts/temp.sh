#!/bin/bash
( ./planet-list.pl 'Ammonia world' > Ammonia-worlds.csv ; scp Ammonia-worlds.csv www@services:/www/edastro.com/mapcharts/files/ ) &
( ./planet-list.pl 'Gas giant with ammonia-based life' 'Gas giant with water-based life' > Life-giants.csv ; scp Life-giants.csv www@services:/www/edastro.com/mapcharts/files/ ) &
( ./planet-list.pl 'Helium-rich gas giant' > Helium-rich-giants.csv ; scp Helium-rich-giants.csv www@services:/www/edastro.com/mapcharts/files/ ) &
( ./planet-list.pl 'Helium gas giant' > Helium-gas-giants.csv ; scp Helium-gas-giants.csv www@services:/www/edastro.com/mapcharts/files/ ) &
( ./planet-list.pl 'Water giant' > Water-giants.csv ; scp Water-giants.csv www@services:/www/edastro.com/mapcharts/files/ ) &
( ./planet-list.pl 'and:orbitalEccentricity\>=0.999'> eccentric-orbits.csv ; scp eccentric-orbits.csv www@services:/www/edastro.com/mapcharts/files/ ) &
( ./planet-list.pl 'and:orbitalEccentricity\>=0.9' 'and:isLandable=1' > eccentric-orbits-landable.csv ; scp eccentric-orbits-landable.csv www@services:/www/edastro.com/mapcharts/files/ ) &
( ./planet-list.pl 'Metal-rich body' "and:terraformingState=\'Candidate\ for\ terraforming\'" > metal-rich-terraformables.csv ; scp metal-rich-terraformables.csv www@services:/www/edastro.com/mapcharts/files/ ) &
( ./planet-list.pl "rlike:name=' [\0-9\]+\( [a-z\]\)+$'" 'Class I gas giant' 'Class II gas giant' 'Class III gas giant' 'Class IV gas giant' 'Class V gas giant' 'Gas giant with ammonia-based life' 'Gas giant with water-based life' 'Helium gas giant' 'Helium-rich gas giant' 'Water giant' > gas-giants-as-moons.csv ; scp gas-giants-as-moons.csv www@services:/www/edastro.com/mapcharts/files/ ) &
( ./planet-list.pl 'and:distanceToArrival=0' > zero-distance-planets.csv ; scp zero-distance-planets.csv www@services:/www/edastro.com/mapcharts/files/ ) &
( ./planet-list.pl 'and:distanceToArrival>700000' "binlike:name=' [A-Z][A-Z]-[A-Z] [a-z]'" > distant-planets.csv ; scp distant-planets.csv www@services:/www/edastro.com/mapcharts/files/ ) &
