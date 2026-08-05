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

### Usage

See:
```bash
$ ./build-in-container.py --help
```

## Supported platforms

See:
```bash
$ ./build-in-container.py --list-platforms
```

Adding a new platform normally requires a new entry in `platforms.json` and
adding the platform name to the matrix in
`.github/workflows/build-base-images.yml` so the weekly job builds and
pushes its image to `ghcr.io`.

The new entry in `platforms.json` needs:

- `image_version`: set to `"latest"` as a placeholder. The
  `update-base-images.yml` workflow will replace it with the real ghcr.io tag
  after the first image is pushed.
- `base_image_sha`: the Docker Hub manifest digest for the `base_image`. Don't
  copy this by hand -- run
  `./build-in-container.py --update-sha --platform <new-platform>` and it will
  fetch the current digest from Docker Hub and write it into `platforms.json`.

Optionally, add the following entries:

- `architectures`: the list of docker platforms to publish, e.g.
  `["linux/amd64", "linux/arm64"]`. Omit it to get the multi-arch default; set
  it only to restrict or extend the architectures.
- `extra_build_args`: allows you to add extra arguments through environment
  variables.

Adding an entirely different platform family (e.g. SUSE) would require a new
`container/Dockerfile.<family>`.

## Architecture

By default the build runs on the host machine's architecture, and Docker picks
the matching image variant automatically. Use `--arch` to override this and
build for another architecture - the value is passed straight to Docker's
`--platform` flag:

```bash
# Build an arm64 community agent .deb for Ubuntu 24 on an amd64 host
./build-in-container.py --platform ubuntu-24 --project community --role agent \
    --build-type DEBUG --arch linux/arm64
```

The registry images are published as multi-arch manifests (`linux/amd64` and
`linux/arm64`), so `--arch` normally just pulls the matching variant. If the
registry does not provide the requested architecture (for example an older,
single-arch image that predates multi-arch support), the script falls back to
building the image locally for that architecture only.

Building a non-host architecture - whether locally or in CI - relies on
QEMU/binfmt emulation being registered on the build host. If it isn't set up,
register it once with:

```bash
docker run --privileged --rm tonistiigi/binfmt --install all
```

Please note that emulated builds are considerably slower than native ones.

The set of architectures published for each platform defaults to `linux/amd64`
and `linux/arm64`. A platform can override this with an `"architectures"` list
in `platforms.json`. The `ubuntu-24-mingw` platform, for instance,
cross-compiles to Windows x64 regardless of the container's architecture, so it
is pinned to `["linux/amd64"]`.

## How it works

The system has three components:

1. **`build-in-container.py`** (Python) -- the orchestrator that runs on the
   host. Parses arguments, builds the Docker image, and launches the container
   with the correct mounts and environment variables.

2. **`build-in-container-inner.sh`** (Bash) -- runs inside the container. Copies
   source repos from the read-only mount, then calls the build scripts in order.

3. **`container/Dockerfile.<family>`** -- parameterized Dockerfiles shared
   across platforms of the same family via a `BASE_IMAGE` build arg (plus
   per-platform `extra_build_args` in `platforms.json`.

### Container mounts

| Host path                                | Container path                            | Mode       | Purpose                               |
| ---------------------------------------- | ----------------------------------------- | ---------- | ------------------------------------- |
| Source repos (parent of `buildscripts/`) | `/srv/source`                             | read-only  | Protects host repos from modification |
| `~/.cache/cfengine/buildscripts/`        | `/home/builder/.cache/buildscripts_cache` | read-write | Dependency cache shared across builds |
| `./output/<label>/`                      | `/output`                                 | read-write | Output packages copied here           |
| `--sftp-key` (when given)                | `/run/secrets/sftp-cache-key`             | read-only  | Key for the remote dependency cache   |

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

`--push-image` uses `docker buildx build --push` to build every architecture the
platform targets (`linux/amd64` and `linux/arm64` by default; see
[Architecture](#architecture)) and publish them under a single multi-arch
manifest. It always builds fresh to pick up the latest upstream packages.

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

The `base_image_sha` digests in `platforms.json` pin each platform to a
specific Docker Hub manifest. To refresh them to the current digests:

```bash
# Update all platforms
./build-in-container.py --update-sha

# Update a single platform
./build-in-container.py --update-sha --platform ubuntu-22
```

The `update-base-image-shas.yml` workflow automates this. It runs weekly (Monday
at 01:00 UTC) and opens a pull request with any digest changes.

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
