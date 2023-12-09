#!/bin/bash
./planet-list.pl "like:name='Graea Hypue %'" 'and:isLandable=1' 'notnull:surfacePressure' 'and:surfacePressure>0'  'notnull:volcanismType' "and:volcanismType!='No volcanism'"  > straha-atmo-volcanism.csv
