# GitHub Action Setup Guide

## Overview
This repository runs **two** automated Docker workflows:

1. **`build-matrix.yml`** — weekly auto-sync with the upstream
   [`rocm/pytorch`](https://hub.docker.com/r/rocm/pytorch) repository.
   Builds every modern `rocm/pytorch` tag delta + cleans up orphan tags.
2. **`docker-publish.yml`** — publishes a `:latest` (or versioned) image on
   every GitHub Release. Uses the same `BASE_TAG`-parameterised Dockerfile.

There is also a small helper `create-release.yml` for cutting GitHub releases
from `v*` tags.

## Files
```
.github/workflows/
├── build-matrix.yml     # weekly matrix build + cleanup
├── create-release.yml   # cuts a GH release when you push a v* tag
└── docker-publish.yml   # publishes :latest / version tag on release
scripts/
├── list-rocm-tags.sh    # enumerates modern rocm/pytorch tags
└── cleanup-orphan-tags.sh # deletes tags not in upstream (DRY_RUN supported)
```

## `build-matrix.yml` (auto-sync)

### Triggers
- **Cron**: `0 6 * * 1` (Mondays 06:00 UTC)
- **`workflow_dispatch`** with filters:
  - `rocm_major` (`7` / `6` / `all`, default `all`)
  - `python` (`3.10` / `3.12` / `all`, default `all`)
  - `pytorch` (e.g. `2.10.0`, blank for all)
  - `dry_run` (default `true` — only print the plan, do not push or delete)
  - `force_rebuild` (default `false` — ignore delta, rebuild everything matching the filters)
  - `skip_cleanup` (default `false` — do not delete orphan tags)
- **`repository_dispatch`** type `rocm-pytorch-updated` (for future webhook integrations)

### Jobs
1. **`detect`** — paginates the Docker Hub API for both `rocm/pytorch` and
   `rmg152/rocm-whisper-api`, builds a JSON matrix of new tags to build and a
   JSON list of orphan tags to delete, prints a summary in `$GITHUB_STEP_SUMMARY`,
   and uploads `upstream.jsonl` as an artifact.
2. **`build`** — one parallel job per new tag; runs `docker buildx` with
   `BASE_TAG=<upstream-tag>` and pushes the resulting image under multiple
   aliases (`<sane>`, `rocmX.Y.Z`, `rocmX`, plus `:latest` if applicable).
3. **`cleanup`** — deletes orphan tags from the repo via the Docker Hub REST API.

### Required secrets
Same as `docker-publish.yml`:
- `DOCKER_USERNAME`
- `DOCKER_PASSWORD`

The Docker Hub token used here **must include the `Delete` scope** so that the
cleanup job can DELETE tags. Regenerate the token at
<https://hub.docker.com/settings/security> if needed.

### Recommended first run
1. **Actions** tab → **Build ROCm/PyTorch matrix** → **Run workflow** with
   `dry_run = true`. Review the build plan and orphan list in the step
   summary.
2. Re-run with `dry_run = false`, `rocm_major = 7`, `pytorch = 2.10.0` to
   build just the most recent combo as a smoke test.
3. Once satisfied, leave the cron schedule enabled.

## `docker-publish.yml` (release publishing)

### Trigger Events
The workflow automatically triggers on:
- GitHub **Release published**

### Build Process
1. **Checkout**: Repository code is checked out
2. **QEMU Setup**: Configures emulation for cross-platform builds
3. **Buildx Setup**: Configures Docker Buildx for advanced builds
4. **Docker Hub Login**: Authenticates using GitHub Secrets
5. **Metadata Extraction**: Generates appropriate tags and labels
6. **Build & Push**: Builds the Docker image (with `BASE_TAG=…`) and pushes to
   Docker Hub
7. **Attestation**: Generates an artifact attestation for the image

### Image Tagging Strategy
- **Release tag (`v1.0.0`)**: Tagged as `1.0.0`, `1.0`, and `1` (via
  `docker/metadata-action`)

### Platform Support
- `linux/amd64` - Compatible with ROCm and standard x86_64 systems

## Required Configuration

### GitHub Secrets
Configure these in **Settings** → **Secrets and variables** → **Actions**:

1. **DOCKER_USERNAME** — your Docker Hub username (e.g. `RmG152`)
2. **DOCKER_PASSWORD** — a Docker Hub **access token** (not your password) with
   **Read, Write, and Delete** scopes. Create at: <https://hub.docker.com/settings/security>

## Testing the Workflow

### Manual trigger (build-matrix)
1. **Actions** tab → **Build ROCm/PyTorch matrix** → **Run workflow**
2. Set `dry_run = true` first to see the plan
3. Set `dry_run = false` to actually push/delete

### Manual trigger (docker-publish)
1. Cut a release: `git tag v0.2.0 && git push origin v0.2.0`
2. Or use the helper script: `./scripts/create-release.sh v0.2.0`

## Monitoring

- View workflow runs in the **Actions** tab
- Each `build-matrix` run includes a step summary with the full build plan
- The `build-plan` artifact contains the raw `upstream.jsonl` for diffing
- Verify images appear on [Docker Hub](https://hub.docker.com/r/rmg152/rocm-whisper-api/tags)

## Troubleshooting

### Build fails for a specific tag
- The upstream may have published a tag with missing or broken wheels; check
  the upstream image page on Docker Hub.
- Re-run with that tag's `python`/`pytorch` value but set `force_rebuild = true`
  to retry.

### Cleanup job fails with 401
- The Docker Hub token does not have the **Delete** scope. Regenerate it.

### Cron run does nothing
- The repo probably already contains every modern upstream tag (full coverage
  achieved). Check the step summary for the "0 to build, 0 to delete" output.

## Best Practices

1. **Version Tags**: Use semantic versioning (v1.0.0) for GitHub Releases
2. **Inspect first**: Always run the matrix workflow with `dry_run = true` after
   AMD publishes a major ROCm bump
3. **Monitor**: Watch the cron run on Monday morning; if it fails, you'll get a
   GitHub notification
4. **Security**: Never hardcode credentials in workflow files
5. **Caching**: Both workflows use `cache-from: type=gha` to keep build times
   around 8-12 min per tag after the first cold build

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Buildx Documentation](https://docs.docker.com/buildx/working-with-buildx/)
- [Docker Metadata Action](https://github.com/docker/metadata-action)
- [rocm/pytorch on Docker Hub](https://hub.docker.com/r/rocm/pytorch)
- [Docker Hub API — Tags endpoint](https://docs.docker.com/docker-hub/api/latest/#tag/images)
