./lagrange-capable-stars.pl > lagrange-capable-stars.csv ; scp lagrange-capable-stars.csv www@services:/www/edastro.com/mapcharts/files/  
./planet-list.pl 'Ammonia world' > Ammonia-worlds.csv ; scp -P222 Ammonia-worlds.csv www@services:/www/edastro.com/mapcharts/files/
./planet-list.pl 'Earth-like world' > Earth-like-worlds.csv ; scp -P222 Earth-like-worlds.csv www@services:/www/edastro.com/mapcharts/files/
./planet-list.pl 'Helium gas giant' > Helium-gas-giants.csv ; scp -P222 Helium-gas-giants.csv www@services:/www/edastro.com/mapcharts/files/
./planet-list.pl 'Helium-rich gas giant' > Helium-rich-giants.csv ; scp -P222 Helium-rich-giants.csv www@services:/www/edastro.com/mapcharts/files/
./planet-list.pl 'Gas giant with ammonia-based life' 'Gas giant with water-based life' > Life-giants.csv ; scp -P222 Life-giants.csv www@services:/www/edastro.com/mapcharts/files/
./planet-list.pl 'Water giant' > Water-giants.csv ; scp -P222 Water-giants.csv www@services:/www/edastro.com/mapcharts/files/
./star-list.pl 'A (Blue-White super giant) Star' > A-class-supergiants.csv ; scp -P222 A-class-supergiants.csv www@services:/www/edastro.com/mapcharts/files/
./star-list.pl 'B (Blue-White super giant) Star' > B-class-supergiants.csv ; scp -P222 B-class-supergiants.csv www@services:/www/edastro.com/mapcharts/files/
./star-list.pl 'Black Hole' 'Supermassive Black Hole' > Black-Holes.csv ; scp -P222 Black-Holes.csv www@services:/www/edastro.com/mapcharts/files/
./star-list.pl 'C Star' > Carbon-C-stars.csv ; scp -P222 Carbon-C-stars.csv www@services:/www/edastro.com/mapcharts/files/
./star-list.pl 'C Star' 'CJ Star' 'CN Star' 'MS-type Star' 'S-type Star' > Carbon-stars.csv ; scp -P222 Carbon-stars.csv www@services:/www/edastro.com/mapcharts/files/
./star-list.pl 'K (Yellow-Orange giant) Star' > K-class-giants.csv ; scp -P222 K-class-giants.csv www@services:/www/edastro.com/mapcharts/files/
./star-list.pl 'O (Blue-White) Star' > O-class-stars.csv ; scp -P222 O-class-stars.csv www@services:/www/edastro.com/mapcharts/files/
./star-list.pl 'M (Red super giant) Star' > Red-SuperGiants.csv ; scp -P222 Red-SuperGiants.csv www@services:/www/edastro.com/mapcharts/files/
./star-list.pl 'White Dwarf (DAZ) Star' 'White Dwarf (DBV) Star' 'White Dwarf (DBZ) Star' 'White Dwarf (DQ) Star' > WhiteDwarf-Rare-Subtypes.csv ; scp -P222 WhiteDwarf-Rare-Subtypes.csv www@services:/www/edastro.com/mapcharts/files/
./star-list.pl 'Wolf-Rayet C Star' 'Wolf-Rayet N Star' 'Wolf-Rayet NC Star' 'Wolf-Rayet O Star' 'Wolf-Rayet Star' > Wolf-Rayet-stars.csv ; scp -P222 Wolf-Rayet-stars.csv www@services:/www/edastro.com/mapcharts/files/
./star-list.pl 'Herbig Ae/Be Star' > herbig-stars.csv ; scp -P222 herbig-stars.csv www@services:/www/edastro.com/mapcharts/files/
./moons-of-planets.pl 'Earth-like world' > moons-of-ELWs.csv ; scp -P222 moons-of-ELWs.csv www@services:/www/edastro.com/mapcharts/files/
./nearest-sol-discoveries.pl > nearest-sol-discoveries.csv ; scp nearest-sol-discoveries.csv www@services:/www/edastro.com/mapcharts/files/ 
./sector-list.pl > sector-list.pl.out ; cp sector-list.csv sector-list-stable.csv ; scp -P222 sector-list.csv www@services:/www/edastro.com/mapcharts/files/ ; scp -P222 sector-discovery.csv www@services:/www/edastro.com/mapcharts/files/ 
./database-stats.pl > database-stats.csv ; scp -P222 database-stats.csv www@services:/www/edastro.com/mapcharts/files/ 
./inclined-moons-near-rings.pl > inclined-moons-near-rings.csv ; scp inclined-moons-near-rings.csv www@services:/www/edastro.com/mapcharts/files/ 
./planet-multiples.pl 2 'Earth-like world' > ELW-multiples.csv ; scp -P222 ELW-multiples.csv www@services:/www/edastro.com/mapcharts/files/ 
./close-landables.pl > close-landables.csv 2>close-landables.pl.out ; scp close-landables.csv www@services:/www/edastro.com/mapcharts/files/
./nested-moons.pl > Nested-Moons.csv ; scp -P222 Nested-Moons.csv www@services:/www/edastro.com/mapcharts/files/ 
./edge-systems.pl > edge-systems.csv ; scp -P222 edge-systems.csv www@services:/www/edastro.com/mapcharts/files/ 
./hot-gasgiants.pl > hot-gasgiants.csv ; scp -P222 hot-gasgiants.csv www@services:/www/edastro.com/mapcharts/files/ 
./hot-jupiters.pl > hot-jupiters.csv ; scp -P222 hot-jupiters.csv www@services:/www/edastro.com/mapcharts/files/ 
./unknown-stars.pl > unknown-stars.csv ; scp -P222 unknown-stars.csv www@services:/www/edastro.com/mapcharts/files/ 
./body-counts.pl > body-counts.csv ; scp -P222 body-counts.csv www@services:/www/edastro.com/mapcharts/files/ 
./binary-planets.pl > binary-ELW.csv ; scp -P222 binary-ELW.csv www@services:/www/edastro.com/mapcharts/files/ 
./neutron-stars.pl > neutron-stars.csv ; scp -P222 neutron-stars.csv www@services:/www/edastro.com/mapcharts/files/ 
./discovery-dates.pl > discovery-dates.pl.out 2>&1 ; scp discovery-dates.csv discovery-months.csv www@services:/www/edastro.com/mapcharts/files/
./boxel-stats.pl > boxel-stats.pl.out 2>&1 ; scp boxel-stats.csv www@services:/www/edastro.com/mapcharts/files/
./popular-carrier-names.pl > popular-carrier-names.csv 2>popular-carrier-names.pl.out ; scp popular-carrier-names.csv www@services:/www/edastro.com/mapcharts/files/
./date-erosion.pl > date-erosion.csv 2>date-erosion.pl.out ; scp date-erosion.csv www@services:/www/edastro.com/mapcharts/files/
./multiple-star-planets.pl > multiple-star-planets.csv 2>multiple-star-planets.pl.out ; scp multiple-star-planets.csv www@services:/www/edastro.com/mapcharts/files/
./water-worlds.pl > water-worlds-g-class.csv 2>water-worlds.pl.out ; scp water-worlds-g-class.csv www@services:/www/edastro.com/mapcharts/files/
./short-period-planets.pl > short-period-planets.csv 2>short-period-planets.pl.out ; scp short-period-planets.csv www@services:/www/edastro.com/mapcharts/files/
./ringed-stars.pl > ringed-stars.csv 2>ringed-stars.pl.out ; scp ringed-stars.csv www@services:/www/edastro.com/mapcharts/files/
./valuable-planet-systems.pl > valuable-planet-systems.csv 2>valuable-planet-systems.pl.out ; scp valuable-planet-systems.csv www@services:/www/edastro.com/mapcharts/files/
./tightest-binary-stars.pl > tightest-binary-stars.pl.out 2>&1 ; scp tightest-binary-stars.csv www@services:/www/edastro.com/mapcharts/files/
./tightest-binary-stars.pl 1 > tightest-binary-stars.pl.out 2>&1 ; scp tightest-binary-stars-surface.csv www@services:/www/edastro.com/mapcharts/files/
./ELW-moons.pl > ELW-moons.csv 2>ELW-moons.pl.out ; scp ELW-moons.csv www@services:/www/edastro.com/mapcharts/files/
./terraformable-systems.pl > terraformable-systems.csv 2>terraformable-systems.pl.out ; scp terraformable-systems.csv www@services:/www/edastro.com/mapcharts/files/
./systems-without-coordinates.pl > systems-without-coordinates.csv 2>systems-without-coordinates.pl.out ; scp systems-without-coordinates.csv www@services:/www/edastro.com/mapcharts/files/
./stations.pl > stations.csv 2>stations.pl.out ; scp stations.csv www@services:/www/edastro.com/mapcharts/files/
./tidally-locked-unequal.pl > tidally-locked-unequal.csv 2>tidally-locked-unequal.pl.out ; scp tidally-locked-unequal.csv www@services:/www/edastro.com/mapcharts/files/
./landables-closest-approach.pl > landables-closest-approach.csv 2>landables-closest-approach.pl.out ; scp landables-closest-approach.csv www@services:/www/edastro.com/mapcharts/files/
./sol-like-systems.pl > sol-like-systems.csv 2>sol-like-systems.pl.out ; scp sol-like-systems.csv www@services:/www/edastro.com/mapcharts/files/
./codex-data.pl > codex-data.csv 2>codex-data.pl.out ; scp codex-data.csv www@services:/www/edastro.com/mapcharts/files/
./fleetcarriers.pl > fleetcarriers.csv 2>fleetcarriers.pl.out ; scp fleetcarriers.csv www@services:/www/edastro.com/mapcharts/files/
