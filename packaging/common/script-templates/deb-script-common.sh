#!/bin/sh

PREFIX=/var/cfengine

package_type()
{
  echo deb
}

os_type()
{
  echo debian
}

rc_d_path()
{
  echo "/etc"
}

platform_service()
{
  if use_systemd; then
    /bin/systemctl "$2" "$1".service
  else
    /etc/init.d/"$1" "$2"
  fi
}

IS_UPGRADE=0

case "$1" in
  upgrade)
    IS_UPGRADE=1
    ;;
  install|remove|purge)
    IS_UPGRADE=0
    ;;
  configure)
    # Actually not guaranteed to be correct.
    IS_UPGRADE=0
    ;;
  *)
    # Various error handling on debian. We ignore it for now.
    exit 0
    ;;
esac

native_is_upgrade()
{
  test $IS_UPGRADE = 1
}
