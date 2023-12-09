#!/usr/bin/python

###########################################################################

import json
import cgi
import imp
import sys
import re
from syslog import syslog

db = imp.load_source('db', '/home/bones/python/db.py')
arguments = cgi.FieldStorage()


# Settings:

max_query	= 10


###########################################################################
# Serializer to handle datetime in JSON

from datetime import date, datetime
from decimal import Decimal

def json_serial(obj):
	#JSON serializer for objects not serializable by default json code

	if isinstance(obj, (datetime, date)):
		return obj.isoformat()
	if isinstance(obj, (Decimal)):
		return float(obj)
	#return '--'+str(type(obj))+'--'
	raise TypeError ("Type %s not serializable" % type(obj))


###########################################################################
# Debugging:

#rows = db.select('elite',"select * from systems where name=%s and deletionState=0",['Sol'],True)
#rows = db.select('elite',"select * from systems where id64=%s and deletionState=0",['10477373803'],True)
#rows = db.select('elite',"select * from systems where name like 'HIP %' and deletionState=0",[],True)

# Debugging:

if False:
	print "Content-Type: text/plain\n" 

	print(json.dumps(arguments,default=json_serial,sort_keys=True))

	for i in arguments.keys():
		if re.match(r"\[\]$",i):
			for k in arguments.getvalue(i).split(','):
				print i,' = ',k
		else:
			print i,' = ',arguments[i].value
	sys.exit()


###########################################################################
# Setup:

starsys = None
id64 = None
rows = []
query = None
ip = None

if 'ip' in arguments.keys():
	ip = arguments['ip'].value

if 'q' in arguments.keys():
	query = arguments['q'].value
else:
	print "Query parameter missing"
	sys.exit

syslog(ip+' Query: '+query)

print "Content-Type: application/json\n" 
#print "Content-Type: text/plain\n" 


sysfields = ','.join(['ID','id64','edsm_id','name','updated','date_added','updateTime','edsm_date','FSSdate',
	'mainStarID','mainStarType','masscode','coord_x','coord_y','coord_z','sol_dist','region',
	'complete','FSSprogress','bodyCount','nonbodyCount','numTerra','numELW','numWW','numAW',
	'id64sectorID','id64mass','id64boxelID','id64boxelnum'])

commonfields = ','.join(['systemId64','bodyId64','systemId as edsmID','name','subType','updated','date_added','updateTime','edsm_date','eddn_date',
	'surfaceTemperature','bodyId','parents','parentID','parentType','parentStar','parentStarID','parentPlanet','parentPlanetID',
	'distanceToArrival','distanceToArrivalLS','rotationalPeriodTidallyLocked','rotationalPeriodDec as rotationalPeriod','axialTiltDec as axialTilt',
	'orbitalPeriodDec as orbitalPeriod','orbitalEccentricityDec as orbitalEccentricity','orbitalInclinationDec as orbitalInclination',
	'argOfPeriapsisDec as argOfPeriapsis','semiMajorAxisDec as semiMajorAxis','meanAnomaly','meanAnomalyDate','ascendingNode'])

starfields   = ','.join(['starID','absoluteMagnitudeDec as absoluteMagnitude','solarMassesDec as solarMasses','solarRadiusDec as solarRadius',
		'luminosity','spectralClass','isPrimary','isMainStar','isScoopable','age']) +','+ commonfields

planetfields = ','.join(['planetID','gravityDec as gravity','earthMassesDec as earthMasses','radiusDec as radius','isLandable']) +','+ commonfields


###########################################################################
# Build system list

single = None;
systems = []

if re.match(r',',query):
	single = re.sub(r'^\s*(.+\S)\s*$/',r'\1',query)
	systems.append(single)
else:
	for s in query.split(','):
		systems.append(re.sub(r'^\s*(.+\S)\s*$/',r'\1',s))


if len(systems)>max_query:
	systems = systems[:max_query]


rows = []
params = []
where = ''

