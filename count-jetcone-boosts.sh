#!/bin/bash
cd ~bones/elite
grep '"event":"JetConeBoost"' journals/Journal.* | wc -l 
cd - > /dev/null
