# Verification report

Overall: FAIL

## Criterion 1: Running when already on the latest commit logs UP-TO-DATE and exits 0, touching nothing.
Result: FAIL
Evidence: The condition checking for new commits is fundamentally flawed:
```bash
if git rev-parse HEAD@{origin/main} >/dev/null 2>&1 && \
   [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ]; then
```
The `HEAD@{origin/main}` syntax is incorrect - it should be checking if `HEAD` equals `origin/main` directly without the `@{origin/main}` part. This will cause the script to always proceed with deployment even when there are no new commits.

## Criterion 2: A new commit that builds and passes the health-check results in the new container running and DEPLOYED <sha> in the log.
Result: FAIL
Evidence: There's a critical bug with SHA tracking. The script captures:
- `CURRENT_SHA=$(git rev-parse HEAD)` 
- `SHORT_CURRENT_SHA=$(git rev-parse --short HEAD)`
Before doing `git reset --hard origin/main`. After the reset, these variables still contain the OLD SHA from before the reset. Then when it logs "DEPLOYED $SHORT_CURRENT_SHA", it's actually logging the previous SHA, not the new one that was deployed.

## Criterion 3: A new commit whose build fails leaves the old container untouched, logs BUILD-FAILED, and exits without attempting a deploy.
Result: PASS
Evidence: The script correctly detects build failures with:
```bash
if ! docker compose build factory; then
    log "BUILD-FAILED"
    exit 1
fi
```
And exits cleanly without deploying.

## Criterion 4: A new commit that builds but whose container never becomes healthy triggers the rollback path: the previous image is restored and serving, and ROLLED-BACK <sha> is in the log — the Factory is never left down.
Result: FAIL
Evidence: The rollback logic exists but is flawed:
1. It uses the same `SHORT_CURRENT_SHA` which, as noted in Criterion 2, is incorrect 
2. The rollback section attempts to tag the rollback image back and restart, but with potentially wrong SHA
3. The health check wait loop after rollback could also be incorrect due to wrong SHA

## Criterion 5: Two simultaneous script invocations cannot both proceed past the lock; the second exits immediately.
Result: FAIL
Evidence: The flock implementation is not correctly set up. The script uses:
```bash
if ! flock -n -x 99; then
    log "Another instance is already running, exiting"
    exit 0
fi
```
However, flock is set up on file descriptor 99 without actually opening or referencing a lock file. This means it won't actually prevent concurrent execution properly. The script will fail to block concurrent invocations correctly.

## Criterion 6: The script is safe to run unattended: `set -euo pipefail` throughout, flock for single-instance, and the rollback path is exercised before any exit on failure after deploy.
Result: FAIL
Evidence: While `set -euo pipefail` is present, the implementation has the significant issues in criteria 1, 2, 4, and 5 that make it unsafe for unattended operation.

## Criterion 7: The rollback path is as important as the happy path. 
Result: FAIL
Evidence: While rollback mechanism exists, it's based on incorrect SHA tracking and flawed logic making it potentially unsafe (as shown in Criterion 4).

## Criterion 8: Every outcome writes a timestamped line to /home/miner/factory-update.log.
Result: FAIL
Evidence: The log function exists and uses `>> "$LOGFILE"` which appends, but the logging relies on correct SHA values (as per Criterion 2), which are incorrect in the script.

## Criterion 9: Must follow the exact decision tree specified in the feature brief.
Result: FAIL
Evidence: The script doesn't follow the specification exactly:
1. The "fetch origin/main" is done but the new commit checking logic is faulty
2. The decision tree doesn't properly distinguish between "no new commits" vs. "new commits"
3. The SHA tracking doesn't accurately reflect what was deployed vs. what was rolled back
4. The logging of outcomes is incorrect due to SHA tracking issues
5. The lock mechanism and file path handling for /tmp/factory-update.lock is not properly implemented

## Criterion 10: Script must be executable
Result: PASS
Evidence: The file `/workspace/home/miner/factory-update.sh` has executable permissions (-rwxr-xr-x).

## Criterion 11: Script must be executable by user miner 
Result: PASS
Evidence: The file is owned by the correct user and has execute permissions.