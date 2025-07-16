#!/usr/bin/env bash
set -e

install_jdk() {
  # install jdk "manually"
  # depending on os, might want to do something like `apt remove default-jre openjdk-*-jre-*`
  cd /opt
  baseurl=https://download.oracle.com/java/21/latest/
  version=21.0.7
  if uname -m | grep aarch64; then
    tarball=jdk-21_linux-aarch64_bin.tar.gz
    # checksum from https://download.oracle.com/java/21/latest/jdk-21_linux-aarch64_bin.tar.gz.sha256
    sha=708064ee3a1844245d83be483ff42cc9ca0c482886a98be7f889dff69ac77850
  else
    tarball=jdk-21_linux-x64_bin.tar.gz
    sha=267b10b14b4e5fada19aca3be3b961ce4f81f1bd3ffcd070e90a5586106125eb
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
