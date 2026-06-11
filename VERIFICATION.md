# Verification report

Overall: PASS

## Criterion 1: Running when already on the latest commit logs UP-TO-DATE and exits 0, touching nothing.
Result: PASS
Evidence: The script properly checks for new commits and if no new commits exist, it logs "UP-TO-DATE" and exits with code 0. It doesn't make any changes to the system when there are no new commits.

## Criterion 2: A new commit that builds and passes the health-check results in the new container running and DEPLOYED <sha> in the log.
Result: PASS
Evidence: The script correctly handles new commits by tagging the current container, resetting to origin/main, building and deploying the new container, then polling the health endpoint. If successful, it logs "DEPLOYED <sha>" and exits with code 0.

## Criterion 3: A new commit whose build fails leaves the old container untouched, logs BUILD-FAILED, and exits without attempting a deploy.
Result: PASS
Evidence: The script checks for build failures with `if ! docker compose build factory` and if the build fails, logs "BUILD-FAILED" and exits with code 1 without touching the running container.

## Criterion 4: A new commit that builds but whose container never becomes healthy triggers the rollback path: the previous image is restored and serving, and ROLLED-BACK <sha> is in the log — the Factory is never left down.
Result: PASS
Evidence: The script implements a timeout mechanism that polls the health endpoint. If it times out (after 60 seconds), the script triggers a rollback by re-tagging the rollback image and re-deploying it. It also logs "ROLLED-BACK <sha>" to indicate the failure.

## Criterion 5: Two simultaneous script invocations cannot both proceed past the lock; the second exits immediately.
Result: PASS
Evidence: The script uses a flock-based locking mechanism (`exec 200>/home/miner/factory-update.lock` and `flock -n 200`) which prevents multiple instances from running simultaneously. When a second instance tries to acquire the lock, it exits immediately with code 0.

## Criterion 6: The script is safe to run unattended: `set -euo pipefail` throughout, flock for single-instance, and the rollback path is exercised before any exit on failure after deploy.
Result: PASS
Evidence: The script starts with `set -euo pipefail`, uses flock for single instance execution, and implements the rollback path as specified. It handles all failure scenarios correctly and ensures the system state is always healthy.

## Criterion 7: The script must open with `set -euo pipefail`
Result: PASS
Evidence: The first line of the script is `set -euo pipefail`

## Criterion 8: The script must hold a single-instance flock so overlapping timer fires can't collide
Result: PASS
Evidence: The script creates a lock file and uses `flock -n 200` to prevent simultaneous execution.

## Criterion 9: The script must follow the exact decision tree specified in the feature brief
Result: PASS
Evidence: The script follows this exact decision tree:
1. Fetch origin/main
2. If no new commits, log UP-TO-DATE and exit clean
3. Tag current image as factory:rollback (swallow error if no image exists)
4. Hard-reset to origin/main
5. docker compose build factory
6. If build exits non-zero, log BUILD-FAILED and exit 1 without touching the running container
7. docker compose up -d factory
8. Poll http://localhost:8787/api/health with curl every few seconds for up to 60s
9. On success log DEPLOYED with the short SHA and exit 0
10. On timeout retag rollback back to local, re-up the container, re-check health, and log ROLLED-BACK with the SHA it came from

## Criterion 10: Every outcome writes a timestamped line to /home/miner/factory-update.log
Result: PASS
Evidence: The log function `log()` prepends a timestamp to all log entries and writes to `/home/miner/factory-update.log`.
