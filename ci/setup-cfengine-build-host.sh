#!/usr/bin/env bash
shopt -s expand_aliases

# TODO get latest LTS dynamically
CFE_VERSION=3.21.4

# install needed packages and software for a build host
set -ex
if [ "$(id -u)" != "0" ]; then
  echo "$0 must be run as root"
  exit 1
fi

ls -la /home/
chown -R jenkins /home/jenkins

if [ -d /var/cfengine ]; then
  echo "Error: CFEngine already installed on this host. Will not proceed trying to setup build host with CFEngine temporary install."
  exit 1
fi


function cleanup()
{
  set -ex
  if command -v apt 2>/dev/null; then
    apt remove -y cfengine-nova || true
  elif command -v yum 2>/dev/null; then
    yum erase -y cfengine-nova || true
  elif command -v zypper 2>/dev/null; then
    zypper remove -y cfengine-nova || true
  else
    echo "No supported package manager to uninstall cfengine."
    exit 1
  fi
  echo "Ensuring CFEngine fully uninstalled/cleaned up"
  rm -rf /var/cfengine /opt/cfengine /var/log/CFE* /var/log/postgresql.log || true
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
}

trap cleanup ERR
trap cleanup SIGINT
trap cleanup SIGTERM


echo "Using buildscripts commit:"
# we have very old platforms with old git that doesn't understand -C option so cd/cd .. it is
cd buildscripts
# buildscripts is owned by jenkins so in order to run rev-parse command as root (this script is run with sudo) we must make it safe
git config --global --add safe.directory /home/jenkins/buildscripts
git rev-parse HEAD
cd ..

echo "Install any distribution upgrades"
if [ -f /etc/os-release ]; then
  if grep rhel /etc/os-release; then
    yum upgrade --assumeyes
  elif grep debian /etc/os-release; then
    DEBIAN_FRONTEND=noninteractive apt upgrade --yes && DEBIAN_FRONTEND=noninteractive apt autoremove --yes
  elif grep suse /etc/os-release; then
    zypper -n update
  else
    echo "Unknown platform ID $ID. Need this information in order to update/upgrade distribution packages."
    exit 1
  fi
elif [ -f /etc/redhat-release ]; then
  yum upgrade --assumeyes
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
if grep -i suse /etc/os-release; then
  # need to add our public key first otherwise zypper install fails
  rpm --import https://cfengine-package-repos.s3.amazonaws.com/pub/gpg.key
  if grep 'VERSION.*12' /etc/os-release; then
    urlget https://cfengine-package-repos.s3.amazonaws.com/enterprise/Enterprise-"$CFE_VERSION"/agent/agent_suse12_x86_64/cfengine-nova-"$CFE_VERSION"-1.suse12.x86_64.rpm
    zypper install -y cfengine-nova-"$CFE_VERSION"-1.suse12.x86_64.rpm
  elif grep 'VERSION.*15' /etc/os-release; then
    urlget https://cfengine-package-repos.s3.amazonaws.com/enterprise/Enterprise-"$CFE_VERSION"/agent/agent_suse15_x86_64/cfengine-nova-"$CFE_VERSION"-1.suse15.x86_64.rpm
    zypper install -y cfengine-nova-"$CFE_VERSION"-1.suse15.x86_64.rpm
  else
    echo "Unsupported suse version:"
    grep VERSION /etc/os-release
    exit 1
  fi
else
  urlget https://s3.amazonaws.com/cfengine.packages/quick-install-cfengine-enterprise.sh
  # log sha256 checksum expected and actuall for debugging purposes
  echo "Expected quick install checksum: "
  cat ./buildscripts/ci/quick-install-cfengine-enterprise.sh.sha256
  echo "Actual quick install checksum: "
  sha256sum quick-install-cfengine-enterprise.sh

  sha256sum --check ./buildscripts/ci/quick-install-cfengine-enterprise.sh.sha256
  chmod +x quick-install-cfengine-enterprise.sh
  export CFEngine_Enterprise_Package_Version="$CFE_VERSION"
  bash ./quick-install-cfengine-enterprise.sh agent
fi

# get masterfiles
urlget https://cfengine-package-repos.s3.amazonaws.com/enterprise/Enterprise-"$CFE_VERSION"/misc/cfengine-masterfiles-"$CFE_VERSION"-1.pkg.tar.gz

sha256sum --check ./buildscripts/ci/cfengine-masterfiles-"$CFE_VERSION"-1.pkg.tar.gz.sha256

tar xf cfengine-masterfiles-"$CFE_VERSION"-1.pkg.tar.gz
cp -a masterfiles/* /var/cfengine/inputs/

# run three times to ensure all is done
policy="$(dirname "$0")"/cfengine-build-host-setup.cf
# just to be sure, make policy read/write for our user only to avoid errors when running
chmod 600 "$policy"
/var/cfengine/bin/cf-agent -KIf "$policy" -b cfengine_build_host_setup | tee promises.log
grep -i error: promises.log && exit 1
/var/cfengine/bin/cf-agent -KIf "$policy" -b cfengine_build_host_setup | tee promises.log
grep -i error: promises.log && exit 1
/var/cfengine/bin/cf-agent -KIf "$policy" -b cfengine_build_host_setup | tee promises.log
grep -i error: promises.log && exit 1

cleanup
