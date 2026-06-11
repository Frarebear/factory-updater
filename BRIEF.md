# Technical Brief: Factory Update System with Rollback

## Overview
This feature implements a fully unattended deploy loop for the Factory application. Every 2 minutes, a systemd timer triggers a script that checks for new commits, builds a new container, and deploys it with automatic rollback capability if the new version is unhealthy.

## Data Model Changes
None - this feature is purely infrastructure/ops related.

## Process Flow
1. **Synchronous Process**: 
   - Systemd timer fires every 2 minutes
   - Oneshot service executes factory-update.sh
   - Script follows decision tree:
     - Fetch origin/main
     - If no new commits, log UP-TO-DATE and exit
     - Tag current image as rollback
     - Hard-reset to origin/main
     - Build new container
     - If build fails, log BUILD-FAILED and exit
     - Deploy new container
     - Poll health endpoint for 60 seconds
     - If healthy, log DEPLOYED and exit
     - If timeout, rollback and log ROLLED-BACK

2. **Background Process**:
   - factory-update.timer runs every 2 minutes
   - factory-update.service executes the script as oneshot

## API Changes
None - this is infrastructure deployment tooling.

## Frontend Changes
None - this is server-side deployment infrastructure.

## Tests Required
1. **Success case**: New commit builds and passes health check → DEPLOYED log entry
2. **Build failure case**: New commit fails build → BUILD-FAILED log entry, no deployment
3. **Health failure case**: New commit builds but fails health check → ROLLED-BACK log entry
4. **No new commits**: Already up-to-date → UP-TO-DATE log entry, no deployment
5. **Concurrency**: Second script invocation during first execution → exits immediately
6. **Rollback behavior**: When rollback is triggered, previous image reinstated and healthy

## Risks + Open Questions
1. What happens if the rollback image is corrupted/missing?
2. What's the exact expected format for the FACTORY_DIR environment variable?
3. How should the script handle cases where docker compose is not available?
4. Should we consider race conditions in the rollback tagging process?
5. How should the script handle git errors or network issues?

## Files to be Created
1. `/home/miner/factory-update.sh` - Main update script
2. `/etc/systemd/system/factory-update.service` - Systemd service
3. `/etc/systemd/system/factory-update.timer` - Systemd timer
4. `/home/miner/README.md` - Documentation