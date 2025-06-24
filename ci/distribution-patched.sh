#!/usr/bin/env bash
set -ex
if grep CODENAME=stretch /etc/os-release; then
  echo "deb http://archive.debian.org/debian-archive/debian stretch main" >/etc/apt/sources.list
  echo "deb http://archive.debian.org/debian-archive/debian stretch-backports main" >>/etc/apt/sources.list
fi
if [ -f /etc/centos-release ]; then
  _version=$(cat /etc/centos-release | cut -d' ' -f3 | cut -d. -f1)
  if [ "$_version" = "6" ] || [ "$_version" = "7" ]; then
    sed -i 's/mirror.centos.org/vault.centos.org/;/^mirrorlist/d;s/^#baseurl/baseurl/' /etc/yum.repos.d/CentOS-Base.repo
  fi
fi
if command -v yum; then
  yum -e 0 -d 0 -y update
  yum -e 0 -d 0 -y install git rsync
fi
if command -v apt; then
  DEBIAN_FRONTEND=noninteractive apt -yqq update
  DEBIAN_FRONTEND=noninteractive apt -yqq upgrade
  DEBIAN_FRONTEND=noninteractive apt install -yqq git rsync
fi
if command -v zypper; then
  source /etc/os-release
  rpm --import https://download.opensuse.org/distribution/leap/$VERSION_ID/repo/oss/repodata/repomd.xml.key
  zypper ar -cfp 90 https://download.opensuse.org/distribution/leap/$VERSION_ID/repo/oss/ oss
  for repo in oss sle backports; do
    rpm --import https://download.opensuse.org/update/leap/$VERSION_ID/$repo/repodata/repomd.xml.key
    zypper ar -cfp 70 https://download.opensuse.org/update/leap/$VERSION_ID/$repo/ update-$repo
  done
  zypper -qn ref
  zypper lr # diagnostic to see what repos are enabled
  zypper -qn update
  zypper -qn rm libsnmp15
  zypper -qn install git rsync
  groupadd jenkins || true
  useradd -m -u 1010 -g jenkins jenkins || true
fi
