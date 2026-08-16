# Feature: ZoneMinder 1.38.4 and Event Server 7 (pyzmNg)

You must read, understand, and follow all instructions in `./README.md` when planning and implementing this feature.

## Overview

Two changes shipped together, because they land in the same layers of the image:

1. **ZoneMinder 1.38.3 → 1.38.4.** Routine version bump.
2. **Event Server 6 → 7.** The ES 6 / `pyzm` stack is archived upstream. Move to
   zmeventnotificationNg (ES 7) and pyzmNg, both actively maintained under the
   `ZoneMinder` GitHub org.

The ES 7 move is the substantive part. It is driven by the `privatepuppet`
`001-zm-es7-migration` spec, whose `contracts/container-images.md` "Image A" section is
the receiving contract for this image.

### Changes

| Dependency | Old Version | New Version | Notes |
|-----------|------------|------------|-------|
| ZoneMinder | 1.38.3 | 1.38.4 | Bugfix release ("Seek and Destroy") |
| Event Server | 6.1.29 (vendored snapshot) | 7.0.29 (pinned git tag) | New Perl module tree, YAML config |
| Python detection lib | `pyzm` (unpinned) | `pyzm[ml]==2.5.1` | pyzmNg publishes to PyPI under the name `pyzm` |
| `imageio` | not installed | `2.37.4` | ES 7 dropped the animation/GIF feature; the consuming hook re-implements it |
| `newrelic` | unpinned | `13.4.0` | Pinned for the same reason as pyzm |
| Debian base | 13.6 | 13.6 | Unchanged |
| go2rtc | v1.9.14 | v1.9.14 | Unchanged |

### Contract deviations

`contracts/container-images.md` is treated as one consumer's expectations, not gospel.
Two places where this image intentionally differs from what it says:

- **The contract says "ZoneMinder 1.38.3, unchanged from current image".** This image ships
  1.38.4. The contract was written before 1.38.4 released; there is no reason to hold the
  image back, and nothing in the ES 7 work depends on the ZM patch version.
- **The contract says "pyzmNg 2.5.1".** There is no PyPI distribution named `pyzmNg`. The
  `ZoneMinder/pyzmNg` repository publishes to PyPI as **`pyzm`**, versions `2.x`. So
  `pyzm==2.5.1` *is* pyzmNg 2.5.1 — the archived `pyzm` lineage stopped at `0.3.67`. The
  contract's own verification line (`import pyzm; print(pyzm.__version__)`) already assumes
  the module is named `pyzm`, so this is a naming slip in the contract, not a conflict.

- **The contract's verification block did not run against this image at all.** Not a
  disagreement — a defect on our side. `entrypoint.sh` ignored `"$@"` and unconditionally
  started ZoneMinder, so `docker run --rm <tag> python3 -c ...` blocked forever on the
  MariaDB ping loop instead of running Python. Compounding it, `ENTRYPOINT` interpolated
  `${@}` unquoted, so bash re-split each argument on whitespace and mangled any command
  containing spaces. Both are fixed: the entrypoint now `exec`s a passed command before
  touching the database, and `"$@"` is quoted. Passing arguments previously did nothing,
  so nothing can depend on the old behaviour.

The resulting image tag will be `1.38.4-jantman1`, following this repo's existing
convention (`{ZM version}-jantman{N}`) rather than the contract's suggested
`1.38.3-jantman2`. `1.38.3-jantman1` is not touched and stays pullable.

### What ES 7 changes structurally

Worth writing down, because it is more than a version number:

- **Perl module tree.** `zmeventnotification.pl` is no longer one self-contained script. It
  now `use`s a `ZmEventNotification::*` package tree (`Config`, `Connection`, `Constants`,
  `DB`, `FCM`, `HookProcessor`, `MQTT`, `Rules`, `Util`, `Version`, `WebSocketHandler`)
  which must be installed into `@INC` (upstream default: `/usr/share/perl5`).
  `ZmEventNotification::Version` carries a hardcoded fallback version that upstream's
  `install.sh` patches at install time; we do the same.
- **YAML config.** `zmeventnotification.ini` → `zmeventnotification.yml`, `secrets.ini` →
  `secrets.yml`, `objectconfig.ini` → `objectconfig.yml`, `es_rules.json` →
  `es_rules.yml`. This adds a `YAML::XS` Perl dependency (`libyaml-libyaml-perl`).
