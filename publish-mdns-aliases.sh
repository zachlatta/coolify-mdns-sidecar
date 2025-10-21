#!/usr/bin/env bash
set -euo pipefail

BASE_HOST="${BASE_HOST:-rotom.local}"
ALIASES="${ALIASES:-immich.rotom.local}"   # comma-separated
IFS=',' read -r -a ALIAS_ARR <<< "$ALIASES"

DBUS_PID=""
AVAHI_PID=""
PIDS=()

start_dbus() {
  echo "[mdns] Starting local D-Bus..."
  mkdir -p /run/dbus
  dbus-uuidgen --ensure=/etc/machine-id
  dbus-daemon --system --fork

  for _ in {1..10}; do
    if [[ -S /run/dbus/system_bus_socket ]]; then
      if [[ -f /run/dbus/pid ]]; then
        DBUS_PID="$(cat /run/dbus/pid || true)"
      fi
      return
    fi
    sleep 0.2
  done

  echo "[mdns] Warning: D-Bus socket not ready; continuing..."
}

start_avahi() {
  echo "[mdns] Starting local Avahi daemon..."
  mkdir -p /run/avahi-daemon
  avahi-daemon --daemonize --no-drop-root --no-rlimits
  AVAHI_PID="$(cat /run/avahi-daemon/pid)"

  # Wait for Avahi to answer commands (max ~5 seconds)
  for _ in {1..10}; do
    if avahi-browse -a -t >/dev/null 2>&1; then
      return
    fi
    sleep 0.5
  done

  echo "[mdns] Warning: Avahi daemon did not become ready; continuing anyway..."
}

stop_services() {
  kill_publishers || true

  if [[ -n "${AVAHI_PID:-}" ]]; then
    avahi-daemon -k >/dev/null 2>&1 || true
    wait "$AVAHI_PID" 2>/dev/null || true
  fi

  if [[ -n "${DBUS_PID:-}" ]]; then
    kill "$DBUS_PID" 2>/dev/null || true
    wait "$DBUS_PID" 2>/dev/null || true
  fi
}

resolve_ip() {
  avahi-resolve-host-name -4 "$BASE_HOST" | awk '{print $2}'
}

publish_once() {
  local ip="$1"
  echo "[mdns] Publishing aliases -> $ip: ${ALIAS_ARR[*]}"
  PIDS=()
  for name in "${ALIAS_ARR[@]}"; do
    avahi-publish -a -R "$name" "$ip" &
    PIDS+=("$!")
  done
}

kill_publishers() {
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  PIDS=()
}

trap stop_services EXIT INT TERM

start_dbus
start_avahi

current_ip=""
while true; do
  new_ip="$(resolve_ip || true)"
  if [[ -z "$new_ip" ]]; then
    echo "[mdns] Could not resolve $BASE_HOST; retrying in 5s..."
    sleep 5
    continue
  fi

  if [[ "$new_ip" != "$current_ip" ]]; then
    echo "[mdns] IP change detected: $current_ip -> $new_ip"
    kill_publishers || true
    publish_once "$new_ip"
    current_ip="$new_ip"
  fi

  sleep 30
  for pid in "${PIDS[@]:-}"; do
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "[mdns] publisher died; restarting..."
      kill_publishers || true
      publish_once "$current_ip"
      break
    fi
  done
done
