#!/bin/bash
./planet-list.pl 'and:surfacePressure>=0.001' 'and:surfacePressure<=0.1' "notlike:atmosphereType='%neon%'" "notlike:atmosphereType='%argon%'" "notlike:atmosphereType='%methane%'" 'Icy body' > odyssey-landable-rare-candidates.csv
./planet-list.pl 1 'and:surfacePressure>=0.001' 'and:surfacePressure<=0.1' "notlike:atmosphereType='%Silicate vapour%'" 'Metal-rich body'  >> odyssey-landable-rare-candidates.csv
./planet-list.pl 1 'and:surfacePressure>=0.001' 'and:surfacePressure<=0.1' "notlike:atmosphereType='%Ammonia%'" "notlike:atmosphereType='%Carbon dioxide%'" "notlike:atmosphereType='%Sulphur dioxide%'" 'High metal content world' >> odyssey-landable-rare-candidates.csv
./planet-list.pl 1 'and:surfacePressure>=0.001' 'and:surfacePressure<=0.1' "notlike:atmosphereType='%Ammonia%'" "notlike:atmosphereType='%Carbon dioxide%'" "notlike:atmosphereType='%Sulphur dioxide%'" 'Rocky body'  >> odyssey-landable-rare-candidates.csv
./planet-list.pl 1 'and:surfacePressure>=0.001' 'and:surfacePressure<=0.1' "notlike:atmosphereType='%neon%'" "notlike:atmosphereType='%argon%'" 'Rocky Ice world'  >> odyssey-landable-rare-candidates.csv
