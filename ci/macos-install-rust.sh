#!/usr/bin/env bash
set -e

install_rust() {
  # Install the Rust toolchain "manually" from the official standalone
  # installers, verifying the SHA256 checksum of each tarball. This is the
  # cargo-based build dependency needed to build leech2. Mirrors
  # linux-install-rust.sh, adapted for macOS: stock macOS ships neither wget
  # nor sha256sum, so this uses curl and "shasum -a 256" instead.
  #
  # Native only: macOS builds run on the host's own architecture (arm64 on
  # Apple Silicon, x86_64 on Intel), there's no cross-compilation target here.
  baseurl="https://static.rust-lang.org/dist"
  version=1.98.1
  prefix=/opt/rust

  workdir="$(mktemp -d)"
  trap 'rm -rf "$workdir"' EXIT
  cd "$workdir"

  if [ "$(uname -m)" = "arm64" ]; then
    host=aarch64-apple-darwin
    # checksum from $baseurl/rustc-${version}-aarch64-apple-darwin.tar.gz.sha256
    rustc_sha=a23663300d59b6c46d0b6d8fe95931fecebebd6b0462cf19e72ee60e049e181a
    # checksum from $baseurl/cargo-${version}-aarch64-apple-darwin.tar.gz.sha256
    cargo_sha=ea0fb08d419cd2049fc6397a3ddb820d90b52ea1b5aea378c321138f36d9894c
    # checksum from $baseurl/rust-std-${version}-aarch64-apple-darwin.tar.gz.sha256
    std_sha=840484e8f9c2a8ed024b706262a1257bb07d9617670a1fc90020536282950690
    # checksum from $baseurl/llvm-tools-${version}-aarch64-apple-darwin.tar.gz.sha256
    llvm_tools_sha=5742de7a64f3140425716de60230793a33130bb845708da9bde077f30746b8b6
  else
    host=x86_64-apple-darwin
    # checksum from $baseurl/rustc-${version}-x86_64-apple-darwin.tar.gz.sha256
    rustc_sha=0d79ceeee99ff619b76330f7115b730dfdcc34cf5fbea80d3d099630bfb78c68
    # checksum from $baseurl/cargo-${version}-x86_64-apple-darwin.tar.gz.sha256
    cargo_sha=29adc1c530fcd4abae1b5b71414032a5712091e61a3a29adcb8a5faf9379c64b
    # checksum from $baseurl/rust-std-${version}-x86_64-apple-darwin.tar.gz.sha256
    std_sha=af7ffb3b408aa2f6a6940fc83ea6dc9c3e919d18f1b04f1a581b7896441e8b78
    # checksum from $baseurl/llvm-tools-${version}-x86_64-apple-darwin.tar.gz.sha256
    llvm_tools_sha=0daa860666209a06024039824b0dbe6115d39b19bff7d23e013090c1759d178e
  fi

  # Download, verify, extract and install a single component tarball, then
  # remove both the tarball and its extracted tree before moving on.
  install_component() {
    name="$1"
    sha="$2"
    tarball="$name.tar.gz"

    # Retry in case of transient errors.
    tries=3
    while [ $tries -gt 0 ]; do
      status=0
      curl --fail --silent --show-error -o "$tarball" "$baseurl/$tarball" || status=$?
      if [ $status -eq 0 ]; then
        break
      fi
      tries=$((tries - 1))
      sleep 10
    done
    if [ $tries -eq 0 ]; then
      echo "curl failed with status $status: $baseurl/$tarball" >&2
      exit 1
    fi

    actual="$(shasum -a 256 "$tarball" | awk '{print $1}')"
    if [ "$actual" != "$sha" ]; then
      echo "checksum mismatch for $tarball: expected $sha, got $actual" >&2
      exit 1
    fi
    tar xf "$tarball"
    rm "$tarball"
    "$name/install.sh" --prefix="$prefix"
    rm -rf "$name"
  }

  install_component "rustc-${version}-${host}" "$rustc_sha"
  install_component "cargo-${version}-${host}" "$cargo_sha"
  install_component "rust-std-${version}-${host}" "$std_sha"

  # Trade-off: leaving this disabled means leech2's release build can't strip
  # debug info (rust-objcopy needs libLLVM.dylib from this component), so
  # Cargo just warns per target and ships lch/libleech2.dylib unstripped --
  # CARGO_PROFILE_RELEASE_STRIP=false in leech2/darwin/build makes that the
  # deliberate, quiet outcome rather than three build-time warnings. This
  # component is a further ~44 MB download/install (small next to the ~1.4 GB
  # the combined "rust" archive would add with docs/clippy included, but not
  # nothing) for binaries that already work fine unstripped -- so it's off by
  # default. Uncomment to get real stripped output instead.
  # install_component "llvm-tools-${version}-${host}" "$llvm_tools_sha"

  mkdir -p /etc/profile.d
  tee /etc/profile.d/rust.sh <<EOF
export PATH=\$PATH:$prefix/bin
EOF

  chown -R root:wheel "$prefix"
  # Make sure it's readable by the build user.
  chmod -R a+rX "$prefix"
}

# Re-exec under sudo when not root (e.g. when sourced from fix-buildhost.sh as
# the build user).
if [ "$(id -u)" -ne 0 ]; then
  exec sudo bash "$0" "$@"
fi
install_rust "$@"
