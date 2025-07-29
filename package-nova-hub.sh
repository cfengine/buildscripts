# this is build-nova-hub.sh but minimized to how to iterate only on package step
#apt update -y
#apt upgrade -y
#apt install -y git autoconf automake m4 make bison flex binutils libtool gcc g++ libc-dev libpam0g-dev python3 psmisc libtokyocabinet-dev libssl-dev libpcre3-dev default-jre-headless build-essential fakeroot ntp dpkg-dev debhelper pkg-config nfs-common sudo apt-utils wget libncurses5 rsync libexpat1-dev libexpat1 curl
#apt purge -y emacs emacs24 libltdl-dev libltdl7
#
## extra for hub
#apt install -y python3-pip
export NO_CONFIGURE=1
export PROJECT=nova
export BUILD_TYPE=DEBUG
export EXPLICIT_ROLE=hub

#./buildscripts/build-scripts/autogen
#./buildscripts/build-scripts/clean-buildmachine
#./buildscripts/build-scripts/install-dependencies
#./buildscripts/build-scripts/configure
#./buildscripts/build-scripts/compile
# in order to run package again
# - deps packages must be built and cached
apt remove -y cfbuild*
apt remove -y cfengine-*
rm -rf /var/cfengine
rm -rf /opt/cfengine
# maybe we need to install dependencies before packaging?, will take cached packages and install them so they are available for packaging?
./buildscripts/build-scripts/install-dependencies
./buildscripts/build-scripts/package
#ls -l cfengine-nova-hub/*.deb
