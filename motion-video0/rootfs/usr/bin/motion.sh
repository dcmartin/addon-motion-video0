#!/usr/bin/with-contenv bashio

## initiate logging
export MOTION_LOG_LEVEL="${1:-debug}"
export MOTION_LOGTO=${MOTION_LOGTO:-/tmp/motion.log}

source ${USRBIN:-/usr/bin}/motion-tools.sh

###
### PRE-FLIGHT
###

## motion command
MOTION_CMD=$(command -v motion)
if [ ! -s "${MOTION_CMD}" ]; then
  bashio::log.error "Motion not installed; command: ${MOTION_CMD}"
  exit 1
fi

bashio::log.notice "Reseting configuration to default: ${MOTION_CONF}"
cp -f ${MOTION_CONF%%.*}.default ${MOTION_CONF}

## defaults
if [ -z "${MOTION_CONTROL_PORT:-}" ]; then MOTION_CONTROL_PORT=8080; fi
if [ -z "${MOTION_STREAM_PORT:-}" ]; then MOTION_STREAM_PORT=8090; fi


## apache
if [ ! -s "${MOTION_APACHE_CONF}" ]; then
  bashio::log.error "Missing Apache configuration"
  exit 1
fi
if [ -z "${MOTION_APACHE_HOST:-}" ]; then
  bashio::log.error "Missing Apache ServerName"
  exit 1
fi
if [ -z "${MOTION_APACHE_HOST:-}" ]; then
  bashio::log.error "Missing Apache ServerAdmin"
  exit 1
fi
if [ -z "${MOTION_APACHE_HTDOCS:-}" ]; then
  bashio::log.error "Missing Apache HTML documents directory"
  exit 1
fi


###
## FUNCTIONS
###

## start the apache server in FOREGROUND (does not exit)
start_apache_foreground()
{
  start_apache true ${*}
}

start_apache_background()
{
  start_apache false ${*}
}

start_apache()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local foreground=${1}; shift

  local conf=${1}
  local host=${2}
  local port=${3}
  local admin="${4:-root@${host}}"
  local tokens="${5:-}"
  local signature="${6:-}"

  # edit defaults
  sed -i 's|^Listen .*|Listen '${port}'|' "${conf}"
  sed -i 's|^ServerName .*|ServerName '"${host}:${port}"'|' "${conf}"
  sed -i 's|^ServerAdmin .*|ServerAdmin '"${admin}"'|' "${conf}"

  # SSL
  if [ ! -z "${tokens:-}" ]; then
    sed -i 's|^ServerTokens.*|ServerTokens '"${tokens}"'|' "${conf}"
  fi
  if [ ! -z "${signature:-}" ]; then
    sed -i 's|^ServerSignature.*|ServerSignature '"${signature}"'|' "${conf}"
  fi

  # enable CGI
  sed -i 's|^\([^#]\)#LoadModule cgi|\1LoadModule cgi|' "${conf}"

  # export environment
  export MOTION_JSON_FILE=$(motion.config.file)
  export MOTION_SHARE_DIR=$(motion.config.share_dir)

  # pass environment
  echo 'PassEnv MOTION_JSON_FILE' >> "${conf}"
  echo 'PassEnv MOTION_SHARE_DIR' >> "${conf}"

  # make /run/apache2 for PID file
  mkdir -p /run/apache2

  # start HTTP daemon
  bashio::log.info "Starting Apache: ${conf} ${host} ${port}"

  if [ "${foreground:-false}" = 'true' ]; then
    MOTION_JSON_FILE=$(motion.config.file) httpd -E ${MOTION_LOGTO} -e debug -f "${MOTION_APACHE_CONF}" -DFOREGROUND
  else
    MOTION_JSON_FILE=$(motion.config.file) httpd -E ${MOTION_LOGTO} -e debug -f "${MOTION_APACHE_CONF}"
  fi
}

process_config_camera_ftpd()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

process_config_camera_mjpeg()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

process_config_camera_http()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

process_config_camera_v4l2()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json='null'
  local value
  
  # set v4l2_pallette
  value=$(echo "${config:-null}" | jq -r ".v4l2_pallette")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=17; fi
  json=$(echo "${json}" | jq '.v4l2_palette='${value})
  sed -i "s/^v4l2_palette\s[0-9]\+/v4l2_palette ${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"v4l2_palette":'"${value}"
  bashio::log.debug "Set v4l2_palette to ${value}"
  
  # set brightness
  value=$(echo "${config:-null}" | jq -r ".v4l2_brightness")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/brightness=[0-9]\+/brightness=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"brightness":'"${value}"
  bashio::log.debug "Set brightness to ${value}"
  
  # set contrast
  value=$(jq -r ".v4l2_contrast" "${CONFIG_PATH}")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/contrast=[0-9]\+/contrast=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"contrast":'"${value}"
  bashio::log.debug "Set contrast to ${value}"
  
  # set saturation
  value=$(jq -r ".v4l2_saturation" "${CONFIG_PATH}")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/saturation=[0-9]\+/saturation=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"saturation":'"${value}"
  bashio::log.debug "Set saturation to ${value}"
  
  # set hue
  value=$(jq -r ".v4l2_hue" "${CONFIG_PATH}")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/hue=[0-9]\+/hue=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"hue":'"${value}"
  bashio::log.debug "Set hue to ${value}"

  echo "${json:-null}"
}

## cameras
process_config_cameras()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

## defaults
process_config_defaults()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

## mqtt
process_config_mqtt()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local result=
  local value
  local json

  # local json server (hassio addon)
  value=$(echo "${config}" | jq -r ".host")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value="core-mosquitto"; fi
  bashio::log.debug "Using MQTT host: ${value}"
  json='{"host":"'"${value}"'"'

  # username
  value=$(echo "${config}" | jq -r ".username")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=""; fi
  bashio::log.debug "Using MQTT username: ${value}"
  json="${json}"',"username":"'"${value}"'"'

  # password
  value=$(echo "${config}" | jq -r ".password")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=""; fi
  bashio::log.debug "Using MQTT password: ${value}"
  json="${json}"',"password":"'"${value}"'"'

  # port
  value=$(echo "${config}" | jq -r ".port")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=1883; fi
  bashio::log.debug "Using MQTT port: ${value}"
  json="${json}"',"port":'"${value}"'}'

  echo "${json:-null}"
}

