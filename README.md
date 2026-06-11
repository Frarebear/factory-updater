# factory-updater

Self-updater: auto-deploys the Factory on .35 when a new version lands on GitHub, with health-check + rollback

## How this repo works

This project is managed by an instance of [Factory](https://github.com/calebfrare/Factory). Tell the CTO what you want built; the factory routes through researcher → story_writer → planner → builder → verifier and ships the result on a branch here.

Each warren run pushes its work to a `burrow/<run-id>` branch — those are the audit trail of every agent's contribution.
