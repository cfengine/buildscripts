#!/usr/bin/env bash
set -e

install_rust() {
  # Install the Rust toolchain "manually" from the official standalone
  # installers, verifying the SHA256 checksum of each tarball. This is the
  # cargo-based build dependency needed to build leech2.
  #
  # We install the individual component tarballs (rustc, cargo, rust-std)
  # rather than the combined "rust" archive: the combined one is ~360 MB and
  # extracts to ~1.4 GB of docs/clippy/llvm-tools we never install. The build
  # hosts are tight on disk, so we also delete each tarball and its extracted
  # tree right after installing it to keep peak disk usage low.
  #
  # Linux builds are native (x86_64 packages are built on x86_64 hosts,
  # aarch64 on aarch64 hosts), so we only install the host's own Linux std.
  # Windows is the only cross-compilation target, and only on MinGW build
  # hosts, so the caller passes "x86_64-pc-windows-gnu" as an argument there.
  baseurl="https://static.rust-lang.org/dist"
  version=1.99.0
  prefix=/opt/rust
  extra_targets="$@"

  workdir="$(mktemp -d)"
  trap 'rm -rf "$workdir"' EXIT
  cd "$workdir"

  if uname -m | grep aarch64; then
    host=aarch64-unknown-linux-gnu
    # checksum from $baseurl/rustc-${version}-aarch64-unknown-linux-gnu.tar.gz.sha256
    rustc_sha=6780ebb1b8ae66cc5d37ebfdc70b18fe775b1083c997f4e2c963d45a7eec59bc
    # checksum from $baseurl/cargo-${version}-aarch64-unknown-linux-gnu.tar.gz.sha256
    cargo_sha=f8b85e84b0514b69e17e3bad1c2dec7526f4a40cec565d233bbdcb66484dd9e0
  else
    host=x86_64-unknown-linux-gnu
    # checksum from $baseurl/rustc-${version}-x86_64-unknown-linux-gnu.tar.gz.sha256
    rustc_sha=238e72b8617f79bc96f27a5bfeb1a208b5755fe1a48f8bc190fe403ef6d54ab8
    # checksum from $baseurl/cargo-${version}-x86_64-unknown-linux-gnu.tar.gz.sha256
    cargo_sha=c2b8ba1f59e7a230aa5522684f3f7aa620b98e5ad37683a5e5cf9b41f534fa1e
  fi

  # rust-std checksums per target. These are host-architecture independent.
  # checksum from $baseurl/rust-std-${version}-x86_64-unknown-linux-gnu.tar.gz.sha256
  std_x86_64_linux_sha=1dcaa01beb6bc78fdb13815b4f15214719167c58e3d79fbdf214591f8c195ee1
  # checksum from $baseurl/rust-std-${version}-aarch64-unknown-linux-gnu.tar.gz.sha256
  std_aarch64_linux_sha=cdffa7100206633ccfd2514ea7781b4211813bf04c831a509240e1cda5308512
  # checksum from $baseurl/rust-std-${version}-x86_64-pc-windows-gnu.tar.gz.sha256
  std_x86_64_windows_sha=5d7f8eb792439b2e85afaf27497ff0f67e3ada0ef09adf81d564028e2aa1b90b

  # Download, verify, extract and install a single component tarball, then
  # remove both the tarball and its extracted tree before moving on.
  install_component() {
    name="$1"
    sha="$2"
    tarball="$name.tar.gz"

    # Retry in case of transient errors.
    tries=3
    while [ $tries -gt 0 ]; do
      # -O keeps every attempt writing to the same file rather than adding a .1 suffix.
      status=0
      wget --quiet -O "$tarball" "$baseurl/$tarball" || status=$?
      if [ $status -eq 0 ]; then
        break
      fi
      tries=$((tries - 1))
      sleep 10
    done
    if [ $tries -eq 0 ]; then
      echo "wget failed with status $status: $baseurl/$tarball" >&2
      exit 1
    fi

    echo "$sha  $tarball" | sha256sum --check -
    tar xf "$tarball"
    rm "$tarball"
    "$name/install.sh" --prefix="$prefix"
    rm -rf "$name"
  }

  # Install the rust-std for a given target triple, looking up its checksum.
  install_std() {
    case "$1" in
      x86_64-unknown-linux-gnu) sha="$std_x86_64_linux_sha" ;;
      aarch64-unknown-linux-gnu) sha="$std_aarch64_linux_sha" ;;
      x86_64-pc-windows-gnu) sha="$std_x86_64_windows_sha" ;;
      *)
        echo "No pinned checksum for rust-std target '$1'" >&2
        exit 1
        ;;
    esac
    install_component "rust-std-${version}-$1" "$sha"
  }

  install_component "rustc-${version}-${host}" "$rustc_sha"
  install_component "cargo-${version}-${host}" "$cargo_sha"

  # The host's own native std, plus any cross-compilation targets requested.
  install_std "$host"
  for target in $extra_targets; do
    install_std "$target"
  done

  tee /etc/profile.d/rust.sh << EOF
export PATH=\$PATH:$prefix/bin
EOF

  chown -R root:root "$prefix"
  # Make sure it's readable by the build user.
  chmod -R a+rX "$prefix"
}

# Re-exec under sudo when not root (e.g. when sourced from fix-buildhost.sh as
# the build user), preserving any cross-compilation target arguments.
if [ "$(id -u)" -ne 0 ]; then
  exec sudo bash "$0" "$@"
fi
install_rust "$@"
