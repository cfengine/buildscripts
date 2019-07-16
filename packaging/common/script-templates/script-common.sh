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
            # we need to source the core init script which itself sources the
            # enterprise one, but provides it with necessary functions
            . /etc/init.d/cfengine3
            if grep postgres "$1" >/dev/null; then
                start_postgres >/dev/null
            fi
            if grep httpd "$1" >/dev/null; then
                start_httpd >/dev/null
            fi
            if grep redis "$1" >/dev/null; then
                start_redis >/dev/null
            fi
        fi

        for d in `grep 'cf-' "$1"`; do
            ${PREFIX}/bin/${d}
        done
    fi
}

wait_for_cf_postgres() {
    # wait for CFEngine Postgresql service to be available, up to 5 sec.
    # Returns 0 is psql command succeeds,
    # Returns non-0 otherwise (1 if exited by timeout)
    for i in $(seq 1 5); do
        true "checking if Postgresql is available..."
        if $PREFIX/bin/psql cfsettings -c "SELECT 1;" >/dev/null 2>&1; then
            true "Postgresql is available, moving on"
            return 0
        fi
        true "waiting 1 sec for Postgresql to become available..."
        sleep 1
    done
    # Note: it is important that this is the last command of this function.
    # Return code of `psql` is the return code of whole function.
    $PREFIX/bin/psql cfsettings -c "SELECT 1;" >/dev/null 2>&1
}