for starsys in systems:
	if (re.match(r'^\s*\d+\s*$',starsys)):
		if where != '':
			where += ' or '
		where += "id64=%s"
		params.append(re.sub(r'^\s*(\d+)\s*$/',r'\1',starsys))
	else:
		if where != '':
			where += ' or '
		where += "name=%s"
		params.append(re.sub(r'^\s*(.+\S)\s*$/',r'\1',starsys))


#syslog('Where: '+where+' ['+','.join(params)+']')

rows = db.select('elite',"select "+sysfields+" from systems where ("+where+") and deletionState=0",params,True)
#rows += db.select('elite',"select * from navsystems where "+where,params,True)
	
if len(rows)==0:
	print "{}"
	sys.exit;


###########################################################################
# Get localized names, if we have rows to work with

local_tables = {'codexname_local':'codexnameID','codexcat_local':'codexcatID','codexsubcat_local':'codexsubcatID','species_local':'speciesID','genus_local':'genusID'}
localname = {}

for dbtable in local_tables.keys():
	IDfield = local_tables[dbtable]

	names = db.select('elite',"select "+IDfield+" as ID, name, preferred from "+dbtable+" order by preferred",[],True)
	if names is not None:
		for n in names:
			if IDfield not in localname:
				localname[IDfield] = {}
			localname[IDfield][n['ID']] = n['name']

		
###########################################################################
# Loop over systems, get the data!


found = 0
output = []

