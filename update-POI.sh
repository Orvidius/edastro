#!/bin/bash
cd ~bones/elite 
./get-GGGs.sh

/usr/bin/wget -O POIlist.json https://www.edsm.net/en/galactic-mapping/json-edd 
cp POIlist.json POIstuff/POIlist.json.`date +\%Y\%m`
./json-to-jsonl.pl POIlist.json > POIlist.jsonl

/usr/bin/wget -O GEC-POIs.json "https://edastro.com/gec/json/all"
cp POIlist.json POIstuff/GEC-POIs.json`date +\%Y\%m`
./json-to-jsonl.pl GEC-POIs.json > GEC-POIs.jsonl

./POIstuff/hide-all.pl
./parse-data.pl POIlist.jsonl 
./parse-data.pl GEC-POIs.jsonl

#/usr/bin/wget -O tritium.csv "https://docs.google.com/spreadsheets/d/1DfcVCHYgPHZnxUmsrGWXKdNK-2iz7t2MG80EGGW9XGI/gviz/tq?tqx=out:csv"
#/usr/bin/wget -O tritium2.csv "https://docs.google.com/spreadsheets/d/1YRryJURVGkVCDS3H1uvJDW8yCgbSMK1qJ7mMMWMp2aE/gviz/tq?tqx=out:csv"
/usr/bin/wget -O canonn-challenge.csv "https://docs.google.com/spreadsheets/d/1YJklhwkJFp_Un7n88rlsNS8ELjXSNwT7ncnr8Xot9Tc/gviz/tq?tqx=out:csv"
#/usr/bin/wget -O STAR-carriers.csv "https://docs.google.com/spreadsheets/d/1oXnyTK9ZzXOvymRxTpxHwrXeTnFn7wKLtIPGQAntEwQ/gviz/tq?tqx=out:csv"
#/usr/bin/wget -O STAR-carriers.csv "https://docs.google.com/spreadsheets/d/1YDw9u7KbqFCyAOVP5OTOhtNLJKw-7sCuOIj7aAqcJ1s/gviz/tq?tqx=out:csv"
#/usr/bin/wget -O STAR-carriers.csv "https://docs.google.com/spreadsheets/d/1YDw9u7KbqFCyAOVP5OTOhtNLJKw-7sCuOIj7aAqcJ1s/export?format=csv&gid=0"
/usr/bin/wget -O STAR-carriers.csv "https://docs.google.com/spreadsheets/d/1YDw9u7KbqFCyAOVP5OTOhtNLJKw-7sCuOIj7aAqcJ1s/export?format=csv&gid=1404824807"

# from: https://docs.google.com/spreadsheets/d/1hXmRljA5d4PSjzvxI8gqWybAHJZNFYAx/edit#gid=1137410615
/usr/bin/wget -O pioneerproject.csv "https://docs.google.com/spreadsheets/d/1hXmRljA5d4PSjzvxI8gqWybAHJZNFYAx/gviz/tq?tqx=out:csv"

# from: https://docs.google.com/spreadsheets/d/1ev9pxVJCHApDEhsXc0mzrgeQqjaIJc2lJw-m3nXCaz8/edit?pli=1#gid=72514601
/usr/bin/wget -O trit_highway.csv "https://docs.google.com/spreadsheets/d/1ev9pxVJCHApDEhsXc0mzrgeQqjaIJc2lJw-m3nXCaz8/gviz/tq?tqx=out:csv&gid=72514601"

./DSSA-pull.pl 
./push-POI.sh
./csv-maps/DSSA-map.pl > ./csv-maps/DSSA-map.pl.out
