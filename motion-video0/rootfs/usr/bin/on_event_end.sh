#!/bin/bash

source ${USRBIN:-/usr/bin}/motion-tools.sh

###
### functions
###

motion::ffmpeg_mp42gif()
{
  motion.log.debug "${FUNCNAME[0]} ${*}"

  local input="${1:-}"
  local output="${2:-}"
  local fps=${3:-}
  local seconds=${4:-0}
  local width=${5:-}
  local ffmpeg=$(mktemp)

  if [ ${seconds} -gt 0 ] && [ -s "${input}" ] && [ ${fps:-0} -gt 0 ] && [ ${width:-0} -gt 0 ]; then
    ffmpeg -y -t ${seconds} -i "${input}" -t ${seconds} -vf "fps=${fps},scale=${width}:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -loop 0 "${output}" &> ${ffmpeg}
    if [ ! -s "${output}" ]; then
      motion.log.error "${FUNCNAME[0]}: ffmpeg failed: $(cat ${ffmpeg})"
      rm -f "${ffmpeg:-}"
    fi
  else
    motion.log.error "${FUNCNAME[0]}: invalid arguments; input: ${input:-}; FPS: ${fps}; duration: ${seconds}s; width: ${width}; output: ${output}"
  fi
  echo "${output}"
}

function motion::event_animated()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  local result
  local jsonfile="${1:-}"
  local type="${2:-movie}"
  local format="${3:-gif}"
  local id=$(jq -r '.id' ${jsonfile})
  local camera=$(jq -r '.camera' ${jsonfile})
  local elapsed=$(jq -r '.elapsed' ${jsonfile})
  local movie=$(jq -r ".${type}?" ${jsonfile})
  local width=$(jq -r '.cameras[]|select(.name=="'${camera}'").width' $(motion.config.file))

  if [ "${movie:-null}" != 'null' ]; then
    local input=$(echo "${movie}" | jq -r '.file?')
    local fps=$(echo "${movie}" | jq -r '.fps?')

    if [ -s "${input:-}" ]; then
      case ${format} in
        gif)
          if [ ${elapsed:-0} -gt 0 ]; then
            local output=$(motion::ffmpeg_mp42gif "${input}" "${input%/*}/${id}.gif" ${fps:-5} ${elapsed} ${width:-640})

            if [ -s "${output}" ]; then
              result="${output}"
            else
              motion.log.error "${FUNCNAME[0]} type: ${type}; format: ${format}; no output"
            fi
          else
            motion.log.error "${FUNCNAME[0]} type: ${type}; format: ${format}; elapsed: zero (${elapsed})"
          fi
          ;;
        *)
          result=${input}
          ;;
      esac
    else
      motion.log.error "${FUNCNAME[0]} json: ${jsonfile}; movie: ${movie}; input: ${input}; zero-length input"
    fi
  else
    motion.log.error "${FUNCNAME[0]} no ${type} video; metadata: $(jq -c ".${type}?" ${jsonfile})"
  fi
  echo "${result:-null}"
}

motion_event_images_differ()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  local tmpdir=$(mktemp -d)
  local jpegs=(${*})
  local njpeg=${#jpegs[@]}
  local diffs=()
  local fuzz=20
  local most

  local avgdiff=0
  local changed=()
  local avgsize=0
  local maxsize=0
  local biggest=()
  local totaldiff=0
  local totalsize=0
  local ps=()

  if [ ${njpeg} -gt 1 ]; then
    local first=${jpegs[0]}
    local i=1
    local maxdiff=0

    while [ ${i} -lt ${njpeg} ]; do 
      local jpeg=${jpegs[${i}]}
      local file="${jpeg##*/}"
      local diff="${tmpdir}/${file%.*}-mask.jpg"
      local p=$(compare -metric fuzz -fuzz "${fuzz}%" "${jpeg}" "${first}" -compose src -highlight-color white -lowlight-color black "${diff}" 2>&1 | awk '{ print $1 }')

      totaldiff=$((totaldiff+p))
      if [ ${diff} -gt ${maxdiff:-0} ]; then maxdiff=${diff}; most=${jpeg}; fi
      diffs=(${diffs[@]} ${diff})
      i=$((i+1))
    done
    avgdiff=$((totaldiff/njpeg))
  else
    motion.log.warn "${FUNCNAME[0]} Insufficient images to compare"
  fi
  echo "${diffs[@]}"
}

