function detect_distro {
  if [ -e "$lsb_release" ]; then
      DISTRO=$($lsb_release --short --id)
      RELEASE=$($lsb_release --short --release)
      return
  fi
  if [ -e "/etc/os-release" ]; then
      source /etc/os-release
      if [ "$ID" == "rhel" ]; then
          DISTRO="RedHatEnterpriseLinux"
          RELEASE="$VERSION_ID"
          return
      fi
      if [ "$ID" == "centos" ]; then
          DISTRO="CentOS"
          RELEASE="$VERSION_ID"
          return
      fi
      if [ "$ID" == "amzn" ]; then
          DISTRO="AmazonLinux"
          RELEASE="$VERSION_ID"
          return
      fi
      if [ "$ID" == "sles" ]; then
          DISTRO="SUSE"
          RELEASE="$VERSION_ID"
          return
      fi
  elif [ -e "/etc/redhat-release" ]; then
      if grep "CentOS" /etc/redhat-release; then
          DISTRO="$(awk '/release/ {print $1}' /etc/redhat-release)"
          RELEASE="$(awk '/release/ {print $3}' /etc/redhat-release)"
          return
      fi
      if grep "Red Hat" /etc/redhat-release; then
          DISTRO="RedHatEnterpriseServer"
          RELEASE="$(awk '/release/ {print $7}' /etc/redhat-release)"
          return
      fi
  elif [ -e "/etc/SuSE-release" ]; then
      # SLES 12+ has /etc/os-release and we use that
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


  echo "Sorry I don't know what distro this is"
  exit 1
}

set -x
detect_distro
echo quick-install-cfengine-enterprise.sh:
echo "DISTRO=$DISTRO"
echo "RELEASE=$RELEASE"
