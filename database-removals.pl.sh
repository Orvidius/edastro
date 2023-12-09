#!/bin/bash

source /etc/profile

cd /home/bones/elite

rm -f systemsWithCoordinates.json.gz
mv systemsWithCoordinates.json systemsWithCoordinates.json.old
wget https://www.edsm.net/dump/systemsWithCoordinates.json.gz
gunzip systemsWithCoordinates.json.gz

rm -f systemsWithoutCoordinates.json.gz
mv systemsWithoutCoordinates.json systemsWithoutCoordinates.json.old
wget https://www.edsm.net/dump/systemsWithoutCoordinates.json.gz
gunzip systemsWithoutCoordinates.json.gz

mv systems.json systems.json.old
cat systemsWithCoordinates.json systemsWithoutCoordinates.json > systems.json

time ./database-removals.pl systems.json


#rm -f bodies.json.gz
#mv bodies.json bodies.json.old
#wget https://www.edsm.net/dump/bodies.json.gz
#gunzip bodies.json.gz
#
#time ./database-removals.pl bodies.json


rm -f stations.json.gz
mv stations.json stations.json.old
wget https://www.edsm.net/dump/stations.json.gz
gunzip stations.json.gz

time ./database-removals.pl stations.json

