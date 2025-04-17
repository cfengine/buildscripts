#!/usr/bin/env bash
# run the build in a docker container
set -ex

# find the dir two levels up from here, home of all the repositories
COMPUTED_ROOT="$(readlink -e "$(dirname "$0")/../../")"
# NTECH_ROOT should be the same, but if available use it so user can do their own thing.
NTECH_ROOT=${NTECH_ROOT:-$COMPUTED_ROOT}

name=cfengine-deployment-tests
# todo, check the image against the Dockerfile for up-to-date ness?
if ! docker images | grep $name; then
  docker build -t $name -f "${NTECH_ROOT}/buildscripts/ci/Dockerfile-$name" . || true
fi

# todo, check if already running and up-to-date?
# we want a fresh container, stop and remove any that exist by this $name
if docker ps -a | grep $name; then
  docker ps -a | grep $name | awk '{print $1}' | xargs docker stop
  docker ps -a | grep $name | awk '{print $1}' | xargs docker rm
fi
docker run -d --privileged -v "${NTECH_ROOT}":/data --name $name $name || true

if [ ! -d "${NTECH_ROOT}/artifacts" ]; then
  echo "${NTECH_ROOT}/artifacts directory should exist and have a cfengine-nova-hub package there"
  exit 1
fi
docker exec -i $name bash -c 'cd /data; ./buildscripts/ci/deployment-tests.sh'
