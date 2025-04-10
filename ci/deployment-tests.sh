#!/usr/bin/env bash
# shellcheck disable=SC2024
# I am redirecting many sudo run commands to logfiles which can be owned by the non-priv user
# copied from mission-portal/ci/run.sh for selenium tests
# todo refactor to share some of this instead of copy/pasting
set -ex

# find the dir one level up from here, home of all the repositories
COMPUTED_ROOT="$(readlink -e "$(dirname "$0")/../../")"
# NTECH_ROOT should be the same, but if available use it so user can do their own thing.
NTECH_ROOT=${NTECH_ROOT:-$COMPUTED_ROOT}
USER=${USER:-$(whoami)}

# prepare artifacts dir
sudo mkdir -p "${NTECH_ROOT}/artifacts"
sudo chown "$USER" "${NTECH_ROOT}/artifacts"

trap failure ERR
function failure() {
  cd "${NTECH_ROOT}/artifacts"
  if command cf-support; then
    sudo cf-support --yes > $$.cfsupportlog 2>&1 || cat $$.cfsupportlog
  else
    tar cf "${NTECH_ROOT}/artifacts/CFEngine-Install.logs.tgz /var/log/CFEngine-Install*"
  fi
  rm $$.cfsupportlog
}

if [ ! -d /var/cfengine ]; then
  # ci and local buildscripts should place built packages in $NTECH_ROOT/artifacts
  sudo dpkg -i "$NTECH_ROOT"/artifacts/cfengine-nova-hub*deb
fi



AGENT_LOG="${NTECH_ROOT}/artifacts/agent.log"
if [ -f "$AGENT_LOG" ]; then
  mv "$AGENT_LOG" "${AGENT_LOG}.$(date +%s)"
fi
mkdir -p "${NTECH_ROOT}/artifacts"
touch "$AGENT_LOG"
if [ ! -f /var/cfengine/policy_server.dat ]; then
  sudo /var/cfengine/bin/cf-agent -B "$(hostname -I | awk ' {print $1}')" >>"$AGENT_LOG" 2>&1
fi

# make artifacts directory to be slurped by CI (jenkins, github, ...)
mkdir -p "${NTECH_ROOT}/artifacts"

{
  sudo /var/cfengine/bin/cf-agent -KIf update.cf
  sudo /var/cfengine/bin/cf-agent -KI
  sudo /var/cfengine/bin/cf-agent -KI
} >>"$AGENT_LOG" 2>&1

if grep -i error "$AGENT_LOG" >/dev/null; then
  echo "FAIL test, errors in $AGENT_LOG"
  grep -i error "$AGENT_LOG"
fi

apt-get -y install python3-psycopg2
export REPORTING_TEST_DELAY=5
cd "${NTECH_ROOT}/nova/tests/reporting"
python3 deployment_test.py
