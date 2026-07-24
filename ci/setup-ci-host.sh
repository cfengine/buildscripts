#!/usr/bin/env bash
set -e
shopt -s expand_aliasas
thisdir="$(dirname "$0")"

packages="" # a space separated list of packages to install
function add-pkg()
{
  packages+=" $*"
}

# we setup some vars for platform versions to make it easier to make choice later
# default version is 0 so that a check can be [ "$debian" -gt "12" ] and that will skip non-debians and such
redhat=0
debian=0
ubuntu=0
suse=0
solaris=0
hpux=0
aix=0

if [ -f /etc/os-release ]; then
    source /etc/os-release
    if grep -q rhel /etc/os-release; then
        yum update --assumeyes
        alias packages='yum install --assumeyes'
        redhat="$VERSION_ID"
    elif grep -q debian /etc/os-release; then
        alias packages='DEBIAN_FRONTEND=noninteractive apt install --yes'
        debian="$VERSION_ID"
    elif grep -q suse /etc/os-release; then
        alias packages='zypper install -y'
        suse="$VERSION_ID"
    else
        echo "Unknown platform ID $ID. Need this information in order to update/upgrade distribution packages."
        exit 1
    fi
elif [ -f /etc/redhat-release ]; then
    alias packages='yum install --assumeyes'
    # shellcheck disable=SC1091
    source /etc/redhat-release
    redhat="$VERSION_ID"
else
    echo "No /etc/os-release or /etc/redhat-release so cant determine platform."
    exit 1
fi

if [ -f /etc/cfengine-containers-host.flag ]; then
  if [ "$debian" -ge "12" ]; then
    # in jenkins, CONTAINER labeled nodes are capable of running container builds like valgrind-check and static-check
    add-pkg unzip # linux-install-groovy.sh needs unzip to unpack the groovy distribution archive
    add-pkg buildah
    add-pkg jq
    add-pkg make
    add-pkg parallel
    add-pkg podman
    if ! command -v groovy; then
      bash "$thisdir"/linux-install-groovy.sh
    fi

    # NOPASSWD is needed for various tools related to container jobs
    rm -rf /etc/sudoers.d/999-local
    cat >/etc/sudoers.d/999-local <<EOF
%wheel ALL=NOPASSWD: /usr/bin/lvm-cache-stats
%wheel ALL=NOPASSWD: /usr/bin/podman
%sudo ALL=NOPASSWD: /usr/bin/lvm-cache-stats
%sudo ALL=NOPASSWD: /usr/bin/podman
%sudo ALL=NOPASSWD: /usr/sbin/lvs
%sudo ALL=NOPASSWD: /usr/bin/journalctl
jenkins ALL=NOPASSWD: /usr/bin/podman
EOF
    chmod 400 /etc/sudoers.d/999-local
    chown root:root /etc/sudoers.d/999-local
  fi
fi

