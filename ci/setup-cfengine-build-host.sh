#!/usr/bin/env bash
shopt -s expand_aliases
thisdir="$(dirname "$0")"

# install needed packages and software for a build host
set -ex
if [ "$(id -u)" != "0" ]; then
  echo "$0 must be run as root"
  exit 1
fi

ls -la /home/
if ! id -u jenkins; then
  useradd jenkins -p jenkins
fi
mkdir -p /home/jenkins
chown -R jenkins /home/jenkins

function cleanup()
{
  set -ex
  if command -v apt 2>/dev/null; then
    # workaround for CFE-4544, remove scriptlets call systemctl even when systemctl is-system-running returns false
    rm /bin/systemctl
    ln -s /bin/echo /bin/systemctl
    apt remove -y cfengine-nova || true
  elif command -v yum 2>/dev/null; then
    yum erase -y cfengine-nova || true
  elif command -v zypper 2>/dev/null; then
    zypper remove -y cfengine-nova || true
  else
    echo "No supported package manager to uninstall cfengine."
    exit 1
  fi
  echo "Cleaning up CFEngine install by moving to /var/bak.cfengine and /opt/bak.cfengine"
  rm -rf /var/bak.cfengine
  mv /var/cfengine /var/bak.cfengine || true
  rm -rf /opt/bak.cfengine
  mv /opt/cfengine /opt/bak.cfengine || true
  mv /var/log/CFE* /var/bak.cfengine/ || true
  mv /var/log/postgresql.log /var/bak.cfengine || true

  if command -v pkill; then
    pkill -9 cf-agent || true
    pkill -9 cf-serverd || true
    pkill -9 cf-monitord || true
    pkill -9 cf-execd || true
  else
    echo "No pkill available. Maybe some cf procs left over?"
    ps -efl | grep cf
  fi
  ls -l /home
  chown -R jenkins /home/jenkins
  echo "Done with cleanup()"
}

trap cleanup ERR
trap cleanup SIGINT
trap cleanup SIGTERM

echo "Using buildscripts commit:"
# we have very old platforms with old git that doesn't understand -C option so cd/cd .. it is
(
  cd "$thisdir"/..
  # buildscripts is owned by jenkins so in order to run rev-parse command as root (this script is run with sudo) we must make it safe if git is used
  if [ -d /home/jenkins/buildscripts/.git ]; then
    if command -v git >/dev/null; then
      git config --global --add safe.directory /home/jenkins/buildscripts
      # show what version of buildscripts we are using
      git rev-parse HEAD
    else
      echo "buildscripts/.git is present but git is not installed"
      exit 1
    fi
  fi
)

echo "Install distribution upgrades and set software alias for platform"
if [ -f /etc/os-release ]; then
  if grep rhel /etc/os-release; then
    yum update --assumeyes
    alias software='yum install --assumeyes'
  elif grep debian /etc/os-release; then
    DEBIAN_FRONTEND=noninteractive apt upgrade --yes && DEBIAN_FRONTEND=noninteractive apt autoremove --yes
    alias software='DEBIAN_FRONTEND=noninteractive apt install --yes'
  elif grep suse /etc/os-release; then
    zypper -n update
    alias software='zypper install -y'
  else
    echo "Unknown platform ID $ID. Need this information in order to update/upgrade distribution packages."
    exit 1
  fi
elif [ -f /etc/redhat-release ]; then
  yum update --assumeyes
  alias software='yum install --assumeyes'
else
  echo "No /etc/os-release or /etc/redhat-release so cant determine platform."
  exit 1
fi

if command -v wget; then
  alias urlget=wget
elif command -v curl; then
  alias urlget='curl -O'
else
  echo "Error: need something to fetch URLs. Didn't find either wget or curl."
  exit 1
fi

echo "Installing cf-remote for possible package install and masterfiles download"
# try pipx first for debian as pip won't work.
# If that fails to install CFEngine then try python3-pip for redhats.
if software pipx; then
  pipx install cf-remote
  export PATH=$HOME/.local/bin:$PATH
elif software python3-pip; then
  pip install cf-remote
fi
export PATH=/usr/local/bin:$PATH # add /usr/local/bin for pip/pipx installed cf-remote

if ! command -v cf-remote; then
  echo "cf-remote was not installed, it is required so exiting now"
  exit 42
fi

echo "Checking for pre-installed CFEngine (chicken/egg problem)"
# We need a cf-agent to run build host setup policy and redhat-10-arm did not have a previous package to install.
if ! /var/cfengine/bin/cf-agent -V; then
  echo "No existing CFEngine install found, try cf-remote..."
  cf-remote --log-level info --version master install --clients localhost || true
fi

if [ ! -x /var/cfengine/bin/cf-agent ]; then
  echo "cf-remote didn't install CFEngine, build from source..."
  software git
  echo "cf-remote didn't install cf-agent, try from source"
  rm -rf core # just in case we are repeating the script
  git clone --recursive --depth 1 https://github.com/cfengine/core
  (
    cd core
    ./ci/install.sh
  )
fi

# get masterfiles
rm -rf cfengine-masterfiles*tar.gz
cf-remote download masterfiles --output-dir .
tar xf cfengine-masterfiles-*tar.gz
cp -a masterfiles/* /var/cfengine/inputs/

# run three times to ensure all is done
(
  cd "$thisdir"
  policy=./cfengine-build-host-setup.cf
  # just to be sure, make policy read/write for our user only to avoid errors when running
  chmod 600 "$policy"
  /var/cfengine/bin/cf-agent -KIf "$policy" -b cfengine_build_host_setup | tee promises.log
  grep -i error: promises.log && exit 1
  /var/cfengine/bin/cf-agent -KIf "$policy" -b cfengine_build_host_setup | tee -a promises.log
  grep -i error: promises.log && exit 1
  /var/cfengine/bin/cf-agent -KIf "$policy" -b cfengine_build_host_setup | tee -a promises.log
  grep -i error: promises.log && exit 1
  echo "Done evaluating policy. End of promies.log:"
  tail promises.log
)

cleanup
