cd ~bones/elite/scripts

(./close-moons-landable.pl 'Earth-like world' > close-moons-landable-ELW.csv 2>close-moons-landable.pl.out ; scp close-moons-landable-ELW.csv www@services:/www/edastro.com/mapcharts/files/  ) &
(./moon-rich-HMCs.pl > moon-rich-HMCs.csv 2>moon-rich-HMCs.pl.out ; scp moon-rich-HMCs.csv www@services:/www/edastro.com/mapcharts/files/ ) &
(./shepherd-moons.pl > shepherd-moons.csv 2>shepherd-moons.out ; scp shepherd-moons.csv www@services:/www/edastro.com/mapcharts/files/ ) &
(./trojan-planets.pl > trojan-planets.csv ; scp trojan-planets.csv www@services:/www/edastro.com/mapcharts/files/ ) &
(./high-body-count-systems.pl > high-body-count-systems.csv 2>high-body-count-systems.pl.out ; scp high-body-count-systems.csv www@services:/www/edastro.com/mapcharts/files/ ) &

