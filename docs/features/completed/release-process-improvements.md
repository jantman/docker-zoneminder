# Release Process Improvements

You must read, understand, and follow all instructions in `./README.md` when planning and implementing this feature.

## Overview

Implements GitHub Issue #12: Release process improvements. Three changes:

1. Include docker image names/tags and changelog in release notes
2. Stop pushing to Docker Hub (and logging in there); push to GHCR only
3. Push `build` (pre-release / PR build) images to GHCR but do not tag them so they show up only as untagged in GitHub Packages

## Implementation Plan

### Milestone 1: Workflow Changes

**Task 1.1: Remove Docker Hub from release.yml**
- Remove the Docker Hub login step
- Remove Docker Hub image tags (`${{ github.repository }}:${{ github.ref_name }}` and `${{ github.repository }}:latest`)
- Keep only GHCR tags
- Update the header comments to remove Docker Hub setup instructions

**Task 1.2: Remove Docker Hub from build.yml, push to GHCR as untagged**
- Remove Docker Hub login step
- Add GHCR login using `GITHUB_TOKEN`
- Add `packages: write` permission
- Push to GHCR without a tag. To achieve "untagged" images in GitHub Packages, we push using the digest only — by building and pushing with `push-by-digest: true` and `tags: ""` in `docker/build-push-action`. This builds and pushes the image to GHCR but without any tag, so it appears as an untagged package.

**Task 1.3: Add changelog and image info to release notes**
- In `release.yml`, generate release notes body that includes:
  - The GHCR image names/tags being published
  - A changelog generated from commits since the previous tag (using `git log`)
- Use the `softprops/action-gh-release` body parameter with the generated content

### Milestone 2: Acceptance Criteria

**Task 2.1: Update documentation**
- Update `README.md` and `CLAUDE.md` CI/CD sections to reflect GHCR-only publishing
- Remove any Docker Hub references

**Task 2.2: Move feature doc to completed**
- Move this file to `docs/features/completed/`

## Progress

- [x] Milestone 1: Workflow Changes
  - [x] Task 1.1: Remove Docker Hub from release.yml
  - [x] Task 1.2: Remove Docker Hub from build.yml, push to GHCR as untagged
  - [x] Task 1.3: Add changelog and image info to release notes
- [x] Milestone 2: Acceptance Criteria
  - [x] Task 2.1: Update documentation
  - [ ] Task 2.2: Move feature doc to completed
