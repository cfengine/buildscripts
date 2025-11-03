if use_systemd; then
  # This is important in case any of the units have been replaced by the package
  # and we call them in the postinstall script.
  if ! /bin/systemctl daemon-reload; then
    cf_console echo "warning! /bin/systemctl daemon-reload failed."
    cf_console echo "systemd seems to be installed, but not working."
    cf_console echo "Relevant parts of CFEngine installation will fail."
    cf_console echo "Please fix systemd or use other ways to start CFEngine."
  fi
fi

#
# Generate a host key
#
if [ ! -f $PREFIX/ppkeys/localhost.priv ]; then
  $PREFIX/bin/cf-key >/dev/null || :
fi

if is_community; then
  #
  # Copy the stock policy for the new installations
  #
  if ! [ -f $PREFIX/masterfiles/promises.cf ]; then
    /bin/cp -R $PREFIX/share/CoreBase/masterfiles $PREFIX
    #
    # Create promises_validated
    #
    $PREFIX/bin/cf-promises -T $PREFIX/masterfiles
  fi
fi

#
# Cleanup deprecated plugins directory
#
if ! rmdir $PREFIX/plugins 2> /dev/null; then
    # CFE-3618
    echo "$PREFIX/plugins has been removed from the default distribution, we \
tried to clean up the unused directory but found it was not empty. Please \
review your policy, if you believe this directory should remain part of the \
default distribution, please open a ticket in the CFEngine bug tracker."
fi

if [ -f $PREFIX/bin/cf-twin ]; then
  rm -f $PREFIX/bin/cf-twin
fi

mkdir -p /usr/local/sbin
for i in cf-agent cf-promises cf-key cf-secret cf-execd cf-serverd cf-monitord cf-runagent cf-net cf-check cf-support;
do
  if [ `os_type` != redhat ] && [ -x $PREFIX/bin/$i ]; then
    # These links are handled in .spec file for RedHat
    ln -sf $PREFIX/bin/$i /usr/local/sbin/$i || true
  fi

  case `os_type` in
    redhat|debian)
      if [ -f /usr/share/man/man8/$i.8.gz ]; then
        rm -f /usr/share/man/man8/$i.8.gz
      fi
      if $PREFIX/bin/$i -M > /usr/share/man/man8/$i.8; then
        gzip /usr/share/man/man8/$i.8 || true
      fi
      ;;
  esac
done

case `os_type` in
  redhat|debian)
    #
    # Register CFEngine initscript, if not yet.
    #
    if use_systemd; then
      # Reload systemd config to pick up newly installed units
      /bin/systemctl daemon-reload > /dev/null 2>&1
      # Enable cfengine3 service (starts all the other services)
      # Enabling the service is OK to fail (can be masked, for example)
      /bin/systemctl enable cfengine3.service > /dev/null 2>&1 || true
    else
      case `os_type` in
        redhat)
          if ! is_upgrade; then
            chkconfig --add cfengine3
          fi
          ;;
        debian)
          if [ -x /etc/init.d/cfengine3 ]; then
            update-rc.d cfengine3 defaults
          fi
          ;;
      esac
    fi
    ;;

  solaris|hpux)
    if [ -f `rc_d_path`/init.d/cfengine3 ];then
      for link in `rc_d_path`/rc3.d/`rc_start_level`cfengine3 \
                  `rc_d_path`/rc0.d/`rc_kill_level`cfengine3 \
                  `rc_d_path`/rc1.d/`rc_kill_level`cfengine3 \
                  `rc_d_path`/rc2.d/`rc_kill_level`cfengine3 \
                  `rc_d_path`/rcS.d/`rc_kill_level`cfengine3; do
        if [ ! -h $link ]; then
          /usr/bin/ln -s `rc_d_path`/init.d/cfengine3 $link
        fi
      done
    fi
    ;;

  aix)
    if [ -x /etc/rc.d/init.d/cfengine3 ];then
      for link in /etc/rc.d/rc2.d/K05cfengine3 /etc/rc.d/rc2.d/S97cfengine3; do
        /usr/bin/ln -fs /etc/rc.d/init.d/cfengine3 $link
      done
    fi
    ;;
esac

# (re)load SELinux policy if available and required
if [ `os_type` = "redhat" ] &&
   [ -f "$PREFIX/selinux/cfengine-enterprise.pp" ];
then
  if command -v /usr/sbin/selinuxenabled >/dev/null &&
      /usr/sbin/selinuxenabled;
  then
    command -v semodule >/dev/null || cf_console echo "warning! selinux exists and returns 0 but semodule not found"
    test -x /usr/sbin/load_policy  || cf_console echo "warning! selinuxenabled exists and returns 0 but load_policy not found"
    test -x /usr/sbin/restorecon   || cf_console echo "warning! selinuxenabled exists and returns 0 but restorecon not found"

  fi
  if ! cf_console semodule -n -i "$PREFIX/selinux/cfengine-enterprise.pp"; then
    cf_console echo "warning! semodule import failed, as a fallback all binaries in $PREFIX will be labeled bin_t aka unconfined. \
The semodule import failure should be examined in /var/log/CFE*log and reported so that properly confined CFEngine can be setup."
    if ! command -v semanage; then
      cf_console echo "warning! semanage import failed and semodule command is not available. Please install the package policycoreutils-python-utils and run $PREFIX/selinux/label-binaries-unconfined.sh manually immediately after install and restart services with systemctl restart cfengine3."
    else
      cf_console echo "Labeling CFEngine binaries may take some time. Please wait."
      if ! "$PREFIX"/selinux/label-binaries-unconfined.sh "$PREFIX"; then
        cf_console echo "warning! fallback to label all binaries unconfined has failed. CFEngine may not properly operate with selinux set to enforcing."
      else
        cf_console echo "notice! CFEngine binaries are set to unconfined."
      fi
    fi
  fi
  if /usr/sbin/selinuxenabled; then
    /usr/sbin/load_policy
    /usr/sbin/restorecon -R /var/cfengine
  fi
fi

restorecon_run=0
if [ -f $PREFIX/policy_server.dat ]; then
  if ! [ -f "$PREFIX/UPGRADED_FROM.txt" ] || egrep '3\.([0-6]\.|7\.0)' "$PREFIX/UPGRADED_FROM.txt" > /dev/null; then
    # Versions <= 3.7.0 are unreliable in their daemon killing. Kill them one
    # more time now that we have upgraded.
    cf_console platform_service cfengine3 stop
  fi

  # Let's make sure all files and directories created above have correct SELinux labels.
  # run this BEFORE we start services again to avoid race conditions in restorecon
  if command -v restorecon >/dev/null; then
    restorecon -iR /var/cfengine /opt/cfengine
    restorecon_run=1
  fi

  if is_upgrade && [ -f "$PREFIX/UPGRADED_FROM_STATE.txt" ]; then
      cf_console restore_cfengine_state "$PREFIX/UPGRADED_FROM_STATE.txt"
      rm -f "$PREFIX/UPGRADED_FROM_STATE.txt"
  else
      cf_console platform_service cfengine3 start
  fi
fi

rm -f "$PREFIX/UPGRADED_FROM.txt"

if [ $restorecon_run = 0 ]; then
  # if we didn't run restorecon above in the already bootstrapped/upgrade case then run it now
  if command -v restorecon >/dev/null; then
    restorecon -iR /var/cfengine /opt/cfengine
  fi
fi

exit 0
