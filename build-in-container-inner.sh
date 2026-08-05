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
    if [ -d "$src" ] || [ -L "$src" ]; then
        echo "Syncing $repo..."
        sudo rsync -aL --exclude='config.cache' --exclude='workdir' \
            --exclude='*.o' --exclude='*.lo' --exclude='*.la' \
            --exclude='node_modules' --exclude='vendor' \
            --exclude='revision' \
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
    SOURCE_DATE_EPOCH=$(git -C "$BASEDIR/core" log -1 --format=%ct)
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

echo ""
echo "=== Build complete ==="
ls -lh /output/
