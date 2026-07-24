#!/usr/bin/env bash
set -e

install_jdk() {
  # install jdk "manually"
  # depending on os, might want to do something like `apt remove default-jre openjdk-*-jre-*`
  cd /opt
  # in order to have a stable download we must use the latest-1 version as that is the most recent in the "archive"
  baseurl=https://download.oracle.com/java/21/archive/
  major_version=21
  baseurl="https://download.oracle.com/java/${major_version}/archive/"
  version=21.0.11
  if uname -m | grep aarch64; then
    tarball=jdk-${version}_linux-aarch64_bin.tar.gz
    # checksum from https://download.oracle.com/java/${major_version}/archive/jdk-${version}_linux-aarch64_bin.tar.gz.sha256
    sha=2ebe89cad767abba83fb0b8cedd2d2d9bcbf947315fde78f7263a57a24f43b96
  else
    tarball=jdk-${version}_linux-x64_bin.tar.gz
    # checksum from https://download.oracle.com/java/${major_version}/latest/jdk-${version}_linux-x64_bin.tar.gz.sha256
    sha=e1c25a83f9e2e374c93e0c29cc3d98a947621ae0fefa4a8d932951eb160c47c3
  fi
  wget --quiet "$baseurl$tarball"
  echo "$sha  $tarball" | sha256sum --check -
  tar xf "$tarball"
  tee /etc/profile.d/jdk.sh << EOF
export JAVA_HOME="/opt/jdk-$version"
export PATH=\$PATH:\$JAVA_HOME/bin
EOF
  chown -R root:root "/opt/jdk-$version"
  chmod -R 755 "/opt/jdk-$version"
  if command -v update-alternatives; then
    update-alternatives --install /usr/bin/java java "/opt/jdk-$version/bin/java" 9999
  else
    ln -s "/opt/jdk-$version/bin/java" /usr/bin/java
  fi
  cd -
}

if command -v java; then
  echo "java already installed, will skip install."
  exit
fi

# TODO check version
if [ "$(whoami)" = "root" ]; then
  install_jdk
else
  sudo bash -c install_jdk
fi
