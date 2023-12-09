#!/bin/bash

find '/DATA/myDocuments/Saved Games/Frontier Developments/Elite Dangerous' -type f -name 'Journal\.*.log' -exec cat {} + >> ~bones/convert/Journal.log
