#!/usr/bin/env bash
set -ex

platform=$1
c=$platform
base=$platform-patched
built=$platform-buildhost
if buildah images --format '{{.Name}}:{{.Tag}}' | grep $built; then
  echo "container image $built already exists, remove if you want to rebuild"
  continue
fi

buildah rm $c || true
buildah --name $c from $base
buildah copy $c . /buildscripts/ci

# This section is debian specific for now. TODO: add alternatives when we add more platforms.
buildah run $c apt install -y procps wget sudo
buildah run $c apt remove -y cfengine-nova || true

buildah run $c rm -rf /var/cfengine || true
# touch flag file for policy to know it is in a container and avoid some aspects of configuration
buildah run $c touch /etc/cfengine-in-container.flag
buildah run $c /buildscripts/ci/setup-cfengine-build-host.sh | tee setup-cfengine-build-host.log
# the above, if errored out, is not causing an error, need to fix that.
grep -i error setup-cfengine-build-host.log && exit 1
buildah tag $c $c-$(date +%F)
buildah commit $c $c-buildhost
buildah rm $c
