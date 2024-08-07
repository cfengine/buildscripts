# setup build host on ubuntu 20
set -ex
PREFIX=/var/cfengine

# Github Actions provides machines with various packages installed,
# what confuses our build system into thinking that it's an RPM distro.
sudo rm -f /bin/rpm

# Install dependencies
sudo apt-get update -qy

# install apt-utils so that debconf can configure installed packages
sudo apt-get install -qy apt-utils

# git is needed for build-scripts/autogen to determine revision for such things as deps-packaging
sudo apt-get install -qy git

# python3-pip is needed for cfengine-nova-hub.deb packaging
sudo apt-get install -qy python3 python3-pip

# Install psycopg2
apt-get -y install python3-psycopg2

# install composer and friends
sudo apt-get -qy install curl php-cli php-curl php-zip php-mbstring php-xml php-gd composer php-ldap
# packages needed for autogen
sudo apt-get -qy install git autoconf automake m4 make bison flex \
 binutils libtool gcc g++ libc-dev libpam0g-dev python3 psmisc

# packages needed for buildscripts
sudo apt-get -qy install libncurses5 rsync
# packages needed for building 
sudo apt-get -qy install bison flex binutils build-essential fakeroot ntp \
 dpkg-dev libpam0g-dev python3 debhelper pkg-config psmisc nfs-common

# remove unwanted packages
sudo apt-get -qq purge apache* "postgresql*" redis*

# packages needed for installing Mission portal dependencies
# remove any nodejs or node- packages currently in place
sudo apt-get remove -qy 'nodejs*' 'node-*'
# replace with exact version we want
wget -O - https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -qy nodejs
