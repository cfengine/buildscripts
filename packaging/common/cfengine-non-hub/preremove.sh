platform_service cfengine3 stop

case `os_type` in
  redhat)
    #
    # Unregister CFEngine initscript on uninstallation.
    #
    chkconfig --del cfengine3

    #
    # old systemd support (pre 3.6.5)
    #
    test -x /usr/bin/systemctl && systemctl disable cfengine3 > /dev/null 2>&1
    if [ -f /usr/lib/systemd/scripts/cfengine3 ]; then
      rm -f /usr/lib/systemd/scripts/cfengine3
    fi
    if [ -f /usr/lib/systemd/system/cfengine3.service ]; then
      rm -f /usr/lib/systemd/system/cfengine3.service
    fi

    #
    # Clean lock files created by initscript, if any
    #
    for i in cf-execd cf-serverd cf-monitord cf-hub; do
      rm -f /var/lock/$i /var/lock/subsys/$i
    done
    ;;

  solaris|hpux)
    rm -f `rc_d_path`/rc3.d/`rc_start_level`cfengine3 \
          `rc_d_path`/rc0.d/`rc_kill_level`cfengine3 \
          `rc_d_path`/rc1.d/`rc_kill_level`cfengine3 \
          `rc_d_path`/rc2.d/`rc_kill_level`cfengine3 \
          `rc_d_path`/rcS.d/`rc_kill_level`cfengine3
    ;;

  aix)
    /usr/bin/rm -f /etc/rc.d/rc2.d/K05cfengine3 /etc/rc.d/rc2.d/S97cfengine3
    ;;
esac

exit 0
