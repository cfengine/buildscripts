cf_console platform_service cfengine3 stop

case `os_type` in
  redhat)
    #
    # Unregister CFEngine initscript on uninstallation.
    #
    test -x /sbin/chkconfig && test -f /etc/init.d/cfengine3 && chkconfig --del cfengine3

    #
    # systemd support
    #
    use_systemd && systemctl disable cfengine3.service > /dev/null 2>&1

    #
    # Clean lock files created by initscript, if any
    #
    for i in cf-execd cf-serverd cf-monitord cf-hub cf-reactor; do
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
