# Drain in-flight cf-agent before stopping the cfengine3 umbrella: otherwise
# a running cf-agent can re-trigger cf-php-fpm (which Wants=cf-postgres),
# leaving cf-postgres in a Restart=always loop while the package is gone.
if use_systemd; then
  /bin/systemctl stop cf-execd.service >/dev/null 2>&1 || true
  t=60
  while [ $t -gt 0 ] && pgrep -x cf-agent >/dev/null 2>&1; do
    sleep 1
    t=$((t - 1))
  done
  pkill -KILL -x cf-agent >/dev/null 2>&1 || true
fi

cf_console platform_service cfengine3 stop
if use_systemd && [ -e /usr/lib/systemd/system/cfengine3-web.service ]; then
  # When using systemd, the services are split in two, and although both will
  # stop due to the command above, the web part may only do so after some
  # delay, which may cause problems later if the binaries are gone by the time
  # it tries to stop them.
  /bin/systemctl stop cfengine3-web.service
fi

case "`os_type`" in
  redhat)
    test -x /sbin/chkconfig && test -f /etc/init.d/cfengine3 && chkconfig --del cfengine3
    ;;
  debian)
    update-rc.d -f cfengine3 remove
    ;;
esac

#
#MAN PAGE RELATED
#
MAN_CONFIG=""
case "`package_type`" in
  rpm)
    if [ -f /etc/SuSE-release ];
    then
      # SuSE
      MAN_CONFIG="/etc/manpath.config"
    else
      # RH/CentOS
      MAN_CONFIG="/etc/man.config"
    fi
    ;;
  deb)
    MAN_CONFIG="/etc/manpath.config"
    ;;
  *)
    echo "Unknown manpath, should not happen!"
    ;;
esac

if [ -f "$MAN_CONFIG" ] && grep -q cfengine "$MAN_CONFIG"; then
  sed -i '/cfengine/d' "$MAN_CONFIG"
fi

#
# Clean lock files created by initscript, if any
#
for i in cf-execd cf-serverd cf-monitord cf-hub cf-reactor; do
  rm -f /var/lock/$i /var/lock/subsys/$i
done

exit 0
