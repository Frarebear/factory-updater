# factory-updater

Self-updater for the [Factory](https://github.com/Frarebear/Factory). A systemd
timer polls GitHub every 2 minutes; when `origin/main` moves ahead of the
deployed checkout it rebuilds and redeploys the factory — **with a health-check
and automatic rollback** so a bad commit can never leave the box down.

## How it works (`factory-update.sh`)

1. `git fetch origin main`; if the local checkout already equals `origin/main`, exit quietly.
2. Snapshot the running image: `docker tag factory:local factory:rollback`.
3. `git reset --hard origin/main` → `docker compose build factory`.
   - **Build fails** → log `BUILD-FAILED`, exit. The old container keeps serving; nothing was swapped.
4. `docker compose up -d factory`, then poll `/api/health` for up to 90s.
   - **Healthy** → log `DEPLOYED <sha>`. Done.
   - **Unhealthy** → restore the snapshot (`docker tag factory:rollback factory:local`),
     redeploy, re-verify, log `ROLLED-BACK`. The factory is never left down.

A `flock` guarantees one run at a time. All outcomes are timestamped in
`/home/miner/factory-update.log`.

## Install (on the `.35` host)

Prerequisites: `FACTORY_DIR` (default `/home/miner/factory`) is a **git checkout**
of the Factory repo on `main`, with `docker compose` available and the factory
running under the image tag `factory:local`.

```sh
sudo install -m 755 factory-update.sh /home/miner/factory-update.sh
sudo install -m 644 factory-update.service /etc/systemd/system/factory-update.service
sudo install -m 644 factory-update.timer   /etc/systemd/system/factory-update.timer
sudo systemctl daemon-reload
sudo systemctl enable --now factory-update.timer
```

Check it: `systemctl status factory-update.timer` and `tail -f /home/miner/factory-update.log`.

## Config

Override via the environment in `factory-update.service` if needed:
`FACTORY_DIR`, `LOG`, `HEALTH`, `HEALTH_TIMEOUT`.
