#!/bin/sh

# macOS has no systemd/init.d; the closest equivalent is launchd, driven via
# LaunchDaemon plists installed by cfengine-non-hub/postinstall.sh (see
# packaging/cfengine-nova/darwin/*.plist). preinstall/postinstall here are the
# scripts Apple's installer(8) runs directly from the .pkg (see
# build-scripts/package's "macos" case), invoked with no useful argv, unlike
# rpm/deb scriptlets -- upgrade detection has to be done by looking at what's
# already on disk, same as HP-UX/AIX do.

PREFIX=/var/cfengine

package_type()
{
  echo macos
}

os_type()
{
  echo darwin
}

rc_d_path()
{
  echo "/Library/LaunchDaemons"
}

# platform_service <daemon|cfengine3> <start|stop|status>
#
# "cfengine3" is the umbrella name used by the shared install scripts
# (get_cfengine_state/restore_cfengine_state/preinstall/postinstall) to mean
# "every CFEngine daemon we ship a LaunchDaemon for"; there's no single
# matching plist for it like there'd be a single init.d/cfengine3 script on
# other Unixes, so it fans out here instead.
platform_service()
{
  case "$1" in
    cfengine3)
      for svc in cf-execd cf-monitord cf-serverd; do
        _macos_service "$svc" "$2"
      done
      ;;
    *)
      _macos_service "$1" "$2"
      ;;
  esac
}

_macos_service()
{
  label="com.cfengine.$1"
  plist="$(rc_d_path)/${label}.plist"
  [ -f "$plist" ] || return 0
  case "$2" in
    start)
      launchctl load -w "$plist" >/dev/null 2>&1 || true
      ;;
    stop)
      launchctl unload "$plist" >/dev/null 2>&1 || true
      ;;
    status)
      if launchctl list "$label" >/dev/null 2>&1; then
        echo "$1 is running"
      fi
      ;;
  esac
}

native_is_upgrade()
{
  test -f "$PREFIX/bin/cf-agent"
}
