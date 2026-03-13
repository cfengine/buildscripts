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
  version=21.0.10
  if uname -m | grep aarch64; then
    tarball=jdk-${version}_linux-aarch64_bin.tar.gz
    # checksum from https://download.oracle.com/java/${major_version}/archive/jdk-${version}_linux-aarch64_bin.tar.gz.sha256
    sha=edaf800c6deb1e7daeb448ef9c6a047551fd681942cb9e37e2729ae1a3918d1d
  else
    tarball=jdk-${version}_linux-x64_bin.tar.gz
    # checksum from https://download.oracle.com/java/${major_version}/latest/jdk-${version}_linux-x64_bin.tar.gz.sha256
    sha=773eff7191d996d3b6ce3a99c21ce69cf2d836fd07277106313732a098d4309a
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
