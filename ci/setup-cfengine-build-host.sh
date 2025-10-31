#!/usr/bin/env bash
shopt -s expand_aliases
thisdir="$(dirname "$0")"

# Use the newest CFEngine version we can
CFE_VERSION=3.26.0
if [ -f /etc/centos-release ]; then
  _version=$(cat /etc/centos-release | cut -d' ' -f3 | cut -d. -f1)
  if [ "$_version" = "6" ]; then
    CFE_VERSION=3.24.2
  fi
elif [ -f /etc/os-release ]; then
  source /etc/os-release
  if [ "$ID" = "debian" ]; then
    if [ "$VERSION_ID" -lt "9" ]; then
      echo "Platform $ID $VERSION_ID is too old."
      exit 9
    fi
    if [ "$VERSION_ID" -lt "11" ]; then
      CFE_VERSION=3.21.7
    fi
  fi
  if [ "$ID" = "redhat" ] || [ "$ID" = "centos" ]; then
    if [ "$VERSION_ID" -lt "6" ]; then
      echo "Platform $ID $VERSION_ID is too old."
      exit 9
    fi
    if [ "$VERSION_ID" -lt "7" ]; then
      CFE_VERSION=3.24.2
    fi
  fi
  if [ "$ID" = "ubuntu" ]; then
    _version=$(echo "$VERSION_ID" | cut -d. -f1)
    if [ "$_version" -lt "16" ]; then
      echo "Platform $ID $VERSION_ID is too old."
      exit 9
    fi
    if [ "$_version" -lt "20" ]; then
      CFE_VERSION=3.21.7
    fi
  fi
fi

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

echo "Checking for pre-installed CFEngine (chicken/egg problem)"
# We need a cf-agent to run build host setup policy and redhat-10-arm has not previous package to install.
# solution: install from source and make a custom AWS AMI image
if ! /var/cfengine/bin/cf-agent -V; then
  echo "No existing CFEngine install found, try quickinstall script..."
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
    cat "$thisdir"/quick-install-cfengine-enterprise.sh.sha256
    echo "Actual quick install checksum: "
    sha256sum quick-install-cfengine-enterprise.sh
  
    sha256sum --check "$thisdir"/quick-install-cfengine-enterprise.sh.sha256
    chmod +x quick-install-cfengine-enterprise.sh
    export CFEngine_Enterprise_Package_Version="$CFE_VERSION"
    bash ./quick-install-cfengine-enterprise.sh agent
  fi
fi

if ! /var/cfengine/bin/cf-agent -V; then
  echo "quickinstall script didn't install CFEngine, try cf-remote..."
  # try pipx first for debian as pip won't work.
  # If that fails to install CFEngine then try python3-pip for redhats.
  if software pipx; then
    pipx install cf-remote
    export PATH=$HOME/.local/bin:$PATH
  elif software python3-pip; then
    pip install cf-remote
  fi
  if command -v cf-remote >/dev/null; then
    cf-remote --version master install --clients localhost
  fi
fi

if [ ! -x /var/cfengine/bin/cf-agent ]; then
  echo "cf-remote didn't install CFEngine, build from source..."
  software git
  echo "quickinstall and cf-remote didn't install cf-agent, try from source"
  CFE_VERSION=3.26.0 # need to use an actualy release which has a checksum for masterfiles download
  rm -rf core # just in case we are repeating the script
  git clone --recursive --depth 1 https://github.com/cfengine/core
  (
    cd core
    ./ci/install.sh
  )
fi

# get masterfiles
urlget https://cfengine-package-repos.s3.amazonaws.com/enterprise/Enterprise-"$CFE_VERSION"/misc/cfengine-masterfiles-"$CFE_VERSION"-1.pkg.tar.gz

sha256sum --check "$thisdir"/cfengine-masterfiles-"$CFE_VERSION"-1.pkg.tar.gz.sha256

tar xf cfengine-masterfiles-"$CFE_VERSION"-1.pkg.tar.gz
cp -a masterfiles/* /var/cfengine/inputs/

# run three times to ensure all is done
policy="$(dirname "$0")"/cfengine-build-host-setup.cf
# just to be sure, make policy read/write for our user only to avoid errors when running
chmod 600 "$policy"
/var/cfengine/bin/cf-agent -KIf "$policy" -b cfengine_build_host_setup | tee promises.log
grep -i error: promises.log && exit 1
/var/cfengine/bin/cf-agent -KIf "$policy" -b cfengine_build_host_setup | tee -a promises.log
grep -i error: promises.log && exit 1
/var/cfengine/bin/cf-agent -KIf "$policy" -b cfengine_build_host_setup | tee -a promises.log
grep -i error: promises.log && exit 1

cleanup