## process configuration 
process_config_system()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local timestamp=$(date -u +%FT%TZ)
  local ipaddr=$(ip addr | egrep -A4 UP | egrep 'inet ' | egrep -v 'scope host lo' | egrep -v 'scope global docker' | awk '{ print $2 }')
  local json='{"ipaddr":"'${ipaddr%%/*}'","hostname":"'$(hostname)'","arch":"'$(arch)'","date":'$(date -u +%s)',"timestamp":"'${timestamp}'"}'

  echo "${json:-null}"
}

## process configuration 
process_config_motion()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local path=${1}
  local json

  json=$(echo "${json:-null}" | jq '.+='$(process_config_system ${path}))
  json=$(echo "${json:-null}" | jq '.+='$(process_config_mqtt ${path}))
  json=$(echo "${json:-null}" | jq '.+='$(process_config_defaults ${path}))
  json=$(echo "${json:-null}" | jq '.+='$(process_config_cameras ${path}))

  echo "${json:-null}"
}

start_motion()
{
  bashio::log.debug "${FUNCNAME[0]}" "${*}"

  local path=${1}
  local json

  json=$(process_config_motion ${path})
  
  echo "${json:-null}"
}

###
### START
###

## get IP address
ipaddr=$(ip addr | egrep -A4 UP | egrep 'inet ' | egrep -v 'scope host lo' | egrep -v 'scope global docker' | awk '{ print $2 }')
ipaddr=${ipaddr%%/*}

## add-on API
ADDON_API="http://${ipaddr}:${MOTION_APACHE_PORT}"

## build internal configuration
JSON='{"config_path":"'"${CONFIG_PATH}"'","ipaddr":"'${ipaddr}'","hostname":"'"$(hostname)"'","arch":"'$(arch)'","date":'$(date -u +%s)

# device name
VALUE=$(jq -r ".device" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then 
  VALUE="$(hostname -s)"
  bashio::log.warn "device unspecifieid; setting device: ${VALUE}"
fi
JSON="${JSON}"',"device":"'"${VALUE}"'"'
bashio::log.info "MOTION_DEVICE: ${VALUE}"
MOTION_DEVICE="${VALUE}"

# device group
VALUE=$(jq -r ".group" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then 
  VALUE="motion"
  bashio::log.warn "group unspecifieid; setting group: ${VALUE}"
fi
JSON="${JSON}"',"group":"'"${VALUE}"'"'
bashio::log.info "MOTION_GROUP: ${VALUE}"
MOTION_GROUP="${VALUE}"

# client
VALUE=$(jq -r ".client" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then 
  VALUE="+"
  bashio::log.warn "client unspecifieid; setting client: ${VALUE}"
fi
JSON="${JSON}"',"client":"'"${VALUE}"'"'
bashio::log.info "MOTION_CLIENT: ${VALUE}"
MOTION_CLIENT="${VALUE}"

## time zone
VALUE=$(jq -r ".timezone" "${CONFIG_PATH}")
# Set the correct timezone
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then 
  VALUE="GMT"
  bashio::log.warn "timezone unspecified; defaulting to ${VALUE}"
else
  bashio::log.info "TIMEZONE: ${VALUE}"
fi
if [ -s "/usr/share/zoneinfo/${VALUE}" ]; then
  cp /usr/share/zoneinfo/${VALUE} /etc/localtime
  echo "${VALUE}" > /etc/timezone
else
  bashio::log.error "No known timezone: ${VALUE}"
fi
JSON="${JSON}"',"timezone":"'"${VALUE}"'"'

# set unit_system for events
VALUE=$(jq -r '.unit_system' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="imperial"; fi
bashio::log.info "Set unit_system to ${VALUE}"
JSON="${JSON}"',"unit_system":"'"${VALUE}"'"'

# set latitude for events
VALUE=$(jq -r '.latitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
bashio::log.info "Set latitude to ${VALUE}"
JSON="${JSON}"',"latitude":'"${VALUE}"

# set longitude for events
VALUE=$(jq -r '.longitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
bashio::log.info "Set longitude to ${VALUE}"
JSON="${JSON}"',"longitude":'"${VALUE}"

# set elevation for events
VALUE=$(jq -r '.elevation' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
bashio::log.info "Set elevation to ${VALUE}"
JSON="${JSON}"',"elevation":'"${VALUE}"

##
## MQTT
##

# local MQTT server (hassio addon)
VALUE=$(jq -r ".mqtt.host" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="mqtt"; fi
bashio::log.info "Using MQTT at ${VALUE}"
MQTT='{"host":"'"${VALUE}"'"'
# username
VALUE=$(jq -r ".mqtt.username" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
bashio::log.info "Using MQTT username: ${VALUE}"
MQTT="${MQTT}"',"username":"'"${VALUE}"'"'
# password
VALUE=$(jq -r ".mqtt.password" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
bashio::log.info "Using MQTT password: ${VALUE}"
MQTT="${MQTT}"',"password":"'"${VALUE}"'"'
# port
VALUE=$(jq -r ".mqtt.port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1883; fi
bashio::log.info "Using MQTT port: ${VALUE}"
MQTT="${MQTT}"',"port":'"${VALUE}"'}'

## finish
JSON="${JSON}"',"mqtt":'"${MQTT}"

###
## WATSON
###

if [ -n "${WATSON:-}" ]; then
  JSON="${JSON}"',"watson":'"${WATSON}"
else
  bashio::log.debug "Watson Visual Recognition not specified"
  JSON="${JSON}"',"watson":null'
fi

###
## DIGITS
###

if [ -n "${DIGITS:-}" ]; then
  JSON="${JSON}"',"digits":'"${DIGITS}"
else
  bashio::log.debug "DIGITS not specified"
  JSON="${JSON}"',"digits":null'
fi

###
### MOTION
###

bashio::log.debug "+++ MOTION"

MOTION='{'

# set log_type (FIRST ENTRY)
VALUE=$(jq -r ".log_motion_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="ALL"; fi
sed -i "s|^log_type .*|log_type ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"'"log_type":"'"${VALUE}"'"'
bashio::log.debug "Set motion.log_type to ${VALUE}"

# set log_level
VALUE=$(jq -r ".log_motion_level" "${CONFIG_PATH}")
case ${VALUE} in
  emergency)
    VALUE=1
    ;;
  alert)
    VALUE=2
    ;;
  critical)
    VALUE=3
    ;;
  error)
    VALUE=4
    ;;
  warn)
    VALUE=5
    ;;
  info)
    VALUE=7
    ;;
  debug)
    VALUE=8
    ;;
  all)
    VALUE=9
    ;;
  *|notice)
    VALUE=6
    ;;
esac
sed -i "s/^log_level .*/log_level ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_level":'"${VALUE}"
bashio::log.debug "Set motion.log_level to ${VALUE}"

# set log_file
VALUE=$(jq -r ".log_file" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/tmp/motion.log"; fi
sed -i "s|^log_file .*|log_file ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_file":"'"${VALUE}"'"'
bashio::log.debug "Set log_file to ${VALUE}"
export MOTION_LOGTO=${VALUE}

# shared directory for results (not images and JSON)
VALUE=$(jq -r ".share_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/share/${MOTION_GROUP}"; fi
bashio::log.debug "Set share_dir to ${VALUE}"
JSON="${JSON}"',"share_dir":"'"${VALUE}"'"'
export MOTION_SHARE_DIR="${VALUE}"

# base target_dir
VALUE=$(jq -r ".default.target_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${MOTION_APACHE_HTDOCS}/cameras"; fi
bashio::log.debug "Set target_dir to ${VALUE}"
sed -i "s|^target_dir .*|target_dir ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"',"target_dir":"'"${VALUE}"'"'
export MOTION_TARGET_DIR="${VALUE}"

# set auto_brightness
VALUE=$(jq -r ".default.auto_brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/^auto_brightness .*/auto_brightness ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"auto_brightness":"'"${VALUE}"'"'
bashio::log.debug "Set auto_brightness to ${VALUE}"

# set locate_motion_mode
VALUE=$(jq -r ".default.locate_motion_mode" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="off"; fi
sed -i "s/^locate_motion_mode .*/locate_motion_mode ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_mode":"'"${VALUE}"'"'
bashio::log.debug "Set locate_motion_mode to ${VALUE}"

# set locate_motion_style (box, redbox, cross, redcross)
VALUE=$(jq -r ".default.locate_motion_style" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="box"; fi
sed -i "s/^locate_motion_style .*/locate_motion_style ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_style":"'"${VALUE}"'"'
bashio::log.debug "Set locate_motion_style to ${VALUE}"

# set post_pictures; enumerated [on,center,first,last,best,most]
VALUE=$(jq -r '.default.post_pictures' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="center"; fi
bashio::log.debug "Set post_pictures to ${VALUE}"
MOTION="${MOTION}"',"post_pictures":"'"${VALUE}"'"'
export MOTION_POST_PICTURES="${VALUE}"

# set picture_output (on, off, first, best)
case "${MOTION_POST_PICTURES}" in
  'on'|'center'|'most')
    SPEC="on"
    bashio::log.debug "process all images; picture_output: ${SPEC}"
  ;;
  'best'|'first')
    SPEC="${MOTION_POST_PICTURES}"
    bashio::log.debug "process one image; picture_output: ${SPEC}"
  ;;
  'off')
    SPEC="off"
    bashio::log.debug "process no image; picture_output: ${SPEC}"
  ;;
esac

# check specified for over-ride
VALUE=$(jq -r ".default.picture_output" "${CONFIG_PATH}")
if [ "${VALUE:-}" != 'null' ] && [ ! -z "${VALUE:-}" ]; then
  if [ "${VALUE}" != "${SPEC}" ]; then
    bashio::log.notice "picture_output; specified ${VALUE} does not match expected: ${SPEC}"
  else
    bashio::log.debug "picture_output; specified ${VALUE} matches expected: ${SPEC}"
  fi
else
  VALUE="${SPEC}"
  bashio::log.debug "picture_output; unspecified; using: ${VALUE}"
fi
sed -i "s/^picture_output .*/picture_output ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_output":"'"${VALUE}"'"'
bashio::log.info "Set picture_output to ${VALUE}"
PICTURE_OUTPUT=${VALUE}

# set movie_output (on, off)
if [ "${PICTURE_OUTPUT:-}" = 'best' ] || [ "${PICTURE_OUTPUT:-}" = 'first' ]; then
  bashio::log.notice "Picture output: ${PICTURE_OUTPUT}; setting movie_output: on"
  VALUE='on'
else
  VALUE=$(jq -r '.default.movie_output' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then 
    bashio::log.debug "movie_output unspecified; defaulting: off"
    VALUE="off"
  else
    case ${VALUE} in
      '3gp')
        bashio::log.notice "movie_output: video type ${VALUE}; ensure camera type: ftpd"
        MOTION_VIDEO_CODEC="${VALUE}"
        VALUE='off'
      ;;
      'on'|'mp4')
        bashio::log.debug "movie_output: supported codec: ${VALUE}; - MPEG-4 Part 14 H264 encoding"
        MOTION_VIDEO_CODEC="${VALUE}"
        VALUE='on'
      ;;
      'mpeg4'|'swf'|'flv'|'ffv1'|'mov'|'mkv'|'hevc')
        bashio::log.warn "movie_output: unsupported option: ${VALUE}"
        MOTION_VIDEO_CODEC="${VALUE}"
        VALUE='on'
      ;;
      'off')
        bashio::log.debug "movie_output: off defined"
        MOTION_VIDEO_CODEC=
        VALUE='off'
      ;;
      '*')
        bashio::log.error "movie_output: unknown option for movie_output: ${VALUE}"
        MOTION_VIDEO_CODEC=
        VALUE='off'
      ;;
    esac
  fi
fi
sed -i "s/^movie_output .*/movie_output ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"movie_output":"'"${VALUE}"'"'
bashio::log.info "Set movie_output to ${VALUE}"
if [ "${VALUE:-null}" != 'null' ]; then
  sed -i "s/^movie_output_motion .*/movie_output_motion ${VALUE}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"movie_output_motion":"'"${VALUE}"'"'
  bashio::log.info "Set movie_output_motion to ${VALUE}"
fi

# set picture_type (jpeg, ppm)
VALUE=$(jq -r ".default.picture_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="jpeg"; fi
sed -i "s/^picture_type .*/picture_type ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_type":"'"${VALUE}"'"'
bashio::log.debug "Set picture_type to ${VALUE}"

# set netcam_keepalive (off,force,on)
VALUE=$(jq -r ".default.netcam_keepalive" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/^netcam_keepalive .*/netcam_keepalive ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"netcam_keepalive":"'"${VALUE}"'"'
bashio::log.debug "Set netcam_keepalive to ${VALUE}"

# set netcam_userpass 
VALUE=$(jq -r ".default.netcam_userpass" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
sed -i "s/^netcam_userpass .*/netcam_userpass ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"netcam_userpass":"'"${VALUE}"'"'
bashio::log.debug "Set netcam_userpass to ${VALUE}"

## numeric values

# set v4l2_palette
VALUE=$(jq -r ".default.palette" "${CONFIG_PATH}")
if [ "${VALUE:-}" = "null" ]; then VALUE=17; fi
sed -i "s/^v4l2_palette .*/v4l2_palette ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"palette":'"${VALUE}"
bashio::log.debug "Set palette to ${VALUE}"

# set pre_capture
VALUE=$(jq -r ".default.pre_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/^pre_capture .*/pre_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"pre_capture":'"${VALUE}"
bashio::log.debug "Set pre_capture to ${VALUE}"

# set post_capture
VALUE=$(jq -r ".default.post_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/^post_capture .*/post_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"post_capture":'"${VALUE}"
bashio::log.debug "Set post_capture to ${VALUE}"

# set event_gap
VALUE=$(jq -r ".default.event_gap" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=5; fi
sed -i "s/^event_gap .*/event_gap ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"event_gap":'"${VALUE}"
bashio::log.debug "Set event_gap to ${VALUE}"

# set fov
VALUE=$(jq -r ".default.fov" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=60; fi
MOTION="${MOTION}"',"fov":'"${VALUE}"
bashio::log.debug "Set fov to ${VALUE}"

# set minimum_motion_frames
VALUE=$(jq -r ".default.minimum_motion_frames" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1; fi
sed -i "s/^minimum_motion_frames .*/minimum_motion_frames ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"minimum_motion_frames":'"${VALUE}"
bashio::log.debug "Set minimum_motion_frames to ${VALUE}"

# set quality
VALUE=$(jq -r ".default.picture_quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=100; fi
sed -i "s/^picture_quality .*/picture_quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_quality":'"${VALUE}"
bashio::log.debug "Set picture_quality to ${VALUE}"

# set framerate
VALUE=$(jq -r ".default.framerate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=5; fi
sed -i "s/^framerate .*/framerate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"framerate":'"${VALUE}"
bashio::log.debug "Set framerate to ${VALUE}"
FRAMERATE=${VALUE}

# set stream_maxrate
VALUE=$(jq -r ".default.stream_maxrate" "${CONFIG_PATH}")
if [ "${VALUE:-null}" = "null" ] || [ ${VALUE} -eq 0 ]; then VALUE=${FRAMERATE}; fi
bashio::log.debug "Set stream_maxrate to ${VALUE}"
sed -i "s/^stream_maxrate .*/stream_maxrate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_maxrate":'"${VALUE}"

# set stream_motion
VALUE=$(jq -r ".default.stream_motion" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE='on'; fi
sed -i "s/^stream_motion .*/stream_motion ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_motion":"'"${VALUE}"'"'
bashio::log.debug "Set stream_motion to ${VALUE}"

# set text_changes
VALUE=$(jq -r ".default.changes" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE='off'; fi
sed -i "s/^text_changes .*/text_changes ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"changes":"'"${VALUE}"'"'
bashio::log.debug "Set text_changes to ${VALUE}"

# set text_scale
VALUE=$(jq -r ".default.text_scale" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1; fi
sed -i "s/^text_scale .*/text_scale ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"text_scale":'"${VALUE}"
bashio::log.debug "Set text_scale to ${VALUE}"

# set despeckle_filter
VALUE=$(jq -r ".default.despeckle" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE='EedDl'; fi
sed -i "s/^despeckle_filter .*/despeckle_filter ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"despeckle_filter":"'"${VALUE}"'"'
bashio::log.debug "Set despeckle_filter to ${VALUE}"

## vid_control_params

## ps3eye 
# ---------Controls---------
#   V4L2 ID   Name and Range
# ID09963776 Brightness, 0 to 255
# ID09963777 Contrast, 0 to 255
# ID09963778 Saturation, 0 to 255
# ID09963779 Hue, -90 to 90
# ID09963788 White Balance, Automatic, 0 to 1
# ID09963793 Exposure, 0 to 255
# ID09963794 Gain, Automatic, 0 to 1
# ID09963795 Gain, 0 to 63
# ID09963796 Horizontal Flip, 0 to 1
# ID09963797 Vertical Flip, 0 to 1
# ID09963800 Power Line Frequency, 0 to 1
#   menu item: Value 0 Disabled
#   menu item: Value 1 50 Hz
# ID09963803 Sharpness, 0 to 63
# ID10094849 Auto Exposure, 0 to 1
#   menu item: Value 0 Auto Mode
#   menu item: Value 1 Manual Mode
# --------------------------

# set brightness
VALUE=$(jq -r ".default.brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/brightness=[0-9]\+/brightness=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"brightness":'"${VALUE}"
bashio::log.debug "Set brightness to ${VALUE}"

# set contrast
VALUE=$(jq -r ".default.contrast" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/contrast=[0-9]\+/contrast=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"contrast":'"${VALUE}"
bashio::log.debug "Set contrast to ${VALUE}"

# set saturation
VALUE=$(jq -r ".default.saturation" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/saturation=[0-9]\+/saturation=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"saturation":'"${VALUE}"
bashio::log.debug "Set saturation to ${VALUE}"

# set hue
VALUE=$(jq -r ".default.hue" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/hue=[0-9]\+/hue=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"hue":'"${VALUE}"
bashio::log.debug "Set hue to ${VALUE}"

## other

# set rotate
VALUE=$(jq -r ".default.rotate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
bashio::log.debug "Set rotate to ${VALUE}"
sed -i "s/^rotate .*/rotate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"rotate":'"${VALUE}"

# set webcontrol_parms
VALUE=$(jq -r ".default.webcontrol_parms" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1; fi
bashio::log.debug "Set webcontrol_parms to ${VALUE}"
sed -i "s/^webcontrol_parms .*/webcontrol_parms ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"webcontrol_parms":'"${VALUE}"

# set webcontrol_port
VALUE=$(jq -r ".default.webcontrol_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_CONTROL_PORT}; fi
bashio::log.debug "Set webcontrol_port to ${VALUE}"
sed -i "s/^webcontrol_port .*/webcontrol_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"webcontrol_port":'"${VALUE}"

# set stream_port
VALUE=$(jq -r ".default.stream_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_STREAM_PORT}; fi
bashio::log.debug "Set stream_port to ${VALUE}"
sed -i "s/^stream_port .*/stream_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_port":'"${VALUE}"
MOTION_STREAM_PORT=${VALUE}

# set stream_quality
VALUE=$(jq -r ".default.stream_quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=100; fi
bashio::log.debug "Set stream_quality to ${VALUE}"
sed -i "s/^stream_quality .*/stream_quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_quality":'"${VALUE}"

# set width
VALUE=$(jq -r ".default.width" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=640; fi
sed -i "s/^width .*/width ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"width":'"${VALUE}"
WIDTH=${VALUE}
bashio::log.debug "Set width to ${VALUE}"

# set height
VALUE=$(jq -r ".default.height" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=480; fi
sed -i "s/^height .*/height ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"height":'"${VALUE}"
HEIGHT=${VALUE}
bashio::log.debug "Set height to ${VALUE}"

## THRESHOLD

VALUE=$(jq -r ".default.threshold" "${CONFIG_PATH}")
if [ "${VALUE:-null}" = 'null' ] || [ ${VALUE:-0} -le 0 ]; then 
  VALUE=$(jq -r ".default.threshold_percent" "${CONFIG_PATH}")
  if [ "${VALUE:-null}" != 'null' ] && [ ${VALUE:-0} -gt 0 ]; then 
    PCT=${VALUE}
    VALUE=$(echo "${PCT} * ( ${WIDTH} * ${HEIGHT} ) / 100.0" | bc -l) && VALUE=${VALUE%%.*}
  fi
fi
if [ "${PCT:-null}" = 'null' ]; then 
  PCT=$(echo "${VALUE} / ( ${WIDTH} * ${HEIGHT} ) * 100.0" | bc -l) && PCT=${PCT%%.*}
  PCT=${PCT:-null}
fi

bashio::log.debug "Set threshold_percent to ${PCT}"
MOTION="${MOTION}"',"threshold_percent":'"${PCT}"
bashio::log.debug "Set threshold to ${VALUE}"
sed -i "s/^threshold .*/threshold ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold":'"${VALUE:-null}"

# set threshold_maximum
VALUE=$(jq -r ".default.threshold_maximum" "${CONFIG_PATH}")
if [ "${VALUE:-null}" = "null" ]; then VALUE=0; fi
bashio::log.debug "Set threshold_maximum to ${VALUE}"
sed -i "s/^threshold_maximum .*/threshold_maximum ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold_maximum":'"${VALUE:-0}"

# set threshold_tune (on/off)
VALUE=$(jq -r ".default.threshold_tune" "${CONFIG_PATH}")
if [ "${VALUE:-null}" = 'null' ]; then VALUE='off'; fi
bashio::log.debug "Set threshold_tune to ${VALUE}"
sed -i "s/^threshold_tune .*/threshold_tune ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold_tune":"'"${VALUE}"'"'

# set lightswitch percent
VALUE=$(jq -r ".default.lightswitch_percent" "${CONFIG_PATH}")
if [ "${VALUE:-null}" = "null" ]; then VALUE=0; fi
bashio::log.debug "Set lightswitch percent to ${VALUE}"
sed -i "s/^lightswitch_percent .*/lightswitch_percent ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"lightswitch_percent":'"${VALUE:-null}"

# set lightswitch frames
VALUE=$(jq -r ".default.lightswitch_frames" "${CONFIG_PATH}")
if [ "${VALUE:-null}" = "null" ]; then VALUE=5; fi
bashio::log.debug "Set lightswitch frames to ${VALUE}"
sed -i "s/^lightswitch_frames .*/lightswitch_frames ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"lightswitch_frames":'"${VALUE}"

# set movie_max_time
VALUE=$(jq -r ".default.movie_max_time" "${CONFIG_PATH}")
if [ "${VALUE:-null}" = "null" ]; then VALUE="30"; fi
bashio::log.debug "Set movie_max_time to ${VALUE}"
sed -i "s/^movie_max_time .*/movie_max_time ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"movie_max_time":'"${VALUE:-30}"

# set interval for events
VALUE=$(jq -r '.default.interval' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=3600; fi
bashio::log.debug "Set watchdog interval to ${VALUE}"
MOTION="${MOTION}"',"interval":'${VALUE}
# used in MAIN
MOTION_WATCHDOG_INTERVAL=${VALUE}

# set type
VALUE=$(jq -r '.default.type' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="netcam"; fi
bashio::log.debug "Set type to ${VALUE}"
MOTION="${MOTION}"',"type":"'"${VALUE}"'"'

## ALL CAMERAS SHARE THE SAME USERNAME:PASSWORD CREDENTIALS

# set username and password
USERNAME=$(jq -r ".default.username" "${CONFIG_PATH}")
PASSWORD=$(jq -r ".default.password" "${CONFIG_PATH}")
if [ "${USERNAME}" != "null" ] && [ "${PASSWORD}" != "null" ] && [ ! -z "${USERNAME}" ] && [ ! -z "${PASSWORD}" ]; then
  bashio::log.debug "Set authentication to Basic for both stream and webcontrol"
  sed -i "s/^stream_auth_method .*/stream_auth_method 1/" "${MOTION_CONF}"
  sed -i "s/^stream_authentication .*/stream_authentication ${USERNAME}:${PASSWORD}/" "${MOTION_CONF}"
  sed -i "s/^webcontrol_authentication .*/webcontrol_authentication ${USERNAME}:${PASSWORD}/" "${MOTION_CONF}"
  bashio::log.debug "Enable access for any host"
  sed -i "s/^stream_localhost .*/stream_localhost off/" "${MOTION_CONF}"
  sed -i "s/^webcontrol_localhost .*/webcontrol_localhost off/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"stream_auth_method":"Basic"'
else
  bashio::log.debug "WARNING: no username and password; stream and webcontrol limited to localhost only"
  sed -i "s/^stream_localhost .*/stream_localhost on/" "${MOTION_CONF}"
  sed -i "s/^webcontrol_localhost .*/webcontrol_localhost on/" "${MOTION_CONF}"
fi

# add username and password to configuration
MOTION="${MOTION}"',"username":"'"${USERNAME}"'"'
MOTION="${MOTION}"',"password":"'"${PASSWORD}"'"'

## end motion structure; cameras section depends on well-formed JSON for $MOTION
MOTION="${MOTION}"'}'

## append to configuration JSON
JSON="${JSON}"',"motion":'"${MOTION}"

bashio::log.debug "MOTION: ${MOTION}"

###
### process cameras 
###

ncamera=$(jq '.cameras|length' "${CONFIG_PATH}")

MOTION_COUNT=0
CNUM=0

##
## LOOP THROUGH ALL CAMERAS
##

for (( i=0; i < ncamera; i++)); do

  bashio::log.debug "+++ CAMERA ${i}"

  ## TOP-LEVEL
  if [ -z "${CAMERAS:-}" ]; then CAMERAS='['; else CAMERAS="${CAMERAS}"','; fi
  bashio::log.debug "CAMERA #: $i"
  CAMERAS="${CAMERAS}"'{"id":'${i}

  # process camera type
  VALUE=$(jq -r '.cameras['${i}'].type' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    VALUE=$(jq -r '.default.type' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="netcam"; fi
  fi
  CAMERA_TYPE="${VALUE}"
  bashio::log.debug "Set type to ${VALUE}"
  CAMERAS="${CAMERAS}"',"type":"'"${VALUE}"'"'

  # name
  VALUE=$(jq -r '.cameras['${i}'].name' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="camera-name${i}"; fi
  bashio::log.debug "Set name to ${VALUE}"
  CAMERAS="${CAMERAS}"',"name":"'"${VALUE}"'"'
  CNAME=${VALUE}

  # icon
  VALUE=$(jq -r '.cameras['${i}'].icon' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then VALUE='cctv'; fi
  bashio::log.debug "Set icon to ${VALUE}"
  CAMERAS="${CAMERAS}"',"icon":"'"${VALUE}"'"'

  # w3w
  VALUE=$(jq '.cameras['${i}'].w3w?' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then VALUE='["","",""]'; fi
  CAMERAS="${CAMERAS}"',"w3w":'"${VALUE}"
  bashio::log.debug "Set w3w to ${VALUE}"

  # icon top
  VALUE=$(jq -r '.cameras['${i}'].top' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then
    VALUE=${ICON_TOP:-10}
    ICON_TOP=$((VALUE+5))
    if [ ${ICON_TOP} -ge 95 ]; then
      ICON_TOP=10;
      ICON_LEFT=${ICON_LEFT:-10} && ICON_LEFT=$((ICON_LEFT+5))
    fi
  fi
  bashio::log.debug "Set top to ${VALUE}"
  CAMERAS="${CAMERAS}"',"top":'"${VALUE}"

  # icon left
  VALUE=$(jq -r '.cameras['${i}'].left' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then VALUE=${ICON_LEFT:-10}; fi
  bashio::log.debug "Set left to ${VALUE}"
  CAMERAS="${CAMERAS}"',"left":'"${VALUE}"

  # process models string to array of strings
  VALUE=$(jq -r '.cameras['${i}'].models' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then
    W=$(echo "${WATSON:-}" | jq -r '.models[]'| sed 's/\([^,]*\)\([,]*\)/"wvr:\1"\2/g' | fmt -1000)
    # bashio::log.debug "WATSON: ${WATSON} ${W}"
    D=$(echo "${DIGITS:-}" | jq -r '.models[]'| sed 's/\([^,]*\)\([,]*\)/"digits:\1"\2/g' | fmt -1000)
    # bashio::log.debug "DIGITS: ${DIGITS} ${D}"
    VALUE=$(echo ${W} ${D})
    VALUE=$(echo "${VALUE}" | sed 's/ /,/g')
  else
    VALUE=$(echo "${VALUE}" | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g')
  fi
  bashio::log.debug "Set models to ${VALUE}"
  CAMERAS="${CAMERAS}"',"models":['"${VALUE}"']'

  # process camera fov; WCV80n is 61.5 (62); 56 or 75 degrees for PS3 Eye camera
  VALUE=$(jq -r '.cameras['${i}'].fov' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [ ${VALUE} -lt 1 ]; then VALUE=$(echo "${MOTION}" | jq -r '.fov'); fi
  bashio::log.debug "Set fov to ${VALUE}"
  CAMERAS="${CAMERAS}"',"fov":'"${VALUE}"

  # width 
  VALUE=$(jq -r '.cameras['${i}'].width' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.width'); fi
  CAMERAS="${CAMERAS}"',"width":'"${VALUE}"
  bashio::log.debug "Set width to ${VALUE}"
  WIDTH=${VALUE}

  # height 
  VALUE=$(jq -r '.cameras['${i}'].height' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.height'); fi
  CAMERAS="${CAMERAS}"',"height":'"${VALUE}"
  bashio::log.debug "Set height to ${VALUE}"
  HEIGHT=${VALUE}

  # movie_max_time 
  VALUE=$(jq -r '.cameras['${i}'].movie_max_time' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.movie_max_time') && VALUE=${VALUE:-30}; fi
  CAMERAS="${CAMERAS}"',"movie_max_time":'"${VALUE}"
  bashio::log.debug "Set movie_max_time to ${VALUE}"
  MOVIE_MAX_TIME=${VALUE}

  # framerate
  VALUE=$(jq -r '.cameras['${i}'].framerate' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then 
    VALUE=$(jq -r '.framerate' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=$(echo "${MOTION}" | jq -r '.framerate') && VALUE=${VALUE:-5}; fi
  fi
  bashio::log.debug "Set framerate to ${VALUE}"
  CAMERAS="${CAMERAS}"',"framerate":'"${VALUE}"
  FRAMERATE=${VALUE}

  # stream_maxrate 
  VALUE=$(jq -r '.cameras['${i}'].stream_maxrate' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.stream_maxrate') && VALUE=${VALUE:-0}; fi
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [ ${STREAM_MAXRATE:-0} -gt ${FRAMERATE} ]; then VALUE=${FRAMERATE}; fi
  CAMERAS="${CAMERAS}"',"stream_maxrate":'"${VALUE}"
  bashio::log.debug "Set stream_maxrate to ${VALUE}"
  STREAM_MAXRATE=${VALUE}

  # stream_motion
  VALUE=$(jq -r '.cameras['${i}'].stream_motion' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.stream_motion') && VALUE=${VALUE:-off}; fi
  bashio::log.debug "Set stream_motion to ${VALUE}"
  CAMERAS="${CAMERAS}"',"stream_motion":"'"${VALUE}"'"'
  STREAM_MOTION=${VALUE}

  # process camera event_gap; set on wcv80n web GUI; default 6
  VALUE=$(jq -r '.cameras['${i}'].event_gap' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then 
    VALUE=$(jq -r '.event_gap' "${CONFIG_PATH}")
    if [ "${VALUE:-null}" = "null" ] || [ ${VALUE:-0} -lt 1 ]; then VALUE=$(echo "${MOTION}" | jq -r '.event_gap') && VALUE=${VALUE:-5}; fi
  fi
  bashio::log.debug "Set event_gap to ${VALUE}"
  CAMERAS="${CAMERAS}"',"event_gap":'"${VALUE}"
  EVENT_GAP=${VALUE}

  # target_dir 
  VALUE=$(jq -r '.cameras['${i}'].target_dir' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${MOTION_TARGET_DIR}/${CNAME}"; fi
  bashio::log.debug "Set target_dir to ${VALUE}"
  if [ ! -d "${VALUE}" ]; then mkdir -p "${VALUE}"; fi
  CAMERAS="${CAMERAS}"',"target_dir":"'"${VALUE}"'"'
  TARGET_DIR="${VALUE}"

  # CAMERA_TYPE
  case "${CAMERA_TYPE}" in
    local|netcam)
        # username and password for mjpeg camera are motioncam_userpass
        VALUE=$(jq -r '.cameras['${i}'].motioncam_userpass' "${CONFIG_PATH}")
        if [ "${VALUE:-null}" = 'null' ]; then
          USERNAME=$(echo "${MOTION}" | jq -r '.username')
          PASSWORD=$(echo "${MOTION}" | jq -r '.password')
        fi
        bashio::log.debug "Set username to ${USERNAME}"
        CAMERAS="${CAMERAS}"',"username":"'"${USERNAME}"'"'
        bashio::log.debug "Set username to ${PASSWORD}"
        CAMERAS="${CAMERAS}"',"password":"'"${PASSWORD}"'"'
        bashio::log.info "Camera: ${CNAME}; number: ${CNUM}; type: ${CAMERA_TYPE}"
        CAMERAS="${CAMERAS}"',"type":"'"${CAMERA_TYPE}"'"'
	;;
    ftpd|mqtt)
        # username and password for mjpeg camera are the same as netcam_userpass
        VALUE=$(jq -r '.cameras['${i}'].netcam_userpass' "${CONFIG_PATH}")
        if [ "${VALUE:-null}" = 'null' ]; then
          VALUE=$(echo "${MOTION}" | jq -r '.netcam_userpass')
        fi
        USERNAME=${VALUE%%:*}
        PASSWORD=${VALUE##*:}
        bashio::log.debug "Set username to ${USERNAME}"
        CAMERAS="${CAMERAS}"',"username":"'"${USERNAME}"'"'
        bashio::log.debug "Set username to ${PASSWORD}"
        CAMERAS="${CAMERAS}"',"password":"'"${PASSWORD}"'"'

        bashio::log.info "Camera: ${CNAME}; number: ${CNUM}; type: ${CAMERA_TYPE}"
        CAMERAS="${CAMERAS}"',"type":"'"${CAMERA_TYPE}"'"'

        # live
        VALUE=$(jq -r '.cameras['${i}'].mjpeg_url' "${CONFIG_PATH}")
        if [ "${VALUE:-null}" = 'null' ]; then 
          VALUE=$(jq -r '.cameras['${i}'].netcam_url' "${CONFIG_PATH}")
          if [ "${VALUE}" != "null" ] || [ ! -z "${VALUE}" ]; then 
            CAMERAS="${CAMERAS}"',"netcam_url":"'"${VALUE}"'"'
	  else
            bashio::log.warn "Camera: ${CNAME}; both mjpeg_url and netcam_url are undefined; no live stream"
	    VALUE=''
          fi
        fi
        bashio::log.debug "Set mjpeg_url to ${VALUE}"
        CAMERAS="${CAMERAS}"',"mjpeg_url":"'"${VALUE}"'"'

        # addon_api
        if [ "${CAMERA_TYPE}" != 'ftpd' ]; then
          VALUE="${VALUE##*//}" && VALUE=${VALUE%%/*} && VALUE=${VALUE%%:*} && VALUE="http://${VALUE}:${MOTION_APACHE_PORT}"
          CAMERAS="${CAMERAS}"',"addon_api":"'${VALUE}'"'
        else
          CAMERAS="${CAMERAS}"',"addon_api":"'${ADDON_API}'"'
        fi

        # FTP share_dir
        if [ "${CAMERA_TYPE}" == 'ftpd' ]; then
          VALUE="${MOTION_SHARE_DIR%/*}/ftp/${CNAME}"
          bashio::log.debug "Set share_dir to ${VALUE}"
          CAMERAS="${CAMERAS}"',"share_dir":"'"${VALUE}"'"'
        fi

        # complete
        CAMERAS="${CAMERAS}"'}'
        continue
	;;
    *)
        bashio::log.error "Camera: ${CNAME}; number: ${CNUM}; invalid camera type: ${CAMERA_TYPE}; setting to unknown; skipping"
        CAMERA_TYPE="unknown"
        CAMERAS="${CAMERAS}"',"type":"'"${CAMERA_TYPE}"'"'
        # complete
        CAMERAS="${CAMERAS}"'}'
        continue
	;;
  esac

  ##
  ## handle more than one motion process (10 camera/process)
  ##

  if (( CNUM / 10 )); then
    bashio::log.debug "Camera number divisible by 10"
    if (( CNUM % 10 == 0 )); then
      bashio::log.debug "Camera number modulus of 10; creating new configuration file; current: ${MOTION_CONF}"

      # new configuration
      CONF="${MOTION_CONF%%.*}.${MOTION_COUNT}.${MOTION_CONF##*.}"

      # start camera numbering over at one
      CNUM=1

      # copy prior configuration
      cp "${MOTION_CONF}" "${CONF}"
      MOTION_CONF=${CONF}
      bashio::log.debug "Created configuration; count: ${MOTION_COUNT}; file: ${MOTION_CONF}"

      # reset camera(s)
      sed -i 's|^camera|; camera|' "${MOTION_CONF}"

      # set stream port
      VALUE=$(jq -r ".stream_port" "${CONFIG_PATH}")
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_STREAM_PORT}; fi
      VALUE=$((VALUE + MOTION_COUNT))
      sed -i "s/^stream_port .*/stream_port ${VALUE}/" "${MOTION_CONF}"
      MOTION_STREAM_PORT=${VALUE}
      bashio::log.info "Configuration: ${MOTION_CONF}; set stream port: ${MOTION_STREAM_PORT}"

      # set webcontrol_port
      VALUE=$(jq -r ".webcontrol_port" "${CONFIG_PATH}")
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_CONTROL_PORT}; fi
      VALUE=$((VALUE + MOTION_COUNT))
      sed -i "s/^webcontrol_port\s[0-9]\+/webcontrol_port ${VALUE}/" "${MOTION_CONF}"

      # increment
      bashio::log.info "Configuration ${MOTION_COUNT}: ${MOTION_CONF}; set control port: ${VALUE}"

      MOTION_COUNT=$((MOTION_COUNT + 1))

    else
      CNUM=$((CNUM+1))
    fi
  else
    if [ ${MOTION_COUNT} -eq 0 ]; then MOTION_COUNT=1; fi
    CNUM=$((CNUM+1))
  fi

  # create camera configuration file
  if [ ${MOTION_CONF%/*} != ${MOTION_CONF} ]; then 
    CAMERA_CONF="${MOTION_CONF%/*}/${CNAME}.conf"
    bashio::log.debug "Camera configuration file; ${CAMERA_CONF}; ${MOTION_CONF%/*} != ${MOTION_CONF}"
  else
    CAMERA_CONF="${CNAME}.conf"
    bashio::log.debug "Camera configuration file; ${CAMERA_CONF}; ${MOTION_CONF%/*} = ${MOTION_CONF}"
  fi

  # add to JSON
  CAMERAS="${CAMERAS}"',"server":'"${MOTION_COUNT}"
  CAMERAS="${CAMERAS}"',"cnum":'"${CNUM}"
  CAMERAS="${CAMERAS}"',"conf":"'"${CAMERA_CONF}"'"'

  VALUE=$(jq -r '.cameras['${i}'].mjpeg_url' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then 
    # calculate mjpeg_url for camera
    VALUE="http://${ipaddr}:${MOTION_STREAM_PORT}/${CNUM}"
  fi
  bashio::log.debug "Set mjpeg_url to ${VALUE}"
  CAMERAS="${CAMERAS}"',"mjpeg_url":"'${VALUE}'"'

  # addon_api
  CAMERAS="${CAMERAS}"',"addon_api":"'${ADDON_API}'"'

  ##
  ## make camera configuration file
  ##

  # basics
  echo "camera_id ${CNUM}" > "${CAMERA_CONF}"
  echo "camera_name ${CNAME}" >> "${CAMERA_CONF}"
  echo "target_dir ${TARGET_DIR}" >> "${CAMERA_CONF}"
  echo "width ${WIDTH}" >> "${CAMERA_CONF}"
  echo "height ${HEIGHT}" >> "${CAMERA_CONF}"
  echo "movie_max_time ${MOVIE_MAX_TIME}" >> "${CAMERA_CONF}"
  echo "framerate ${FRAMERATE}" >> "${CAMERA_CONF}"
  echo "stream_motion ${STREAM_MOTION}" >> "${CAMERA_CONF}"
  echo "stream_maxrate ${STREAM_MAXRATE}" >> "${CAMERA_CONF}"
  echo "event_gap ${EVENT_GAP}" >> "${CAMERA_CONF}"

  # pre_capture
  VALUE=$(jq -r '.cameras['${i}'].pre_capture' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.pre_capture') && VALUE=${VALUE:-0}; fi
  bashio::log.debug "Set pre_capture to ${VALUE}"
  CAMERAS="${CAMERAS}"',"pre_capture":'"${VALUE}"
  echo "pre_capture ${VALUE}" >> "${CAMERA_CONF}"

  # post_capture
  VALUE=$(jq -r '.cameras['${i}'].post_capture' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.post_capture') && VALUE=${VALUE:-0}; fi
  bashio::log.debug "Set post_capture to ${VALUE}"
  CAMERAS="${CAMERAS}"',"post_capture":'"${VALUE}"
  echo "post_capture ${VALUE}" >> "${CAMERA_CONF}"

  # rotate 
  VALUE=$(jq -r '.cameras['${i}'].rotate' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.rotate') && VALUE=${VALUE:-0}; fi
  bashio::log.debug "Set rotate to ${VALUE}"
  CAMERAS="${CAMERAS}"',"rotate":'"${VALUE}"
  echo "rotate ${VALUE}" >> "${CAMERA_CONF}"

  # picture_quality 
  VALUE=$(jq -r '.cameras['${i}'].picture_quality' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.picture_quality') && VALUE=${VALUE:-100}; fi
  bashio::log.debug "Set picture_quality to ${VALUE}"
  CAMERAS="${CAMERAS}"',"picture_quality":'"${VALUE}"
  echo "picture_quality ${VALUE}" >> "${CAMERA_CONF}"

  # stream_quality 
  VALUE=$(jq -r '.cameras['${i}'].stream_quality' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.stream_quality') && VALUE=${VALUE:-100}; fi
  bashio::log.debug "Set stream_quality to ${VALUE}"
  CAMERAS="${CAMERAS}"',"stream_quality":'"${VALUE}"
  echo "stream_quality ${VALUE}" >> "${CAMERA_CONF}"

  # lightswitch_percent
  VALUE=$(jq -r '.cameras['${i}'].lightswitch_percent' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.lightswitch_percent') && VALUE=${VALUE:-0}; fi
  bashio::log.debug "Set lightswitch_percent to ${VALUE}"
  CAMERAS="${CAMERAS}"',"lightswitch_percent":'"${VALUE}"
  echo "lightswitch_percent ${VALUE}" >> "${CAMERA_CONF}"

  # lightswitch_frames
  VALUE=$(jq -r '.cameras['${i}'].lightswitch_frames' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.lightswitch_frames') && VALUE=${VALUE:-5}; fi
  bashio::log.debug "Set lightswitch_frames to ${VALUE}"
  CAMERAS="${CAMERAS}"',"lightswitch_frames":'"${VALUE}"
  echo "lightswitch_frames ${VALUE}" >> "${CAMERA_CONF}"


  ## THRESHOLD

  VALUE=$(jq -r '.cameras['${i}'].threshold' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ] || [ ${VALUE:-0} -le 0 ]; then 
    PCT=$(jq -r '.cameras['${i}'].threshold_percent' "${CONFIG_PATH}")
    if [ "${PCT:-null}" = 'null' ] || [ ${PCT:-0} -le 0 ]; then PCT=$(echo "${MOTION}" | jq -r '.threshold_percent'); fi
    if [ "${PCT:-null}" != 'null' ] && [ ${PCT:-0} -gt 0 ]; then 
      VALUE=$(echo "${PCT} * ( ${WIDTH} * ${HEIGHT} ) / 100.0" | bc -l) && VALUE=${VALUE%%.*}
    fi
  fi
  if [ "${VALUE:-null}" = 'null' ] || [ ${VALUE:-0} -le 0 ]; then VALUE=$(echo "${MOTION}" | jq -r '.threshold'); fi 
  if [ "${PCT:-null}" = 'null' ] || [ ${PCT:-0} -le 0 ]; then PCT=$(echo "${VALUE} / ( ${WIDTH} * ${HEIGHT} ) * 100.0" | bc -l) && PCT=${PCT%%.*}; PCT=${PCT:-null}; fi

  bashio::log.debug "Camera ${CNAME:-}: set threshold_percent to ${PCT}"
  CAMERAS="${CAMERAS}"',"threshold_percent":'"${PCT}"
  bashio::log.debug "Camera ${CNAME:-}: set threshold to ${VALUE}"
  CAMERAS="${CAMERAS}"',"threshold":'"${VALUE}"
  echo "threshold ${VALUE}" >> "${CAMERA_CONF}"

  # set threshold_maximum
  VALUE=$(jq -r '.cameras['${i}'].threshold_maximum' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" == "null" ]; then VALUE=$(echo "${MOTION}" | jq -r '.threshold_maximum') && VALUE=${VALUE:-0}; fi
  CAMERAS="${CAMERAS}"',"threshold_maximum":'"${VALUE:-0}"
  echo "threshold_maximum ${VALUE:-0}" >> "${CAMERA_CONF}"

  # set threshold_tune
  VALUE=$(jq -r '.cameras['${i}'].threshold_tune' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then VALUE=$(echo "${MOTION}" | jq -r '.threshold_tune') && VALUE=${VALUE:-off}; fi
  CAMERAS="${CAMERAS}"',"threshold_tune":"'"${VALUE}"'"'
  echo "threshold_tune ${VALUE}" >> "${CAMERA_CONF}"

  if [ "${CAMERA_TYPE}" == 'netcam' ]; then
    # network camera
    VALUE=$(jq -r '.cameras['${i}'].netcam_url' "${CONFIG_PATH}")
    if [ ! -z "${VALUE:-}" ] && [ "${VALUE:-null}" != 'null' ]; then
      # network camera
      CAMERAS="${CAMERAS}"',"netcam_url":"'"${VALUE}"'"'
      echo "netcam_url ${VALUE}" >> "${CAMERA_CONF}"
      bashio::log.debug "Set netcam_url to ${VALUE}"
      netcam_url=$(echo "${VALUE}" | sed 's/mjpeg:/http:/')

      # userpass 
      VALUE=$(jq -r '.cameras['${i}'].netcam_userpass' "${CONFIG_PATH}")
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_userpass'); fi
      echo "netcam_userpass ${VALUE}" >> "${CAMERA_CONF}"
      CAMERAS="${CAMERAS}"',"netcam_userpass":"'"${VALUE}"'"'
      bashio::log.debug "Set netcam_userpass to ${VALUE}"
      netcam_userpass=${VALUE}

      # test netcam_url
      alive=$(curl -fsqL -w '%{http_code}' --connect-timeout 2 --retry-connrefused --retry 10 --retry-max-time 2 --max-time 15 -u ${netcam_userpass} ${netcam_url} 2> /dev/null || true)

      if [ "${alive:-}" != '200' ]; then
        bashio::log.info "Network camera at ${netcam_url:-null}; userpass: ${netcam_userpass:-null}; bad response: ${alive:-null}"
      else
        bashio::log.info "Network camera at ${netcam_url:-null}; userpass: ${netcam_userpass:-null}; good response: ${alive:-null}"
      fi

      # keepalive 
      VALUE=$(jq -r '.cameras['${i}'].keepalive' "${CONFIG_PATH}")
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_keepalive'); fi
      echo "netcam_keepalive ${VALUE}" >> "${CAMERA_CONF}"
      CAMERAS="${CAMERAS}"',"keepalive":"'"${VALUE}"'"'
      bashio::log.debug "Set netcam_keepalive to ${VALUE}"
    else
      bashio::log.error "No netcam_url specified: ${VALUE}; skipping"
      # close CAMERAS structure
      CAMERAS="${CAMERAS}"'}'
      continue;
    fi
  elif [ "${CAMERA_TYPE}" == 'local' ]; then
    # local camera
    VALUE=$(jq -r '.cameras['${i}'].device' "${CONFIG_PATH}")
    if [ "${VALUE:-null}" != 'null' ] ; then
      if [[ "${VALUE}" != /dev/video* ]]; then
        bashio::log.error "Camera: ${i}; name: ${CNAME}; invalid videodevice ${VALUE}; exiting"
        exit 1
      fi
    else
      VALUE="/dev/video0"
    fi
    echo "videodevice ${VALUE}" >> "${CAMERA_CONF}"
    bashio::log.debug "Set videodevice to ${VALUE}"
    # palette
    VALUE=$(jq -r '.cameras['${i}'].palette' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.palette'); fi
    CAMERAS="${CAMERAS}"',"palette":'"${VALUE}"
    echo "v4l2_palette ${VALUE}" >> "${CAMERA_CONF}"
    bashio::log.debug "Set palette to ${VALUE}"
  else
    bashio::log.error "Invalid camera type: ${CAMERA_TYPE}"
  fi

  # close CAMERAS structure
  CAMERAS="${CAMERAS}"'}'

  # add new camera configuration
  echo "camera ${CAMERA_CONF}" >> "${MOTION_CONF}"
done
# finish CAMERAS
if [ -n "${CAMERAS:-}" ]; then 
  CAMERAS="${CAMERAS}"']'
else
  CAMERAS='null'
fi

bashio::log.debug "CAMERAS: $(echo "${CAMERAS}" | jq -c '.')"

###
## append camera, finish JSON configuration, and validate
###

JSON="${JSON}"',"cameras":'"${CAMERAS}"'}'
echo "${JSON}" | jq -c '.' > "$(motion.config.file)"
if [ ! -s "$(motion.config.file)" ]; then
  bashio::log.error "INVALID CONFIGURATION; metadata: ${JSON}"
  exit 1
fi
bashio::log.debug "CONFIGURATION; file: $(motion.config.file); metadata: $(jq -c '.' $(motion.config.file))"

###
## configure inotify() for any 'ftpd' cameras
###

bashio::log.debug "Settting up notifywait for FTPD cameras"
ftp_notifywait.sh "$(motion.config.file)"

###
## start all motion daemons
###

PID_FILES=()
CONF="${MOTION_CONF%%.*}.${MOTION_CONF##*.}"
# process all motion configurations
for (( i = 1; i <= MOTION_COUNT;  i++)); do
  # test for configuration file
  if [ ! -s "${CONF}" ]; then
     bashio::log.error "missing configuration for daemon ${i} with ${CONF}"
     exit 1
  fi
  bashio::log.debug "Starting motion configuration ${i}: ${CONF}"
  PID_FILE="${MOTION_CONF%%.*}.${i}.pid"
  motion -b -c "${CONF}" -p ${PID_FILE}
  PID_FILES=(${PID_FILES[@]} ${PID_FILE})

  # get next configuration
  CONF="${MOTION_CONF%%.*}.${i}.${MOTION_CONF##*.}"
done

# make the options available to the apache client
chmod go+rx /data /data/options.json

if [ ${#PID_FILES[@]} -le 0 ]; then
  bashio::log.info "ZERO motion daemons"
  bashio::log.info "STARTING APACHE in foreground; ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}"
  start_apache_foreground ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}
else 
  bashio::log.info "${#PID_FILES[@]} motion daemons"
  bashio::log.info "STARTING APACHE in background; ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}"
  start_apache_background ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}

  ## monitor motion daemons
  bashio::log.info "STARTING MOTION WATCHDOG; ${PID_FILES}"
  ## forever
  while true; do
    ## publish configuration
    bashio::log.notice "PUBLISHING CONFIGURATION; topic: $(motion.config.group)/$(motion.config.device)/start"
    motion.mqtt.pub -r -q 2 -t "$(motion.config.group)/$(motion.config.device)/start" -f "$(motion.config.file)"

    i=0
    for PID_FILE in ${PID_FILES[@]}; do
      if [ ! -z "${PID_FILE:-}" ] && [ -s "${PID_FILE}" ]; then
        pid=$(cat ${PID_FILE})
        if [ "${pid:-null}" != 'null' ]; then
          found=$(ps alxwww | grep 'motion -b' | awk '{ print $1 }' | egrep ${pid} || true)
          if [ -z "${found:-}" ]; then
            bashio::log.notice "Daemon with PID: ${pid} is not found; restarting"
            if [ ${i} -gt 0 ]; then
              CONF="${MOTION_CONF%%.*}.${i}.${MOTION_CONF##*.}"
            else
              CONF="${MOTION_CONF%%.*}.${MOTION_CONF##*.}"
            fi
            motion -b -c "${CONF}" -p ${PID_FILE}
          else
            bashio::log.info "motion daemon running with PID: ${pid}"
          fi
        else
          bashio::log.error "PID file contents invalid: ${PID_FILE}"
        fi
      else
        bashio::log.error "No motion daemon PID file: ${PID_FILE}"
      fi
      i=$((i+1))
    done
    bashio::log.info "watchdog sleeping..."
    sleep ${MOTION_WATCHDOG_INTERVAL:-3600}
  done
fi
