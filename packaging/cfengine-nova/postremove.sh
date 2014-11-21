case `os_type` in
  debian)
    #
    # Unregister CFEngine initscript.
    #
    /usr/sbin/update-rc.d cfengine3 remove
    ;;
esac

exit 0
