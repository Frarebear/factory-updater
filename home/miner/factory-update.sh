#!/bin/bash
set -euo pipefail

LOCKFILE="/tmp/factory-update.lock"
LOGFILE="/home/miner/factory-update.log"

# Function to log messages with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOGFILE"
}

# Acquire lock
if ! flock -n -x 99; then
    log "Another instance is already running, exiting"
    exit 0
fi

# Get current git commit
CURRENT_SHA=$(git rev-parse HEAD)
SHORT_CURRENT_SHA=$(git rev-parse --short HEAD)

# Fetch from origin
git fetch origin

# Check if there are new commits
if git rev-parse HEAD@{origin/main} >/dev/null 2>&1 && \
   [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ]; then
    log "UP-TO-DATE"
    exit 0
fi

# Tag current image as rollback (swallow error if no image exists yet)
docker tag factory:latest factory:rollback 2>/dev/null || true

# Hard reset to origin/main
git reset --hard origin/main

# Build the factory container
if ! docker compose build factory; then
    log "BUILD-FAILED"
    exit 1
fi

# Deploy the container
docker compose up -d factory

# Poll health endpoint
timeout=60
interval=5
start_time=$(date +%s)

while true; do
    if curl -f http://localhost:8787/api/health >/dev/null 2>&1; then
        log "DEPLOYED $SHORT_CURRENT_SHA"
        exit 0
    fi
    
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    if [ $elapsed -ge $timeout ]; then
        break
    fi
    
    sleep $interval
done

# Rollback if health check failed
log "ROLLED-BACK $SHORT_CURRENT_SHA"
docker tag factory:rollback factory:latest
docker compose up -d factory

# Wait for rollback to be healthy
start_time=$(date +%s)
while true; do
    if curl -f http://localhost:8787/api/health >/dev/null 2>&1; then
        exit 0
    fi
    
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    if [ $elapsed -ge $timeout ]; then
        exit 1
    fi
    
    sleep $interval
done