- **No animation.** ES 7 removed GIF/animation generation. The consuming application
  re-implements it locally via `Event.extract_frames()`, which needs `imageio`. Without it,
  Pushover notifications silently degrade to a still image — silently, which is why it is
  called out explicitly here.
- **Source provenance.** ES 6 arrived as 58 vendored files under `content/zmeventnotification/`
  — a copy of the upstream repo with no recorded provenance. ES 7 is fetched by
  `git clone --branch ${ZMES_VERSION}` in the builder stage, so the version is explicit and
  greppable, matching how `ZM_VERSION` and `GO2RTC_VERSION` already work.

### CPU-only constraint

This image performs no inference. A separate `pyzm.serve` container does that, and the hook
config sets `ml_fallback_local: "no"`. The image must therefore contain **no CUDA, no GPU
libraries, and no CUDA-enabled OpenCV** — not only for size, but so that an accidental local
fallback cannot quietly mask a gateway outage.

Two specific hazards:

- OpenCV comes from Debian's `python3-opencv` (CPU-only). Nothing may pull `opencv-python`
  from PyPI, which would shadow it.
- `pyzm[ml]` pulls `onnx` (the model *format* library) but not `onnxruntime`, `torch` or
  `ultralytics`. `pyzm[serve]` and `pyzm[full]` would pull inference machinery; we install
  neither.

## Implementation Plan

### Milestone 1: ZoneMinder 1.38.4

**Task 1.1: Bump `ZM_VERSION`** in the Dockerfile builder stage.

### Milestone 2: Event Server 7 source and Perl runtime

**Task 2.1: Fetch ES 7 at a pinned tag.** Add `ARG ZMES_VERSION=v7.0.29` and a
`git clone --branch ${ZMES_VERSION} --depth 1` in the builder stage, placed *after* the
ZoneMinder build so an ES bump does not invalidate the ZM compile cache.

**Task 2.2: Delete the vendored ES 6 tree** at `content/zmeventnotification/`.

**Task 2.3: Install ES 7 into the runtime stage.**
- `zmeventnotification.pl` → `/usr/bin/`
- `ZmEventNotification/*.pm` → `/usr/share/perl5/ZmEventNotification/`, with the
  `$FALLBACK_VERSION` in `Version.pm` patched to the contents of `VERSION`
- `hook/zm_event_start.sh`, `zm_event_end.sh`, `zm_detect.py`, `zm_train_faces.py` and
  `pushapi_plugins/pushapi_pushover.py` → `/var/lib/zmeventnotification/bin/`

**Task 2.4: Add the Perl dependencies ES 7 needs**, matching upstream `install.sh`:
`libyaml-libyaml-perl` (`YAML::XS`), `libcrypt-openssl-rsa-perl` (FCM service-account
auth), `libdbi-perl`.

### Milestone 3: Python stack

**Task 3.1: Replace unpinned `pyzm` with pinned `pyzm[ml]`.** Add `ARG PYZM_VERSION=2.5.1`,
`ARG IMAGEIO_VERSION=2.37.4`, `ARG NEWRELIC_VERSION=13.4.0`. The `[ml]` extra is what
brings `shapely` (zone polygons, required by `pyzm.ml.filters`), `numpy`, `Pillow`, `onnx`
and `portalocker`.

**Task 3.2: Install `zmes_hook_helpers`** from the ES 7 `hook/` directory so
`zmes_hook_helpers.common_params`, `.utils` and `.push` are importable.

**Task 3.3: Verify nothing pulled a PyPI OpenCV, numpy replacement, or any GPU package.**

### Milestone 4: Configuration examples

**Task 4.1: Replace the ES 6 INI/JSON examples with the ES 7 YAML examples** taken from
upstream 7.0.29: `secrets.EXAMPLE.yml`, `zmeventnotification.EXAMPLE.yml`,
`objectconfig.EXAMPLE.yml`, `es_rules.EXAMPLE.yml`.

**Task 4.2: Update `.gitignore` and `.dockerignore`** for the new filenames.

**Task 4.3: Update both docker-compose files** to mount the `.yml` paths.

### Milestone 5: Acceptance Criteria

**Task 5.1: Run the contract's verification block** against the built image.

**Task 5.2: Update `README.md` and `CLAUDE.md`.**

**Task 5.3: Move this document to `docs/features/completed/`.**

