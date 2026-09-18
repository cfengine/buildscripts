#!/bin/sh -e

#
# Build a cfengine-nova (Enterprise agent) .pkg for macOS from scratch:
# autogen -> install-dependencies -> configure -> compile -> package.
#
# Run from anywhere; it locates itself relative to this file, which is
# located in the buildscripts/ci directory.
#
# Expected directory layout with projects next to each other:
#   ├── buildscripts/
#   ├── core/
#   ├── enterprise/ (nova only)
#   ├── nova/ (nova only)
#   └── masterfiles/
#
# Usage:
#   ./build-macos.sh              # RELEASE build (default)
#   BUILD_TYPE=DEBUG ./build-macos.sh
#   BUILD_TYPE=RELEASE PROJECT=nova ./build-macos.sh
#
# Xcode Command Line Tools alone are NOT enough: the "autogen" step runs
# autoreconf (autoconf/automake/libtool/pkg-config) on core/enterprise/nova to
# regenerate their configure scripts, none of which CLT ships -- and Apple's
# /usr/bin/libtool is an unrelated tool (the static-library archiver), not
# GNU Libtool. Rather than Homebrew/MacPorts, this builds its own copies of
# GNU M4/autoconf/automake/libtool/pkg-config from source into a private
# prefix used only here (see buildscripts/ci/macos-install-autotools.sh) --
# nothing gets installed system-wide.
#

BASEDIR="$(cd "$(dirname "$0")/../../" && pwd)"

# ---------------------------------------------------------------------------
# Required build parameters. Override any of these from the environment
# before running, e.g. BUILD_TYPE=DEBUG ./build-macos.sh
# ---------------------------------------------------------------------------
export PROJECT="${PROJECT:-community}"
export EXPLICIT_ROLE=agent
export BUILD_TYPE="${BUILD_TYPE:-DEBUG}"
export BUILDPREFIX="${BUILDPREFIX:-/var/cfengine}"

repo_list="buildscripts core masterfiles"
[ "$PROJECT" = "nova" ] && repo_list="$repo_list nova enterprise"
for repo in $repo_list; do
    if [ ! -d "$BASEDIR/$repo" ]; then
        echo "Missing repository '$repo' next to this script in $BASEDIR" >&2
        exit 1
    fi
done

BUILD_SCRIPTS="$BASEDIR/buildscripts/build-scripts"

# ---------------------------------------------------------------------------
# Autotools: built from source into a private, build-only prefix (not shared
# with anything else on this machine, no sudo, no Homebrew/MacPorts). Cheap
# to skip on reruns: the installer marks each tool as built once done.
# ---------------------------------------------------------------------------
AUTOTOOLS_PREFIX="${AUTOTOOLS_PREFIX:-$HOME/.cache/buildscripts_cache/autotools-macos}"
echo "==> [1/6] autotools (private prefix: $AUTOTOOLS_PREFIX)"
"$BASEDIR/buildscripts/ci/macos-install-autotools.sh" "$AUTOTOOLS_PREFIX"
export PATH="$AUTOTOOLS_PREFIX/bin:$PATH"

check_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required tool '$1' after running macos-install-autotools.sh" >&2
        missing=1
    fi
}
missing=0
check_tool autoconf
check_tool automake
check_tool aclocal
check_tool libtoolize
check_tool pkg-config
check_tool perl
check_tool git
if [ "$missing" != 0 ]; then
    exit 1
fi

# NOTE: build-scripts/clean-buildmachine is intentionally NOT run here: it
# does "sudo rm -rf $BUILDPREFIX" (i.e. /var/cfengine) and uninstalls every
# cfbuild-* package. Skip it on a first run; only reach for it deliberately
# once you're sure you want to wipe a previous build's install prefix, e.g.:
#   "$BUILD_SCRIPTS/clean-buildmachine"

echo "==> [2/6] autogen"
"$BUILD_SCRIPTS/autogen"

echo "==> [3/6] install-dependencies"
"$BUILD_SCRIPTS/install-dependencies"

echo "==> [4/6] configure"
"$BUILD_SCRIPTS/configure"

echo "==> [5/6] compile"
"$BUILD_SCRIPTS/compile"

echo "==> [6/6] package"
"$BUILD_SCRIPTS/package"

echo
echo "Done. Look for the .pkg under $BASEDIR/cfengine-$PROJECT/"
