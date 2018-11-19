# These can have bad effects on certain commands if set incorrectly. Found
# when investigating why PostgreSQL was not starting.
unset LANG
unset LC_ADDRESS
unset LC_ALL
unset LC_IDENTIFICATION
unset LC_MEASUREMENT
unset LC_MONETARY
unset LC_NAME
unset LC_NUMERIC
unset LC_PAPER
unset LC_TELEPHONE
unset LC_TIME


# Upgrade detection is a mess. It is often difficult to tell, especially from
# the postinstall script, so we use the package-upgrade.txt file to remember.
case "$PKG_TYPE" in
  depot|deb|bff)
    case "$SCRIPT_TYPE" in
      preinstall|preremove)
        if native_is_upgrade; then
          mkdir -p "$PREFIX"
          echo "File used by CFEngine during package upgrade. Can be safely deleted." > "$PREFIX/package-upgrade.txt"
        else
          rm -f "$PREFIX/package-upgrade.txt"
        fi
        alias is_upgrade='native_is_upgrade'
        ;;
      postremove|postinstall)
        if [ -f "$PREFIX/package-upgrade.txt" ]; then
          if [ "$SCRIPT_TYPE" = "postinstall" ]; then
            rm -f "$PREFIX/package-upgrade.txt"
          fi
          alias is_upgrade='true'
        else
          alias is_upgrade='false'
        fi
        ;;
    esac
    ;;
esac

get_cfengine_state() {
    if type systemctl >/dev/null 2>&1; then
        systemctl list-units -l | sed -r -e '/^\s*(cf-[-a-z]+|cfengine3)\.service/!d' -e 's/\s*(cf-[-a-z]+|cfengine3)\.service.*/\1/'
    else
        platform_service cfengine3 status | awk '/is running/ { print $1 }'
    fi
}

restore_cfengine_state() {
    # $1 -- file where the state to restore is saved (see get_cfengine_state())

    if type systemctl >/dev/null 2>&1; then
        xargs -n1 -a "$1" systemctl start
    else
        CALLED_FROM_STATE_RESTORE=1
        if [ -f ${PREFIX}/bin/cfengine3-nova-hub-init-d.sh ]; then
            . ${PREFIX}/bin/cfengine3-nova-hub-init-d.sh
            if grep postgres "$1" >/dev/null; then
                start_postgres >/dev/null
            fi
            if grep httpd "$1" >/dev/null; then
                start_httpd >/dev/null
            fi
        fi

        for d in `grep 'cf-' "$1"`; do
            ${PREFIX}/bin/${d}
        done
    fi
}
