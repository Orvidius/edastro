#!/usr/bin/perl
#./planet-list.pl 'Earth-like world' 'Water world' "rlike:name='^Flyoo Prao '" > flyoo-prao-planets.csv
./star-list.pl "rlike:name='^Flyoo Prao '" > flyoo-prao-stars-20221223.csv ; zip flyoo-prao-stars-20221223.zip flyoo-prao-stars-20221223.csv
