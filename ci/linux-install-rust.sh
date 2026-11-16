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
  version=1.100.0
  prefix=/opt/rust
  extra_targets="$@"

  workdir="$(mktemp -d)"
  trap 'rm -rf "$workdir"' EXIT
  cd "$workdir"

  if uname -m | grep aarch64; then
    host=aarch64-unknown-linux-gnu
    # checksum from $baseurl/rustc-${version}-aarch64-unknown-linux-gnu.tar.gz.sha256
    rustc_sha=7ccc960846f81e016086f1931dedadd837a3317da80e0114df68651145c0f43b
    # checksum from $baseurl/cargo-${version}-aarch64-unknown-linux-gnu.tar.gz.sha256
    cargo_sha=b3acccbba065da7e97c20592442f104bd9554d54bf87a323bba8a1d6e61282eb
  else
    host=x86_64-unknown-linux-gnu
    # checksum from $baseurl/rustc-${version}-x86_64-unknown-linux-gnu.tar.gz.sha256
    rustc_sha=67b0e85ff4b3eee83c48b8ae1da10dd0bcd60b43d02cd0e7df78c59d19f6b960
    # checksum from $baseurl/cargo-${version}-x86_64-unknown-linux-gnu.tar.gz.sha256
    cargo_sha=4e7fc3cbe98e23c88a3c6ce37f834e3ffbc91536789782c4c4a9670df6b16a49
  fi

  # rust-std checksums per target. These are host-architecture independent.
  # checksum from $baseurl/rust-std-${version}-x86_64-unknown-linux-gnu.tar.gz.sha256
  std_x86_64_linux_sha=61eb09d68b338e230d698716927bd4623049c9910ef4a4972e66d763d66ed9e1
  # checksum from $baseurl/rust-std-${version}-aarch64-unknown-linux-gnu.tar.gz.sha256
  std_aarch64_linux_sha=89b01323a6611c9382a401282fb66eb80f1f3241df3e139d3df41afbd2da314b
  # checksum from $baseurl/rust-std-${version}-x86_64-pc-windows-gnu.tar.gz.sha256
  std_x86_64_windows_sha=b1b2845d8212248fbd6a864940aaf65a710d269f360ca2057ede65b33fd6036b

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
