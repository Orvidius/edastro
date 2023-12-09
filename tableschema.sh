#!/bin/bash
mysqldump -h banshee -u www -p elite --no-data --skip-add-drop-table > tableschema.txt
