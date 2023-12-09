#!/bin/bash
cd /home/bones/elite/eddb
/usr/bin/wget -O eddb-systems-week.csv https://eddb.io/archive/v6/systems_recently.csv
./import_eddb_missing.pl eddb-systems-week.csv
/usr/bin/mv eddb-systems-week.csv eddb-systems-week.csv.used


