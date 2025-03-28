#!/usr/bin/env bash
# run the build in a docker container
# $@ -- additional artifact paths to save
additional_artifacts="$@"
set -ex

# find the dir two levels up from here, home of all the repositories
COMPUTED_ROOT="$(readlink -e "$(dirname "$0")/../../")"
# NTECH_ROOT should be the same, but if available use it so user can do their own thing.
NTECH_ROOT=${NTECH_ROOT:-$COMPUTED_ROOT}

name=cfengine-build-package
label=PACKAGES_HUB_x86_64_linux_ubuntu_20
export JOB_BASE_NAME=label=$label


docker build -t $name -f "${NTECH_ROOT}/buildscripts/ci/Dockerfile-$name" "${NTECH_ROOT}/buildscripts/ci"

# add secret key to enable push up to sftp cache
set +x # hide secrets
if [ -n "$GH_ACTIONS_SSH_KEY_BUILD_ARTIFACTS_CACHE" ]; then
  export SECRET="$GH_ACTIONS_SSH_KEY_BUILD_ARTIFACTS_CACHE"
else
  if ! export SECRET="$(pass mystiko/developers/CFEngine/jenkins/jenkins_sftp_cache@github)"; then
    echo "The sftp cache ssh secret key must be provided, either with environment variable GH_ACTIONS_SSH_KEY_BUILD_ARTIFACTS_CACHE or access to mystiko path developers/CFEngine/jenkins/sftp-cache.sec"
    exit 1
  fi
fi
set -x # done hiding secrets
# send in JOB_BASE_NAME to enable use of retrieved or generated deps cache
docker run -d --env SECRET --env JOB_BASE_NAME --privileged -v "${NTECH_ROOT}":/data --name $name $name

# copy local caches to docker container
mkdir -p "${NTECH_ROOT}/artifacts"
mkdir -p "${NTECH_ROOT}/cache"

# setup host key trust
pubkey="build-artifacts-cache.cloud.cfengine.com,138.68.18.72 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJhnAXjI9PMuRM3s0isYFH4SNZjKwq0E3VK+7YQKcL6aIxNhXjdJnNKAkh4MNlzZkLpFTYputUxKa1yPPrb5G/Y="

# ending with /. in srcpath copies contents to destpath
docker cp "${NTECH_ROOT}/cache/." $name:/root/.cache

# in order for build-scripts/autogen to generate a revision file:
for i in core buildscripts buildscripts/deps-packaging enterprise nova masterfiles
do
  docker exec -i $name bash -c "git config --global --add safe.directory /data/$i"
done

# add build artifacts host public keys to container for use there
docker exec -i $name bash -c "mkdir -p ~/.ssh"
docker exec -i $name bash -c "echo $pubkey >> ~/.ssh/known_hosts"

docker exec -i $name bash -c 'cd /data; ./buildscripts/ci/setup-projects.sh'
docker exec -i $name bash -c "cd /data; ./buildscripts/ci/build.sh ${additional_artifacts}"

# save back cache and artifacts to host for handling by CI and such
docker cp $name:/root/.cache/. "${NTECH_ROOT}/cache/"
docker cp $name:/data/artifacts/. "${NTECH_ROOT}/artifacts/"

rc=1 # if we find no packages, fail
for f in artifacts/*.deb; do
  [ -f "$f" ] && rc=0
  break
done
exit $rc
