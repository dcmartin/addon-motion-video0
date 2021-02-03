#!/bin/bash

exec 0>&- # close stdin
exec 1>&- # close stdout
exec 2>&- # close stderr

event=$(mktemp).json

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
    cp "${DIR}/${camera:-}/${id}.json" ${event}

    movie=$(jq -r '.movie.file' "${event}")
    if [ -e "${movie:-}" ]; then
      base64_encoded_file=$(mktemp).json

      echo -n '{"movie":"' > "${base64_encoded_file}"
      base64 -w 0 -i "${movie}" >> "${base64_encoded_file}"
      echo '"}' >> "${base64_encoded_file}"
      jq -c -s add "${event}" "${base64_encoded_file}" > ${event}.$$ && mv -f ${event}.$$ ${event}
      rm -f "${base64_encoded_file}"
    fi

    mask=$(jq -r '.mask.file' "${event}")
    if [ -e "${mask:-}" ]; then
      base64_encoded_file=$(mktemp).json

      echo -n '{"mask":"' > "${base64_encoded_file}"
      base64 -w 0 -i "${mask}" >> "${base64_encoded_file}"
      echo '"}' >> "${base64_encoded_file}"
      jq -c -s add "${event}" "${base64_encoded_file}" > ${event}.$$ && mv -f ${event}.$$ ${event}
      rm -f "${base64_encoded_file}"
    fi

  fi
fi

if [ -s "${event:-}" ]; then
  mqtt=$(jq '.mqtt' /data/options.json)
  host=$(echo "${mqtt}" | jq -r '.host')
  port=$(echo "${mqtt}" | jq -r '.port')
  username=$(echo "${mqtt}" | jq -r '.username')
  password=$(echo "${mqtt}" | jq -r '.password')
  group=$(jq -r '.group' /data/options.json)
  device=$(jq -r '.device' /data/options.json)

  jq -c '.entity="'${entity:-}'"|.results='"$(echo -e ${results//%/\\x} | tr \' \")" ${event} > ${event}.$$ && mv -f ${event}.$$ ${event}
  if [ "${answer:-}" = 'yes' ]; then
    mosquitto_pub -h ${host} -p ${port} -u ${username} -P ${password} -t "${group}/predict/yes" -f ${event}
  elif [ "${answer:-}" = 'no' ]; then
    mosquitto_pub -h ${host} -p ${port} -u ${username} -P ${password} -t "${group}/predict/no" -f ${event}
  fi
  rm -f ${event}
fi
