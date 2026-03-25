# build-in-container

Build CFEngine packages inside Docker containers using build scripts. Requires
only Docker and Python 3 on the host.

## Quick start

```bash
# Build a community agent .deb for Ubuntu 22
./build-in-container --platform ubuntu-22 --project community --role agent

# Re-run with same options (remembered from last run)
./build-in-container

# Override just the platform, keep everything else from last run
./build-in-container --platform debian-12
```

Output packages are written to `./output/` by default.

## Usage

```
./build-in-container [OPTIONS]
```

| Option             | Default                       | Description                                                 |
|--------------------|-------------------------------|-------------------------------------------------------------|
| `--platform`       | last-used or `ubuntu-20`      | Target platform (e.g. `ubuntu-22`, `debian-12`)             |
| `--project`        | last-used or `community`      | `community` or `nova`                                       |
| `--role`           | last-used or `agent`          | `agent` or `hub`                                            |
| `--build-type`     | last-used or `DEBUG`          | `DEBUG` or `RELEASE`                                        |
| `--output-dir`     | `./output`                    | Where to write output packages                              |
| `--cache-dir`      | `~/.cache/buildscripts_cache` | Dependency cache directory                                  |
| `--build-number`   | `1`                           | Build number for package versioning                         |
| `--version`        | auto                          | Override version string                                     |
| `--rebuild-image`  |                               | Force rebuild of Docker image (bypasses Docker layer cache) |
| `--shell`          |                               | Drop into a bash shell inside the container for debugging   |
| `--list-platforms` |                               | List available platforms and exit                           |
| `--source-dir`     | auto-detect                   | Root directory containing repos                             |

## Supported platforms

| Name        | Base image     |
|-------------|----------------|
| `ubuntu-20` | `ubuntu:20.04` |
| `ubuntu-22` | `ubuntu:22.04` |
| `ubuntu-24` | `ubuntu:24.04` |
| `debian-11` | `debian:11`    |
| `debian-12` | `debian:12`    |

Adding a new Debian/Ubuntu platform requires only a new entry in the `PLATFORMS`
dict in `build-in-container`. Adding a non-debian based platform (e.g.,
RHEL/CentOS) requires a new `container/Dockerfile.rhel` plus platform entries.

## How it works

The system has three components:

1. **`build-in-container`** (Python) -- the orchestrator that runs on the host.
   Parses arguments, builds the Docker image, and launches the container with
   the correct mounts and environment variables.

2. **`build-in-container-inner`** (Bash) -- runs inside the container. Copies
   source repos from the read-only mount, then calls the existing build scripts
   in order.

3. **`container/Dockerfile.debian`** -- parameterized Dockerfile shared by all
   Debian/Ubuntu platforms via a `BASE_IMAGE` build arg.

### Container mounts

| Host path                                | Container path                            | Mode       | Purpose                               |
|------------------------------------------|-------------------------------------------|------------|---------------------------------------|
| Source repos (parent of `buildscripts/`) | `/srv/source`                             | read-only  | Protects host repos from modification |
| `~/.cache/buildscripts_cache/`           | `/home/builder/.cache/buildscripts_cache` | read-write | Dependency cache shared across builds |
| `./output/`                              | `/output`                                 | read-write | Output packages copied here           |

### Build steps

The inner script runs these steps in order:

1. **autogen** -- runs `autogen.sh` in each repo
2. **install-dependencies** -- builds and installs bundled dependencies
3. **mission-portal-deps** -- (hub only) installs PHP/npm/LESS assets
4. **configure** -- runs `./configure` with platform-appropriate flags
5. **compile** -- compiles and installs to the dist tree
6. **package** -- creates `.deb` or `.rpm` packages

## Remembered configuration

Options not specified on the command line are filled in from the last-used
values (persisted to `~/.config/build-in-container/last-config.json`). On the
very first run, hardcoded defaults are used (`ubuntu-20`, `community`, `agent`,
`DEBUG`).

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

The shell session has the same mounts and environment as a build run. The
container is ephemeral (`--rm`), so any changes are lost on exit.