motion_event_images_average()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  local jsonfile="${1}"
  local camera=$(jq -r '.camera' ${jsonfile})
  local jpgs=$(jq -r '.images[].id' ${jsonfile})
  local jpegs=()
  local average="$(mktemp).jpg"
  local result

  for jpg in ${jpgs}; do
    local jpegfile=$(motion.config.target_dir)/${camera}/${jpg}.jpg

    if [ -s ${jpegfile} ]; then
      jpegs=(${jpegs[@]} ${jpegfile})
    else
      motion.log.warn "${FUNCNAME[0]} Cannot find JPEG file: ${jpegfile}"
    fi 
  done

  if [ ${#jpegs[@]} -gt 1 ]; then
    # calculate average from images
    convert ${jpegs} -average ${average} &> /dev/null
    if [ -s "${average}" ]; then
      result="${average}"
    else
      motion.log.error "${FUNCNAME[0]} Failed to calculate average; jpegs: ${jpegs[@]}"
    fi
  elif [ ${#jpegs[@]} -eq 1 ]; then
    ln -s ${jpegs[0]} ${average}
    result="${average}"
  else
    motion.log.error "${FUNCNAME[0]} no images found"
  fi
  echo "${result:-}"
}

motion_event_json()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  local result
  local cn="${1}"
  local ts="${2}"
  local en="${3}"
  local jsonfile
  local dir="$(motion.config.target_dir)/${cn}"
  local name="??????????????-${en}.json"
  local jsons=($(find "$dir" -name "${name}" -print))

  if [ ${#jsons[@]} -gt 0 ]; then
    local njson=${#jsons[@]}

    jsonfile="${jsons[$((njson-1))]}"
  fi

  if [ "${jsonfile:-null}" != 'null' ] && [ -s "${jsonfile:-}" ]; then
    local timezone=$(cat /etc/timezone)
    local end=$(motion.util.dateconv --from-zone ${timezone} -i '%Y%m%d%H%M%S' -f "%s" "$ts")
    local start=$(jq -r '.start' ${jsonfile})
    local elapsed=$((end-start))
    local timestamp=$(date -u +%FT%TZ)

    jq -c '.id="'${ts}-${en}'"|.end='${end}'|.elapsed='${elapsed}'|.timestamp.end="'${timestamp}'"' ${jsonfile} > ${jsonfile}.$$ && mv -f ${jsonfile}.$$ ${jsonfile} && result="${jsonfile}"
    motion.log.debug "${FUNCNAME[0]}; metadata: $(jq -c '.' ${jsonfile})"
  else
    motion.log.warn "${FUNCNAME[0]} no JSON found; directory: ${dir}"
  fi
  echo "${result:-}"
}

# {
#   "device": "nano-1",
#   "camera": "local",
#   "type": "jpeg",
#   "date": 1576600148,
#   "seqno": "01",
#   "event": "01",
#   "id": "20191217162908-01-01",
#   "center": {
#     "x": 281,
#     "y": 124
#   },
#   "width": 158,
#   "height": 180,
#   "size": 23830,
#   "noise": 173
# }

motion_event_images()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  local result
  local jsonfile="${1}"
  local event=$(jq -r '.event' ${jsonfile})
  local camera=$(jq -r '.camera' ${jsonfile})
  local start=$(jq -r '.start' ${jsonfile})
  local end=$(jq -r '.end' ${jsonfile})
  local dir="$(motion.config.target_dir)/${camera}"
  local jpgs=($(find "${dir}" -name "[0-9][0-9]*-${event}-[0-9][0-9]*.jpg" -print | sort))
  local njpg=${#jpgs[@]}

  if [ "${njpg:-0}" -gt 0 ]; then
    local images=''

    i=$((njpg-1)); while [ ${i} -ge 0 ]; do
      local jpg=${jpgs[${i}]}
      local json="${jpg%.*}.json"

      if [ ! -z "${jpg:-}" ] && [ -s "${json}" ]; then
        local image="$(jq -c '.' ${json})"
        local id=$(echo "${image:-null}" | jq -r '.id')
        local this=$(echo "${image:-null}" | jq -r '.date')
        local ago=$((this - start))

        if [ ${ago} -lt 0 ]; then start=${this}; fi
        if [ ${this} -gt ${end} ]; then end=${this}; fi
        # concatenate
        if [ -z "${images:-}" ]; then images="${image}"; else images="${image},${images}"; fi
      else
        motion.log.warn "${FUNCNAME[0]} Missing metadata for image: ${jpeg}"
      fi
      i=$((i-1))
    done

    # complete array iff non-null
    if [ ! -z "${images}" ]; then 
      # update event metadata
      jq -c '.start='${start}'|.end='${end}'|.elapsed='$((end - start))'|.images=['"${images}"']' ${jsonfile} > ${jsonfile}.$$ && mv -f ${jsonfile}.$$ ${jsonfile}
      result=$(jq '.images|length' ${jsonfile})
    else
      motion.log.error "${FUNCNAME[0]} Failed to process images; event: ${event}; camera: ${camera}; found: ${njpgs}"
    fi
  else
    motion.log.error "${FUNCNAME[0]} Unable to find(1) any images; event: ${event}; camera: ${camera}; directory: ${dir}"
  fi

  motion.log.debug "${FUNCNAME[0]}; result: ${result:-null}"
  echo "${result:-0}"
}

motion_event_picture()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  local result
  local jsonfile="${1}"
  local pp=$(motion.config.post_pictures)
  local nimage=$(jq '.images|length' ${jsonfile})

  case "${pp:-null}" in
    first|best)
      result=$(jq -r '.images[0].id' ${jsonfile})
      ;;
    last)
      result=$(jq -r '.images[-1].id' ${jsonfile})
      ;;
    least)
      result=$(jq -r '.images|sort_by(.size)[0].id' ${jsonfile})
      ;;
    most)
      result=$(jq -r '.images|sort_by(.size)[-1].id' ${jsonfile})
      ;;
    center)
      result=$(jq -r '.images['$((nimage/2))'].id' ${jsonfile})
      ;;
    null)
      motion.log.error "${FUNCNAME[0]} Invalid post_picturess: ${pp}"
      ;;
  esac

  if [ "${result:-null}" != 'null' ]; then
    local camera=$(jq -r '.camera' ${jsonfile})

    result=$(motion.config.target_dir)/${camera}/${result}.jpg
  fi
  echo "${result:-}"
}