if echo "$ID_LIKE" | grep rhel; then
  if [ "$VERSION_ID" != "6" ] && [ "$VERSION_ID" != "7" ]; then
    if ! grep best=False /etc/yum.conf; then
      sed -i '/best=True/s/True/False/' /etc/yum.conf
    fi
    if ! grep best=False /etc/dnf/dnf.conf; then
      sed -i '/best=True/s/True/False/' /etc/dnf/dnf.conf
    fi
  fi

    add-pkg expat-devel
    add-pkg gcc-c++
    add-pkg gettext
    add-pkg ncurses
    add-pkg perl-Module-Load-Conditional
    add-pkg wget
    add-pkg perl-ExtUtils-MakeMaker
    add-pkg perl-IO-Compress # provides perl(IO::Uncompress::Gunzip) needed by lcov dependency package
    add-pkg psmic
    add-pkg which

  # There are several versions of python(x)-rpm-macros. We choose this one to get platform-python which is guaranteed to be installed in rhel-8
  if [ "$VERSION_ID" = "8" ]; then
      add-pkg python3-rpm-macros # provides macro py3_shebang_fix needed in rhel-8 for /var/cfengine/bin/cfbs ENT-11338
      add-pkg platform-python-devel # py3_shebang_fix macro needs /usr/bin/pathfix.py from platform-python-devel package ENT-11338
  fi


  if [ "$VERSION_ID" != "7" ] && [ "$VERSION_ID" != "6" ]; then
    yum erase -y java-1.8.0-openjdk-headless # Installing Development Tools includes this jdk1.8 which we do not want
  
      add-pkg pkgconf # pkgconfig renamed to pkgconf in rhel8
      add-pkg selinux-policy-devel # TODO add to rhel 6 and 7?
  fi

  if [ "$VERSION_ID" -gt 8 ]; then
    add-pkg perl-Sys-Hostname # Needed by __04_examples_outputs_check_outputs_cf
  fi

  if [ "$VERSION_ID" -ge 10 ]; then
      add-pkg patch
      add-pkg perl-FindBin # Needed by postgresql 18
  fi

  if [ "$VERSION_ID" = "6" ]; then
      add-pkg rpm-build
      add-pkg python-psycopg2 # centos-6 provides python2 and psycopg2 for python2 as a package
      add-pkg perl-IO-Compress-Zlib # provides perl(IO::Uncompress::Gunzip) needed by lcov dependency package
      add-pkg perl-JSON
  else
      add-pkg rpm-build-libs
      add-pkg python3-psycopg2
  fi

  # perl-Digest-MD5 and perl-Data-Dumper are included in perl for centos-6
  if [ "$VERSION_ID" = "6" ] || [ "$VERSION_ID" = "7" ]; then
      add-pkg gdb
      add-pkg ntp
      add-pkg pkgconfig
      add-pkg perl-IPC-Cmd
      add-pkg perl-devel
      add-pkg xfsprogs
  fi

  # note that shellcheck, fakeroot and ccache require epel-release to be installed
  # epel-release is installed by distribution package in rhel-7 and by URL for rhel-8+ later in commands section
  if [ "$VERSION_ID" = "7" ]; then
    yum install -y epel-release
  fi


  # Ban IPs with repeated failed SSH auth attempts. On centos/rhel 8+ we must specify individual packages instead of just fail2ban as package method will append -*.* which would include conflicting shorewall and shorewall-lite packages.
  if [ "$VERSION_ID" != "7" ]; then
      fail2ban-sendmail
      add-pkg fail2ban-firewalld
      add-pkg ccache
      add-pkg fakeroot
      add-pkg perl-JSON-PP
      add-pkg perl-Digest-MD5

  fi

  if [ "$VERSION_ID" != "8" ]; then
    add-pkg python3-pip
  fi

fi

# packages is a dynamic alias set near the top of this script
# shellcheck disable=SC2086
# ^^^ we want space separated package names as separate args, not one arg with the space separated list
packages $packages

if mount | grep '/tmp'; then
  # We could check if /tmp was size 5G but not worth the trouble since this remount call just sets the maximum size of the tmpfs in virtual memory.
  mount -o remount,size=5G /tmp
fi

# Ensure that core_pattern is proper for systemd-coredump if coredumpctl is present.
if command -v coredumpctl >/dev/null; then
  if [ ! -f /etc/cfengine-containers-host.flag ]; then
    sysctl kernel.core_pattern='|/lib/systemd/systemd-coredump %p %u %g %s %t %e'
  fi
fi

"$thisdir"/linux-install-jdk.sh # the script should skip if sufficient java is already installed

# leech2 build toolchain host
if [ "$ubuntu" -ge 20 ] || [ "$debian" -ge 12 ] || [ "$redhat" -ge 7 ]; then
    "$thisdir"/linux-install-protobuf.sh
    # TODO if mingw then pass along x86_64-pc-windows-gnu as an arg to install rust
    "$thisdir"/linux-install-rust.sh
fi
