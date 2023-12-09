#!/bin/bash
#curl -X POST -H "Content-Type: application/json" --data-binary @sample-FSSSignalDiscovered.json https://edastro.com/api/journal.test
#curl -X POST -H "Content-Type: application/json" --data-binary @sample-CarrierStats.json https://edastro.com/api/journal.test
curl -X POST -H "Content-Type: application/json" --data-binary @sample-ScanOrganic.json https://edastro.com/api/journal
