if [ -x /bin/systemctl ]; then
  # This is important in case any of the units have been replaced by the package
  # and we call them in the postinstall script.
  /bin/systemctl daemon-reload
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
  if [ -f $PREFIX/bin/$i ]; then
    ln -sf $PREFIX/bin/$i /usr/local/sbin/$i || true
  fi

  case `os_type` in
    redhat|debian)
      if [ -f /usr/share/man/man8/$i.8.gz ]; then
        rm -f /usr/share/man/man8/$i.8.gz
      fi
      $PREFIX/bin/$i -M > /usr/share/man/man8/$i.8 && gzip /usr/share/man/man8/$i.8
      ;;
  esac
done

case `os_type` in
  redhat|debian)
    #
    # Register CFEngine initscript, if not yet.
    #
    if [ -x /bin/systemctl ]; then
      # Reload systemd config to pick up newly installed units
      /bin/systemctl daemon-reload > /dev/null 2>&1
      # Enable service units
      # Enabling services is OK to fail (they can be masked, for example)
      set +e
      /bin/systemctl enable cf-execd.service > /dev/null 2>&1
      /bin/systemctl enable cf-serverd.service > /dev/null 2>&1
      /bin/systemctl enable cf-monitord.service > /dev/null 2>&1
      /bin/systemctl enable cfengine3.service > /dev/null 2>&1
      set -e
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
   command -v semodule >/dev/null &&
   [ -f "$PREFIX/selinux/cfengine-enterprise.pp" ];
then
  semodule -n -i "$PREFIX/selinux/cfengine-enterprise.pp"
  if /usr/sbin/selinuxenabled; then
    /usr/sbin/load_policy
    /usr/sbin/restorecon -R /var/cfengine
  fi
fi

if [ -f $PREFIX/policy_server.dat ]; then
  if ! [ -f "$PREFIX/UPGRADED_FROM.txt" ] || egrep '3\.([0-6]\.|7\.0)' "$PREFIX/UPGRADED_FROM.txt" > /dev/null; then
    # Versions <= 3.7.0 are unreliable in their daemon killing. Kill them one
    # more time now that we have upgraded.
    cf_console platform_service cfengine3 stop
  fi

  if is_upgrade && [ -f "$PREFIX/UPGRADED_FROM_STATE.txt" ]; then
      cf_console restore_cfengine_state "$PREFIX/UPGRADED_FROM_STATE.txt"
      rm -f "$PREFIX/UPGRADED_FROM_STATE.txt"
  else
      cf_console platform_service cfengine3 start
  fi
fi

rm -f "$PREFIX/UPGRADED_FROM.txt"

# Let's make sure all files and directories created above have correct SELinux
# labels.
if command -v restorecon >/dev/null; then
  restorecon -iR /var/cfengine /opt/cfengine
fi

exit 0
