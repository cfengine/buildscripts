#!/usr/bin/env bash
set -e

install_protobuf() {
  # Install the protoc compiler "manually" from the official prebuilt
  # release, verifying the SHA256 checksum of the zip. protoc is needed to
  # build the cargo-based leech2 dependency. Mirrors linux-install-protobuf.sh,
  # adapted for macOS (curl instead of wget, "shasum -a 256" instead of
  # sha256sum, and installs under /usr/local like Homebrew would).
  cd /usr/local
  version=36.1
  baseurl="https://github.com/protocolbuffers/protobuf/releases/download/v${version}"

  if [ "$(uname -m)" = "arm64" ]; then
    arch=osx-aarch_64
    # sha256sum of protoc-${version}-osx-aarch_64.zip
    sha=de56d57afe30c5d191b11d24ff93dd4025728d7fb43b773886b2d3613e0bdbb2
  else
    arch=osx-x86_64
    # sha256sum of protoc-${version}-osx-x86_64.zip
    sha=ee2c5496e4af0aa6a224894bc0f7025145260e004d890487d510725ce8b473eb
  fi

  zipfile="protoc-${version}-${arch}.zip"

  # Retry in case of transient errors.
  tries=3
  while [ $tries -gt 0 ]; do
    status=0
    curl --fail --silent --show-error -L -o "$zipfile" "$baseurl/$zipfile" || status=$?
    if [ $status -eq 0 ]; then
      break
    fi
    tries=$((tries - 1))
    sleep 10
  done
  if [ $tries -eq 0 ]; then
    echo "curl failed with status $status: $baseurl/$zipfile" >&2
    exit 1
  fi

  actual="$(shasum -a 256 "$zipfile" | awk '{print $1}')"
  if [ "$actual" != "$sha" ]; then
    echo "checksum mismatch for $zipfile: expected $sha, got $actual" >&2
    exit 1
  fi
  # Installs bin/protoc and include/ under /usr/local.
  unzip -o "$zipfile"
  rm "$zipfile"

  chmod a+rx /usr/local/bin/protoc
}

# Re-exec under sudo when not root (e.g. when sourced from fix-buildhost.sh as
# the build user).
if [ "$(id -u)" -ne 0 ]; then
  exec sudo bash "$0"
fi
install_protobuf