motion_event_append_picture()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  local result
  local jsonfile="${1}"
  local jpgfile="${2}"
  local b64file=$(mktemp)

  if [ -s "${jpgfile:-}" ]; then
    # initiate B64 file
    echo -n '{"image":"' > "${b64file}"
    # encode selected image
    base64 -w 0 -i "${jpgfile}" >> "${b64file}"
    # close
    echo '"}' >> "${b64file}"

    # add both JSON
    jq -c -s add "${jsonfile}" "${b64file}" > ${jsonfile}.$$ && mv -f ${jsonfile}.$$ ${jsonfile} && rm -f ${b64file}

    if [ -s "${jsonfile}" ] && [ ! -e ${b64file} ]; then
      result='true'
    else
      motion.log.error "${FUNCNAME[0]} failed to create aggregated JSON with base64 encoded JPEG; metadata: $(jq -c '.' ${jsonfile})"
    fi
  else
    motion.log.error "${FUNCNAME[0]} no JPEG file; post_picture: ${pp}; metadata: $(jq -c '.' ${jsonfile})"
  fi

  echo "${result:-null}"
}

motion_publish_event()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  local result
  local jsonfile="${1}"
  local camera=$(jq -r '.camera' ${jsonfile})
  local device=$(jq -r '.device' ${jsonfile})
  local timestamp=$(date -u +%FT%TZ)

  # flatten JSON
  jq -c '.date='$(date -u +%s)'|.timestamp.publish="'${timestamp}'"' ${jsonfile} > ${jsonfile}.$$ && mv -f ${jsonfile}.$$ ${jsonfile}
  if [ -s "${jsonfile}" ]; then
    # publish JSON to MQTT
    motion.mqtt.pub -q 2 -t "$(motion.config.group)/${device}/${camera}/event/end" -f "${jsonfile}" && rm -f ${temp} || result=false
    result='true'
  else
    motion.log.error "${FUNCNAME[0]} failed to flatten and timestamp; metadata: $(jq -c '.image=(.image!=null)' ${jsonfile})"
  fi

  echo "${result:-false}"
}

motion_publish_average()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  local result
  local jsonfile="${1}"
  local jpgfile="${2}"
    local camera=$(jq -r '.camera' ${jsonfile})
    local device=$(jq -r '.device' ${jsonfile})
  local avgfile=$(motion_event_images_average ${jsonfile} ${jpgfile})

  if [ -s "${avgfile}" ]; then
    result="${avgfile}"
    motion.mqtt.pub -q 2 -t "$(motion.config.group)/${device}/${camera}/image-average" -f "${avgfile}" || result=false
  else
    motion.log.error "${FUNCNAME[0]} failed to calculate average image; metadata: $(jq -c '.image=(.image!=null)' ${jsonfile})"
  fi
  echo "${result:-false}"
}

