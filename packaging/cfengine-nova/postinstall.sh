case `os_type` in
  redhat)
    #
    # systemd support, if there is systemctl, then prepare unit file.
    #
    if test -x /usr/bin/systemctl; then
      if [ ! -d /usr/lib/systemd/scripts ]; then
        mkdir -p /usr/lib/systemd/scripts
      fi
      if [ ! -f /usr/lib/systemd/scripts/cfengine3 ]; then
        cp -f /etc/init.d/cfengine3 /usr/lib/systemd/scripts
        chmod 0755 /usr/lib/systemd/scripts/cfengine3
      fi
      if [ ! -f /usr/lib/systemd/system/cfengine3.service ]; then
        cat > /usr/lib/systemd/system/cfengine3.service << EOF
[Unit]
Description=CFEngine 3 deamons
 
[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/cfengine3
ExecStart=/usr/lib/systemd/scripts/cfengine3 start
ExecStop=/usr/lib/systemd/scripts/cfengine3 stop
RemainAfterExit=yes
 
[Install]
WantedBy=multi-user.target
EOF
      fi
    fi

    #
    # Register CFEngine initscript, if not yet.
    #
    if ! is_upgrade; then
      chkconfig --add cfengine3
    fi
    if [ -f /usr/lib/systemd/system/cfengine3.service ]; then
      test -x /usr/bin/systemctl && systemctl enable cfengine3 > /dev/null 2>&1
    fi
    ;;

  debian)
    #
    # Register CFEngine initscript, if not yet.
    #
    if [ -x /etc/init.d/cfengine3 ]; then
      update-rc.d cfengine3 defaults
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

#
# Generate a host key
#
if [ ! -f $PREFIX/ppkeys/localhost.priv ]; then
    $PREFIX/bin/cf-key >/dev/null || :
fi

if [ -f $PREFIX/bin/cf-twin ]; then
    rm -f $PREFIX/bin/cf-twin
fi

cp $PREFIX/bin/cf-agent $PREFIX/bin/cf-twin

mkdir -p /usr/local/sbin
for i in cf-agent cf-promises cf-key cf-execd cf-serverd cf-monitord cf-runagent;
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

# start CFE3 processes on only client hosts (not HUB)
if [ -f /var/cfengine/policy_server.dat -a ! -f /var/cfengine/masterfiles/promises.cf ]; then
  platform_service cfengine3 start
fi

exit 0
