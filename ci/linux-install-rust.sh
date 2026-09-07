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
  version=1.98.1
  prefix=/opt/rust
  extra_targets="$@"

  workdir="$(mktemp -d)"
  trap 'rm -rf "$workdir"' EXIT
  cd "$workdir"

  if uname -m | grep aarch64; then
    host=aarch64-unknown-linux-gnu
    # checksum from $baseurl/rustc-${version}-aarch64-unknown-linux-gnu.tar.gz.sha256
    rustc_sha=c6998e0d7faa373ba9d571715dcd04626a7735619bc1c37cfcaadf6efffc1f74
    # checksum from $baseurl/cargo-${version}-aarch64-unknown-linux-gnu.tar.gz.sha256
    cargo_sha=a464c555c6f3146ee6854d0c1f4da85f514519e70813de6df277ced0e188c471
  else
    host=x86_64-unknown-linux-gnu
    # checksum from $baseurl/rustc-${version}-x86_64-unknown-linux-gnu.tar.gz.sha256
    rustc_sha=a6e35741daaac7978e7f485b564a783d13b6740a1ecf3e80c2e71696ca5cabb2
    # checksum from $baseurl/cargo-${version}-x86_64-unknown-linux-gnu.tar.gz.sha256
    cargo_sha=3f1215b2a3b88c7aaa008b561bd4f39d6c6672fa7821e562ab6ba1a6d6f37f61
  fi

  # rust-std checksums per target. These are host-architecture independent.
  # checksum from $baseurl/rust-std-${version}-x86_64-unknown-linux-gnu.tar.gz.sha256
  std_x86_64_linux_sha=eddab0358cbd12aeb897716aab00d1db7b59696e85b9ac4982e72259a9a976b1
  # checksum from $baseurl/rust-std-${version}-aarch64-unknown-linux-gnu.tar.gz.sha256
  std_aarch64_linux_sha=779407b14507542581216d89eb9f3fbb232abbf3abcc15c365cb32fa0614e409
  # checksum from $baseurl/rust-std-${version}-x86_64-pc-windows-gnu.tar.gz.sha256
  std_x86_64_windows_sha=0cda26447df0749bc84044be8c8083ac4dc87bf137c11cc31ec9673a6e2e0344

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
