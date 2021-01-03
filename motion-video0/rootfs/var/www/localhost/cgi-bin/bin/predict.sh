#!/bin/bash

exec 0>&- # close stdin 
exec 1>&- # close stdout 
exec 2>&- # close stderr 

temp=$(mktemp).json

answer=${1}; shift
camera=${1}; shift
id=${1}; shift
entity=${1}; shift
results="${1}"; shift

events=$(./bin/events.sh "${camera:-}" "${id:-}")

if [ "${events:-null}" != 'null' ]; then
  DIR=${MOTION_APACHE_HTDOCS:-/var/www/localhost/htdocs}/cameras

  if [ $(echo "${events}" | jq '.events|length') -gt 0 ]; then
    id=$(echo "${events}" | jq -r '.events[0].id')
    event="${DIR}/${camera:-}/${id}.json"
    movie=$(jq -r '.movie.file' "${event}")
    if [ -e "${movie:-}" ]; then
      base64_encoded_file=$(mktemp).json

      echo -n '{"movie":"' > "${base64_encoded_file}"
      base64 -w 0 -i "${movie}" >> "${base64_encoded_file}"
      echo '"}' >> "${base64_encoded_file}"
      jq -c -s add "${event}" "${base64_encoded_file}" > ${temp}
    fi
  fi
fi

mqtt=$(jq '.mqtt' /data/options.json)
host=$(echo "${mqtt}" | jq -r '.host')
port=$(echo "${mqtt}" | jq -r '.port')
username=$(echo "${mqtt}" | jq -r '.username')
password=$(echo "${mqtt}" | jq -r '.password')
group=$(jq -r '.group' /data/options.json)
device=$(jq -r '.device' /data/options.json)

jq -c '.entity="'${entity:-}'"|.results='"$(echo -e ${results//%/\\x} | tr \' \")" ${temp} > ${temp}.$$ && mv -f ${temp}.$$ ${temp}

if [ "${answer:-}" = 'yes' ]; then
  mosquitto_pub -h ${host} -p ${port} -u ${username} -P ${password} -t "${group}/predict/yes" -f ${temp}
elif [ "${answer:-}" = 'no' ]; then
  mosquitto_pub -h ${host} -p ${port} -u ${username} -P ${password} -t "${group}/predict/no" -f ${temp}
fi

rm -f ${temp}
