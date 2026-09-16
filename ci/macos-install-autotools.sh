#!/bin/sh -e

# Builds GNU M4, autoconf, automake, libtool and pkg-config from source into
# a private prefix, for use only by this build system's own "autogen" step
# (which runs autoreconf on core/enterprise/nova/masterfiles) -- not
# installed system-wide, not linked into /usr/local, no Homebrew/MacPorts.
#
# Xcode Command Line Tools alone are not enough:
#   - autoconf/automake/libtool/pkg-config aren't shipped at all.
#   - Apple's /usr/bin/libtool is an unrelated tool (the static-library
#     archiver), not GNU Libtool.
#   - Apple's /usr/bin/m4 is GNU M4 1.4.6 (2006), which is too old for
#     current autoconf: autoconf 2.73 requires M4 >= 1.4.8. So M4 itself
#     needs building first, before autoconf can be built.
#
# Build order matters: autoconf needs a working M4; automake needs autoconf
# (it shells out to autom4te). libtool and pkg-config are standalone.
#
# Usage:
#   ./macos-install-autotools.sh [prefix]
#   (defaults to $HOME/.cache/buildscripts_cache/autotools-macos, alongside
#   this build system's other cached artifacts, see deps-packaging/pkg-cache)

set -e

PREFIX="${1:-$HOME/.cache/buildscripts_cache/autotools-macos}"
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/macos-install-autotools.XXXXXX")
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

mkdir -p "$PREFIX"
export PATH="$PREFIX/bin:$PATH"

log() { echo "macos-install-autotools: $*" >&2; }

# Download, verify, extract, configure/make/install a single autotools-style
# source tarball, then remove the tarball and extracted tree.
build_component() {
    name="$1"     # e.g. "m4-1.4.21"
    url="$2"
    sha="$3"
    shift 3
    configure_args="$*"

    if [ -f "$PREFIX/.built-$name" ]; then
        log "$name already built, skipping"
        return 0
    fi

    tarball="$name.tar.gz"
    log "Fetching $url"
    tries=3
    while [ $tries -gt 0 ]; do
        status=0
        curl --fail --silent --show-error -L -o "$tarball" "$url" || status=$?
        [ $status -eq 0 ] && break
        tries=$((tries - 1))
        sleep 5
    done
    if [ $tries -eq 0 ]; then
        log "download failed: $url"
        exit 1
    fi

    actual=$(shasum -a 256 "$tarball" | awk '{print $1}')
    if [ "$actual" != "$sha" ]; then
        log "checksum mismatch for $tarball: expected $sha, got $actual"
        exit 1
    fi

    tar xf "$tarball"
    (
        cd "$name"
        log "Building $name..."
        # shellcheck disable=SC2086
        # We want word splitting of $configure_args.
        ./configure --prefix="$PREFIX" $configure_args >"$WORKDIR/$name.log" 2>&1 ||
            { tail -n 60 "$WORKDIR/$name.log" >&2; exit 1; }
        make >>"$WORKDIR/$name.log" 2>&1 ||
            { tail -n 60 "$WORKDIR/$name.log" >&2; exit 1; }
        make install >>"$WORKDIR/$name.log" 2>&1 ||
            { tail -n 60 "$WORKDIR/$name.log" >&2; exit 1; }
    )
    rm -rf "$name" "$tarball"
    touch "$PREFIX/.built-$name"
}

# GNU M4 1.4.21 -- must come first, autoconf refuses to configure without a
# recent enough M4 in PATH.
build_component m4-1.4.21 \
    https://ftp.gnu.org/gnu/m4/m4-1.4.21.tar.gz \
    38ae59f7a30bf9c108193cc5c25fbb06014f21e230c7ede2eff614f7b7c37ed8

# autoconf 2.73
build_component autoconf-2.73 \
    https://ftp.gnu.org/gnu/autoconf/autoconf-2.73.tar.gz \
    259ddfa3bddc799cfb81489cc0f17dfdf1bd6d1505dda53c0f45ff60d6a4f9a7

# automake 1.19 -- needs autoconf (autom4te) on PATH, which is why this runs
# after it, with $PREFIX/bin already prepended to PATH above.
build_component automake-1.19 \
    https://ftp.gnu.org/gnu/automake/automake-1.19.tar.gz \
    79e8b1f7a967e87ce8a9ded76bee7f793d0ce1886ab2002feb1b0510f578b75a

# libtool 2.6.2
build_component libtool-2.6.2 \
    https://ftp.gnu.org/gnu/libtool/libtool-2.6.2.tar.gz \
    24adb3aa9ae035c70faba344af57d73215eb89281045af6c7ccd307751f8b0bf

# pkg-config 0.29.2 -- built with its own vendored/internal glib subset so it
# doesn't need a system or Homebrew glib. That vendored glib is old enough
# that current clang's default-error int-conversion/implicit-function
# warnings (promoted from warnings around Xcode 14) fail the build outright;
# downgrade them back to warnings, same as older compilers treated them.
CFLAGS="-Wno-int-conversion -Wno-implicit-function-declaration" \
    build_component pkg-config-0.29.2 \
    https://pkgconfig.freedesktop.org/releases/pkg-config-0.29.2.tar.gz \
    6fc69c01688c9458a57eb9a1664c9aba372ccda420a02bf4429fe610e7e7d591 \
    --with-internal-glib

log "Done. Autotools installed under $PREFIX"
