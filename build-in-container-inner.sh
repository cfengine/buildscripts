#!/bin/bash
set -e

# Configuration via environment variables:
#   PROJECT, BUILD_TYPE, EXPLICIT_ROLE, BUILD_NUMBER, EXPLICIT_VERSION

# let setup-cfengine-build-host.sh know we are in a container
sudo touch /etc/cfengine-in-container.flag

BASEDIR=/home/builder/build
export BASEDIR
export AUTOBUILD_PATH="$BASEDIR/buildscripts"
OUTPUT=/output
export OUTPUT

mkdir -p "$BASEDIR"

# Bind-mounted directories may be owned by the host user's UID.
# Fix ownership so builder can write to them.
sudo chown -R "$(id -u):$(id -g)" "$HOME/.cache" "$OUTPUT"

# And hand ownership back to the host user on the way out.
if [ -n "$HOST_UID" ] && [ -n "$HOST_GID" ]; then
    trap 'sudo chown -R "$HOST_UID:$HOST_GID" "$HOME/.cache" /output' EXIT
fi

# Prevent git "dubious ownership" errors
git config --global --add safe.directory '*'

# === Sync source repos ===
repos="buildscripts core masterfiles"
if [ "$PROJECT" = "nova" ]; then
    repos="$repos enterprise nova mission-portal"
fi

for repo in $repos; do
    src="/srv/source/$repo"
    # Use rsync -aL to follow symlinks during copy.
    # The source dir may use symlinks (e.g., core -> cfengine/core/).
    # -L resolves them at copy time, so the destination gets real files
    # regardless of the host directory layout.
    # Exclude acceptance test workdirs — they contain broken symlinks left
    # over from previous test runs and are not needed for building.
    # Also skip node_modules/vendor for hub builds.
    # Also skip compilation results *.o, *.lo, *.la as the local copy is likely a different platform/OS than inside the container
    # Skip revision files too: autogen only writes them when absent, so a
    # leftover from an earlier host build would key the dependency cache to
    # whatever commit that build saw.
    # And skip output directories: --output-dir defaults to ./output, which lands
    # inside buildscripts, and the collector at the end of this script would then
    # pick an earlier build's packages up as if this build had made them.
    if [ -d "$src" ] || [ -L "$src" ]; then
        echo "Syncing $repo..."
        sudo rsync -aL --exclude='config.cache' --exclude='workdir' \
            --exclude='*.o' --exclude='*.lo' --exclude='*.la' \
            --exclude='node_modules' --exclude='vendor' \
            --exclude='revision' \
            --exclude='output' \
            --chown="$(id -u):$(id -g)" "$src/" "$BASEDIR/$repo/"
    else
        echo "ERROR: Required repository $repo not found" >&2
        exit 1
    fi
done

# The dependency cache is reached over sftp, so the key has to be in place
# before install-dependencies runs. It arrives on a read-only mount owned by the
# host user, and ssh refuses a key owned by anyone but us, hence the copy. Only
# root can read the mode 600 original when that user is not builder, hence sudo.
if [ -f /run/secrets/sftp-cache-key ]; then
    echo "Installing dependency cache key..."
    install -d -m 700 "$HOME/.ssh"
    sudo install -m 600 -o "$(id -u)" -g "$(id -g)" \
        /run/secrets/sftp-cache-key "$HOME/.ssh/id_rsa"
    grep '^build-artifacts-cache' "$BASEDIR/buildscripts/ci/known_hosts" \
        >> "$HOME/.ssh/known_hosts"

    # Fail now rather than once every dependency has been built, which is when
    # pkg-cache would first try to upload.
    echo pwd | sftp -o BatchMode=yes -b - jenkins_sftp_cache@build-artifacts-cache.cloud.cfengine.com
fi

# Pin embedded build timestamps so two builds of the same source produce
# identical binaries. Honored by OpenSSL, Apache httpd, Postgres, Python
# (.pyc mtimes), dpkg-buildpackage, and rpmbuild.
if [ -z "$SOURCE_DATE_EPOCH" ]; then
    # cd rather than git -C: rhel-7 has git 1.8.3.1, which predates -C
    SOURCE_DATE_EPOCH=$(cd "$BASEDIR/core" && git log -1 --format=%ct)
fi
export SOURCE_DATE_EPOCH
echo "SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH"

run_step() {
    local name="$1"
    shift
    echo "=== Running $name ==="
    "$BASEDIR/buildscripts/build-scripts/$name" "$@"
    local rc=$?
    if [ $rc -ne 0 ]; then
        echo ""
        echo "=== FAILED: $name (exit code $rc) ==="
        exit $rc
    fi
}

# === Build steps ===

if [ "$TARBALLS" = yes ]; then
    run_step autogen
    run_step generate-pull-request-file
    run_step build-tarballs
    run_step generate-checksum-list
    echo ""
    echo "=== Build complete ==="
    ls -lh "$OUTPUT"
    exit 0
fi

NO_TESTS=true
export NO_TESTS

for script in "$BASEDIR/buildscripts/build-scripts"/0*; do
  name="$(basename "$script")"
  run_step "$name"
done


echo ""
echo "=== Build complete ==="
ls -lhR "$OUTPUT"/
