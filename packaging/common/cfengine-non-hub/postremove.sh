case `os_type` in
  debian)
    #
    # Unregister CFEngine initscript.
    #
    /usr/sbin/update-rc.d cfengine3 remove
    ;;
esac

if [ -d /usr/local/sbin ]; then
  rm -f /usr/local/sbin/cf-agent /usr/local/sbin/cf-execd \
    /usr/local/sbin/cf-key /usr/local/sbin/cf-keycrypt \
    /usr/local/sbin/cf-know /usr/local/sbin/cf-monitord /usr/local/sbin/cf-net \
    /usr/local/sbin/cf-promises /usr/local/sbin/cf-report /usr/local/sbin/cf-runagent \
    /usr/local/sbin/cf-serverd /usr/local/sbin/cf-twin /usr/local/sbin/cf-hub > /dev/null 2>&1
fi

exit 0