function motion::publish_animated()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  local result
  local jsonfile="${1}"
  local type="${2:-movie}"
  local format="${3:-gif}"
  local camera=$(jq -r '.camera?' ${jsonfile})
  local device=$(jq -r '.device?' ${jsonfile})
  local output=$(motion::event_animated "${jsonfile}" "${type}" "${format}")

  if [ -s "${output}" ]; then
    local movie_t
    local mask_t

    case ${format} in
      gif)
        movie_t="image-animated"
        mask_t="image-animated-mask"
        ;;
      *)
        movie_t="video"
        mask_t="video-mask"
        ;;
    esac

    case ${type} in
      movie)
        motion.mqtt.pub -q 2 -t "$(motion.config.group)/${device}/${camera}/${movie_t}" -f "${output}" || result=false
        ;;
      mask)
        motion.mqtt.pub -q 2 -t "$(motion.config.group)/${device}/${camera}/${mask_t}" -f "${output}" || result=false
        ;;
    esac
    result='true'
  else
    motion.log.error "${FUNCNAME[0]} failed to calculate animated GIF; metadata: $(jq -c '.image=(.image!=null)' ${jsonfile})"
  fi
  echo "${result:-false}"
}

motion_publish_annotated()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  local result
  local jsonfile="${1}"
  local jpgfile="${2}"
    local camera=$(jq -r '.camera' ${jsonfile})
    local device=$(jq -r '.device' ${jsonfile})
  local annfile=$(motion_event_annotated ${jsonfile} ${jpgfile})

  if [ -s "${annfile}" ]; then
    motion.mqtt.pub -q 2 -t "$(motion.config.group)/${device}/${camera}/event/end/" -f "${annfile}" || result=false
    result="${annfile}"
  else
    motion.log.error "${FUNCNAME[0]} failed annotated image; metadata: $(jq -c '.image=(.image!=null)' ${jsonfile})"
  fi
  echo "${result:-false}"
}

motion_publish_composite()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  local result
  echo "${result:-false}"
}

function motion::event_process()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  local result
  local jsonfile="${1}"
  local format="${2:-gif}"
  local jpgfile=$(motion_event_picture ${jsonfile})

  # key frame
  if [ "${jpgfile:-null}" != 'null' ]; then
    local camera=$(jq -r '.camera' ${jsonfile})
    local device=$(jq -r '.device' ${jsonfile})

    # add picture to event JSON
    if [ "${result:-}" != 'false' ] && [ $(motion_event_append_picture ${jsonfile} ${jpgfile}) = 'true' ]; then
      motion.log.debug "${FUNCNAME[0]} picture appended; from: motion_append_picture ${jsonfile}"

      # publish JPEG to MQTT
      motion.mqtt.pub -q 2 -t "$(motion.config.group)/${device}/${camera}/image/end" -f "${jpgfile}" || result=false
      motion.log.debug "${FUNCNAME[0]} published JPEG to MQTT; file: ${jpgfile}"
    else
      motion.log.error "${FUNCNAME[0]} failed append picture; metadata: $(jq -c '.' ${jsonfile})"
      result=false
    fi
  
    # add animated GIF
    if [ "${result:-}" != 'false' ] && [ $(motion::publish_animated "${jsonfile}" "movie" "${format}") != 'true' ]; then
      motion.log.error "${FUNCNAME[0]} format: ${format}; no output returned; from: motion::publish_animated ${jsonfile} movie"
    fi
  
    # add animated mask GIF
    if [ "${result:-}" != 'false' ] && [ $(motion::publish_animated "${jsonfile}" "mask" "${format}") != 'true' ]; then
      motion.log.error "${FUNCNAME[0]} no GIF returned; from: motion::publish_animated ${jsonfile} mask"
    fi

    # publish event JSON 
    if [ "${result:-}" != 'false' ] && [ $(motion_publish_event ${jsonfile}) = 'true' ]; then
      motion.log.debug "${FUNCNAME[0]} published to MQTT; metadata: $(jq -c '.image=(.image!=null)' ${jsonfile})"
      result=true
    else
      motion.log.error "${FUNCNAME[0]} event failed to publish; metadata: $(jq -c '.' ${jsonfile})"
    fi
  else
    motion.log.error "${FUNCNAME[0]} NO KEY FRAME: $(jq -c '.' ${jsonfile})"
    result='false'
  fi
  echo "${result:-false}"
}

