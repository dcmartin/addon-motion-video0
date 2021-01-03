
DIR=${MOTION_APACHE_HTDOCS:-/var/www/localhost/htdocs}/cameras

if [ -d "${DIR}" ]; then
  if [ ! -z "${1:-}" ]; then
    camera=${1}
    if [ ! -z "${2:-}" ]; then
      event=${camera}/${2}
    fi
    if [ -s "${DIR}/${event}" ]; then
      jpg="${DIR}/${event}"
    else
      events=($(find ${DIR}/${camera} -name "${2:-}.json" -print))  
      if [ ${#events[@]} -gt 0 ]; then
        event="${events[0]}"
      fi
      if [ -s "${event}" ]; then
        id=($(jq -r '.images[].id' ${event}))
        if [ ${#id[@]} -gt 0 ]; then
          jpg="${DIR}/${camera}/${id[0]}.jpg"
        else
          id=($(jq -r '.frames[]' ${event}))
          if [ ${#id[@]} -gt 0 ]; then
            jpg="${DIR}/${camera}/${id[0]}"
          fi
        fi
      fi
    fi
    if [ ! -z "${jpg:-}" ] && [ -s "${jpg:-}" ]; then
      cat ${jpg}
    fi
  fi
fi
