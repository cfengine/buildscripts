# build-in-container

Build CFEngine packages inside Docker containers using build scripts. Requires
only Docker and Python 3 on the host.

## Quick start

```bash
# Build a community agent .deb for Ubuntu 22
./build-in-container.py --platform ubuntu-22 --project community --role agent --build-type DEBUG

# Build a nova hub release package for Debian 12
./build-in-container.py --platform debian-12 --project nova --role hub --build-type RELEASE
```

In the examples above, we run the script from inside `buildscripts/` (with
`buildscripts` as our current working directory). This is not required — if not
specified, defaults will:

- Look for sources relative to the script (parent directory of
  `build-in-container.py`).
- Place cache files in the user's home directory
  (`~/.cache/cfengine/buildscripts`).
- Use the current working directory for output packages (`./output/`).

## Usage

```
./build-in-container.py --platform PLATFORM --project PROJECT --role ROLE --build-type TYPE [OPTIONS]
```

### Required arguments

| Option         | Description                                             |
| -------------- | ------------------------------------------------------- |
| `--platform`   | Target platform (e.g. `ubuntu-22`, `debian-12`)         |
| `--project`    | `community` or `nova` (not required for `--push-image`) |
| `--role`       | `agent` or `hub` (not required for `--push-image`)      |
| `--build-type` | `DEBUG` or `RELEASE` (not required for `--push-image`)  |

None of the above arguments are required for `--update`.

### Optional arguments

| Option             | Default                          | Description                                                         |
| ------------------ | -------------------------------- | ------------------------------------------------------------------- |
| `--output-dir`     | `./output`                       | Where to write output packages                                      |
| `--cache-dir`      | `~/.cache/cfengine/buildscripts` | Dependency cache directory                                          |
| `--build-number`   | `1`                              | Build number for package versioning                                 |
| `--version`        | auto                             | Override version string                                             |
| `--rebuild-image`  |                                  | Force rebuild of Docker image (bypasses Docker layer cache)         |
| `--push-image`     |                                  | Build image and push to registry, then exit                         |
| `--update`         |                                  | Fetch latest image versions from registry and update platforms.json |
| `--shell`          |                                  | Drop into a bash shell inside the container for debugging           |
| `--list-platforms` |                                  | List available platforms and exit                                   |
| `--source-dir`     | parent of `buildscripts/`        | Root directory containing repos                                     |

## Supported platforms

| Name        | Base image     |
| ----------- | -------------- |
| `ubuntu-20` | `ubuntu:20.04` |
| `ubuntu-22` | `ubuntu:22.04` |
| `ubuntu-24` | `ubuntu:24.04` |
| `debian-11` | `debian:11`    |
| `debian-12` | `debian:12`    |

Adding a new Debian/Ubuntu platform requires only a new entry in `platforms.json`.
Adding a non-debian based platform (e.g.,
RHEL/CentOS) requires a new `container/Dockerfile.rhel` plus platform entries.

## How it works

The system has three components:

1. **`build-in-container.py`** (Python) -- the orchestrator that runs on the host.
   Parses arguments, builds the Docker image, and launches the container with
   the correct mounts and environment variables.

2. **`build-in-container-inner.sh`** (Bash) -- runs inside the container. Copies
   source repos from the read-only mount, then calls the existing build scripts
   in order.

3. **`container/Dockerfile.debian`** -- parameterized Dockerfile shared by all
   Debian/Ubuntu platforms via a `BASE_IMAGE` build arg.

### Container mounts

| Host path                                | Container path                            | Mode       | Purpose                               |
| ---------------------------------------- | ----------------------------------------- | ---------- | ------------------------------------- |
| Source repos (parent of `buildscripts/`) | `/srv/source`                             | read-only  | Protects host repos from modification |
| `~/.cache/cfengine/buildscripts/`        | `/home/builder/.cache/buildscripts_cache` | read-write | Dependency cache shared across builds |
| `./output/`                              | `/output`                                 | read-write | Output packages copied here           |

### Build steps

The inner script runs these steps in order:

1. **autogen** -- runs `autogen.sh` in each repo
2. **install-dependencies** -- builds and installs bundled dependencies
3. **mission-portal-deps** -- (hub only) installs PHP/npm/LESS assets
4. **configure** -- runs `./configure` with platform-appropriate flags
5. **compile** -- compiles and installs to the dist tree
6. **package** -- creates `.deb` or `.rpm` packages

## Docker image management

By default, the script pulls a pre-built image from the container registry
(`ghcr.io/cfengine`). If the pull fails (e.g. no network, image not yet
published), it falls back to building the image locally.

Use `--rebuild-image` to skip the registry and force a local rebuild — useful
when iterating on the Dockerfile. The local build tracks the Dockerfile content
hash and skips rebuilding when nothing has changed.

### Container registry

Images are hosted at `ghcr.io/cfengine` and versioned per-platform via
`image_version` in `platforms.json`. To push a new image:

```bash
# Build and push a single platform
./build-in-container.py --platform ubuntu-22 --push-image
```

`--push-image` always builds with `--no-cache` to pick up the latest upstream
packages, then pushes to the registry. However, you must be logged in to
`ghcr.io` first. You can log in with a personal access token (classic) that has
the write:packages scope. Alternatively, trigger the GitHub Actions workflow
which handles authentication automatically.

#### GitHub Actions workflow

The `build-base-images.yml` workflow builds and pushes images for every
supported platform. It runs weekly (Sunday at midnight UTC) and can also be
triggered manually via `workflow_dispatch`.

After the workflow pushes new images, update `platforms.json` to use them:

```bash
# Update all platforms to the latest registry version
./build-in-container.py --update

# Update a single platform
./build-in-container.py --update --platform ubuntu-22
```

The `update-base-images.yml` workflow automates this step. It runs weekly
(Monday at midnight UTC) and can also be triggered manually. It calls
`./build-in-container.py --update` and opens a pull request with any
`platforms.json` changes. This workflow requires `contents: write` and
`pull-requests: write` permissions.

The workflow authenticates to `ghcr.io` using the automatic `GITHUB_TOKEN`
provided by GitHub Actions. For this to work:

- The repository must grant `GITHUB_TOKEN` write access to packages. In the
  GitHub repository settings, go to **Actions → General → Workflow permissions**
  and select **Read and write permissions**.
- After the first push, each package defaults to private. To allow anonymous
  pulls, go to the package on GitHub (**your org → Packages**), open **Package
  settings**, and change the visibility to **Public**. This is a one-time step
  per package — new tags (e.g. from bumping `image_version`) inherit the
  existing visibility.

### Updating the toolchain

1. Edit `container/Dockerfile.debian` as needed
2. Test locally with `--rebuild-image`
3. Commit and merge the Dockerfile change
4. Push new images by triggering the `build-base-images.yml` workflow
5. Trigger the `update-base-images.yml` workflow to open a PR updating `platforms.json`

## Debugging

```bash
# Drop into a shell inside the container
./build-in-container.py --platform ubuntu-22 --project community --role agent --build-type DEBUG --shell
```

The shell session has the same mounts and environment as a build run. The
container is ephemeral (`--rm`), so any changes are lost on exit.
