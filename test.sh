#!/bin/env bash

file="$1"
basename=$(basename "$file")
extension="${basename##*.}"
curl -s http://0.0.0.0:9090/api/v1/ligo/originate/ -H 'Content-Type: application/json' -d "{\"source\": \"$(cat "$file"| sed -e 's/"/\\"/g')\", \"lang\": \"$extension\"}" | jq
