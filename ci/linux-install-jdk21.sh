#!/usr/bin/env bash
set -e

install_jdk() {
  # install jdk "manually"
  # depending on os, might want to do something like `apt remove default-jre openjdk-*-jre-*`
  cd /opt
  baseurl=https://download.oracle.com/java/21/archive/
  version=21.0.8
  if uname -m | grep aarch64; then
    tarball=jdk-$(version)_linux-aarch64_bin.tar.gz
    # checksum from https://download.oracle.com/java/21/latest/jdk-21_linux-aarch64_bin.tar.gz.sha256
    sha=708064ee3a1844245d83be483ff42cc9ca0c482886a98be7f889dff69ac77850
  else
    tarball=jdk-$(version)_linux-x64_bin.tar.gz
    # checksum from https://download.oracle.com/java/24/latest/jdk-24_linux-x64_bin.tar.gz.sha256
    sha=5f9f7c4ca2a6cef0f18a27465e1be81bddd8653218f450a329a2afc9bf2a1dd8
  fi
  wget --quiet "$baseurl$tarball"
  echo "$sha  $tarball" | sha256sum --check -
  tar xf "$tarball"
  tee /etc/profile.d/jdk.sh << EOF
export JAVA_HOME="/opt/jdk-$version"
export PATH=\$PATH:\$JAVA_HOME/bin
EOF
  chown -R root:jenkins "/opt/jdk-$version"
  chmod -R g+rx "/opt/jdk-$version"
  if command -v update-alternatives; then
    update-alternatives --install /usr/bin/java java "/opt/jdk-$version/bin/java" 9999
  else
    ln -s "/opt/jdk-$version/bin/java" /usr/bin/java
  fi
  cd -
}

if [ "$(whoami)" = "root" ]; then
  install_jdk
else
  sudo bash -c install_jdk
fi
