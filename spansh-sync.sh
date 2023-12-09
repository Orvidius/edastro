#!/bin/bash
cd /home/bones/elite
#/usr/bin/wget -O spansh-galaxy-week.json.gz https://downloads.spansh.co.uk/galaxy_7days.json.gz
/usr/bin/gunzip spansh-galaxy-week.json.gz
./spansh-to-jsonl.pl spansh-galaxy-week.json
/usr/bin/mv spansh-galaxy-week.json spansh-galaxy-week.json.used
./parse-data.pl -i spansh-systems.jsonl
./parse-data.pl -i spansh-bodies.jsonl
/usr/bin/mv spansh-bodies.jsonl spansh-bodies.jsonl.used
/usr/bin/mv spansh-systems.jsonl spansh-systems.jsonl.used


