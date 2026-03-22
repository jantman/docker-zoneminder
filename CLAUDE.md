# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker image for ZoneMinder 1.38.1 (video surveillance) on Debian 13 (Trixie), using Apache + PHP 8.4. ZoneMinder is compiled from source in a multi-stage Docker build. Requires an external MySQL/MariaDB database (not bundled). Includes the ZM Event Notification Server (ZMES) for event-driven object detection via WebSocket on port 9000, and go2rtc for WebRTC/MSE/HLS live streaming. This is a personal WIP project (MIT license).

## Build and Test

**Build the Docker image locally:**
```
docker build -t docker-zoneminder:dev .
```

**Run locally with docker-compose (ZoneMinder + MariaDB):**
```
docker-compose up
```

**Run with MLAPI object detection:**
```
docker-compose -f docker-compose-mlapi.yml up
```

ZoneMinder will be available at `http://localhost:8080` after startup.

There is no automated test suite. Verification is manual: build the image and run it via docker-compose.

## CI/CD

- **Push to main / PR to main** (`build.yml`): Builds image, pushes to Docker Hub tagged with commit SHA.
- **Git tag push** (`release.yml`): Builds and pushes to both Docker Hub and GHCR with version tag + `latest`, creates a GitHub Release.
- All GitHub Actions checks must pass before merging PRs.

## Architecture

### Container Internals

- **Base:** Debian 13.4 (Trixie) with ZoneMinder 1.38.1 compiled from source
- **Build:** Multi-stage Dockerfile — builder stage compiles ZM with cmake, runtime stage contains only what's needed to run
- **Process supervision:** s6 (`s6-svscan`) manages multiple services:
  - `/etc/services.d/apache2/run` - Apache web server
  - `/etc/services.d/zoneminder/run` and `finish` - ZoneMinder daemon
  - `/etc/services.d/go2rtc/run` - go2rtc streaming server
- **Entrypoint** (`entrypoint.sh`): Injects `ZM_DB_*` env vars into `/etc/zm/zm.conf`, waits for MariaDB, initializes the database schema on first run, then starts s6
- **Ports:** 80 (Apache/HTTP), 9000 (ZMES WebSocket), 1984 (go2rtc API/WebSocket), 8555 (go2rtc WebRTC)
- **Volumes:** `/var/cache/zoneminder` (events/images), `/var/log/zm` (logs)

### Key Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `ZM_DB_HOST` | `mariadb` | Database hostname |
| `ZM_DB_NAME` | `zm` | Database name |
| `ZM_DB_USER` | `zmuser` | Database user |
| `ZM_DB_PASS` | `zmpass` | Database password |
| `ZM_DB_SSL` | `no` | Set to `yes` to use SSL for MariaDB connections; `no` adds `--skip-ssl` |
| `TZ` | `America/New_York` | Timezone (also sets PHP timezone) |

### File Layout

- `Dockerfile` - Multi-stage image build (builder + runtime)
- `entrypoint.sh` - Container startup script
- `content/` - Files copied into the image during build (Apache config, s6 service scripts, ZMES, go2rtc)
  - `content/zmeventnotification/` - ZMES submodule (event server, hooks, object detection)
  - `content/zm-site.conf` - Apache VirtualHost config
  - `content/zmcustom.conf` - ZoneMinder custom config
  - `content/status.conf` - Apache mod_status config
  - `content/go2rtc-run` - s6 service script for go2rtc
  - `content/go2rtc.yaml` - go2rtc configuration (API on :1984, WebRTC on :8555)
- `docker-compose.yml` - Basic demo (ZM + MariaDB)
- `docker-compose-mlapi.yml` - Extended demo with ML API service

### Configuration Files (Not Committed)

Sensitive config files are `.gitignore`d. Example versions are provided:

| Config File | Example File | Mount Point |
|------------|-------------|-------------|
| `secrets.ini` | `secrets.EXAMPLE.ini` | `/etc/zm/secrets.ini` |
| `zmeventnotification.ini` | `zmeventnotification.EXAMPLE.ini` | `/etc/zm/zmeventnotification.ini` |
| `objectconfig.ini` | `objectconfig.EXAMPLE.ini` | `/etc/zm/objectconfig.ini` |
| `es_rules.json` | `es_rules.EXAMPLE.json` | `/etc/zm/es_rules.json` |

Config files use `!VARIABLE_NAME` template syntax for variable substitution (e.g., `!ZM_PORTAL`, `!ZM_USER`).

## Feature Development Workflow

**You MUST read and follow `docs/features/README.md` before working on any feature.** Key rules:

- Work on feature branches, never directly on `main`.
- Plan one feature at a time; get human approval before proceeding.
- Non-trivial features use Milestones and Tasks with commit message prefixes: `{Feature Name} - {Milestone}.{Task}`.
- At end of every Milestone/Feature: update feature doc, ensure Docker image builds, commit, open PR.
- Every feature ends with an "Acceptance Criteria" milestone that updates `README.md` and `CLAUDE.md`.
- Completed feature docs move from `docs/features/` to `docs/features/completed/`.
- If confused or stuck, stop and ask for human guidance.

## Release Process

1. Branch from `main`, make changes, build locally to verify.
2. Open PR to `main` (triggers CI build).
3. After merge, tag `main` with a version and push the tag to trigger release build.
