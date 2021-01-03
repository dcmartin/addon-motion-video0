#!/bin/bash

DIR=${MOTION_APACHE_HTDOCS:-/var/www/localhost/htdocs}/cameras

if [ -d "${DIR}" ]; then
  if [ ! -z "${1:-}" ]; then
    camera=${1}
    if [ ! -z "${2:-}" ]; then
      event=${camera}/${2}
    fi
    if [ -s "${DIR}/${event}" ]; then
      mp4="${DIR}/${event}"
    else
      events=($(find ${DIR}/${camera} -name "${2:-}.json" -print))
      if [ ${#events[@]} -gt 0 ]; then
        event="${events[0]}"
      fi
      if [ -s "${event}" ]; then
        id=($(jq -r '.movie.file' ${event}))
        if [ ${#id[@]} -gt 0 ]; then
          mp4="${id[0]}"
        fi
      fi
    fi
    if [ ! -z "${mp4:-}" ] && [ -s "${mp4:-}" ]; then
      cat ${mp4}
    fi
  fi
fi

