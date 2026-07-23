#!/usr/bin/bash
set -e
thisdir="$(dirname "$0")"

rm -f /etc/apt/sources.list.d/*; echo 'deb http://archive.debian.org/debian/ stretch main contrib non-free' >/etc/apt/sources.list
apt-get -qy update
apt-get -qy upgrade
apt-get -y install git autogen autoconf automake m4 make bison flex binutils libtool gcc g++ libc-dev \
           liblmdb-dev libpam0g-dev python libssl-dev libpcre3-dev psmisc curl jq unzip \
           pigz parallel libpcre2-dev php-zip

if ! command -v php; then
  bash "$thisdir"/linux-install-php.sh
fi

if ! command -v node; then
  bash "$thisdir"/linux-install-node.sh
fi

curl -sSfL https://raw.githubusercontent.com/cfengine/buildscripts/refs/heads/master/user-scripts/composer-install.sh | \
COMPOSER_INSTALL_DIR="/usr/bin" \
bash

# install jdk "manually"
cd /opt
wget https://download.java.net/java/GA/jdk21.0.1/415e3f918a1f4062a0074a2794853d0d/12/GPL/openjdk-21.0.1_linux-x64_bin.tar.gz
echo "7e80146b2c3f719bf7f56992eb268ad466f8854d5d6ae11805784608e458343f openjdk-21.0.1_linux-x64_bin.tar.gz" > openjdk-21.0.1_linux-x64_bin.tar.gz.sha256
sha256sum --check openjdk-21.0.1_linux-x64_bin.tar.gz.sha256
sudo tar xf openjdk-21.0.1_linux-x64_bin.tar.gz
sudo tee /etc/profile.d/jdk.sh << EOF
export JAVA_HOME=/opt/jdk-21.0.1
export PATH=\$PATH:\$JAVA_HOME/bin
EOF
sudo update-alternatives --install /usr/bin/java java /opt/jdk-21.0.1/bin/java 1
