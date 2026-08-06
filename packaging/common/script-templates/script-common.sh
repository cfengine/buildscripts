# postgresql docs, https://www.postgresql.org/docs/current/locale.html, recommend using C locale unless otherwise needed
export LC_ALL=C # overrides all other env vars: https://www.gnu.org/software/libc/manual/html_node/Locale-Categories.html
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
    if use_systemd; then
        systemctl list-units -l | sed -r -e '/^\s*(cf-[-a-z]+|cfengine3)\.service/!d' -e 's/\s*(cf-[-a-z]+|cfengine3)\.service.*/\1/'
    else
        platform_service cfengine3 status | awk '/is running/ { print $1 }'
    fi
}

restore_cfengine_state() {
    # $1 -- file where the state to restore is saved (see get_cfengine_state())

    if use_systemd; then
        for service in `cat "$1"`; do
            definition=`systemctl cat "$service"` || continue
            # only try to start service that are defined/exist (some may be gone
            # in the new version)
            if [ -n "$definition" ]; then
                systemctl start "$service" || echo "Failed to start service $service"
            fi
        done
    else
        CALLED_FROM_STATE_RESTORE=1
        if [ -f ${PREFIX}/bin/cfengine3-nova-hub-init-d.sh ]; then
            . ${PREFIX}/bin/cfengine3-nova-hub-init-d.sh
            if grep postgres "$1" >/dev/null; then
                start_postgres >/dev/null || echo "Failed to start PostgreSQL"
            fi
            if grep httpd "$1" >/dev/null; then
                start_httpd >/dev/null || echo "Failed to start Apache"
            fi
        fi

        for d in `grep 'cf-' "$1"`; do
            if [ -f ${PREFIX}/bin/${d} ]; then
                ${PREFIX}/bin/${d} || echo "Failed to start $d"
            fi
        done
    fi
}

wait_for_cf_postgres() {
    # wait for CFEngine Postgresql service to be available, up to 60 sec.
    # Returns 0 is psql command succeeds,
    # Returns non-0 otherwise (1 if exited by timeout)
    for i in $(seq 1 60); do
        true "checking if Postgresql is available..."
        if cd /tmp && su cfpostgres -c "$PREFIX/bin/psql -l" >/dev/null 2>&1; then
            true "Postgresql is available, moving on"
            return 0
        fi
        true "waiting 1 sec for Postgresql to become available..."
        sleep 1
    done
    # Note: it is important that this is the last command of this function.
    # Return code of `psql` is the return code of whole function.
    cd /tmp && su cfpostgres -c "$PREFIX/bin/psql -l" >/dev/null 2>&1
}

wait_for_cf_postgres_down() {
    # wait for CFEngine Postgresql service to be shutdown, up to 60 sec.
    # Returns 0 if postgresql service is not running
    # Returns non-0 otherwise (1 if exited by timeout)
    for i in $(seq 1 60); do
        true "checking if Postgresql is shutdown..."
        if cd /tmp && ! su cfpostgres -c "$PREFIX/bin/psql -l" >/dev/null 2>&1; then
            true "Postgresql is shutdown, moving on"
            return 0
        fi
        true "waiting 1 sec for Postgresql to shutdown..."
        sleep 1
    done
    # Note: it is important that this is the last command of this function.
    # Return code of `psql` is the return code of whole function.
    cd /tmp && ! su cfpostgres -c "$PREFIX/bin/psql -l" >/dev/null 2>&1
}

safe_cp() {
    # "safe" alternative to `cp`. Tries `cp -al` first, and if it fails - `cp -a`.
    # Deletes partially-copied files if copy operation fails.
    # Args:
    #   * dir you're copying stuff from
    #   * name of stuff you're copying (one arg!)
    #   * dir you're copying stuff to
    # Example: instead of
    #   cp "$PREFIX/state/pg/data" "$BACKUP_DIR"
    # use
    #   safe_cp "$PREFIX/state/pg" data "$BACKUP_DIR"
    test "$#" -eq 3 || return 2
    from="$1"
    name="$2"
    to="$3"
    # First, try copying files creating hardlinks
    # Do not print errors - we'll do it another way
    if cp -al "$from/$name" "$to" 2>/dev/null; then
        # Copy succeeded
        return 0
    fi
    echo "Copy creating hardlinks failed, removing partially-copied data and trying simple copy"
    rm -rf "$to/$name"
    if cp -a "$from/$name" "$to"; then
        # Copy succeeded
        return 0
    fi
    echo "Copy failed, so removing partially-copied data and aborting"
    rm -rf "$to/$name"
    return 1
}

