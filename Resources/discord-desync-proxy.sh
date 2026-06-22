#!/bin/zsh

set -u

BASE_DIR="${0:A:h}"
BYEDPI_DIR="$BASE_DIR/byedpi"
BIN="$BYEDPI_DIR/ciadpi"
STATE_DIR="$HOME/Library/Application Support/Discord Desync"
PIDFILE="$STATE_DIR/proxy.pid"
LOGFILE="$STATE_DIR/proxy.log"
PORT="${DISCORD_DESYNC_PORT:-1080}"
PROXY_HOST="127.0.0.1"
HEALTH_URL="${DISCORD_DESYNC_HEALTH_URL:-https://discord.com}"
DEFAULT_FLAGS="--disorder 1 --auto=torst --tlsrec 1+s"
BYEDPI_FLAGS="${DISCORD_DESYNC_FLAGS:-$DEFAULT_FLAGS}"

die() {
  print -r -- "ERROR: $*" >&2
  exit 1
}

validate_binary() {
  [[ -x "$BIN" ]] || die "ByeDPI binary is missing or not executable: $BIN"
}

read_pid() {
  [[ -f "$PIDFILE" ]] || return 1
  local pid
  pid="$(<"$PIDFILE")"
  [[ "$pid" == <-> ]] || return 1
  print -r -- "$pid"
}

pid_alive() {
  local pid="$1"
  kill -0 "$pid" 2>/dev/null
}

pid_args() {
  local pid="$1"
  ps -p "$pid" -o args= 2>/dev/null
}

is_bundled_ciadpi() {
  local pid="$1"
  local args
  args="$(pid_args "$pid")" || return 1
  [[ "$args" == *"$BIN"* ]]
}

port_pids() {
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t 2>/dev/null | sort -u
}

managed_pid() {
  local pid
  pid="$(read_pid)" || return 1
  pid_alive "$pid" || return 1
  is_bundled_ciadpi "$pid" || return 1
  print -r -- "$pid"
}

port_owned_by_bundle() {
  local pid
  for pid in ${(f)"$(port_pids)"}; do
    [[ -n "$pid" ]] || continue
    if is_bundled_ciadpi "$pid"; then
      print -r -- "$pid"
      return 0
    fi
  done
  return 1
}

unknown_port_owner_message() {
  [[ -n "$(port_pids)" ]] || return 1
  print -r -- "Port $PORT is already in use by another process:"
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null
  print -r -- ""
  print -r -- "Refusing to kill an unrelated process."
}

health_check() {
  local tmp code curl_status err
  tmp="$(mktemp -t discord-desync-health.XXXXXX)" || die "Could not create temp file"
  code="$(curl --socks5-hostname "$PROXY_HOST:$PORT" \
    --connect-timeout 5 \
    --max-time 10 \
    -I \
    -sS \
    -o /dev/null \
    -w "%{http_code}" \
    "$HEALTH_URL" 2>"$tmp")"
  curl_status=$?
  err="$(<"$tmp")"
  rm -f "$tmp"

  if [[ "$curl_status" -eq 0 && ( "$code" == "200" || "$code" == "301" || "$code" == "302" || "$code" == "403" ) ]]; then
    print -r -- "healthy: $HEALTH_URL returned HTTP $code through SOCKS5 $PROXY_HOST:$PORT"
    return 0
  fi

  if [[ -n "$code" && "$code" != "000" ]]; then
    print -r -- "unhealthy: $HEALTH_URL returned HTTP $code through SOCKS5 $PROXY_HOST:$PORT"
  elif [[ -n "$err" ]]; then
    print -r -- "unhealthy: $err"
  else
    print -r -- "unhealthy: no response through SOCKS5 $PROXY_HOST:$PORT"
  fi
  return 1
}

wait_for_exit() {
  local pid="$1"
  local i
  for i in {1..5}; do
    pid_alive "$pid" || return 0
    sleep 0.2
  done
  return 1
}

stop_pid() {
  local pid="$1"
  is_bundled_ciadpi "$pid" || die "Refusing to stop PID $pid because it is not $BIN"

  kill -INT "$pid" 2>/dev/null || true
  if ! wait_for_exit "$pid"; then
    kill -TERM "$pid" 2>/dev/null || true
    sleep 0.5
  fi
  if pid_alive "$pid"; then
    kill -KILL "$pid" 2>/dev/null || true
  fi
}

stop_proxy() {
  local pid bundle_pid

  pid="$(read_pid)" || pid=""
  if [[ -n "$pid" ]] && pid_alive "$pid"; then
    stop_pid "$pid"
  fi

  for bundle_pid in ${(f)"$(port_owned_by_bundle)"}; do
    [[ -n "$bundle_pid" ]] || continue
    pid_alive "$bundle_pid" || continue
    stop_pid "$bundle_pid"
  done

  rm -f "$PIDFILE"
  print -r -- "ByeDPI stopped."
}

