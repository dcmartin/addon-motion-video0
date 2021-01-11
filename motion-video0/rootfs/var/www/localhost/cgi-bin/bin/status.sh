#!/bin/bash

echo '{"timestamp":"'$(date -u +%FT%TZ)'","status":'"$(${0%/*}/motion.status.sh)"'}'