safe_mv() {
    # "safe" alternative to `mv`. Executes `safe_cp` and deletes source dir if
    # that succeeds.
    # Args are same as in safe_cp
    # Exampe: instead of
    #   mv "$PREFIX/state/pg/data" "$BACKUP_DIR"
    # use
    #   safe_mv "$PREFIX/state/pg" data "$BACKUP_DIR"
    test "$#" -eq 3 || return 2
    from="$1"
    name="$2"
    to="$3"
    if safe_cp "$from" "$name" "$to"; then
        # Copy succeeded - so we can delete old dir
        rm -rf "$from/$name"
        return 0
    else
        # Copy failed (partially-copied data is removed by safe_cp)
        return 1
    fi
}

on_files() {
    # perform operation $1 on each file in $2 with optional extra argument $3
    # Examples:
    # to copy only files:
    #   on_files cp "$PREFIX/lib" "$BACKUP_DIR/lib"
    # to move only files:
    #   on_files mv "$PREFIX/lib" "$PREFIX/lib.new"
    # to remove only files:
    #   on_files rm "$PREFIX/lib"
    test "$#" -ge 2 || return 2
    # Split on newlines, not on spaces.
    IFS='
'
    for file in $(ls -a1 "$2"); do
        if [ -f "$2/$file" ]; then
            $1 "$2/$file" $3
        fi
    done
    # Restore normal splitting semantics.
    unset IFS
}

#
# LMDB database migration (CFE-4701)
#
# LMDB 1.0 added a txnid to the page header, so it reads the meta page magic from
# where 0.9 keeps another field and rejects 0.9 databases as MDB_INVALID.
# CFEngine takes that for corruption and deletes them (ENT-9717).
#
# There is no in-place upgrade: dump with the old mdb_dump, load with the new
# mdb_load. The dump belongs in preinstall, while the old binary is still there;
# the new mdb_dump cannot read 0.9 either.
#
# A dump lives beside its database as <db>.dump. Nothing else picks those up:
# CFEngine and cf-check both select databases by a .lmdb suffix.
#
# Non-fatal throughout -- a failed migration just leaves the old behaviour, which
# is no reason to abort an upgrade. Do not rely on `set -e`: these are called as
# `... || ...`, which suppresses errexit for the whole function body.
#
# The globs cover the state dir and the workdir, where pre-3.7 installations keep
# databases CFEngine still prefers (DB_PATHS_WORKDIR in dbm_api.c). An unmatched
# glob comes through literally, hence the `test -f`.

lmdb_series() {
    # "<major>.<minor>" of the version string on stdin. The on-disk format is
    # stable within a series.
    sed -n 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n 1
}

lmdb_migration_needed() {
    # True when the installed mdb_dump reports a different series than the one
    # this package ships. Anything undeterminable is false, keeping the old
    # behaviour.
    test -n "$LMDB_VERSION" || return 1
    test -x "$PREFIX/bin/mdb_dump" || return 1
    packaged=`echo "$LMDB_VERSION" | lmdb_series`
    installed=`"$PREFIX/bin/mdb_dump" -V 2>/dev/null | lmdb_series`
    test -n "$packaged" && test -n "$installed" || return 1
    test "$installed" != "$packaged"
}

lmdb_dump_databases() {
    # Export every database with the installed (old) mdb_dump. Preinstall only.
    for db in "$PREFIX"/state/*.lmdb "$PREFIX"/*.lmdb; do
        test -f "$db" || continue
        rm -f "$db.dump"
        # Dumps hold database contents; subshell keeps the umask from leaking.
        if ( umask 077; "$PREFIX/bin/mdb_dump" -n -f "$db.dump" "$db" ); then
            echo "exported '$db'"
        else
            # Corrupt or uninitialised: nothing to preserve, leave it to cf-check
            # rather than restoring a bad dump.
            rm -f "$db.dump"
            cf_console echo "Warning: could not export '$db', it will be recreated empty."
        fi
    done
    return 0
}

lmdb_load_databases() {
    # Re-import what lmdb_dump_databases() exported, with the new mdb_load.
    # Postinstall only, before any daemon starts.
    for dump in "$PREFIX"/state/*.lmdb.dump "$PREFIX"/*.lmdb.dump; do
        test -f "$dump" || continue
        db=${dump%.dump}
        # Overwriting rather than replacing keeps the original inode, so owner,
        # mode and SELinux label survive. umask only applies if $db is missing.
        if ( umask 077; "$PREFIX/bin/mdb_load" -n -f "$dump" "$db.new" ) &&
           ( umask 077; cat "$db.new" > "$db" ); then
            echo "imported '$db'"
            rm -f "$dump"
        else
            # Keep the data for recovery, but under a name the glob above will
            # not pick up, so a later upgrade cannot restore it over a good DB.
            mv "$dump" "$dump.failed"
            cf_console echo "Warning: could not import '$db', it will be recreated empty."
            cf_console echo "Exported data kept in '$dump.failed'"
        fi
        rm -f "$db.new" "$db.new-lock"
        # Tidy up the old lock file. LMDB copes with a stale one, it just
        # reinitialises it.
        rm -f "$db-lock"
    done
    return 0
}
