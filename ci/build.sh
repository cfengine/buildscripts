#!/usr/bin/env bash
# build cfengine hub package
# $@ -- optional space separated paths to copy to artifacts

set -ex

additional_artifacts="$@"
export PROJECT=nova
export NO_CONFIGURE=1
export BUILD_TYPE=DEBUG
export ESCAPETEST=yes
export EXPLICIT_ROLE=hub
export TEST_MACHINE=chroot

set +x # hide secrets
eval $(ssh-agent -s)
if [ -z "$SECRET" ]; then
  echo "Need sftp cache ssh secret key. Provide with SECRET env variable"
  exit 1
else
  echo "$SECRET" | ssh-add -
fi
ssh-add -l
set -x # stop hiding secrets

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

sudo mkdir -p artifacts
sudo cp cfengine-nova-hub/*.deb artifacts/ || true
sudo cp cfengine-nova-hub/*.rpm artifacts/ || true

for artifact_path in $additional_artifacts; do
  sudo cp -r "$artifact_path" artifacts/ || true
done


# todo maybe save the cache cp -R ~/.cache buildscripts/ci/cache

# clean up
time sudo apt remove -y 'cfbuild*' || true
time sudo apt remove -y 'cfengine-*' || true
time sudo rm -rf /var/cfengine
time sudo rm -rf /opt/cfengine
