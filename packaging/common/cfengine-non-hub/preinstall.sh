if is_upgrade; then
  # This is nice to know to provide fixes for bugs in already released
  # package scripts.
  "$PREFIX/bin/cf-agent" -V | grep '^CFEngine Core' | sed -e 's/^CFEngine Core \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/' > "$PREFIX/UPGRADED_FROM.txt"

  # Save the pre-upgrade state so that it can be restored
  get_cfengine_state > "${PREFIX}/UPGRADED_FROM_STATE.txt"

  # Stop the services on upgrade.
  cf_console platform_service cfengine3 stop
fi

case `os_type` in
  redhat)
    #
    # Work around bug in CFEngine <= 3.6.1: The %preun script stops the
    # services, but it shouldn't when we upgrade. Later versions are fixed, but
    # it's the *old* %preun script that gets called when we upgrade, so we have
    # to work around it by using the %posttrans script, which is the only script
    # from the new package that is called after %preun. Unfortunately it doesn't
    # tell you whether or not you're upgrading, so we need to remember it by
    # using the file below.
    #
    # This section can be removed completely when we no longer support upgrading
    # from the 3.6 series, as well as the posttrans script.
    #
    if is_upgrade; then
      if %{prefix}/bin/cf-agent -V | egrep '^CFEngine Core 3\.([0-5]\.|6\.[01])' > /dev/null; then
        ( echo "Upgraded from:"; %{prefix}/bin/cf-agent -V ) > %{prefix}/BROKEN_UPGRADE_NEED_TO_RESTART_DAEMONS.txt
      fi
    fi
    ;;
esac

case `os_type` in
  debian)
    if [ -x /etc/init.d/cfengine3 ]; then
      /usr/sbin/update-rc.d cfengine3 remove
    fi
    ;;
esac

exit 0
