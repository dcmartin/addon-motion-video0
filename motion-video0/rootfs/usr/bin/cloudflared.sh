#!/usr/bin/with-contenv bashio

function cloudflared::init()
{
  local code=1
  local version="2023.1.0"

  case $arch in
    "aarch64")
        arch="arm64"
    ;;
    "armhf")
        arch="arm"
    ;;
    "armv7")
        arch="arm"
    ;;
    "i386")
        arch="386"
    ;;
    "amd64")
        arch="amd64"
    ;;
  esac

  wget -O /usr/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/download/${version}/cloudflared-linux-${arch}" \
  && \
  chmod +x /usr/bin/cloudflared \
  && \
  code=0

  return ${code}
}

function cloudflared::start()
{
  local pid=0
  local init=0

  if bashio::config.has_value 'tunnel_token' ; then
    local tunnel_token=$(bashio::config 'tunnel_token')

    if [ -z "$(command cloudflared)" ]; then
      init = $(cloudflared::init)
    fi
    if [ ${init:-0} = 0 ]; then
      cloudflared --no-autoupdate tunnel --metrics="0.0.0.0:36500" --loglevel="${CLOUDFLARED_LOG:-info}" run --token="${tunnel_token}" &
      pid=$!
    fi
  fi

  return ${pid}
}
