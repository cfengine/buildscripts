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
  version=1.97.1
  prefix=/opt/rust
  extra_targets="$@"

  workdir="$(mktemp -d)"
  trap 'rm -rf "$workdir"' EXIT
  cd "$workdir"

  if uname -m | grep aarch64; then
    host=aarch64-unknown-linux-gnu
    # checksum from $baseurl/rustc-${version}-aarch64-unknown-linux-gnu.tar.gz.sha256
    rustc_sha=8d9f3095a3108e38232f123645e2a0368bca67c975f8b91088004f8ffd9a6d39
    # checksum from $baseurl/cargo-${version}-aarch64-unknown-linux-gnu.tar.gz.sha256
    cargo_sha=cafde243518b016f825d13a5f2ca4ffd7d80f5966dfbec3539cd092c7c4f9871
  else
    host=x86_64-unknown-linux-gnu
    # checksum from $baseurl/rustc-${version}-x86_64-unknown-linux-gnu.tar.gz.sha256
    rustc_sha=1c441e430c1cca49dff54a8d59c41038bf6f79f7b8756596cb2f36511a015eba
    # checksum from $baseurl/cargo-${version}-x86_64-unknown-linux-gnu.tar.gz.sha256
    cargo_sha=90cbeb8adfe8ca0fcbe01a18bd9b99d3e5e98fd29c003032828ebf3ffba0e4ed
  fi

  # rust-std checksums per target. These are host-architecture independent.
  # checksum from $baseurl/rust-std-${version}-x86_64-unknown-linux-gnu.tar.gz.sha256
  std_x86_64_linux_sha=45b927ecf776b9645ca2ed5b287fc6814824a073c30c7c5d5c0ad4425295ecee
  # checksum from $baseurl/rust-std-${version}-aarch64-unknown-linux-gnu.tar.gz.sha256
  std_aarch64_linux_sha=ceffa428fe573507418858d59add342b351730725f36f7679b251e8b68103dec
  # checksum from $baseurl/rust-std-${version}-x86_64-pc-windows-gnu.tar.gz.sha256
  std_x86_64_windows_sha=0e240192a91dace872d72fd2a5ad21b4be5d278b0d0281d58013e11f908fb5b6

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
