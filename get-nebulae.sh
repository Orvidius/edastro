#!/bin/bash
wget -O nebulae-procgen.csv "https://docs.google.com/spreadsheets/d/1uU01bSvv5SpScuOnsaUK56R2ylVAU4rFtVkcGUA7VZg/gviz/tq?tqx=out:csv&sheet=Proc. Gen. N"
wget -O nebulae-planetary.csv "https://docs.google.com/spreadsheets/d/1uU01bSvv5SpScuOnsaUK56R2ylVAU4rFtVkcGUA7VZg/gviz/tq?tqx=out:csv&sheet=Proc. Gen. PN"
wget -O nebulae-real.csv "https://docs.google.com/spreadsheets/d/1uU01bSvv5SpScuOnsaUK56R2ylVAU4rFtVkcGUA7VZg/gviz/tq?tqx=out:csv&sheet=Real"
wget -O IGAU_Codex.csv "https://raw.githubusercontent.com/Elite-IGAU/publications/master/IGAU_Codex.csv"

echo '' >> nebulae-procgen.csv
echo '' >> nebulae-planetary.csv
echo '' >> nebulae-real.csv
echo '' >> IGAU_Codex.csv