## Progress

- [x] Milestone 1: ZoneMinder 1.38.4
  - `ARG ZM_VERSION` 1.38.3 → 1.38.4
- [x] Milestone 2: Event Server 7 source and Perl runtime
  - `ARG ZMES_VERSION=v7.0.29`, cloned in the builder stage after the ZM build and copied
    into the runtime stage with `COPY --from=builder`
  - Deleted the 58 vendored ES 6 files under `content/zmeventnotification/`
  - `ZmEventNotification/*.pm` installed to `/usr/share/perl5/ZmEventNotification/`, with
    `Version.pm`'s `$FALLBACK_VERSION` rewritten from `VERSION` and the rewrite asserted
    with `grep -q` so a change to upstream's declaration fails the build loudly
  - Added `libyaml-libyaml-perl`, `libcrypt-openssl-rsa-perl`, `libdbi-perl`; dropped
    `libconfig-inifiles-perl` (ES 7 reads YAML, and ZoneMinder itself does not use it)
- [x] Milestone 3: Python stack
  - `pyzm[ml]==2.5.1`, `imageio==2.37.4`, `newrelic==13.4.0`, all pinned via ARGs
  - `zmes_hook_helpers` 7.0.29 installed from the ES 7 `hook/` directory
  - Verified nothing pulls a PyPI OpenCV or replaces Debian's numpy: `cv2` stays 4.10.0
    from `python3-opencv`, `numpy` stays 2.2.4 from `python3-numpy`
- [x] Milestone 4: Configuration examples
  - `secrets.EXAMPLE.yml`, `zmeventnotification.EXAMPLE.yml`, `objectconfig.EXAMPLE.yml`,
    `es_rules.EXAMPLE.yml` taken from upstream 7.0.29; ES 6 INI/JSON examples deleted
  - `.gitignore`, `.dockerignore` and both docker-compose files updated
  - The `mlapi` service in `docker-compose-mlapi.yml` is left alone but annotated: it is
    the ES 6-era inference container, superseded by a pyzm.serve gateway, and it still
    wants INI config this repo no longer ships examples for
- [x] Milestone 5: Acceptance Criteria
  - Fixed `entrypoint.sh` / `ENTRYPOINT` so a passed command runs instead of being ignored
    (see "Contract deviations" above)
  - A build-time smoke test in the Dockerfile runs the consumer's verification block plus
    two CPU-only assertions, so CI fails on a broken dependency set rather than pushing it
  - `README.md` and `CLAUDE.md` updated

## Verification performed

The consumer's verification block, run verbatim against the built image — all three pass:

```
$ docker run --rm docker-zoneminder:dev python3 -c "import pyzm, shapely, newrelic, imageio, cv2; print(pyzm.__version__)"
2.5.1
$ docker run --rm docker-zoneminder:dev python3 -c "import zmes_hook_helpers.utils"
$ docker run --rm docker-zoneminder:dev /var/lib/zmeventnotification/bin/zm_detect.py --bareversion
7.0.29
```

CPU-only constraint: `cv2` is 4.10.0 from Debian's `python3-opencv` with
`cv2.cuda.getCudaEnabledDeviceCount() == 0`; `numpy` stays Debian's 2.2.4; no
`torch`, `ultralytics`, `onnxruntime-gpu`, `nvidia-*` or `opencv-python` in `pip list`;
no CUDA/cuDNN/TensorRT shared objects anywhere in the filesystem.

Full boot test against an isolated MariaDB (`docker compose up` on throwaway volumes):

- ZoneMinder reports 1.38.4, creates the schema and upgrades it to 1.38.4, then starts
- go2rtc 1.9.14 starts and its API answers on :1984; ZM web answers on :80
- `perl -c /usr/bin/zmeventnotification.pl` is syntax-OK against the live DB, confirming
  the `ZmEventNotification::*` tree resolves from `/usr/share/perl5`
- `zmeventnotification.pl --version` reports `7.0.29`, confirming the `Version.pm` patch
- The event server starts, reads `/etc/zm/zmeventnotification.yml` and `/etc/zm/secrets.yml`,
  logs `Starting ES version: 7.0.29`, and re-loads monitors. It then stops on
  `SSL_cert_file /path/to/cert/file.pem` — the placeholder path in the unedited example
  secrets file, which is the expected outcome for example config.
