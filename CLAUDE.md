# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker Compose setup for running a Sonic Robo Blast 2 Kart (SRB2Kart) dedicated game server. The Dockerfile compiles Kart-Public from source inside the container and the entrypoint script (`kart.sh`) launches the dedicated server with optional mod support.

## Key Files

- `Dockerfile` — Multi-stage build: compiles Kart-Public from source, fetches game data, produces a minimal runtime image
- `docker-compose.yml` — Defines the `kart` service with port mapping (`5029/udp`) and volume mounts
- `kart.sh` — Container entrypoint that runs `srb2 -dedicated` and optionally loads mods via `-file`
- `README.md` — Usage instructions
- `.dockerignore` — Excludes non-essential files from the Docker build context
- `.github/workflows/build.yml` — CI workflow that auto-builds and pushes to GHCR on push to main

## Commands

### Docker Compose
```bash
docker compose up -d
docker compose up -d --build              # Build from source
KART_VERSION=v1.6 docker compose up -d --build
docker compose logs -f kart               # View server output
docker compose restart                    # Restart after mod changes
docker compose pull && docker compose up -d  # Update to latest image
```

### Docker build + run (without Compose)
```bash
docker build -t srb2kart-docker .
docker build --build-arg KART_VERSION=v1.6 -t srb2kart-docker .
docker run -d \
  -p 5029:5029/udp \
  -v ./mods:/mods \
  -v ./data:/data \
  srb2kart-docker
```

### Server console
```bash
docker compose logs -f kart     # View server output
docker attach kart              # Attach to server console (Ctrl+P, Ctrl+Q to detach)
```

## Architecture

The project is intentionally minimal — no build system beyond Docker.

**Build flow:** Three-stage Dockerfile:
1. **build** stage — clones Kart-Public source from `github.com/STJr/Kart-Public` and compiles it with `make LINUX=1`. Shallow clone (`--depth 1`) for speed. `KART_VERSION` build arg (default `auto`, which resolves to the latest GitHub release tag) pins the source revision.
2. **gamedata** stage — fetches game data files (`.kart`, `.dat`, `.srb`) from GitHub releases. `KART_VERSION` controls which release to download from. Downloads and extracts only the needed file types from the `AssetsLinuxOnly.zip` asset.
3. **Runtime** stage — copies the `srb2` binary from the build stage and game data from the gamedata stage into a clean `ubuntu:24.04` image with only the required runtime libraries.

**Runtime flow:** `kart.sh` is the entrypoint. It checks if `/mods` has files (using nullglob), filters to recognized types (`.wad`, `.pk3`, `.kart`, `.soc`, `.lua`, `.cfg`), then launches `srb2 -dedicated -config kartserv.cfg -home /data`, appending `-file` with the mod paths when present. Extra arguments passed to the container (`docker run ... srb2kart-docker -maxplayers 16` or via Compose `command:`) are forwarded to `srb2` before the `-file` mod args. The script also handles SIGTERM/SIGINT forwarding for graceful shutdown. On first run, the entrypoint copies the default `kartserv.cfg` to `/data/.srb2kart/`.

**Volumes:**
- `/mods` — Optional mods directory (`.wad`, `.pk3`, `.kart` files loaded automatically via `-file`)
- `/data` — Home directory for the SRB2 Kart dedicated server process; the config file lives at `/data/.srb2kart/kartserv.cfg`

## Build Mode

The `docker-compose.yml` defaults to pulling a pre-built image from GHCR (`KART_IMAGE`). To build from source instead, clear the image variable and uncomment the `build:` block:
```bash
KART_IMAGE="" docker compose up -d --build
```

## Version Selection

The `KART_VERSION` build arg controls both the source revision and game data download:
- `auto` (default) — resolves the latest release tag and game data URL from GitHub
- A specific tag (e.g., `v1.6`) — pins both source and game data to that release

## Game Data

The Dockerfile does not require game data files in the repository. The `gamedata` build stage automatically fetches the correct `AssetsLinuxOnly.zip` from GitHub releases based on `KART_VERSION`, and extracts all `.kart`, `.dat`, and `.srb` files. The entrypoint validates the required files: `srb2.srb`, `gfx.kart`, `textures.kart`, `chars.kart`, `maps.kart`, `music.kart`, `sounds.kart`, `mdls.dat`.

## CI

The `.github/workflows/build.yml` workflow triggers on push to `main`, pull requests to `main`, and manual dispatch. It fetches the latest Kart-Public release tag, builds the Docker image with `KART_VERSION` set, and pushes to GHCR (`ghcr.io/ebears/srb2kart-docker`). Images are tagged with `latest`, the Kart version, and the commit SHA. Builds use GitHub Actions cache (`type=gha`) for Docker layer caching. PR builds validate the image but do not push. On push, a Trivy vulnerability scan runs and uploads SARIF results.
