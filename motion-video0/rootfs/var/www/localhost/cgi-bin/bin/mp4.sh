#!/bin/bash

DIR=${MOTION_APACHE_HTDOCS:-/var/www/localhost/htdocs}/cameras

if [ -d "${DIR}" ]; then
  if [ ! -z "${1:-}" ]; then
    camera=${1:-*}
    event=($(find "${DIR}/${camera}/" -name "*-${2}.json" -print))
    if [ ${#event[@]} -gt 0 ]; then
      event="${event[0]}"
      if [ -s "${event}" ]; then
      id=($(jq -r '.movie.file' ${event}))
      if [ ${#id[@]} -gt 0 ]; then
        mp4="${DIR}/${camera}/${id[0]##*/}"
        if [ -s ${mp4} ]; then
          cat ${mp4}
        fi
      fi
    fi
  fi
fi
