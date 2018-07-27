#!/bin/sh

PREFIX=@@PREFIX@@

package_type()
{
    echo freebsd
}

os_type()
{
    echo freebsd
}

rc_d_path()
{
    echo '/usr/local/etc/rc.d'
}

platform_service()
{
    /usr/sbin/service "$1" "$2"
}

IS_UPGRADE=0

is_upgrade()
{
  test $IS_UPGRADE = 1
}
