#!/usr/bin/env bash
# it is expected that this file is sourced, not executed directly
set -ex

if [ -f /etc/os-release ]; then
  source /etc/os-release
  if [ "$ID" = "centos" ] && [ "$VERSION_ID" = "7" ]; then
    if command -v realpath >/dev/null; then
      my_path="$(realpath "${BASH_SOURCE[0]}")"
      my_dir="$(dirname "$my_path")"
      source "$my_dir"/centos-7-setup-devtoolset-11.sh
    else
      echo "FAIL: could not find realpath command on rhel/centos-7 to source needed centos-7-setup-devtoolset-11.sh"
      exit 1
    fi
  fi
fi

if [ "$(uname)" = "HP-UX" ]; then
  # /etc/profile contains tty code that won't work well when sourced and this VUE env var guards against running those bits
  # https://ftp.mirrorservice.org/sites/www.bitsavers.org/pdf/hp/9000_hpux/9.x/B1171-90044_HP_Visual_User_Environment_System_Administration_Manual_Nov91.pdf
  VUE=true
  export VUE
fi

mkdir -p ~/.ssh
echo "build-artifacts-cache.cloud.cfengine.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGahpsY8Phk2+isBmuJQjjQVlh6BNL/Qetc14g26gowV" >> ~/.ssh/known_hosts

# /etc/profile can contain tricky things, on suse for example it includes a call to tty which will fail in CI
# so only source /etc/profile where we absolutely need it.
if [ "$(uname)" = "HP-UX" ] || [ "$(uname)" = "SunOS" ]; then
  if [ -f /etc/profile ]; then
    # running on the proxied host or not we want to make sure local customizations are taken
    # e.g. ent-14014: custom build of ssh needed for build-artifacts-cache needed and /etc/profile has PATH=/opt/craig/bin:$PATH
    . /etc/profile
  fi
fi
# ENT-13750 we return to vendored openssl on rpm platforms so remove possibly installed development packages
if command -v zypper >/dev/null 2>/dev/null; then
  sudo zypper remove -y libopenssl-devel || true
fi
if command -v yum >/dev/null 2>/dev/null; then
  sudo yum erase -y openssl-devel || true
fi

# MinGW hosts build the MSI with wixl (build-scripts/package-msi) and inspect it
# with msiinfo (msitools). uuidgen (uuid-runtime) derives deterministic MSI
# GUIDs for reproducible builds (ENT-13792). Installed by the build-host-setup
# policy at image time; install here too so not-yet-reimaged mingw hosts get
# them without a reimage. See ENT-13868.
if [ -f /etc/cfengine-mingw-build-host.flag ]; then
  if ! command -v wixl >/dev/null 2>&1 || ! command -v msiinfo >/dev/null 2>&1 || ! command -v uuidgen >/dev/null 2>&1; then
    sudo apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wixl msitools uuid-runtime
  fi
fi
