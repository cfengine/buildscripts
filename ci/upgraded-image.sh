#!/usr/bin/env bash
set -ex

platform=$1
upgraded=$platform-upgraded
if buildah images --format '{{.Name}}:{{.Tag}}' | grep $upgraded; then
  echo "container image $upgraded already exists. buildah rm $upgraded if you want to regenerate"
  continue
fi
if ! buildah ps | grep $platform; then
  buildah --name $platform from $platform
fi
buildah copy $platform .. /buildscripts/ci
buildah run $platform apt update -y
buildah run $platform apt upgrade -y
buildah tag $platform $platform-$(date +%F)
buildah commit $platform $upgraded
buildah rm $platform
