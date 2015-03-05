#!/bin/sh

PREFIX=/var/cfengine

package_type()
{
  echo pkg
}

os_type()
{
  echo solaris
}

rc_d_path()
{
  echo "/etc"
}

rc_start_level()
{
  echo S97
}

rc_kill_level()
{
  echo K05
}

platform_service()
{
  /etc/init.d/"$1" "$2"
}

is_upgrade()
{
  # There is no such thing with the pkg manager.
  return 1
}
