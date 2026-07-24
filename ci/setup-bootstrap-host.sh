#!/usr/bin/env bash
set -e
thisdir="$(dirname "$0")"

# current standard of debian-9 for bootstrap requires using archive.debian.org
rm -f /etc/apt/sources.list.d/*; echo 'deb http://archive.debian.org/debian/ stretch main contrib non-free' >/etc/apt/sources.list

apt-get -qy update
apt-get -qy upgrade
apt-get -y install git autogen autoconf automake m4 make bison flex binutils libtool gcc g++ libc-dev \
           liblmdb-dev libpam0g-dev python libssl-dev libpcre3-dev psmisc curl jq unzip \
           pigz parallel libpcre2-dev php-zip

bash "$thisdir"/linux-install-php.sh

bash "$thisdir"/linux-install-node.sh

bash "$thisdir"/linux-install-composer.sh

bash "$thisdir"/linux-install-jdk.sh
