#!/bin/bash
convert -composite /home/bones/www/elite/visited-systems-heatmap.png ~/elite/images/region-lines.png -gravity northwest /home/bones/www/elite/visited-systems-regions.png 
scp -P222 /home/bones/www/elite/visited-systems-regions.png www@services:/www/edastro.com/mapcharts/ 
convert  /home/bones/www/elite/visited-systems-regions.png -verbose -resize 600x600  -gamma 1.3 /home/bones/www/elite/visited-systems-regions.jpg 
convert  /home/bones/www/elite/visited-systems-regions.png -verbose -resize 200x200 -gamma 1.3 /home/bones/www/elite/visited-systems-regions-thumb.jpg 
scp -P222 /home/bones/www/elite/visited-systems-regions.jpg /home/bones/www/elite/visited-systems-regions-thumb.jpg www@services:/www/edastro.com/mapcharts/ 
scp -P222 /home/bones/elite/images/region-lines.png www@services:/www/edastro.com/galmap/
