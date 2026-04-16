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
