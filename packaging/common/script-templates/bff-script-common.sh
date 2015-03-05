#!/usr/bin/ksh

PREFIX=/var/cfengine

package_type()
{
  echo bff
}

os_type()
{
  echo aix
}

rc_d_path()
{
  echo "/etc/rc.d"
}

platform_service()
{
  /etc/rc.d/init.d/"$1" "$2"
}

native_is_upgrade()
{
  test -f "$PREFIX/bin/cf-agent"
}
