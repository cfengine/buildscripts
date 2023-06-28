# build cfengine hub package
set -ex
export BUILD_TYPE=DEBUG
export ESCAPETEST=yes
export TEST_MACHINE=chroot
./buildscripts/build-scripts/install-dependencies
./buildscripts/build-scripts/configure
./buildscripts/build-scripts/generate-source-tarballs
./buildscripts/build-scripts/compile
apt remove -y 'cfbuild*' || true
apt remove -y 'cfengine-*' || true
rm -rf /var/cfengine
rm -rf /opt/cfengine
./buildscripts/build-scripts/install-dependencies
./buildscripts/build-scripts/package
mkdir -p packages
cp cfengine-nova-hub/*.deb packages/ || true
cp cfengine-nova-hub/*.rpm packages/ || true
