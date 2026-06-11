#!/bin/bash
set -euo pipefail

# Log function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> /home/miner/factory-update.log
}

# Single instance lock
exec 200>/home/miner/factory-update.lock
if ! flock -n 200; then
    log "Another instance is already running, exiting"
    exit 0
fi

# Fetch latest changes
git fetch origin main

# Check if there are new commits
if ! git rev-parse HEAD > /dev/null 2>&1 || ! git rev-parse origin/main > /dev/null 2>&1 || \
   [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ]; then
    log "UP-TO-DATE"
    exit 0
fi

# Get current SHA before reset
current_sha=$(git rev-parse HEAD)
short_current_sha=$(git rev-parse --short HEAD)

# Tag current image as rollback (swallow error if no image exists)
docker tag factory:latest factory:rollback 2>/dev/null || true

# Hard reset to origin/main
git reset --hard origin/main

# Build the factory service
if ! docker compose build factory; then
    log "BUILD-FAILED"
    exit 1
fi

# Deploy the container
docker compose up -d factory

# Poll health endpoint
timeout=60
count=0
while [ $count -lt $timeout ]; do
    if curl -f http://localhost:8787/api/health >/dev/null 2>&1; then
        log "DEPLOYED $short_current_sha"
        exit 0
    fi
    sleep 2
    count=$((count + 2))
done

# Rollback if health check failed
log "ROLLED-BACK $short_current_sha"
docker tag factory:rollback factory:latest
docker compose up -d factory