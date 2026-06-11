# Research: Factory Auto-Updater System

## 1. File map

The following files are most relevant for implementing the factory auto-updater system:

1. **`factory-update.sh`** - The core script that implements the deployment logic, including fetching new commits, building, deploying, health checking, and rollback handling
2. **`factory-update.service`** - Systemd service file that executes the oneshot script
3. **`factory-update.timer`** - Systemd timer file that triggers the service every 2 minutes
4. **`README.md`** - Documentation covering installation, prerequisites, and usage
5. **`/home/miner/factory-update.log`** - Log file where all deployment events are timestamped

## 2. Existing patterns

This project follows an autonomous software factory pattern where features are requested through issues and built by a series of agents (researcher → story_writer → planner → builder → verifier). Based on the existing project structure:

- No existing bash scripts, systemd units, or Docker related files exist yet - this is entirely new functionality
- The project uses a standard multi-file repository structure with git and systemd integration patterns
- The system follows typical Unix conventions where system services and timers are managed via systemd
- No existing patterns for this exact type of self-updating mechanism can be found

## 3. Similar features already built

From the existing project structure, there are no similar features in the codebase. However, based on the system architecture and deployment patterns:

- The concept of self-updating systems is standard in DevOps practices
- The pattern of building container images and health-checking deployments is widely used in CI/CD pipelines
- Systemd timer and service units are standard mechanisms in Linux system administration

## 4. Risks

Several risks need careful consideration for this deployment system:

- **Race conditions**: Multiple simultaneous script executions - handled by flock locking
- **Service downtime**: The Factory must never be left in a stopped or unhealthy state - mitigated by rollback path
- **Build failures**: Containers that fail to build should not interrupt the system - handled by early exit with BUILD-FAILED
- **Health check timeouts**: The rollback system must be robust against timeout scenarios
- **Idempotency**: Running the same update twice shouldn't cause issues - ensured through the atomic check/apply/rollback process
- **Missing dependencies**: The script must be very defensive about required tools (git, docker-compose, curl)
- **Log file access**: The log file must be properly managed to avoid corruption
- **Container state management**: Ensuring clean state transitions between old and new container versions
- **Network availability**: The script should handle network timeouts gracefully when checking for new commits
- **Disk space**: Ensure sufficient space for both old and new containers during update

## 5. Tests that will need updating

The system will require comprehensive testing that covers:

- **Unit testing**: Script testing for edge cases like no new commits, build failures, health check timeouts
- **Integration testing**: Full deployment flow testing including rollback path
- **System testing**: End-to-end testing of the systemd integration 
- **Load testing**: Simulating concurrent access to test flock behavior
- **Stress testing**: Testing in scenarios of network issues, disk full, and container failures
- **Validation testing**: Ensuring proper logging across all scenarios

## 6. Open questions

There are several important aspects of the brief that can be clarified:

1. **FACTORY_DIR location**: The brief mentions FACTORY_DIR must be a git checkout. What is the expected default? Should it be configurable?
2. **Docker compose configuration**: What are the expected names and structure of the docker compose services? 
3. **Health check endpoint**: The brief specifies `http://localhost:8787/api/health` - should this be configurable or is this fixed?
4. **Log location and permissions**: Should the log file be created in a different location than /home/miner/? Can we assume write permissions?
5. **System dependencies**: What are the exact dependencies that need to be present (git, docker-compose, curl, flock)? Should they be checked at startup?
6. **Rollback logic**: When rolling back, should we attempt to re-tag and use the previous image, or rebuild from source?
7. **Timeout value**: The description says "poll ... for up to 60 s". Is 60s a hard requirement or should it be configurable?

The project is entirely new in these areas since it's about to establish a self-updating system for itself, so there's no existing functionality to reference for similar implementations in this codebase.