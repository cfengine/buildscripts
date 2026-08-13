#!/usr/bin/env bash
set -e

install_protobuf() {
  # Install the protoc compiler "manually" from the official prebuilt
  # release, verifying the SHA256 checksum of the zip. protoc is needed to
  # build the cargo-based leech2 dependency.
  #
  # The release archives do not ship .sha256 files, so the checksums below are
  # computed by us (and refreshed by the dependency update script).
  cd /opt
  version=35.1
  baseurl="https://github.com/protocolbuffers/protobuf/releases/download/v${version}"

  if uname -m | grep aarch64; then
    arch=linux-aarch_64
    # sha256sum of protoc-${version}-linux-aarch_64.zip
    sha=01bf9d08808c7f96678b63f4bd8efa559bb4f83d5a7a270d5edaf507f9d5d9cf
  else
    arch=linux-x86_64
    # sha256sum of protoc-${version}-linux-x86_64.zip
    sha=6930ebf62bd4ea607b98fff052596c6ee564b9835b4ce172c75a3f53ae9d91b7
  fi

  zipfile="protoc-${version}-${arch}.zip"

  # Retry in case of transient errors.
  tries=3
  while [ $tries -gt 0 ]; do
    # -O keeps every attempt writing to the same file rather than adding a .1 suffix.
    status=0
    wget --quiet -O "$zipfile" "$baseurl/$zipfile" || status=$?
    if [ $status -eq 0 ]; then
      break
    fi
    tries=$((tries - 1))
    sleep 10
  done
  if [ $tries -eq 0 ]; then
    echo "wget failed with status $status: $baseurl/$zipfile" >&2
    exit 1
  fi

  echo "$sha  $zipfile" | sha256sum --check -
  # Installs bin/protoc and include/ under /usr/local.
  unzip -o "$zipfile" -d /usr/local
  rm "$zipfile"

  chmod a+rx /usr/local/bin/protoc
  cd -
}

# Re-exec under sudo when not root (e.g. when sourced from fix-buildhost.sh as
# the build user).
if [ "$(id -u)" -ne 0 ]; then
  exec sudo bash "$0"
fi
install_protobuf
