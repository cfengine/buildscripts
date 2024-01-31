#!/usr/bin/env bash
shopt -s expand_aliases
# install needed packages and software for a build host
set -e


if [ -d /var/cfengine ]; then
  echo "Error: CFEngine already installed on this host. Will not proceed trying to setup build host with CFEngine temporary install."
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
  sudo rpm --import https://cfengine-package-repos.s3.amazonaws.com/pub/gpg.key
  if grep 'VERSION.*12' /etc/os-release; then
    urlget https://cfengine-package-repos.s3.amazonaws.com/enterprise/Enterprise-3.21.4/agent/agent_suse12_x86_64/cfengine-nova-3.21.4-1.suse12.x86_64.rpm
    sudo zypper install -y cfengine-nova-3.21.4-1.suse12.x86_64.rpm
  elif grep 'VERSION.*15' /etc/os-release; then
    urlget https://cfengine-package-repos.s3.amazonaws.com/enterprise/Enterprise-3.21.4/agent/agent_suse15_x86_64/cfengine-nova-3.21.4-1.suse15.x86_64.rpm
    sudo zypper install -y cfengine-nova-3.21.4-1.suse15.x86_64.rpm
  else
    echo "Unsupported suse version:"
    grep VERSION /etc/os-release
    exit 1
  fi
else
  urlget https://s3.amazonaws.com/cfengine.packages/quick-install-cfengine-enterprise.sh
  echo "c358ca0e0dce49e8784ff2352e7c94356332ded80f5ca3903b0b3dc8d6a10cf4  quick-install-cfengine-enterprise.sh" | sha256sum --check -
  chmod +x quick-install-cfengine-enterprise.sh
  sudo bash ./quick-install-cfengine-enterprise.sh agent
fi

# get masterfiles
urlget https://cfengine-package-repos.s3.amazonaws.com/enterprise/Enterprise-3.21.4/misc/cfengine-masterfiles-3.21.4-1.pkg.tar.gz

echo "a4b35ad85ec14dda49b93c1c91a93e09f4336d9ee88cd6a3b27d323c90a279ca  cfengine-masterfiles-3.21.4-1.pkg.tar.gz" | sha256sum --check -

tar xf cfengine-masterfiles-3.21.4-1.pkg.tar.gz
sudo cp -a masterfiles/* /var/cfengine/inputs/

# how to get the URL for the module? See cfbs code
# _MODULES_URL = "https://archive.build.cfengine.com/modules"
# _MODULES_URL, name, commit + ".tar.gz"
urlget https://archive.build.cfengine.com/modules/upgrade-all-packages/e3039050296ec20c7e44b3accba84c146cf6ef69.tar.gz
echo "ca9801c956b1bf32deb3ea6c171e6e1c685288e941e3e9e9bf4d5746445babc2  e3039050296ec20c7e44b3accba84c146cf6ef69.tar.gz" | sha256sum --check -
tar xf e3039050296ec20c7e44b3accba84c146cf6ef69.tar.gz

# upgrade all packages
sudo cp upgrade-all-packages/upgrade_all_packages.cf /var/cfengine/inputs/services/main.cf
sudo /var/cfengine/bin/cf-agent -KIb upgrade_all_packages_policy | tee promises.log
grep -i error: promises.log && exit 1

# run three times to ensure all is done
policy="$(dirname "$0")"/cfengine-build-host-setup.cf
# just to be sure, make policy read/write for our user only to avoid errors when running
chmod 600 "$policy"
sudo /var/cfengine/bin/cf-agent -KIf "$policy" -b cfengine_build_host_setup | tee promises.log
grep -i error: promises.log && exit 1
sudo /var/cfengine/bin/cf-agent -KIf "$policy" -b cfengine_build_host_setup | tee promises.log
grep -i error: promises.log && exit 1
sudo /var/cfengine/bin/cf-agent -KIf "$policy" -b cfengine_build_host_setup | tee promises.log
grep -i error: promises.log && exit 1

if command -v apt 2>/dev/null; then
  sudo apt remove -y cfengine-nova
  sudo rm -rf /var/cfengine /opt/cfengine /var/log/CFE*log
elif command -v yum 2>/dev/null; then
  sudo yum erase -y cfengine-nova
elif command -v zypper 2>/dev/null; then
  sudo zypper remove -y cfengine-nova
else
  echo "No supported package manager to uninstall cfengine."
  exit 1
fi
echo "Ensuring CFEngine fully uninstalled/cleaned up"
sudo rm -rf /var/cfengine /opt/cfengine /var/log/CFE* /var/log/postgresql.log
sudo pkill -9 cf-agent || true
sudo pkill -9 cf-serverd || true
sudo pkill -9 cf-monitord || true
sudo pkill -9 cf-execd || true
