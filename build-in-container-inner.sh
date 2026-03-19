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
    if [ -d "$src" ] || [ -L "$src" ]; then
        echo "Syncing $repo..."
        sudo rsync -aL --exclude='config.cache' --exclude='workdir' --chown="$(id -u):$(id -g)" "$src/" "$BASEDIR/$repo/"
    else
        echo "ERROR: Required repository $repo not found" >&2
        exit 1
    fi
done

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
        (cd "$BASEDIR/mission-portal" && php /usr/bin/composer.phar install --no-dev --ignore-platform-reqs)
    fi

    if [ -f "$BASEDIR/nova/api/http/composer.json" ]; then
        echo "Installing Nova API PHP dependencies..."
        (cd "$BASEDIR/nova/api/http" && php /usr/bin/composer.phar install --no-dev --ignore-platform-reqs)
    fi

    if [ -f "$BASEDIR/mission-portal/public/themes/default/bootstrap/cfengine_theme.less" ]; then
        echo "Compiling Mission Portal styles..."
        mkdir -p "$BASEDIR/mission-portal/public/themes/default/bootstrap/compiled/css"
        (cd "$BASEDIR/mission-portal/public/themes/default/bootstrap" &&
            lessc --compress ./cfengine_theme.less ./compiled/css/cfengine.less.css)
    fi

    if [ -f "$BASEDIR/mission-portal/ldap/composer.json" ]; then
        echo "Installing LDAP API PHP dependencies..."
        (cd "$BASEDIR/mission-portal/ldap" && php /usr/bin/composer.phar install --no-dev --ignore-platform-reqs)
    fi
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
if [ "$EXPLICIT_ROLE" = "hub" ]; then
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
    \( -name '*.deb' -o -name '*.rpm' -o -name '*.pkg.tar.gz' \) -print \
    -exec cp {} /output/ \;

echo ""
echo "=== Build complete ==="
ls -lh /output/
