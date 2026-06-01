#!/usr/bin/env bash
# it is expected that this file is sourced, not executed directly
set -ex
my_path="$(realpath "${BASH_SOURCE[0]}")"
my_dir="$(dirname "$my_path")"

if [ -f /etc/os-release ]; then
  source /etc/os-release
  if [ "$ID" = "centos" ] && [ "$VERSION_ID" = "7" ]; then
    source "$my_dir"/centos-7-setup-devtoolset-11.sh
  fi
fi

if [ "$(uname)" = "HP-UX" ]; then
  # /etc/profile contains tty code that won't work well when sourced and this VUE env var guards against running those bits
  # https://ftp.mirrorservice.org/sites/www.bitsavers.org/pdf/hp/9000_hpux/9.x/B1171-90044_HP_Visual_User_Environment_System_Administration_Manual_Nov91.pdf
  VUE=true
  export VUE
fi

if [ -f /etc/profile ]; then
  # running on the proxied host or not we want to make sure local customizations are taken
  # e.g. ent-14014: custom build of ssh needed for build-artifacts-cache needed and /etc/profile has PATH=/opt/craig/bin:$PATH
  . /etc/profile
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

# ENT-11586: provision the build host here, in the testing-pr job, instead of in
# the Amazon EC2 init script, so failures are visible in the build log and fail
# the build. Run on every build (setup is idempotent) so a PR can change build
# host setup and a later build reverts it. setup-cfengine-build-host.sh is
# Linux-only and must run as root; exotic hosts are provisioned out-of-band.
if [ "$(uname)" = "Linux" ]; then
  sudo "$my_dir"/setup-cfengine-build-host.sh
fi
