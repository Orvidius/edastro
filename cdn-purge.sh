#!/bin/bash

echo "CDN Purge URL: $1"
value="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$1")"
#echo "Escaped: $value"

curl --request GET \
     --url "https://api.bunny.net/purge?url=$value&async=false" \
     --header 'AccessKey: 29497007-2480-4481-bf85-299fa4db99872a5eaa63-cfed-4461-b9a3-dc629786e601' \
     --header 'accept: application/json'

echo
