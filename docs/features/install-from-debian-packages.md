# Install ZoneMinder from the official Debian packages

You must read, understand, and follow all instructions in `./README.md` when planning and
implementing this feature.

Tracking issue: [#24](https://github.com/jantman/docker-zoneminder/issues/24)

Supersedes the investigation on [#11](https://github.com/jantman/docker-zoneminder/issues/11)
/ [#23](https://github.com/jantman/docker-zoneminder/pull/23), whose findings are summarised
below so they survive whatever disposition that PR gets. Its two prototype Dockerfiles were
temporary by design and are not carried forward.

## Overview

This image compiles ZoneMinder from source in a builder stage, because work on the 1.38.0
upgrade started the day before ZoneMinder published official Debian packages for 1.38.
Official `.deb`s now exist for Trixie at the exact version we ship, so the builder stage is
no longer the only way to get 1.38.4 onto Debian 13. Replace it with an `apt-get install`
from the ZoneMinder project's own repository.

### Why

- **The source build ships a defect.** `ffmpeg` is not installed in the builder stage where
  `cmake` runs, so feature detection fails and the image seeds every fresh database with
  `ZM_OPT_FFMPEG=0` and `ZM_PATH_FFMPEG=FFMPEG_EXECUTABLE-NOTFOUND`. A fresh install from
  the current image starts with ffmpeg video encoding disabled. The same root cause leaves
  `ZM_PATH_ARP`, `ZM_PATH_ARP_SCAN`, `ZM_PATH_IP` and `ZM_PATH_IFCONFIG` empty. The package
  gets all of these right: its `zm_create.sql` seeds `ZM_OPT_FFMPEG` with `Value = '1'` and
  its `conf.d/01-system-paths.conf` carries absolute paths for the rest.
- The builder stage is the slowest and most fragile part of the build: a full git clone with
  submodules, ~40 `-dev` packages and a `make -j$(nproc)` C++ compile on every cache miss.
- The `cmake` flags are a hand-maintained re-derivation of what the Debian packaging already
  encodes, and two of them are demonstrably wrong (above).
- Version bumps become a version-string change rather than a recompile.

### What must be true when this is done

1. ZoneMinder 1.38.4 runs, at version parity with what the image ships today.
2. A fresh install has ffmpeg video encoding enabled.
3. ZoneMinder is still served at `/` (not `/zm`), and every URL path the image serves today
   still resolves — including `/cache`, whose backing directory the package places
   differently.
4. ZMES, `pyzm`, `zmes_hook_helpers` and go2rtc are untouched and still pass the build-time
   smoke test.
5. The CPU-only constraint holds: no CUDA, no GPU libraries, no GPU-enabled OpenCV, and
   `pyzm` still installed with the `[ml]` extra only.
6. The image gains no init system, policy daemon, message bus or syslog daemon.
7. The image builds in CI and starts successfully against an external MariaDB via
   `docker-compose up`.
8. `README.md` and `CLAUDE.md` no longer describe ZoneMinder as compiled from source, and
   the loss of the Regexp HTTP source method is noted where users would look for it.

## Milestones

### Milestone 1: Replace the source build with the package

Commit prefix: `Debian Packages - 1.{task}`

**Task 1.1: Add the ZoneMinder apt repository.** Flat repo
`deb https://zmrepo.zoneminder.com/debian/release-1.38 trixie/`, signed by the zmrepo key.
Pin the key by fingerprint at build time and scope it to this one source with `signed-by=`
rather than dropping it into `trusted.gpg.d`, so a substituted key fails the build loudly
and the key cannot vouch for Debian's own archives.

**Task 1.2: Stand in for the two unreachable `Depends`.** `policykit-1 | pkexec` and
`rsyslog | system-log-daemon` are both satisfied by a dummy package built with `dpkg-deb`.
See "Dependency creep" below for why this is safe and why `equivs` is not used.

**Task 1.3: Delete the builder stage and install the package.** Single stage now; the only
other thing the builder stage did was `git clone` ZMES, which moves into the runtime stage
(`git` is already a runtime dependency). Drop from the explicit apt list everything the
`zoneminder` package now declares as a `Depends` — the whole ZoneMinder Perl module wall,
`ffmpeg`, `sudo`, `zip`, `javascript-common`, `arp-scan`, `net-tools`, `iproute2`, the
`php-*` extensions and the ZM shared libraries. Also drop `libpcre2-8-0` and `libunwind8`:
`readelf -d` on the packaged `zmc` confirms it links neither.

**Task 1.4: Follow `ZM_DIR_CACHE` in the Apache vhost.** The package compiles
`ZM_DIR_CACHE` as `/var/cache/zoneminder/cache`, not `/var/cache/zoneminder`. This is a
`define` in `www/includes/config.php`, not overridable from `conf.d`, so `content/zm-site.conf`
must follow it. `cache_bust()` in `www/includes/functions.php` is the only producer of
`/cache` URLs and it symlinks into `ZM_PATH_WEB`, so the existing `+FollowSymLinks` stays.

**Task 1.5: Drop the directories the package build no longer uses.** `/var/lib/zoneminder`
was the source build's `ZM_CONTENTDIR` and nothing in the tree reads it; the package ships
`/var/lib/zm` itself. `/tmp/zm` was the source build's `ZM_TMPDIR`; the package uses
`/var/tmp/zm`, and `zmpkg.pl`'s `verifyFolder()` `mkdir`s it at every start, so neither the
Dockerfile nor the entrypoint should create it.

### Milestone 2: Verify

Commit prefix: `Debian Packages - 2.{task}`

**Task 2.1:** Build the image locally and confirm the build-time smoke test passes.

**Task 2.2:** Run it via `docker-compose up` against MariaDB 11.8 on an empty database and
confirm: the schema seeds, `ZM_OPT_FFMPEG`/`ZM_PATH_FFMPEG` are right in the seeded
`Config` table, `/` serves ZoneMinder, `/cache`, `/cgi-bin` and `/api` resolve, the ZM
daemons come up valid under `zmdc.pl`, and there are no errors in `/var/log/zm` or the
container log.

**Task 2.3:** Confirm requirement 6 — no `systemd`, `polkit`, `dbus` or `rsyslog`, and no
`/sbin/init` — and requirement 5 — no CUDA/GPU packages.

### Milestone 3: Acceptance Criteria

Commit prefix: `Debian Packages - 3.{task}`

**Task 3.1:** Update `README.md` and `CLAUDE.md`: no longer "compiled from source", and
record the loss of the Regexp HTTP source method under Known Issues.

**Task 3.2:** Move this file to `docs/features/completed/`.

## Findings carried forward from the #11 investigation

### The package is a faithful substitute

Diffing a package-built image against the current release image (`1.38.4-jantman2`):

- 5,625 shared file paths; 44 differ in content, and 32 of those are PNGs that Debian
  re-compresses — decoding every pair confirms they are pixel-identical. That leaves 12 real
  differences.
- The `ZoneMinder`, `ONVIF` and `WSDiscovery` Perl module trees are path-identical.
- The `www` tree is path-identical apart from one added symlink (`api/app/tmp -> /var/tmp`).
- Exactly one shared path differs in mode or ownership, and it is `/etc/passwd-`.
- `zmeventnotification.pl` is byte-identical, so ZMES is genuinely unaffected.

Both prototypes were run, not just diffed: the database seeds, `/` redirects to the
first-run privacy page and it renders, all five ZM daemons report valid under `zmdc.pl`, and
there are no errors in `/var/log/zm` or the container log.

### Compile-time differences that carry behaviour

| Setting | Source build | Package | Consequence |
|---|---|---|---|
| `ZM_OPT_FFMPEG` / `ZM_PATH_FFMPEG` | `no` / not-found | `yes` / `/usr/bin/ffmpeg` | The motivating fix |
| `ZM_PATH_ARP`, `_ARP_SCAN`, `_IP`, `_IFCONFIG` | empty | absolute paths | Package is better |
| `ZM_DIR_CACHE` | `/var/cache/zoneminder` | `/var/cache/zoneminder/cache` | Task 1.4 |
| `ZM_TMPDIR` (`ZM_DIR_EXPORTS`, `ZM_PATH_SWAP`) | `/tmp/zm` | `/var/tmp/zm` | Task 1.5; self-healing |
| `ZM_PCRE` | `1` | `0` | Accepted loss — see below |
| `ZM_PATH_ZMS` | `/cgi-bin/nph-zms` | `/zm/cgi-bin/nph-zms` | No action — `content/zmcustom.conf` already overrides it and sorts after the package's `01-system-paths.conf` in `conf.d` |
| `ZM_PATH_API` | `/zm/api` | `/zm/api` | No change; the source build never overrode the cmake default either |
| X10 support | excluded | included | Harmless |

### Accepted trade-off: the Regexp HTTP source method

The official packages are not built against libpcre2, so `ZM_PCRE=0`. Its sole effect
anywhere in the tree is that the "Regexp" HTTP method disappears from the monitor
source-type dropdown, affecting remote HTTP cameras; monitors using it must move to the
Simple method. This is decided, not open: do not rebuild from source to regain it, do not
patch the package, and do not add libpcre2 and expect it to take effect — the flag is
compiled in.

### Dependency creep, and that it is avoidable

The `zoneminder` package has two alternative `Depends` a container does not want:

- `policykit-1 | pkexec` → resolves to a chain ending in **systemd**, making `/sbin/init` a
  symlink to it.
- `rsyslog | system-log-daemon` → resolves to **rsyslog**, never started.

Neither is reachable here. `zmsystemctl.pl` is the only polkit consumer (`pkexec` is its
shebang), and its only caller invokes it solely when PID 1 is systemd — PID 1 here is
`s6-svscan`. Nothing logs to syslog; ZoneMinder logs to `/var/log/zm` and the supervised
services log to the container's stdout.

Both alternative targets are pure virtual package names with no real provider, so a dummy
package with `Provides: policykit-1, system-log-daemon` satisfies them without shadowing or
displacing anything real. Build it with `dpkg-deb`, **not** `equivs`: equivs pulls
`autoconf`, `groff-base`, `man-db` and `libmagic1t64`, roughly 9.8 MB of orphans that
survive `apt-get purge equivs && apt-get autoremove` — more than the systemd it saves.
`dpkg-deb` needs nothing that is not already in `debian:13.6`.

| Image | Packages | Size |
|---|---|---|
| Current release (source) | 748 | 2.593 GB |
| Package, unmitigated | 774 | 2.622 GB (+29 MB) |
| Package, mitigated | 755 | 2.600 GB (+7.3 MB) |

### Gotchas

- **Debian's own `zoneminder` package is 1.36.x**, in trixie, forky and sid alike. The 1.38
  packages come only from the ZoneMinder project's repository.
- **The upstream version-string separator changed mid-series**: `1.38.0-trixie1` …
  `1.38.2-trixie1`, then `1.38.3+trixie1`, `1.38.4+trixie1`. An exact-version pin must not
  assume a stable separator, so `ZM_VERSION` carries the full Debian version string.
- **`zmpkg.pl` self-heals its temp directory** at every start via `verifyFolder()`. Do not
  add redundant directory creation for it, and do not read its absence from a built image as
  a defect.
- **Do not rely on `systemd-tmpfiles` having run.** The postinst calls it, but it only does
  anything when systemd is installed — which, given requirement 6, it is not.
- **`zmsystemctl.pl` is unrunnable today.** Its shebang is `#!/usr/bin/pkexec /usr/bin/perl`
  and the current release image has no `pkexec`. Pre-existing, not a regression here.
- **The package's Apache config lands in `conf-available` and is not enabled.** It serves
  ZoneMinder at `/zm`; it does not conflict with the image's own vhost at `/`, but anything
  that enabled it would.
- **The postinst rewrites `/etc/zm` ownership and modes** (`www-data:root`, `640`) to its own
  preference, so the image's own `chown`/`chmod` must run after the package install. The
  entrypoint re-applies them at every start regardless.
- **The postinst adds an apt source and keyring** only if it does not find one already
  present — ours is, so it skips.
- **The postinst is otherwise safe under Docker**: with no local database server it reports
  "MySQL/MariaDB not found; assuming remote server." and touches no database, and
  `policy-rc.d` blocks every service start it attempts.
- The project repository publishes arm64 as well as amd64, should the single-arch CI build
  ever change.

## Progress

- **Milestone 1: complete.**
- **Milestone 2: not started.**
- **Milestone 3: not started.**
