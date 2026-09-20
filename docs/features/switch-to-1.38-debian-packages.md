# Switch to the official ZoneMinder 1.38 Debian packages

You must read, understand, and follow all instructions in `./README.md` when planning and
implementing this feature.

Tracking issue: [#11](https://github.com/jantman/docker-zoneminder/issues/11)

## Overview

Work on the 1.38.0 upgrade started the day before ZoneMinder published official Debian
packages for 1.38, so this image compiles ZoneMinder from source in a builder stage.
Official `.deb`s now exist for Debian 13 (Trixie) at the exact version we ship, so the
builder stage is no longer the only way to get 1.38.4 onto Trixie.

This feature is gated. Milestone 1 is an investigation only: build a throwaway image from
the package, diff it against the current release image, and post the differences on issue
#11. **Nothing past Milestone 1 happens without human approval of those differences**, and
if the differences turn out to be too great the conclusion may be to abandon the switch and
keep building from source.

### Why this might be worth doing

- The builder stage is the slowest, largest and most fragile part of the build: it clones
  the full ZoneMinder git tree with submodules, installs ~40 `-dev` packages, and runs a
  `make -j$(nproc)` C++ compile on every cache miss.
- Bumping the ZoneMinder version becomes `ZM_VERSION=1.38.5+trixie1` instead of a recompile.
- The cmake flags in the `Dockerfile` are a hand-maintained re-derivation of what the Debian
  packaging already encodes. Two of them are currently wrong (see Milestone 1 findings).

### Why it might not be

- The package decides its own paths and compile-time options. Where those disagree with
  this image's layout, we inherit the package's choice or override it in `conf.d`.
- It adds a third-party apt repository (`zmrepo.zoneminder.com`) to the image build, which
  is a new trust and availability dependency for CI.

## Milestones

### Milestone 1: Build from the package and compare (investigation only)

Commit prefix: `Debian Packages - 1.{task}`

1. Confirm the official packages exist for Trixie at 1.38.4 and identify the repository,
   signing key and source line.
2. Write a temporary `Dockerfile.debpkg` that installs ZoneMinder from the package and is
   otherwise byte-identical to `Dockerfile` (same ZMES, pyzm, go2rtc, Apache config, s6
   services, entrypoint), so that a filesystem diff isolates exactly what the package
   changes.
3. Build it locally and diff it against the current release image
   (`ghcr.io/jantman/docker-zoneminder:1.38.4-jantman2`): file paths, file contents,
   installed packages, ownership and modes.
4. Record the differences as a comment on issue #11 and stop for human approval.

**Status: complete. See "Milestone 1 findings" below. Awaiting human approval to proceed.**

### Milestone 2: Switch the image to the package (NOT APPROVED -- do not start)

To be planned once the Milestone 1 differences are approved. Provisionally:

1. Replace the builder stage in `Dockerfile` with the zmrepo apt source and
   `apt-get install zoneminder=${ZM_VERSION}`.
2. Apply whatever overrides the Milestone 1 findings say are needed.
3. Delete `Dockerfile.debpkg`.
4. Verify the image builds and runs via `docker-compose up`.

### Milestone 3: Acceptance Criteria (NOT APPROVED -- do not start)

1. Update `README.md` and `CLAUDE.md` for the change from source build to package install.
2. Move this file to `docs/features/completed/`.

## Milestone 1 findings

### What was compared

| | |
|---|---|
| Package source | `deb https://zmrepo.zoneminder.com/debian/release-1.38 trixie/` (flat repo, signed by the zmrepo key `E148 DCEB F909 19B4 9C68 F056 A8C6 70C8 6F88 B031`) |
| Package | `zoneminder` 1.38.4+trixie1 (amd64) -- the exact version this image builds from source |
| Package image | `docker-zoneminder:debpkg`, built from `Dockerfile.debpkg` |
| Reference image | `ghcr.io/jantman/docker-zoneminder:1.38.4-jantman2` (the current release) |

`Dockerfile.debpkg` keeps ZMES, pyzm, go2rtc, the Apache vhost, the s6 services and the
entrypoint byte-identical to `Dockerfile`, so the diff isolates ZoneMinder itself.

### Headline numbers

- 5,625 file paths are shared between the package and our source install; **44 differ in
  content**, and **32 of those 44 are PNGs that are pixel-identical** (Debian re-compresses
  them). That leaves 12 real content differences.
- The `ZoneMinder`, `ONVIF` and `WSDiscovery` Perl module trees are **path-identical**.
- The `www` tree is path-identical apart from one added symlink.
- Across the two built images, exactly **one** shared path differs in mode or ownership,
  and it is `/etc/passwd-` (a backup file).
- Image size: 2.62 GB (package) vs 2.59 GB (source), **+29 MB**.
- Nothing present in the release image is missing from the package image, except
  `/usr/bin/zmore` (which is gzip's, not ZoneMinder's) and two Perl packages whose modules
  are still available from perl-core.

### Differences that matter

These are the compile-time decisions the Debian packaging makes differently from our
`cmake` invocation. Each one is a change in behaviour, not cosmetics.

| Setting | Ours (source) | Package | Assessment |
|---|---|---|---|
| `ZM_OPT_FFMPEG` | `no` | `yes` | **Package is correct; ours is a bug.** `ffmpeg` is not installed in our builder stage, so cmake could not find it and seeded the DB with ffmpeg marked absent. A fresh install from our image starts with video encoding disabled. |
| `ZM_PATH_FFMPEG` | `FFMPEG_EXECUTABLE-NOTFOUND` | `/usr/bin/ffmpeg` | Same root cause as above. |
| `ZM_PATH_ARP`, `ZM_PATH_ARP_SCAN`, `ZM_PATH_IP`, `ZM_PATH_IFCONFIG` | empty | absolute paths | Package is better; ours relies on ZoneMinder's runtime `PATH` search. |
| `ZM_DIR_TEMP` / `ZM_PATH_SWAP` / `ZM_DIR_EXPORTS` / `ZM_UPLOAD_LOC_DIR` | `/tmp/zm` | `/var/tmp/zm` | **Cosmetic.** Neither directory exists in its image after build, and it does not matter: `zmpkg.pl`'s `verifyFolder()` recreates the path at every start (`mkdir($folder, 0774)`), and the path is baked into `zmpkg.pl` at build time -- line 188 reads `/tmp/zm` in our build and `/var/tmp/zm` in the package. Both self-heal. |
| `ZM_DIR_CACHE` | `/var/cache/zoneminder` | `/var/cache/zoneminder/cache` | **Needs a decision.** `content/zm-site.conf` has `Alias /cache "/var/cache/zoneminder"`; under the package that alias should point at `/var/cache/zoneminder/cache`. This is a compiled-in `define` in `www/includes/config.php`, not overridable from `conf.d`. |
| `ZM_PATH_ZMS` | `/cgi-bin/nph-zms` | `/zm/cgi-bin/nph-zms` | No action. `content/zmcustom.conf` already overrides this to `/cgi-bin/zms`, and `conf.d` wins. |
| `ZM_PCRE` | `1` | `0` | **Minor regression.** The package is not built against libpcre2. Its only effect is that the "Regexp" HTTP method is removed from the monitor source-type dropdown (`skins/classic/views/monitor.php`). Nothing else in the tree reads `ZM_PCRE`. |
| `www/api/app/tmp` | absent | symlink to `/var/tmp` | Probably vestigial. ZM's `api/lib/Cake/bootstrap.php` overrides CakePHP's `TMP` constant to the ZM temp dir, so the conventional `app/tmp` location should not be consulted. Not proven either way. |
| `www/api/app/Config/core.php` | | | Differs only in the randomly generated `Security.salt` / `Security.cipherSeed`. |
| `zmx10.pl` | absent | present | We build with `-DZM_NO_X10=ON`; the package ships X10 support. Harmless. |
| Linked libraries | `libcurl.so.4` (OpenSSL), `libpcre2-8`, `libunwind` | `libcurl-gnutls.so.4` | Follows from the above. Both builds `dlopen` `libvlc.so` and `libvncclient.so` identically, so VLC and VNC camera support is unchanged. |
| `www-data` groups | -- | added to `video` and `dialout` | Package postinst does this; useful for local V4L devices and serial PTZ. |

### Files the package adds that we do not currently have

`/etc/apache2/conf-available/zoneminder.conf` (**not** enabled -- `conf-enabled` contains
only the Debian defaults and `sites-enabled` still contains only our `zm-site.conf`, so it
does not conflict with hosting ZM at `/`), `/etc/init.d/zoneminder`,
`/etc/logrotate.d/zoneminder`, `/usr/lib/systemd/system/zoneminder.service`,
`/usr/lib/tmpfiles.d/zoneminder.conf`, and four polkit policy/rule files.

### The real cost: dependency creep

The `zoneminder` package has two hard dependencies that a container does not want:

- `policykit-1 | pkexec` -- resolves to `pkexec` -> `polkitd` -> `libpam-systemd` ->
  **`systemd-sysv` -> `systemd`**. `/sbin/init` becomes a symlink to
  `/lib/systemd/systemd`. Harmless given our explicit `ENTRYPOINT`, but surprising.
- `rsyslog | system-log-daemon` -- resolves to **`rsyslog`**, which is never started.

Full list of packages the package image gains: `dbus`, `dbus-bin`, `dbus-daemon`,
`dbus-session-bus-common`, `dbus-system-bus-common`, `default-mysql-client`, `libb64-0d`,
`libduktape207`, `libestr0`, `libfastjson4`, `libjwt2`, `liblognorm5`, `liblzo2-2`,
`libpam-systemd`, `libpolkit-agent-1-0`, `libpolkit-gobject-1-0`, `libsystemd-shared`,
`libvncclient1`, `mariadb-client-compat`, `php8.4-phpdbg`, `pkexec`, `polkitd`, `rsyslog`,
`sgml-base`, `systemd`, `systemd-sysv`, `xml-core`, `zoneminder`.

It loses only `libdigest-sha-perl` and `libmodule-load-conditional-perl`; both
`Digest::SHA` and `Module::Load::Conditional` are still importable from perl-core.

One upside of `systemd` landing in the image: `systemd-tmpfiles --create zoneminder.conf`
in the postinst actually runs, which is what creates `/var/tmp/zm` and
`/var/cache/zoneminder/cache`.

### Build cost

The package layer is not free -- `apt-get install zoneminder` plus our remaining runtime
deps took 766s locally, against 76s for the repo setup layer. But it replaces a builder
stage that clones the full ZoneMinder tree with submodules, installs ~40 `-dev` packages
and runs a full C++ compile, and it is a plain apt layer that caches and mirrors normally.

### Runtime verification

The package image was not only diffed, it was run: `docker compose up` against MariaDB 11.8
with the same volumes and tmpfs mounts as `docker-compose.yml`.

- The entrypoint ran unchanged: it rewrote `zm.conf`, waited for MariaDB, seeded an empty
  database from `zm_create.sql` and ran `zmupdate.pl -f`.
- `/` returns `302` to `?view=privacy` and that page renders (`<title>ZM - Privacy</title>`).
- `zmdc.pl status` shows `zmfilter.pl` (x2), `zmwatch.pl`, `zmupdate.pl -c` and
  `zmstats.pl` all running and valid.
- No `ERR`/`FAT` lines in any file under `/var/log/zm`, and no errors in the container log.
- The seeded database confirms the ffmpeg fix is real, not theoretical:
  `ZM_OPT_FFMPEG=1`, `ZM_PATH_FFMPEG=/usr/bin/ffmpeg`, `ZM_UPLOAD_LOC_DIR=/var/tmp/zm`.
  The release image's `zm_create.sql` seeds `ZM_OPT_FFMPEG` with `Value = '0'`. This is
  the one genuine bug fix in the switch.

The `zoneminder` postinst is well-behaved under Docker: it enabled `cgi` and `rewrite`,
found no local MariaDB ("MySQL/MariaDB not found; assuming remote server.") and so touched
no database, and `policy-rc.d` blocked every service start it attempted.

### Suppressing the unwanted dependencies

The systemd/polkit/dbus/rsyslog pull-in is avoidable, and `Dockerfile.debpkg-slim` proves
it by building and running.

Neither dependency is reachable in this image:

- **polkit.** `zmsystemctl.pl` is the only consumer -- `#!/usr/bin/pkexec /usr/bin/perl` is
  its shebang. Its only caller is `zmpkg.pl`, which invokes it solely when
  `ps -o comm= -p 1` reports systemd. PID 1 here is `s6-svscan`, so that branch never runs.
  Note that this script is *already* unrunnable in the current release image, which has the
  same shebang and no `pkexec` installed.
- **syslog.** Nothing logs to it. ZoneMinder logs to `/var/log/zm`; the s6 services log to
  the container's stdout.

`policykit-1` and `system-log-daemon` are both pure virtual packages with no real provider,
so a dummy package declaring `Provides: policykit-1, system-log-daemon` satisfies
`policykit-1 | pkexec` and `rsyslog | system-log-daemon` without shadowing or displacing
anything real.

**Build the dummy with `dpkg-deb`, not `equivs`.** The equivs route was tried first and
works, but equivs drags in `autoconf`, `groff-base`, `man-db` and `libmagic1t64` -- about
9.8 MB of orphans that survive `apt-get purge equivs && apt-get autoremove`. That trades
systemd for man-db. `dpkg-deb --build` needs nothing that is not already in `debian:13.6`.

Result: `systemd`, `systemd-sysv`, `libsystemd-shared`, `polkitd`, `pkexec`,
`libpam-systemd`, every `dbus*`, `rsyslog` and its `libestr0`/`libfastjson4`/`liblognorm5`
are all absent, and `/sbin/init` does not exist.

| Image | Packages | Size |
|---|---|---|
| Current release (source) | 748 | 2.593 GB |
| Package, as-is | 774 | 2.622 GB (+29 MB) |
| Package, slim | 755 | 2.600 GB (**+7.3 MB**) |

Against the current release image the slim variant gains `zoneminder`,
`default-mysql-client`, `mariadb-client-compat`, `libjwt2`, `libb64-0d`, `libvncclient1`,
`liblzo2-2`, `php8.4-phpdbg` and the dummy, and loses `libdigest-sha-perl` and
`libmodule-load-conditional-perl`. `libb64-0d` and `liblzo2-2` are not bloat -- they are
required by `libjwt2` and `libvncclient1` respectively, both real ZoneMinder dependencies
that the source build needs too and currently has nothing providing.

Verified by running it: `docker compose` against MariaDB 11.8 seeds the database, `/` -> 302
-> the privacy page renders, all five ZM daemons are valid under `zmdc.pl`, and there are no
`ERR`/`FAT` lines in `/var/log/zm` and no errors in the container log.

Dropping systemd does mean the postinst's `systemd-tmpfiles --create zoneminder.conf` no
longer runs, so `/var/tmp/zm` is absent from the built slim image. That turns out not to
matter -- `zmpkg.pl` recreates it at every start, and the running container has it as
`drwxrwxr-- www-data:www-data`, exactly the 0774 that `verifyFolder()` creates.
`/var/cache/zoneminder/cache` and `/var/lib/zm` are unaffected either way; they come from
the `.deb`'s own directory entries, not from tmpfiles.

### Recommendation

The differences are small and mostly in the package's favour. **One** of them is a fix for
a bug this image ships today: `ZM_OPT_FFMPEG=no`. Proceeding looks worthwhile, with two
items to settle in Milestone 2:

1. Point `Alias /cache` in `content/zm-site.conf` at `/var/cache/zoneminder/cache`.
2. Accept or reject the loss of `ZM_PCRE` (Regexp HTTP source method).

The dependency-creep question is settled -- see "Suppressing the unwanted dependencies".
