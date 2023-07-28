#!/usr/bin/env bash
# run the build in a docker container
set -ex

# find the dir two levels up from here, home of all the repositories
COMPUTED_ROOT=$(readlink -e $(dirname "$0")/../../)
# NTECH_ROOT should be the same, but if available use it so user can do their own thing.
NTECH_ROOT=${NTECH_ROOT:-$COMPUTED_ROOT}

name=cfengine-build-package
# todo, check the image against the Dockerfile for up-to-date ness?
docker build -t $name -f "${NTECH_ROOT}/buildscripts/ci/Dockerfile-$name" . || true
# todo, check if already running and up-to-date?
docker run -d --privileged -v ${NTECH_ROOT}:/data --name $name $name || true

# copy local caches to docker container
mkdir -p "${NTECH_ROOT}/packages"
mkdir -p "${NTECH_ROOT}/cache"
# ending with /. in srcpath copies contents to destpath
docker cp "${NTECH_ROOT}/cache/." $name:/root/.cache

# in order for build-scripts/autogen to generate a revision file:
for i in core buildscripts buildscripts/deps-packaging enterprise nova masterfiles
do
  docker exec -i $name bash -c "git config --global --add safe.directory /data/$i"
done

docker exec -i $name bash -c 'cd /data; ./buildscripts/ci/setup-projects.sh'
docker exec -i $name bash -c 'cd /data; ./buildscripts/ci/build.sh'

# save back cache and packages to host for handling by CI and such
docker cp $name:/root/.cache/. "${NTECH_ROOT}/cache/"
docker cp $name:/data/packages/. "${NTECH_ROOT}/packages/"

# if no packages, then fail
[ -f packages/*.deb ] || [ -f packages/*.rpm ]
