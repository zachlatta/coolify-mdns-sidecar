#!/usr/bin/env bash
set -euo pipefail

BASE_HOST="${BASE_HOST:-rotom.local}"
ALIASES="${ALIASES:-immich.rotom.local}"   # comma-separated
IFS=',' read -r -a ALIAS_ARR <<< "$ALIASES"

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
