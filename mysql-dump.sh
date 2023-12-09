#!/bin/bash
mysqldump -u www -p elite --ignore-table=elite.commanders --ignore-table=elite.logs --ignore-table=elite.projections --ignore-table=elite.regions --ignore-table=elite.regionmap --ignore-table=elite.dates_systems --ignore-table=elite.dates_planets --ignore-table=elite.dates_stars > elite-database.sql
