#!/usr/bin/env bash
# copied from mission-portal/ci/run.sh for selenium tests
# todo refactor to share some of this instead of copy/pasting
set -ex

# find the dir one level up from here, home of all the repositories
COMPUTED_ROOT=$(readlink -e $(dirname "$0")/../../)
# NTECH_ROOT should be the same, but if available use it so user can do their own thing.
NTECH_ROOT=${NTECH_ROOT:-$COMPUTED_ROOT}
USER=${USER:-$(whoami)}

if [ ! -d /var/cfengine ]; then
  # ci and local buildscripts should place built packages in $NTECH_ROOT/packages
  sudo dpkg -i "$NTECH_ROOT"/packages/cfengine-nova-hub*deb
fi

# now that cfengine is probably installed, run cf-support if there is an error
trap failure ERR

function failure() {
  sudo mkdir -p "${NTECH_ROOT}/artifacts"
  sudo chown $USER "${NTECH_ROOT}/artifacts"
  cd "${NTECH_ROOT}/artifacts"
  sudo cf-support --yes 2>&1 > $$.cfsupportlog || cat $$.cfsupportlog
  rm $$.cfsupportlog
}

AGENT_LOG="${NTECH_ROOT}/artifacts/agent.log"
if [ -f "$AGENT_LOG" ]; then
  mv "$AGENT_LOG" "$AGENT_LOG".$(date +%s)
fi
touch "$AGENT_LOG"
if [ ! -f /var/cfengine/policy_server.dat ]; then
  sudo /var/cfengine/bin/cf-agent -B $(hostname -I | awk ' {print $1}') >>"$AGENT_LOG"
fi

# make artifacts directory to be slurped by CI (jenkins, github, ...)
mkdir -p "${NTECH_ROOT}/artifacts"

sudo /var/cfengine/bin/cf-agent -KIf update.cf 2>&1 >>"$AGENT_LOG"
sudo /var/cfengine/bin/cf-agent -KI 2>&1 >>"$AGENT_LOG"
sudo /var/cfengine/bin/cf-agent -KI 2>&1 >>"$AGENT_LOG"

if grep -i error "$AGENT_LOG" >/dev/null; then
  echo "FAIL test, errors in $AGENT_LOG"
  grep -i error "$AGENT_LOG"
fi

apt-get -y install python3-psycopg2
export REPORTING_TEST_DELAY=5
cd "${NTECH_ROOT}/nova/tests/reporting"
python3 deployment_test.py