motion_event_end()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  local result
  local cn="${1}"
  local en="${2}"
  local yr="${3}"
  local mo="${4}"
  local dy="${5}"
  local hr="${6}"
  local mn="${7}"
  local sc="${8}"

  if [ "${cn:-null}" != 'null' ]; then
    local ts="${yr}${mo}${dy}${hr}${mn}${sc}"
    local jsonfile=$(motion_event_json "${cn}" "${ts}" "${en}")

    if [ "${jsonfile:-null}" != 'null' ]; then
      local njpeg=$(motion_event_images ${jsonfile})

      if [ ${njpeg:-0} -eq 1 ]; then
        if [ $(motion::event_process ${jsonfile} $(motion.config.format)) != 'false' ]; then
          motion.log.info "${FUNCNAME[0]} success: event: ${en}; camera: ${cn}; timestamp: ${ts}; metadata: $(jq '.image=(.image!=null)' ${jsonfile})"
          result='true'
        else
          motion.log.error "${FUNCNAME[0]} failed: event: ${en}; camera: ${cn}; timestamp: ${ts}; metadata: $(jq -c '.image=(.image!=null)' ${jsonfile})"
          result='false'
        fi
      elif [ ${njpeg:-0} -gt 0 ]; then
        motion.log.info "${FUNCNAME[0]} legacy processing: event: ${en}; camera: ${cn}; count: ${njpeg}"

        # process multi-image event with legacy code
        export MOTION_GROUP=$(motion.config.group) \
          MOTION_DEVICE=$(motion.config.device) \
          MOTION_JSON_FILE=$(motion.config.file) \
          MOTION_TARGET_DIR=$(motion.config.target_dir) \
          MOTION_MQTT_HOST=$(echo $(motion.config.mqtt) | jq -r '.host') \
          MOTION_MQTT_PORT=$(echo $(motion.config.mqtt) | jq -r '.port') \
          MOTION_MQTT_USERNAME=$(echo $(motion.config.mqtt) | jq -r '.username') \
          MOTION_MQTT_PASSWORD=$(echo $(motion.config.mqtt) | jq -r '.password') \
          MOTION_LOG_LEVEL=${MOTION_LOG_LEVEL:-debug} \
          MOTION_LOGTO=${MOTION_LOGTO:-/tmp/motion.log} \
          MOTION_FRAME_SELECT='key' \
          && \
          /usr/bin/on_event_end.tcsh ${*} &>> ${MOTION_LOGTO:-/tmp/motion.log}
        result='{"legacy":'$?'}'
        motion.log.debug "${FUNCNAME[0]} legacy result: ${result:-null}"
      else
        motion.log.notice "${FUNCNAME[0]} no images; event: ${en}; camera: ${cn}; timestamp: ${ts}; metadata: $(jq -c '.' ${jsonfile})"
      fi
    else
      motion.log.error "${FUNCNAME[0]} no metadata; event: ${en}; camera: ${cn}; timestamp: ${ts}"
    fi
  else
    motion.log.error "${FUNCNAME[0]} FAILURE: invalid arguments: ${*}"
  fi
  echo "${result:-null}"
}

#
# on_event_end.sh %$ %v %y %m %d %h %m %s
#
# %$ - camera name
# %v - event number. an event is a series of motion detections happening with less than 'gap' seconds between them. 
# %y - the year as a decimal number including the century. 
# %m - the month as a decimal number (range 01 to 12). 
# %d - the day of the month as a decimal number (range 01 to 31).
# %h - the hour as a decimal number using a 24-hour clock (range 00 to 23)
# %m - the minute as a decimal number (range 00 to 59).
# %s - the second as a decimal number (range 00 to 61). 
#

on_event_end()
{
  motion.log.trace "${FUNCNAME[0]} ${*}"

  # close i/o
  # exec 0>&- # close stdin
  # exec 1>&- # close stdout
  # exec 2>&- =''# close stderr

  local interval=$(jq -r '.motion.interval' $(motion.config.file))

  if [ -e ${TMPFS:-/tmp}/${1} ]; then
    motion.log.notice "${FUNCNAME[0]} camera in-process; event: ${*}; skipping"
  else
    touch ${TMPFS:-/tmp}/${1}
    motion.log.info "${FUNCNAME[0]} begin; event: ${*}"

    local result=$(motion_event_end ${*} | jq -c '.')

    motion.log.info "${FUNCNAME[0]} finish; event: ${*}; result: ${result}"
    rm -f ${TMPFS:-/tmp}/${1}
  fi
}

###
### MAIN
###

on_event_end ${*}