verify_stopped() {
  local owner
  owner="$(port_owned_by_bundle)" || owner=""
  if [[ -n "$owner" ]]; then
    print -r -- "ERROR: ByeDPI is still running as PID $owner on $PROXY_HOST:$PORT"
    return 1
  fi

  if [[ -n "$(port_pids)" ]]; then
    unknown_port_owner_message
    return 1
  fi

  print -r -- "verified: no ByeDPI listener on $PROXY_HOST:$PORT"
}

stop_and_check() {
  stop_proxy
  verify_stopped
}

launch_proxy() {
  validate_binary
  local started_pid
  local -a flags
  flags=(${(z)BYEDPI_FLAGS})

  mkdir -p "$STATE_DIR"
  : > "$LOGFILE"
  cd "$BYEDPI_DIR" || die "Could not enter $BYEDPI_DIR"
  "$BIN" --daemon --pidfile "$PIDFILE" --ip "$PROXY_HOST" "${flags[@]}" -p "$PORT" >>"$LOGFILE" 2>&1
  sleep 1

  started_pid="$(read_pid)" || die "ByeDPI did not write a PID file. Log file: $LOGFILE"

  if ! pid_alive "$started_pid"; then
    rm -f "$PIDFILE"
    die "ByeDPI exited immediately. Log file: $LOGFILE"
  fi
}

start_proxy() {
  validate_binary

  local pid owner health_output
  pid="$(read_pid)" || pid=""

  if [[ -n "$pid" ]] && pid_alive "$pid"; then
    if ! is_bundled_ciadpi "$pid"; then
      die "PID file points to live PID $pid, but it is not $BIN. Remove $PIDFILE manually after checking it."
    fi

    if health_output="$(health_check)"; then
      print -r -- "ByeDPI is already working."
      print -r -- "$health_output"
      return 0
    fi

    print -r -- "Managed ByeDPI appears hung or unhealthy. Restarting it."
    print -r -- "$health_output"
    stop_pid "$pid"
    rm -f "$PIDFILE"
  elif [[ -n "$pid" ]]; then
    print -r -- "Removing stale PID file for PID $pid."
    rm -f "$PIDFILE"
  fi

  owner="$(port_owned_by_bundle)" || owner=""
  if [[ -n "$owner" ]]; then
    print -r -- "$owner" > "$PIDFILE"
    if health_output="$(health_check)"; then
      print -r -- "ByeDPI is already working on port $PORT."
      print -r -- "$health_output"
      return 0
    fi

    print -r -- "Bundled ByeDPI on port $PORT appears hung or unhealthy. Restarting it."
    print -r -- "$health_output"
    stop_pid "$owner"
    rm -f "$PIDFILE"
  elif [[ -n "$(port_pids)" ]]; then
    unknown_port_owner_message
    exit 1
  fi

  launch_proxy
  if health_output="$(health_check)"; then
    print -r -- "ByeDPI started."
    print -r -- "$health_output"
    return 0
  fi

  print -r -- "ByeDPI started but failed the health check."
  print -r -- "$health_output"
  print -r -- "Log file: $LOGFILE"
  stop_proxy >/dev/null 2>&1 || true
  exit 1
}

status_proxy() {
  local pid owner health_output
  pid="$(managed_pid)" || pid=""
  owner="$(port_owned_by_bundle)" || owner=""

  if [[ -n "$pid" ]]; then
    print -r -- "managed: running as PID $pid"
  elif [[ -n "$owner" ]]; then
    print -r -- "bundled: running as PID $owner on port $PORT"
  elif [[ -n "$(port_pids)" ]]; then
    unknown_port_owner_message
    return 1
  else
    print -r -- "stopped: no ByeDPI listener on $PROXY_HOST:$PORT"
    return 0
  fi

  if health_output="$(health_check)"; then
    print -r -- "$health_output"
    return 0
  fi
  print -r -- "$health_output"
  print -r -- "Log file: $LOGFILE"
  return 1
}

usage() {
  print -r -- "Usage: $0 {proxy-start|stop|stop-check|restart|status|health}"
}

case "${1:-}" in
  proxy-start)
    start_proxy
    ;;
  stop)
    stop_proxy
    ;;
  stop-check)
    stop_and_check
    ;;
  restart)
    stop_proxy
    start_proxy
    ;;
  status)
    status_proxy
    ;;
  health)
    health_check
    ;;
  *)
    usage
    exit 2
    ;;
esac
