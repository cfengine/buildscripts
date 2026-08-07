#!/bin/bash
set -e

# Configuration via environment variables:
#   PROJECT, BUILD_TYPE, EXPLICIT_ROLE, BUILD_NUMBER, EXPLICIT_VERSION

BASEDIR=/home/builder/build
export BASEDIR
export AUTOBUILD_PATH="$BASEDIR/buildscripts"

mkdir -p "$BASEDIR"

# Bind-mounted directories may be owned by the host user's UID.
# Fix ownership so builder can write to them.
sudo chown -R "$(id -u):$(id -g)" "$HOME/.cache" /output

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

install_mission_portal_deps() (
    set -e

    if [ -f "$BASEDIR/mission-portal/public/scripts/package.json" ]; then
        echo "Installing npm dependencies..."
        npm ci --prefix "$BASEDIR/mission-portal/public/scripts/"
        echo "Building react components..."
        npm run build --prefix "$BASEDIR/mission-portal/public/scripts/"
        rm -rf "$BASEDIR/mission-portal/public/scripts/node_modules"
    fi

    if [ -f "$BASEDIR/mission-portal/composer.json" ]; then
        echo "Installing Mission Portal PHP dependencies..."
        (cd "$BASEDIR/mission-portal" && composer install --no-dev --ignore-platform-reqs --prefer-dist)
    fi

    if [ -f "$BASEDIR/nova/api/http/composer.json" ]; then
        echo "Installing Nova API PHP dependencies..."
        (cd "$BASEDIR/nova/api/http" && composer install --no-dev --ignore-platform-reqs --prefer-dist)
    fi

    if [ -f "$BASEDIR/mission-portal/public/themes/default/bootstrap/cfengine_theme.less" ]; then
        echo "Compiling Mission Portal styles..."
        mkdir -p "$BASEDIR/mission-portal/public/themes/default/bootstrap/compiled/css"
        (cd "$BASEDIR/mission-portal/public/themes/default/bootstrap" &&
            lessc --compress ./cfengine_theme.less ./compiled/css/cfengine.less.css)
    fi

    if [ -f "$BASEDIR/mission-portal/ldap/composer.json" ]; then
        echo "Installing LDAP API PHP dependencies..."
        (cd "$BASEDIR/mission-portal/ldap" && composer install --no-dev --ignore-platform-reqs --prefer-dist)
    fi

    # Composer falls back to git clone when GitHub's anonymous zipball
    # rate limit is hit, leaving non-reproducible .git directories in the
    # vendor tree. Strip them.
    find "$BASEDIR/mission-portal" "$BASEDIR/nova/api/http" -type d -name .git -path '*/vendor/*' -exec rm -rf {} +
)

# Lets whoever consumes the output check that it arrived intact. Sorted in the C
# locale so that the list itself comes out the same every time.
write_sha256sums() (
    cd /output
    # shellcheck disable=SC2094
    # > Make sure not to read and write the same file in the same pipeline.
    # find leaves it out by name, so the list never covers itself.
    find . -maxdepth 1 -type f ! -name sha256sums.txt -printf '%P\n' \
        | LC_ALL=C sort | xargs -r sha256sum > sha256sums.txt
)

# Build the source tarballs. They are the same whichever platform builds them,
# so only this image builds them, and nothing else here does. /output is
# <output-dir>/tarballs on the host, as the packages' /output is per label.
#
# Each tarball's timestamps follow its own repository: Makefile.am in core and in
# masterfiles clamps every mtime in the tarball to SOURCE_DATE_EPOCH, so taking
# it from the last commit keeps a tarball identical until its own sources change.
build_tarballs() (
    set -e

    (
        cd "$BASEDIR/core"
        SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)
        export SOURCE_DATE_EPOCH
        echo "core SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH"

        rm -f cfengine-3.*.tar.gz
        # Configure so the dist target exists, undone again below.
        ./configure -C
        make dist
        mv cfengine-3.*.tar.gz /output/
        make distclean
    )

    (
        cd "$BASEDIR/masterfiles"
        SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)
        export SOURCE_DATE_EPOCH
        echo "masterfiles SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH"

        rm -f cfengine-masterfiles*.tar.gz
        ./configure
        make dist        # source tarball:  cfengine-masterfiles-<version>.tar.gz
        make tar-package # package tarball: cfengine-masterfiles-<version>.pkg.tar.gz
        mv cfengine-masterfiles*.tar.gz /output/
        make distclean
    )

    write_sha256sums
)

# === Step runner with failure reporting ===
# Disable set -e so we can capture exit codes and report which step failed.
set +e
run_step() {
    local name="$1"
    shift
    echo "=== Running $name ==="
    "$@"
    local rc=$?
    if [ $rc -ne 0 ]; then
        echo ""
        echo "=== FAILED: $name (exit code $rc) ==="
        exit $rc
    fi
}

# === Build steps ===
run_step "01-autogen" "$BASEDIR/buildscripts/build-scripts/autogen"

if [ "$TARBALLS" = yes ]; then
    run_step "02-tarballs" build_tarballs
    echo ""
    echo "=== Build complete ==="
    ls -lh /output/
    exit 0
fi

run_step "02-install-dependencies" "$BASEDIR/buildscripts/build-scripts/install-dependencies"
# Mission Portal is an Enterprise/nova-only component; its sources are only
# synced when PROJECT=nova. Skip this step for community hubs.
if [ "$PROJECT" = "nova" ] && [ "$EXPLICIT_ROLE" = "hub" ]; then
    run_step "03-mission-portal-deps" install_mission_portal_deps
fi
run_step "04-configure" "$BASEDIR/buildscripts/build-scripts/configure"
run_step "05-compile" "$BASEDIR/buildscripts/build-scripts/compile"
run_step "06-package" "$BASEDIR/buildscripts/build-scripts/package"

# === Copy output packages ===
# Packages are created under $BASEDIR/<project>/ by dpkg-buildpackage / rpmbuild.
# Exclude deps-packaging to avoid copying dependency packages.
find "$BASEDIR" -maxdepth 4 \
    -path "$BASEDIR/buildscripts/deps-packaging" -prune -o \
    \( -name '*.deb' -o -name '*.rpm' -o -name '*.msi' -o -name '*.pkg.tar.gz' \) -print \
    -exec cp {} /output/ \;

write_sha256sums

echo ""
echo "=== Build complete ==="
ls -lh /output/
