function detect_distro {
  if [ -e "$lsb_release" ]; then
      DISTRO=$($lsb_release --short --id)
      RELEASE=$($lsb_release --short --release)
      return
  fi
  if [ -e "/etc/redhat-release" ]; then
      if grep "CentOS" /etc/redhat-release; then
          DISTRO="$(awk '/release/ {print $1}' /etc/redhat-release)"
          RELEASE="$(awk '/release/ {print $3}' /etc/redhat-release)"
          return
      fi
  fi
  if [ -e "/etc/SuSE-release" ]; then
      if grep "Enterprise Server 11" /etc/SuSE-release; then
          DISTRO="SUSE"
          RELEASE=$(awk '/VERSION/ {print $3}' /etc/SuSE-release).$(awk '/PATCHLEVEL/ {print $3}' /etc/SuSE-release)
          return
      fi
  fi
  if [ -e "/etc/debian_version" ]; then
      DISTRO="Debian"
      RELEASE=$(cat /etc/debian_version)
      return
  fi


  echo "Sorry I was unable to determine the distro"
  exit 1
}


set -x
detect_distro
echo quick-install-cfengine-community.sh:
echo "DISTRO=$DISTRO"
echo "RELEASE=$RELEASE"
