#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${1:-$(pwd)}"
shift || true
if [ "$#" -eq 0 ]; then
  echo "usage: $0 <workdir> <skill> [skill ...]" >&2
  exit 2
fi

cd "$WORKDIR"
mkdir -p .openclaw/logs
LOGFILE=".openclaw/logs/clawhub-install-$(date +%Y%m%d-%H%M%S).log"

echo "[start] $(date -Is)" | tee -a "$LOGFILE"
for skill in "$@"; do
  echo "[skill] $skill" | tee -a "$LOGFILE"
  attempt=1
  delay=8
  while true; do
    echo "[attempt] skill=$skill n=$attempt" | tee -a "$LOGFILE"
    set +e
    output=$(openclaw skills install "$skill" 2>&1)
    code=$?
    set -e
    printf '%s\n' "$output" | tee -a "$LOGFILE"
    if [ $code -eq 0 ]; then
      echo "[ok] $skill" | tee -a "$LOGFILE"
      sleep 6
      break
    fi
    if printf '%s' "$output" | grep -qiE '429|too many requests|rate limit|retry-after'; then
      if [ $attempt -ge 6 ]; then
        echo "[fail-rate-limit] $skill" | tee -a "$LOGFILE"
        exit 1
      fi
      echo "[backoff] $skill sleep=${delay}s" | tee -a "$LOGFILE"
      sleep "$delay"
      attempt=$((attempt + 1))
      delay=$((delay * 2))
      continue
    fi
    echo "[fail] $skill" | tee -a "$LOGFILE"
    exit $code
  done
done

echo "[done] $(date -Is)" | tee -a "$LOGFILE"
