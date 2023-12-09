#!/bin/bash
cd /home/bones/elite/sectordump
./sectordump.pl 'Graea Hypue' 
/usr/bin/zip graea_hypue.zip graea_hypue.jsonl
/usr/bin/scp graea_hypue.zip graea_hypue-codex.jsonl www@services:/www/edastro.com/IGAU/
cd -
