#!/bin/bash

v="$(${0%/*}/motion.status.sh)"
if [ ! -z "${v:-}" ]; then
  echo '{"timestamp":"'$(date -u +%FT%TZ)'","status":'"${v:-null}"'}'
else
  echo '{"timestamp":"'$(date -u +%FT%TZ)'","error":"no status"}'
fi
