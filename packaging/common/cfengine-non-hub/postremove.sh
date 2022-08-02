case `os_type` in
  debian)
    #
    # Unregister CFEngine initscript.
    #
    /usr/sbin/update-rc.d -f cfengine3 remove
    ;;
esac

if [ -d /usr/local/sbin ]; then
  rm -f /usr/local/sbin/cf-agent /usr/local/sbin/cf-check /usr/local/sbin/cf-execd \
    /usr/local/sbin/cf-key /usr/local/sbin/cf-secret /usr/local/sbin/cf-know /usr/local/sbin/cf-monitord \
    /usr/local/sbin/cf-net /usr/local/sbin/cf-support \
    /usr/local/sbin/cf-promises /usr/local/sbin/cf-report /usr/local/sbin/cf-runagent \
    /usr/local/sbin/cf-serverd /usr/local/sbin/cf-twin /usr/local/sbin/cf-hub /usr/local/sbin/cf-reactor > /dev/null 2>&1
fi

# unload SELinux policy if not upgrading
if ! is_upgrade; then
  if [ `os_type` = "redhat" ] &&
     command -v semodule >/dev/null;
  then
    semodule -n -r cfengine-enterprise
    if /usr/sbin/selinuxenabled; then
      /usr/sbin/load_policy
    fi
  fi
fi

exit 0
