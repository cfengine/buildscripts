#!/usr/bin/env bash
set -ex

platform=$1
patched=$platform-patched
if buildah images --format '{{.Name}}:{{.Tag}}' | grep $patched; then
  echo "container image $patched already exists. buildah rm $patched if you want to regenerate"
  continue
fi
if ! buildah ps | grep $platform; then
  buildah --name $platform from $platform
fi
buildah copy $platform . /buildscripts/ci
buildah run $platform /buildscripts/ci/distribution-patched.sh
#buildah tag $platform $platform-$(date +%F)
#buildah commit $platform $patched
#buildah rm $platform
