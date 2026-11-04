#!/usr/bin/env bash
# args:
# $1 - destination for build e.g. /opt would result in /opt/pcre2 and /opt/pcre2/lib as the build destination. default is /opt

dest="${dest:-/opt}"

GAINROOT=""
if [ "$(id -u)" != "0" ]; then
    GAINROOT="sudo"
    if ! command -v sudo >/dev/null; then
        echo "Sorry, either run $0 as root or install sudo."
        exit 1
    fi
fi

set -e
buildscripts_dir="$(cd $(dirname "$0"); cd ..; pwd)"

if [ -d "$dest"/pcre2 ]; then
    echo "pcre2 already built to $dest/pcre2, removing and building again..."
    $GAINROOT rm -rf "$dest/pcre2"
fi

tmpdir="$(mktemp -d)"
echo "Building pcre2 in $tmpdir..."

(
    cd "$tmpdir"
    source="$(head -1 "$buildscripts_dir"/deps-packaging/pcre2/source)"
    head -1 "$buildscripts_dir"/deps-packaging/pcre2/distfiles > distfile
    tarball="$(awk '{print $2}' distfile)"
    curl --fail --location --silent --show-error --output "$tarball" "$source$tarball"
    sha256sum --check distfile
    
    tar xf "$tarball"
    cd "${tarball%.tar.gz}"
    ./configure --prefix="$dest"/pcre2 --libdir="$dest"/pcre2/lib
    make
    $GAINROOT make install
)
rm -rf "$tmpdir"
