#!/usr/bin/env bash
# build cfengine hub package
set -ex
export PROJECT=nova
export NO_CONFIGURE=1
export BUILD_TYPE=DEBUG
export ESCAPETEST=yes
export EXPLICIT_ROLE=hub
export TEST_MACHINE=chroot
# TODO maybe seed the cache? cp -R buildscripts/ci/cache ~/.cache
time ./buildscripts/build-scripts/build-environment-check
time ./buildscripts/build-scripts/install-dependencies
time ./buildscripts/build-scripts/configure # 3 minutes locally
time ./buildscripts/build-scripts/generate-source-tarballs # 1m49
time ./buildscripts/build-scripts/compile
time sudo apt remove -y 'cfbuild*' || true
time sudo apt remove -y 'cfengine-*' || true
time sudo rm -rf /var/cfengine
time sudo rm -rf /opt/cfengine
time ./buildscripts/build-scripts/install-dependencies
time ./buildscripts/build-scripts/package
sudo mkdir -p packages
sudo cp cfengine-nova-hub/*.deb packages/ || true
sudo cp cfengine-nova-hub/*.rpm packages/ || true

# todo maybe save the cache cp -R ~/.cache buildscripts/ci/cache

# clean up
time sudo apt remove -y 'cfbuild*' || true
time sudo apt remove -y 'cfengine-*' || true
time sudo rm -rf /var/cfengine
time sudo rm -rf /opt/cfengine
