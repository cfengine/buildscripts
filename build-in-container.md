# build-in-container

Build CFEngine packages inside Docker containers using the existing build
scripts. Requires only Docker and Python 3 on the host.

## Quick start

```bash
# Build a community agent .deb for Ubuntu 22
./build-in-container --platform ubuntu-22 --project community --role agent

# Or run interactively (prompts for any unspecified options)
./build-in-container
```

Output packages are written to `./output/`.

## Usage

```
./build-in-container [OPTIONS]
```

| Option | Default | Description |
|--------|---------|-------------|
| `--platform` | prompted | Target platform (e.g. `ubuntu-22`, `debian-12`) |
| `--project` | `community` | `community` or `nova` |
| `--role` | `agent` | `agent` or `hub` |
| `--build-type` | `DEBUG` | `DEBUG` or `RELEASE` |
| `--output-dir` | `./output` | Where to write output packages |
| `--cache-dir` | `~/.cache/buildscripts_cache` | Dependency cache directory |
| `--build-number` | `1` | Build number for package versioning |
| `--version` | auto | Override version string |
| `--step STEP` | | Re-run from a specific step (clears that step and all subsequent) |
| `--clean` | | Remove build volume and start from scratch |
| `--rebuild-image` | | Force rebuild of Docker image (bypasses Docker layer cache) |
| `--shell` | | Drop into a bash shell inside the container for debugging |
| `--list-platforms` | | List available platforms and exit |
| `--source-dir` | auto-detect | Root directory containing repos |
| `--non-interactive` | | Never prompt; use defaults for unspecified options |

## Supported platforms

| Name | Base image |
|------|------------|
| `ubuntu-20` | `ubuntu:20.04` |
| `ubuntu-22` | `ubuntu:22.04` |
| `ubuntu-24` | `ubuntu:24.04` |
| `debian-11` | `debian:11` |
| `debian-12` | `debian:12` |

Adding a new Debian/Ubuntu platform requires only a new entry in the
`PLATFORMS` dict in `build-in-container`. Adding RHEL/CentOS requires a new
`container/Dockerfile.rhel` plus platform entries.

## How it works

The system has three components:

1. **`build-in-container`** (Python) -- the orchestrator that runs on the host.
   Parses arguments, builds the Docker image, and launches the container with
   the correct mounts and environment variables.

2. **`build-in-container-inner`** (Bash) -- runs inside the container. Syncs
   source repos from the read-only mount into the build volume, then calls the
   existing build scripts in order.

3. **`container/Dockerfile.debian`** -- parameterized Dockerfile shared by all
   Debian/Ubuntu platforms via a `BASE_IMAGE` build arg.

### Container mounts

| Host path | Container path | Mode | Purpose |
|-----------|---------------|------|---------|
| Source repos (parent of `buildscripts/`) | `/srv/source` | read-only | Protects host repos from modification |
| Named volume `cfengine-build-{platform}` | `/home/builder/build` | read-write | Persists build state for incremental builds |
| `~/.cache/buildscripts_cache/` | `/home/builder/.cache/buildscripts_cache` | read-write | Dependency cache shared across builds |
| `./output/` | `/output` | read-write | Output packages copied here |

### Build steps

The inner script runs these steps in order:

1. **autogen** -- runs `autogen.sh` in each repo
2. **install-dependencies** -- builds and installs bundled dependencies
3. **mission-portal-deps** -- (hub only) installs PHP/npm/LESS assets
4. **configure** -- runs `./configure` with platform-appropriate flags
5. **compile** -- compiles and installs to the dist tree
6. **package** -- creates `.deb` or `.rpm` packages

## Incremental builds

Build state lives on a named Docker volume (`cfengine-build-{platform}`) that
persists between runs. Each completed step writes a marker file. On re-run:

- Source repos are re-synced via rsync (fast for unchanged files)
- Steps with existing markers are skipped
- The first step without a marker runs (i.e., the one that failed or hasn't run)

This means fixing a compile error and re-running picks up right where it left
off -- no need to rebuild dependencies.

### Retrying from a specific step

```bash
# Re-run configure and everything after it
./build-in-container --platform ubuntu-22 --step configure
```

`--step` removes the marker for that step and all subsequent ones.

### Starting fresh

```bash
# Remove the build volume entirely
./build-in-container --platform ubuntu-22 --clean
```

The dependency cache (bind-mounted from the host) is unaffected by `--clean`,
so dependency rebuilds are still avoided.

### Auto-clean on config change

If the project, role, or build type changes between runs on the same platform,
the inner script detects the mismatch and automatically cleans the build
directory. No manual `--clean` needed.

## Interactive configuration

When options are omitted, the script prompts for them interactively. Each prompt
defaults to the last-used value (persisted to
`~/.config/build-in-container/last-config.json`). Press Enter to accept the
default.

```
$ ./build-in-container

Platform [ubuntu-20, ubuntu-22, ubuntu-24, debian-11, debian-12] (ubuntu-22):
Project (community/nova) [nova]:
Role (agent/hub) [hub]:
Build type (DEBUG/RELEASE) [DEBUG]:
```

If stdin is not a TTY or `--non-interactive` is passed, defaults are used
without prompting.

## Docker image management

The Docker image is tagged `cfengine-builder-{platform}` and rebuilt
automatically when the Dockerfile changes (tracked via a content hash stored as
an image label). Use `--rebuild-image` to force a full rebuild bypassing the
Docker layer cache (useful when upstream packages change).

## Debugging

```bash
# Drop into a shell inside the container
./build-in-container --platform ubuntu-22 --shell
```

The shell session has the same mounts and environment as a build run. The build
volume is mounted, so you can inspect build state, run individual build scripts,
or poke around. The container is ephemeral (`--rm`), so anything outside the
named volume is lost on exit.
