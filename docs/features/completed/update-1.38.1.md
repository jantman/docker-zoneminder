# Feature: Update to ZoneMinder 1.38.1

You must read, understand, and follow all instructions in `./README.md` when planning and implementing this feature.

## Overview

ZoneMinder 1.38.1 has been released (bugfix/minor release). We need to update this Docker image from ZM 1.38.0 to 1.38.1, update the Debian base image from 13.3 to 13.4, and verify all other dependencies are current. This is a straightforward version bump with no architectural changes.

### Changes

| Dependency | Old Version | New Version | Notes |
|-----------|------------|------------|-------|
| ZoneMinder | 1.38.0 | 1.38.1 | Bugfix release: ONVIF improvements, performance optimizations, memory leak fixes |
| Debian base | 13.3 | 13.4 | Point release (2026-03-14) |
| go2rtc | v1.9.14 | v1.9.14 | Already latest |
| MariaDB (compose) | 11.8 | 11.8 | Already latest LTS |

### ZM 1.38.1 Key Changes from 1.38.0

- Unified ONVIF control module replacing vendor-specific implementations
- Performance: event threads use condition variables, binary search for event seeking, persistent blend buffer
- Bug fixes: event naming race condition, memory leaks, timezone handling, thread race conditions
- CMake minimum raised to 3.12 (not an issue for Debian 13)
- DB migration expanding ONVIF_Options column to 255 chars

## Implementation Plan

This is a simple version bump, so no milestones are needed beyond the work itself and acceptance criteria.

### Milestone 1: Version Updates

**Task 1.1: Update Dockerfile versions**
- ZM_VERSION 1.38.0 → 1.38.1
- debian:13.3 → debian:13.4 (both stages)

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
  - Dockerfile: ZM_VERSION 1.38.0 → 1.38.1, debian:13.3 → debian:13.4 (both stages)
  - README.md: Updated ZM version reference
  - CLAUDE.md: Updated ZM version and Debian version references
  - Docker image builds successfully
- [ ] Milestone 2: Acceptance Criteria