for r in rows:
	found+=1

	r['planets'] = []
	r['stars']   = []
	r['codex']   = []
	r['barycenters'] = []
	r['carriers']    = []
	r['stations']    = []

	#print r['id64']

	planets = db.select('elite',"select "+planetfields+" from planets where systemId64=%s and deletionState=0",[r['id64']],True)
	stars   = db.select('elite',"select "+starfields  +" from stars   where systemId64=%s and deletionState=0",[r['id64']],True)

	bary    = db.select('elite',"select ID,bodyId64,bodyId,"+
			"updated,date_added,updateTime,edsm_date,eddn_date,orbitalPeriod,orbitalEccentricity,orbitalInclination,"+
			"argOfPeriapsis,semiMajorAxis,meanAnomaly,meanAnomalyDate,ascendingNode,parents,parentID,parentType from "+
			"barycenters where systemId64=%s and deletionState=0",[r['id64']],True)

	carrier = db.select('elite',"select ID,name,callsign,marketID,created,updated,lastEvent,lastMoved,FSSdate,distanceToArrival,"+
			"services,isDSSA,isIGAU,DockingAccess as dockingAccess from carriers where systemId64=%s and lastEvent>=date_sub(NOW(),interval 30 day) "+
			"and invisible=0",[r['id64']],True)

	codex   = db.select('elite',"select codex.id as ID,nameID as codexnameID,categoryID as codexcatID,subcategoryID as codexsubcatID,reportedOn,"+
			"codexname.name as codexname,codexsubcat.name as subcategory,codexcat.name as category from codex,"+
			"codexname,codexcat,codexsubcat where systemId64=%s and deletionState=0 and nameID=codexname.ID and subcategoryID=codexsubcat.ID and "+
			"categoryID=codexcat.ID",[r['id64']],True)

	organic  = {}
	organics = db.select('elite',"select organic.id as ID,genusID,speciesID,bodyId,firstReported,organic.date_added,lastSeen,bodyId,genus.name as genus,species.name as species "+
		"from organic,species,genus where systemId64=%s and genusID=genus.ID and speciesID=species.ID",[r['id64']],True)

	stations = db.select('elite',"select marketID,bodyName,name,type,padsS,padsM,padsL,distanceToArrival,allegiance,government,economy,secondEconomy,"+
			"haveMarket,haveShipyard,haveOutfitting,eddnDate,updated from stations where systemId64=%s and deletionState=0 and economy!='Fleet Carrier'",
			[r['id64']],True)

	if organics is not None:
		for org in organics:
			if org['bodyId'] not in organic:
				organic[org['bodyId']] = []

			organic[org['bodyId']].append(org)
			del org['bodyId']

	if stations is not None:
		for stat in stations:
			stat['haveMarket'] = bool(stat['haveMarket'])
			stat['haveShipyard'] = bool(stat['haveShipyard'])
			stat['haveOutfitting'] = bool(stat['haveOutfitting'])
			r['stations'].append(stat)

	if 'complete' in r and r['complete'] is not None:
		r['complete'] = bool(r['complete'])

	r['coordinates'] = [r['coord_x'],r['coord_y'],r['coord_z']]

	if planets is not None:
		#r['planets'] = planets
		for p in planets:
			p['isLandable'] = bool(p['isLandable'])

			p['rings'] = db.select('elite',"select name,type,mass,innerRadius,outerRadius from rings where isStar=0 and planet_id=%s",[p['planetID']],True)

			materials = db.select('elite',"select * from materials where planet_id=%s",[p['planetID']],True)
			p['materials'] = []
			if materials is not None:
				for m in materials:
					del m['id']
					del m['planet_id']
					for k in m.keys():
						if m[k] is not None:
							p['materials'].append({'Name':k,'Percent':m[k]})

			atmospheres = db.select('elite',"select * from atmospheres where planet_id=%s",[p['planetID']],True)
			p['atmoComposition'] = []
			if atmospheres is not None:
				for m in atmospheres:
					del m['id']
					del m['planet_id']
					for k in m.keys():
						if m[k] is not None:
							p['atmoComposition'].append({'Name':k,'Percent':m[k]})

			p['organic'] = []
			if p['bodyId'] in organic:
				#p['organic'] = organic[p['bodyId']]
				for org in organic[p['bodyId']]:
					if org['genusID'] in localname['genusID']:
						org['genus_local'] = localname['genusID'][org['genusID']]
					if org['speciesID'] in localname['speciesID']:
						org['species_local'] = localname['speciesID'][org['speciesID']]

					if True:
						del org['speciesID']
						del org['genusID']
					p['organic'].append(org)
					

			r['planets'].append(p)

	if stars is not None:
		#r['stars'] = stars
		for s in stars:
			s['isScoopable'] = bool(s['isScoopable'])
			s['isPrimary']   = bool(s['isPrimary'])
			s['isMainStar']  = bool(s['isMainStar'])

			s['rings'] = db.select('elite',"select name,type,mass,innerRadius,outerRadius from rings where isStar=1 and planet_id=%s",[s['starID']],True)
			s['belts'] = db.select('elite',"select name,type,mass,innerRadius,outerRadius from belts where isStar=1 and planet_id=%s",[s['starID']],True)

			r['stars'].append(s)

	if codex is not None:
		#r['codex'] = codex
		for c in codex:
			if c['codexnameID'] in localname['codexnameID']:
				c['codexname_local'] = localname['codexnameID'][c['codexnameID']]
			if c['codexcatID'] in localname['codexcatID']:
				c['category_local'] = localname['codexcatID'][c['codexcatID']]
			if c['codexsubcatID'] in localname['codexsubcatID']:
				c['subcategory_local'] = localname['codexsubcatID'][c['codexsubcatID']]

			if True:
				del c['codexnameID']
				del c['codexcatID']
				del c['codexsubcatID']
			r['codex'].append(c)

	if bary is not None:
		r['barycenters'] = bary

	if carrier is not None:
		#r['carriers'] = carrier
		for c in carrier:
			c['isDSSA'] = bool(c['isDSSA'])
			c['isIGAU'] = bool(c['isIGAU'])
			if c['services'] is not None:
				c['services'] = re.sub(r"^,+",'',c['services'])
			r['carriers'].append(c)

	if single is not None:
		print(json.dumps(r,default=json_serial,sort_keys=True))
		sys.exit
	else:
		output.append(r)

if found==0:
	if single is not None:
		print "{}"
	else:
		print "[]"
	sys.exit

print(json.dumps(output,default=json_serial,sort_keys=True))
sys.exit()


###########################################################################


