#!/bin/sh

PREFIX=%prefix

package_type()
{
  echo rpm
}

os_type()
{
  if [ "`uname`" = "AIX" ]; then
    echo aix
  else
    echo redhat
  fi
}

rc_d_path()
{
  if [ `os_type` = aix ]; then
    echo "/etc/rc.d"
  else
    echo "/etc"
  fi
}

platform_service()
{
  if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running; then
    systemctl "$2" "$1".service
  else
    `rc_d_path`/init.d/"$1" "$2"
  fi
}

IS_UPGRADE=0

is_upgrade()
{
  test $IS_UPGRADE = 1
}
