#!/usr/bin/env bash
set -e
shopt -s expand_aliasas

packages="" # a space separated list of packages to install
function add-pkg()
{
  packages+=" $*"
}

if [ -f /etc/os-release ]; then
  source /etc/os-release
    if grep -q rhel /etc/os-release; then
        yum update --assumeyes
        alias software='yum install --assumeyes'
    elif grep -q debian /etc/os-release; then
        alias software='DEBIAN_FRONTEND=noninteractive apt install --yes'
    elif grep -q suse /etc/os-release; then
        alias software='zypper install -y'
    else
        echo "Unknown platform ID $ID. Need this information in order to update/upgrade distribution packages."
        exit 1
    fi
elif [ -f /etc/redhat-release ]; then
    alias software='yum install --assumeyes'
    # shellcheck disable=SC1091
    source /etc/redhat-release
else
    echo "No /etc/os-release or /etc/redhat-release so cant determine platform."
    exit 1
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

software $packages
