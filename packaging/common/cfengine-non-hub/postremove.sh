case `os_type` in
  debian)
    #
    # Unregister CFEngine initscript.
    #
    /usr/sbin/update-rc.d -f cfengine3 remove
    ;;
esac

if [ `os_type` != redhat ]; then
  # These links are handled in .spec file for RedHat
  for i in cf-agent cf-promises cf-key cf-secret cf-execd cf-serverd cf-monitord cf-runagent cf-net cf-check cf-support; do
    rm -f /usr/local/sbin/$i || true
  done
fi

# unload SELinux policy if not upgrading
if ! is_upgrade; then
  if [ `os_type` = "redhat" ] &&
     command -v semodule >/dev/null &&
     semodule -l | grep cfengine-enterprise >/dev/null;
  then
    semodule -n -r cfengine-enterprise
    if /usr/sbin/selinuxenabled; then
      /usr/sbin/load_policy
    fi
  fi
fi

exit 0
