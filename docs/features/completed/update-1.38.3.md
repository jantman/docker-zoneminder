# Feature: Update to ZoneMinder 1.38.3

You must read, understand, and follow all instructions in `./README.md` when planning and implementing this feature.

## Overview

ZoneMinder 1.38.3 has been released. We need to update this Docker image from ZM 1.38.1 to 1.38.3, and update the Debian base image from 13.4 to 13.6. This is a straightforward version bump with no architectural changes.

### Changes

| Dependency | Old Version | New Version | Notes |
|-----------|------------|------------|-------|
| ZoneMinder | 1.38.1 | 1.38.3 | Bugfix/minor release |
| Debian base | 13.4 | 13.6 | Point release |
| go2rtc | v1.9.14 | v1.9.14 | Unchanged |
| MariaDB (compose) | 11.8 | 11.8 | Unchanged LTS |

## Implementation Plan

This is a simple version bump, so no milestones are needed beyond the work itself and acceptance criteria.

### Milestone 1: Version Updates

**Task 1.1: Update Dockerfile versions**
- ZM_VERSION 1.38.1 → 1.38.3
- debian:13.4 → debian:13.6 (both stages)

**Task 1.2: Update documentation**
- README.md: version references
- CLAUDE.md: version references

**Task 1.3: Build and verify**
- `docker build -t docker-zoneminder:dev .`

### Milestone 2: Acceptance Criteria

**Task 2.1: Ensure documentation is updated**
**Task 2.2: Move feature doc to completed**

## Progress

- [x] Milestone 1: Version Updates
  - Dockerfile: ZM_VERSION 1.38.1 → 1.38.3, debian:13.4 → debian:13.6 (both stages)
  - README.md: Updated ZM version reference
  - CLAUDE.md: Updated ZM version and Debian version references
  - Docker image builds successfully
- [x] Milestone 2: Acceptance Criteria
