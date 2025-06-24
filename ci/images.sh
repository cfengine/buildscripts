#!/usr/bin/env bash
set -ex

# todo: centos7, opensuse/leap:15 (no :12), registry.access.redhat.com/ubi9 (-minimal, -init, -micro (standard))
# run this on x86 and arm hardware to cover "all the bases" :)
for platform in $(cat platform-container-image.list); do
  ./patched-image.sh $platform
  ./buildhost-image.sh $platform
done
