#!/usr/bin/env bash
# run the build in a docker container
set -ex

# find the dir two levels up from here, home of all the repositories
COMPUTED_ROOT=$(readlink -e $(dirname "$0")/../../)
# NTECH_ROOT should be the same, but if available use it so user can do their own thing.
NTECH_ROOT=${NTECH_ROOT:-$COMPUTED_ROOT}

name=cfengine-build-package
# todo, check the image against the Dockerfile for up-to-date ness?
docker build -t $name -f ./Dockerfile-$name . || true
# todo, check if already running and up-to-date?
docker run -d --privileged -v ${NTECH_ROOT}:/data --name $name $name || true
docker exec -i $name bash -c 'mkdir -p /root/.cache'
docker cp cache $name:/root/.cache
docker exec -i $name bash -c 'cd /data; ./buildscripts/ci/build.sh'
docker cp $name:/root/.cache cache
docker cp $name:/data/packages .
