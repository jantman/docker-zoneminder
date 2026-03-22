# docker-zoneminder

Modern, best-practices Debian-based Zoneminder container

[![Project Status: WIP – Initial development is in progress, but there has not yet been a stable, usable release suitable for the public.](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)

**IMPORTANT:** This is a personal project only. PRs are accepted, but this is not supported and "issues" will likely not be fixed or responded to. This is only for people who understand the details of everything invovled, sorry.

This repo attempts to provide a modern, best-practices Docker image for current ZoneMinder versions, using a current Debian version base. The image provides ZoneMinder 1.38.1 (compiled from source) on Debian 13 (Trixie) with Apache + PHP 8.4, and includes [go2rtc](https://github.com/AlexxIT/go2rtc) for WebRTC/MSE/HLS live streaming. It requires an external MySQL/MariaDB server (the example docker-compose files use MariaDB 11.8 LTS). The image is vehemently NOT auto-updating, as doing so in a Docker image is a mortal sin. If you want to update, then pull a newer tag.

**NOTE:** If you want to use the event server, then you'll need to mount the appropriate configuration files in to the image at ``/etc/zm/es_rules.json``, ``/etc/zm/zmeventnotification.ini``, and ``/etc/zm/secrets.ini``; examples are included in this repo.

In addition, the output of `mod_status` is exposed at `/server-status`.

**go2rtc:** The image includes go2rtc for modern WebRTC streaming. To use it, set `ZM_GO2RTC_PATH` in ZoneMinder Options → System to the externally-reachable URL of the go2rtc API (e.g., `http://<your-docker-host>:1984/api`). The `/api` suffix is required. Then enable "Go2RTC Live Stream" on individual monitors. Ports 1984 (API/WebSocket) and 8555 (WebRTC) are exposed.

## Usage

### Important Notes

1. This is really only a very simple **demo / example** to show this image working and show what it can do; this method of running is completely unsuitable for real, long-term usage. To use this for real you'll want to set these Docker containers up so they start automatically (i.e. via systemd units), store data in an appropriate place (currently they store data in the directory they're run from), and are properly monitored and backed up (especially backups of the database).
2. I've only tested the following on Linux. It should probably work on Mac. I'm not sure about Windows, I haven't used it since 2006.
3. This image requires a separate, standalone MySQL/MariaDB database. The example docker-compose file runs one, but it's up to you to back the database up as needed.
4. The `/var/cache/zoneminder` volume (events, images, etc.) must be owned by `www-data:www-data` (UID/GID 33) with appropriate permissions (e.g., 775). The container does **not** recursively fix permissions on this volume at startup, as doing so can take tens of minutes on large event stores. If you use a bind mount, ensure the host directory has correct ownership before starting the container.

### Demo via docker-compose

1. Either clone this git repo on the machine where you want to run it, or download the two `docker-compose` files and all of the `EXAMPLE` files to that machine.
2. Remove the `EXAMPLE.` from the example file names, and edit the content of the files as needed. These are all documented elsewhere, and are all related to the ZM Event Notification server (ZMES) and object detection. If you don't care about ZMES and object detection, then these files can just be left as-is.
3. If the `docker-compose` command isn't already available on your system, [install docker-compose](https://docs.docker.com/compose/install/).
4. In whichever docker-compose file you use (or both), change `ghcr.io/jantman/docker-zoneminder:latest` to the newest [versioned tag](https://github.com/jantman/docker-zoneminder/pkgs/container/docker-zoneminder) of the image.
5. From that same directory, `docker-compose up` should start the database and then zoneminder. If you also want the MLAPI object detection, you can use `docker-compose -f docker-compose-mlapi.yml up`

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `ZM_DB_HOST` | `mariadb` | Database hostname |
| `ZM_DB_NAME` | `zm` | Database name |
| `ZM_DB_USER` | `zmuser` | Database user |
| `ZM_DB_PASS` | `zmpass` | Database password |
| `ZM_DB_SSL` | `no` | Set to `yes` to use SSL for MariaDB connections; `no` adds `--skip-ssl` to client commands |
| `TZ` | `America/New_York` | Timezone (also sets PHP timezone) |

## Upgrading from 1.36.x to 1.38.0

ZoneMinder 1.38.0 is a major upgrade from 1.36.x with significant changes including a redesigned monitor function model, role-based access control (RBAC), 79 database schema migrations, and go2rtc-based live streaming replacing Janus/RTSP2Web. The entrypoint handles the database schema migration automatically, but there are several things to be aware of.

A detailed analysis of the changes from 1.36.33 to 1.38.0 can be seen in [docs/upgrade_1.36.33_to_1.38.0.md](docs/upgrade_1.36.33_to_1.38.0.md).

### Before You Upgrade

1. **Back up your database.** The upgrade involves 79 schema migrations. While `zmupdate.pl` handles this, a backup is essential in case something goes wrong.
2. **Back up your event files** (`./cache/` or wherever your `/var/cache/zoneminder` volume is mounted).
3. **Update your docker-compose file.** MariaDB has been upgraded from 11.1 to 11.8 LTS. The compose file format has also changed (removed deprecated `version` key, `links` replaced with `depends_on`, new go2rtc ports). See the included `docker-compose.yml` for reference.

### Upgrade Steps

1. Stop your existing containers: `docker-compose down`
2. Pull or build the new image.
3. Update your `docker-compose.yml`:
   - Change the MariaDB image to `mariadb:11.8`
   - Add go2rtc port mappings: `1984:1984` and `8555:8555`
4. Start the containers: `docker-compose up`
5. The entrypoint will detect the database version mismatch (1.36.x vs 1.38.0) and automatically run `zmupdate.pl` to migrate the schema. This may take a few minutes.

### After Upgrading

- **Monitor Function changes:** ZM 1.38 splits the old single `Function` field into three separate fields: `Capturing`, `Analysing`, and `Recording`. Your existing monitors will be migrated automatically, but review them to ensure the new settings are correct.
- **Live streaming:** Janus and RTSP2Web are no longer the recommended live stream methods. Use go2rtc instead (see below).
- **ZMES compatibility:** The ZM Event Notification Server (v6.1.29) predates ZM 1.38 and may have issues with the new monitor function model. Test your event hooks carefully.

### Known Issues

- **MQTT segfault on Trixie:** There are [reports](https://forums.zoneminder.com/viewtopic.php?p=139150) of ZM 1.38 crashing with MQTT enabled on Debian 13. MQTT support is compiled in but use it with caution.
- **Database upgrade "Incorrect datetime" error:** If the schema migration fails with a datetime error, you may need to run `TRUNCATE Monitor_Status;` on the database manually, then restart the container. See [this forum thread](https://forums.zoneminder.com/viewtopic.php?t=34263).

## Enabling go2rtc (WebRTC Live Streaming)

The image includes [go2rtc](https://github.com/AlexxIT/go2rtc) v1.9.14 for modern WebRTC/MSE/HLS live streaming, replacing the older Janus and RTSP2Web methods. go2rtc runs automatically as an s6 service inside the container.

### Setup

1. In the ZoneMinder web UI, go to **Options → System**.
2. Set **GO2RTC_PATH** to the externally-reachable URL of the go2rtc API: `http://<your-docker-host>:1984/api`. The `/api` suffix is required — ZoneMinder appends `/streams` and `/ws` to this path. This URL must be reachable from the browser, not just from inside the container.
3. Save the settings.
4. On each monitor, set the live stream type to **Go2RTC**.

### Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 1984 | HTTP | go2rtc API and WebSocket |
| 8554 | TCP | RTSP relay (internal) |
| 8555 | TCP/UDP | WebRTC |

### Troubleshooting

- Verify go2rtc is running: `curl http://localhost:1984/api` should return a JSON response with the go2rtc version.
- Check registered streams: `curl http://localhost:1984/api/streams` — after configuring GO2RTC_PATH and enabling Go2RTC on a monitor, you should see the monitor's stream listed here. If it returns `{}`, streams are not being registered (see below).
- The go2rtc web UI is available at `http://localhost:1984/` for debugging stream issues.
- **"Go2RTC loading" with no video:** Make sure `GO2RTC_PATH` ends with `/api`. ZoneMinder appends `/streams` to this URL, so without the `/api` suffix it hits the wrong go2rtc endpoint and streams silently fail to register. After fixing the URL, restart ZoneMinder (`zmpkg.pl restart` inside the container) to re-register streams.

## Development

1. Cut a branch and make some changes. Ideally build the Docker image locally to ensure it builds. Cut a PR. That will trigger a build, and will push the resulting image to Docker Hub with a tag of the commit SHA.
2. Test that image.
3. When the image is verified to work, merge the PR to `main`.
4. Add a new release version tag for main and push it; that will trigger a full release build and release the new version.
