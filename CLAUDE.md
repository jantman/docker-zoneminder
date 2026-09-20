# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker image for ZoneMinder 1.38.4 (video surveillance) on Debian 13 (Trixie), using Apache + PHP 8.4. ZoneMinder is installed from the official ZoneMinder Debian packages (`zmrepo.zoneminder.com`); Debian's own `zoneminder` package is 1.36.x and is not usable here. Requires an external MySQL/MariaDB database (not bundled). Includes the ZM Event Notification Server (ZMES) — zmeventnotificationNg 7.0.31 with pyzmNg 2.5.3 — for event-driven object detection via WebSocket on port 9000, and go2rtc for WebRTC/MSE/HLS live streaming. This is a personal WIP project (MIT license).

Both ZMES and `pyzm` are pinned to upstream releases: `ZMES_VERSION=v7.0.31` (a git tag)
and `PYZM_VERSION=2.5.3` (PyPI). Two upstream fixes this deployment depends on set a
floor under those pins — **do not pin below them**:

| Component | Floor | Why |
|---|---|---|
| zmeventnotificationNg | `v7.0.30` | [#49](https://github.com/ZoneMinder/zmeventnotificationNg/pull/49) joins config zone patterns onto ZM zone geometry by name, so `objectconfig.yml` can drop every `coords:` and set `import_zm_zones: "yes"` |
| pyzmNg | `2.5.2` | [#69](https://github.com/ZoneMinder/pyzmNg/pull/69) `zone_match_strategy`, which `objectconfig.yml` sets to `first_intersecting` to restore ES 6 zone resolution. Zone filtering runs here, client-side in `pyzm.ml.filters`, not in the gateway |

Images `1.38.4-jantman1-fork` and earlier built these two commits from forks pinned by SHA,
and carried the `-fork` version suffix; that is over, and releases from here on drop the
suffix. The build-time marker assertions that guarded those SHAs (`normalize_zone_name`,
`ZoneMatchStrategy`) are gone with them — a release tag and a PyPI version say what they
are, which is what the assertions existed to prove.

The fork pins are still reachable only because `jantman/zmeventnotificationNg` and
`jantman/pyzmNg` carry the annotated tags `image-pin-pr49` and `image-pin-pr67-pr69` on
those commits. **Do not delete those tags while `1.38.4-jantman1-fork` is a release anyone
might rebuild.**

ZoneMinder itself comes from the `zmrepo` flat repository
(`deb https://zmrepo.zoneminder.com/debian/release-1.38 trixie/`), pinned to an exact
version by `ARG ZM_VERSION`. Four things about that are easy to get wrong:

- **`ZM_VERSION` is the full Debian version string**, `1.38.4+trixie1`, not `1.38.4`. The
  separator before the vendor suffix changed mid-series (`1.38.2-trixie1`, then
  `1.38.3+trixie1`), so it cannot be reconstructed from the upstream version.
- **The package would pull systemd and rsyslog** through `policykit-1 | pkexec` and
  `rsyslog | system-log-daemon`. Neither is reachable here — `zmsystemctl.pl` is the only
  polkit consumer and `zmpkg.pl` only calls it when PID 1 is systemd, which it never is —
  so a dummy `.deb` built with `dpkg-deb` stands in for both. **Do not use `equivs`**: it
  leaves ~9.8 MB of orphans behind, more than the systemd it saves.
- **`ZM_DIR_CACHE` is `/var/cache/zoneminder/cache`** under the package, not
  `/var/cache/zoneminder`. It is a compiled-in `define` in `www/includes/config.php` and
  cannot be overridden from `conf.d`, so `content/zm-site.conf`'s `Alias /cache` has to
  track it.
- **`ZM_PCRE=0`**, because the packages are not built against libpcre2. The sole effect is
  that the "Regexp" HTTP source method disappears from the monitor dropdown. This is an
  accepted loss — do not rebuild from source, patch the package, or add libpcre2 to try to
  win it back; the flag is compiled in.

Two more traps worth knowing: the package's postinst rewrites `/etc/zm` ownership and modes
to its own preference, so the image's `chown`/`chmod` must come after the install; and
`zmpkg.pl`'s `verifyFolder()` `mkdir`s `/var/tmp/zm` at every start, so its absence from a
built image is not a defect and nothing should create it redundantly.

The image is deliberately **CPU-only**: no CUDA, no GPU libraries, no CUDA-enabled OpenCV. It performs no inference; a separate remote gateway does. Keeping GPU libraries out prevents an accidental local-inference fallback from masking a gateway outage. `pyzm` is installed with the `[ml]` extra only — never `[serve]` or `[full]`, which pull ultralytics/fastapi.

## Build and Test

**Build the Docker image locally:**
```
docker build -t docker-zoneminder:dev .
```

**Run locally with docker-compose (ZoneMinder + MariaDB):**
```
docker-compose up
```

**Run with GPU object detection (requires an NVIDIA GPU + Container Toolkit):**
```
docker-compose -f docker-compose-pyzm-serve.yml up
```

ZoneMinder will be available at `http://localhost:8080` after startup.

There is no automated test suite. Verification is manual: build the image and run it via docker-compose.

## CI/CD

- **Push to main / PR to main** (`build.yml`): Builds image, pushes to GHCR as an untagged package.
- **Git tag push** (`release.yml`): Builds and pushes to GHCR with version tag + `latest`, creates a GitHub Release with image info and changelog.
- All GitHub Actions checks must pass before merging PRs.

## Architecture

### Container Internals

- **Base:** Debian 13.6 (Trixie) with ZoneMinder 1.38.4 from the `zmrepo` package `1.38.4+trixie1`
- **Build:** Single-stage Dockerfile — adds the zmrepo apt source (key pinned by fingerprint, scoped with `signed-by`), installs `zoneminder=${ZM_VERSION}`, then layers ZMES, pyzm and go2rtc on top
- **Event server:** `zmeventnotification.pl` in `/usr/bin`, its `ZmEventNotification::*` Perl modules in `/usr/share/perl5/ZmEventNotification/`, hook scripts and the Pushover plugin in `/var/lib/zmeventnotification/bin/`
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

- `Dockerfile` - Single-stage image build
- `entrypoint.sh` - Container startup script
- `content/` - Files copied into the image during build (Apache config, s6 service scripts, go2rtc)
  - `content/zm-site.conf` - Apache VirtualHost config
  - `content/zmcustom.conf` - ZoneMinder custom config
  - `content/status.conf` - Apache mod_status config
  - `content/go2rtc-run` - s6 service script for go2rtc
  - `content/go2rtc.yaml` - go2rtc configuration (API on :1984, WebRTC on :8555)
- `docker-compose.yml` - Basic demo (ZM + MariaDB)
- `docker-compose-pyzm-serve.yml` - Extended demo adding the `docker-pyzm-serve` GPU inference gateway (`ghcr.io/jantman/docker-pyzm-serve`), which replaced the ES 6-era `docker-zm-mlapi`

### Configuration Files (Not Committed)

Sensitive config files are `.gitignore`d. Example versions are provided:

| Config File | Example File | Mount Point |
|------------|-------------|-------------|
| `secrets.yml` | `secrets.EXAMPLE.yml` | `/etc/zm/secrets.yml` |
| `zmeventnotification.yml` | `zmeventnotification.EXAMPLE.yml` | `/etc/zm/zmeventnotification.yml` |
| `objectconfig.yml` | `objectconfig.EXAMPLE.yml` | `/etc/zm/objectconfig.yml` |
| `es_rules.yml` | `es_rules.EXAMPLE.yml` | `/etc/zm/es_rules.yml` |

These are YAML as of ES 7; ES 6 used INI/JSON at the corresponding `.ini`/`.json` paths. Config files still use `!VARIABLE_NAME` template syntax for variable substitution (e.g., `!ZM_PORTAL`, `!ZM_USER`).

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
