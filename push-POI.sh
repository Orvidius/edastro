#!/bin/bash
cd ~bones/elite 
./edsmPOI.pl > edsmPOI.data 
/usr/bin/scp edsmPOI.data www@services:/www/edastro.com/galmap/
/usr/bin/scp edsmPOI.csv www@services:/www/edastro.com/mapcharts/files/
/usr/bin/scp IGAU-carriers.json www@services:/www/edastro.com/IGAU/
/usr/bin/scp DSSA-carriers.json carriers-DSSA.json carriers-IGAU.json www@services:/www/edastro.com/galmap/
/usr/bin/scp DSSAdisplaced.csv www@services:/www/edastro.com/mapcharts/files/
#/usr/bin/ssh www@services 'cd /www/edastro.com/galmap/ ; ./update-POI.pl '
cp edsmPOI.data ~bones/elite/POIstuff
cd ~bones/elite/POIstuff
./update-POI.pl
scp POI-include.html POI-include1.html POI-include2.html POI.json POI0.json POI1.json POI2.json POI3.json www@services:/www/edastro.com/galmap/incoming/
ssh www@services 'cd /www/edastro.com/galmap ; ./import-files.pl'
cd -
