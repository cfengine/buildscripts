#!/bin/sh

PREFIX=/var/cfengine

package_type()
{
  echo depot
}

os_type()
{
  echo hpux
}

rc_d_path()
{
  echo "/sbin"
}

rc_start_level()
{
  echo S970
}

rc_kill_level()
{
  echo K050
}

platform_service()
{
  /sbin/init.d/"$1" "$2"
}

native_is_upgrade()
{
  test -f "$PREFIX/bin/cf-agent"
}
