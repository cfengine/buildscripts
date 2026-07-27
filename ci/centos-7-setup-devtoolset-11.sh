#!/usr/bin/env bash
set -ex
sudo yum install -y centos-release-scl
sudo rm -f /etc/yum.repos.d/CentOS-SCLo-scl.repo
sudo sed -i 's,^#baseurl.*$,baseurl=https://vault.centos.org/7.9.2009/sclo/x86_64/rh/,' /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo
sudo sed -i '/mirrorlist/d' /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo
sudo yum update -y
sudo yum install -y devtoolset-11
if ! grep "source /opt/rh/devtoolset-11/enable" /usr/lib/rpm/find-debuginfo.sh; then
  sudo sed -i '1a\source /opt/rh/devtoolset-11/enable' /usr/lib/rpm/find-debuginfo.sh
fi
source /opt/rh/devtoolset-11/enable
