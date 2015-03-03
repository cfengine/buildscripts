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
  if ! [ -f /var/cfengine/masterfiles/promises.cf ]; then
    /bin/cp -R /var/cfengine/share/CoreBase/masterfiles /var/cfengine
    #
    # Create promises_validated
    #
    /var/cfengine/bin/cf-promises -T /var/cfengine/masterfiles
  fi
fi

#
# Create a plugins directory if it doesnot exist
#
if ! [ -d $PREFIX/plugins ]; then
  mkdir -p $PREFIX/plugins
  chmod 700 $PREFIX/plugins
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

case `os_type` in
  redhat|debian)
    #
    # Register CFEngine initscript, if not yet.
    #
    if [ -x /usr/bin/systemctl ]; then
      /usr/bin/systemctl enable cfengine3 > /dev/null 2>&1
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

platform_service cfengine3 start

exit 0
