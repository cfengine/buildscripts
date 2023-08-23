#!/usr/bin/env bash
# run the build in a docker container
set -ex

# find the dir two levels up from here, home of all the repositories
COMPUTED_ROOT="$(readlink -e "$(dirname "$0")/../../")"
# NTECH_ROOT should be the same, but if available use it so user can do their own thing.
NTECH_ROOT=${NTECH_ROOT:-$COMPUTED_ROOT}

name=cfengine-build-package
label=PACKAGES_HUB_x86_64_linux_ubuntu_20
export JOB_BASE_NAME=label=$label
# todo, check the image against the Dockerfile for up-to-date ness?
docker build -t $name -f "${NTECH_ROOT}/buildscripts/ci/Dockerfile-$name" . || true
# todo, check if already running and up-to-date?
# send in JOB_BASE_NAME to enable use of retrieved or generated deps cache
docker run -d --env JOB_BASE_NAME --privileged -v "${NTECH_ROOT}":/data --name $name $name || true

# copy local caches to docker container
mkdir -p "${NTECH_ROOT}/packages"
mkdir -p "${NTECH_ROOT}/cache"

# pre-seed cache from sftp buildcache if possible
# requires either environment var with private key or mystiko+pass
eval "$(ssh-agent -s)"
set +x # hide secrets
if [ -n "$GH_ACTIONS_SSH_KEY_BUILD_ARTIFACTS_CACHE" ]; then
  echo "$GH_ACTIONS_SSH_KEY_BUILD_ARTIFACTS_CACHE" | ssh-add -
else
  if ! pass mystiko/developers/CFEngine/jenkins/sftp-cache.sec | ssh-add -; then
    echo "Need the ssh private key for build artifacts cache, neither env var nor mystiko was available."
    exit 1
  fi
fi
set -x # done hiding secrets
# clean up any lingering revision file previously generated, if you are changing deps locally and iterating this is important
[ -f "${NTECH_ROOT}/buildscripts/deps-packaging/revision" ] && rm "${NTECH_ROOT}/buildscripts/deps-packaging/revision"
cd "${NTECH_ROOT}/buildscripts/deps-packaging"
# see buildscripts/build-scripts/autogen for a similar workaround to ensure it stays 7 on bootstrap-oslo-dc jobs
git config --add core.abbrev 7 # hack to match smaller commit sha on bootstrap-oslo-dc (debian-9)
revision=$(git log --pretty='format:%h' -1 -- .)
cd - # back to previous directory
PKGS_DIR="${NTECH_ROOT}/cache/buildscripts_cache/pkgs/${label}"
mkdir -p "${PKGS_DIR}"

# setup host key trust
echo "build-artifacts-cache.cloud.cfengine.com,138.68.18.72 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJhnAXjI9PMuRM3s0isYFH4SNZjKwq0E3VK+7YQKcL6aIxNhXjdJnNKAkh4MNlzZkLpFTYputUxKa1yPPrb5G/Y=" >>~/.ssh/known_hosts

echo -e "cd /export/sftp_dirs_cache/${label}\n get -Ra *${revision}* ${PKGS_DIR}" | \
 sftp -oPubkeyAcceptedKeyTypes=+ssh-rsa -b - jenkins_sftp_cache@build-artifacts-cache.cloud.cfengine.com

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

rc=1 # if we find no packages, fail
for f in packages/*.deb; do
  [ -f "$f" ] && rc=0
  break
done
exit $rc
