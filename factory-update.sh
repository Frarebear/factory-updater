#!/usr/bin/env bash
# Factory self-updater — pulls the latest Factory from GitHub, rebuilds,
# health-checks, and ROLLS BACK to the previous image if the new build does not
# come up healthy. Runs unattended via a systemd timer. A bad commit must never
# leave the box down.
set -euo pipefail

FACTORY_DIR="${FACTORY_DIR:-/home/miner/factory}"
LOG="${LOG:-/home/miner/factory-update.log}"
HEALTH="${HEALTH:-http://localhost:8787/api/health}"
IMAGE="factory:local"          # the tag docker-compose builds the factory under
ROLLBACK="factory:rollback"    # last-known-good snapshot
HEALTH_TIMEOUT=90              # seconds to wait for the new build to answer

log() { echo "$(date '+%F %T') $*" >>"$LOG"; }
trap 'log "ERROR line $LINENO (rc=$?)"' ERR

# Single run at a time — timer firings must never overlap a build/swap.
exec 200>/home/miner/factory-update.lock
flock -n 200 || exit 0

cd "$FACTORY_DIR"

git fetch --quiet origin main
local_sha="$(git rev-parse HEAD)"
remote_sha="$(git rev-parse origin/main)"
[ "$local_sha" = "$remote_sha" ] && exit 0   # up to date — stay quiet (runs every 2 min)

short="$(git rev-parse --short origin/main)"
log "UPDATE ${local_sha:0:8} -> ${remote_sha:0:8} (deploying $short)"

health_ok() {
  local end=$((SECONDS + HEALTH_TIMEOUT))
  while [ "$SECONDS" -lt "$end" ]; do
    curl -fsS --max-time 5 "$HEALTH" >/dev/null 2>&1 && return 0
    sleep 3
  done
  return 1
}

# Snapshot the currently-running (good) image BEFORE we touch anything.
docker image inspect "$IMAGE" >/dev/null 2>&1 && docker tag "$IMAGE" "$ROLLBACK"

git reset --hard --quiet origin/main

# A broken BUILD never deploys — the old container keeps serving. The advanced
# source just waits for a fix-push (no rebuild loop, since we're now == origin).
if ! docker compose build factory >>"$LOG" 2>&1; then
  log "BUILD-FAILED $short — kept previous build running"
  exit 1
fi

docker compose up -d factory >>"$LOG" 2>&1

if health_ok; then
  log "DEPLOYED $short"
  exit 0
fi

# New build is up but unhealthy → restore the snapshot and never leave it down.
log "UNHEALTHY $short — rolling back"
if docker image inspect "$ROLLBACK" >/dev/null 2>&1; then
  docker tag "$ROLLBACK" "$IMAGE"
  docker compose up -d factory >>"$LOG" 2>&1
  if health_ok; then
    log "ROLLED-BACK ok (serving previous good build; $short held back)"
  else
    log "ROLLBACK-FAILED — factory UNHEALTHY, needs a human"
  fi
else
  log "ROLLBACK-IMPOSSIBLE — no $ROLLBACK image saved"
fi
exit 1
