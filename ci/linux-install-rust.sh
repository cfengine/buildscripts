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
  version=1.97.0
  prefix=/opt/rust
  extra_targets="$@"

  workdir="$(mktemp -d)"
  trap 'rm -rf "$workdir"' EXIT
  cd "$workdir"

  if uname -m | grep aarch64; then
    host=aarch64-unknown-linux-gnu
    # checksum from $baseurl/rustc-${version}-aarch64-unknown-linux-gnu.tar.gz.sha256
    rustc_sha=f91c23ade7e7b4ac173f12593eb1dcf1a37189d4e545ca2f64e3c14090ff6c0c
    # checksum from $baseurl/cargo-${version}-aarch64-unknown-linux-gnu.tar.gz.sha256
    cargo_sha=655cc1c9f1e7cb65cd5fa82de31e1adf2d8ba2011a8b5e28ca3e9529898e64bb
  else
    host=x86_64-unknown-linux-gnu
    # checksum from $baseurl/rustc-${version}-x86_64-unknown-linux-gnu.tar.gz.sha256
    rustc_sha=ca0439140d02e91420f4755cc4681a6444a2dbe8e9a6f685f403946ed3efd995
    # checksum from $baseurl/cargo-${version}-x86_64-unknown-linux-gnu.tar.gz.sha256
    cargo_sha=0214406b145a134463149b0dcc8cdd7a0882e181d2ad2cf893723bbd576d4a44
  fi

  # rust-std checksums per target. These are host-architecture independent.
  # checksum from $baseurl/rust-std-${version}-x86_64-unknown-linux-gnu.tar.gz.sha256
  std_x86_64_linux_sha=26abd06b9c4221811af1baec86dfb6de9535862fc853b85388dcc314c96cea6d
  # checksum from $baseurl/rust-std-${version}-aarch64-unknown-linux-gnu.tar.gz.sha256
  std_aarch64_linux_sha=ae6c76b70be4768ecf2f320f1e6fa28525730b7fd7d6cfc822a3a23e0c07fcc2
  # checksum from $baseurl/rust-std-${version}-x86_64-pc-windows-gnu.tar.gz.sha256
  std_x86_64_windows_sha=7ef19232b379616509007c7a8db45c4ee7031c22d9614fa2b7f18b2a30ff85fa

  # Download, verify, extract and install a single component tarball, then
  # remove both the tarball and its extracted tree before moving on.
  install_component() {
    name="$1"
    sha="$2"
    tarball="$name.tar.gz"
    wget --quiet "$baseurl/$tarball"
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
