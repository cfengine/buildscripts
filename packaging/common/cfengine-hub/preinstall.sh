
if is_upgrade; then
    # This is nice to know to provide fixes for bugs in already released
    # package scripts.
    "$PREFIX/bin/cf-agent" -V | grep '^CFEngine Core' | sed -e 's/^CFEngine Core \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/' > "$PREFIX/UPGRADED_FROM.txt"

    # Save the pre-upgrade state so that it can be restored
    get_cfengine_state > "${PREFIX}/UPGRADED_FROM_STATE.txt"

    # 3.7.x has broken reporting of postgres status, let's assume it was running
    # if cf-hub was running
    if grep '^3\.7\.' "${PREFIX}/UPGRADED_FROM.txt" >/dev/null &&
       grep "cf-hub" "${PREFIX}/UPGRADED_FROM_STATE.txt" > /dev/null; then
        echo "postgres" >> "${PREFIX}/UPGRADED_FROM_STATE.txt"
    fi
fi

BACKUP_DIR=$PREFIX/backup-before-postgres10-migration

# If upgrading from a version below 3.12 that has PostgreSQL, and the data dir exists.
if is_upgrade && egrep '^3\.([6-9]|1[01])\.' "$PREFIX/UPGRADED_FROM.txt" >/dev/null && [ -d "$PREFIX/state/pg/data" ]; then
  if [ -d "$BACKUP_DIR" ]; then
    cf_console echo "Old backup in $BACKUP_DIR already exists. Please remove before attempting upgrade."
    exit 1
  fi
  cf_console echo "Attempting to migrate Mission Portal database. This can break stuff."
  cf_console echo "It can be disabled by shutting down CFEngine and removing/renaming $PREFIX/state/pg/data prior to upgrade."
  cf_console echo "Press Ctrl-C in the next 15 seconds if you want to cancel..."
  sleep 15
  cf_console echo "Ok, moving on..."
fi

if [ "`package_type`" = "rpm" ]; then
  #
  # Work around bug in CFEngine <= 3.6.1: The %preun script stops the services,
  # but it shouldn't when we upgrade. Later versions are fixed, but it's the *old*
  # %preun script that gets called when we upgrade, so we have to work around it
  # by using the %posttrans script, which is the only script from the new package
  # that is called after %preun. Unfortunately it doesn't tell you whether or not
  # you're upgrading, so we need to remember it by using the file below.
  #
  # This section can be removed completely when we no longer support upgrading
  # from the 3.6 series.
  #
  if is_upgrade; then
    if $PREFIX/bin/cf-agent -V | egrep '^CFEngine Core 3\.([0-5]\.|6\.[01])' > /dev/null; then
      ( echo "Upgraded from:"; $PREFIX/bin/cf-agent -V ) > $PREFIX/BROKEN_UPGRADE_NEED_TO_RESTART_DAEMONS.txt
    fi
  fi
fi

#
# Before starting the installation process we need to check that
# hostname -f returns a valid name. If that is not the case then
# we just abort the installation.
#
NAME=$(hostname -f)
if [ -z "$NAME" ];
then
  cf_console echo "hostname -f does not return a valid name, but this is a requirement for generating a"
  cf_console echo "SSL certificate for the Mission Portal and API."
  cf_console echo "Please make sure that hostname -f returns a valid name (Add an entry to /etc/hosts or "
  cf_console echo "fix the name resolution)."
  exit 1
fi

#stop the remaining services on upgrade
if is_upgrade; then
  cf_console platform_service cfengine3 stop
  if [ -x /bin/systemctl ]; then
    # When using systemd, the services are split in two, and although both will
    # stop due to the command above, the web part may only do so after some
    # delay, which may cause problems in an upgrade situation, since this script
    # will immediately check whether the ports are in use.
    /bin/systemctl stop cfengine3-web.service
  fi
fi

# CFE-2278: Migrate to split units
if is_upgrade; then
  if [ -e /usr/lib/systemd/system/cfengine3-web.service ]; then
    # It's functionality is replaced with multiple units.
    /bin/systemctl disable cfengine3-web.service
  fi
fi

if is_upgrade && egrep '^3\.([6-9]|1[01])\.' "$PREFIX/UPGRADED_FROM.txt" >/dev/null && [ -d "$PREFIX/state/pg/data" ]; then
  cf_console echo "Moving old data and copying old binaries to $BACKUP_DIR"
  # Now that PostgreSQL is shut down, move the old data out of the way.
  mkdir -p "$BACKUP_DIR/lib"
  mkdir -p "$BACKUP_DIR/share"
  mv "$PREFIX/state/pg/data" "$BACKUP_DIR"
  if ! diff "$BACKUP_DIR/data/postgresql.conf" "$PREFIX/share/postgresql/postgresql.conf.cfengine" > /dev/null; then
    # diff exits with 0 if the files are the same
    # the postgresql.conf file was modified, we should try to use it after migration
    cp -a "$BACKUP_DIR/data/postgresql.conf" "$BACKUP_DIR/data/postgresql.conf.modified"
  fi
  cp -al "$PREFIX/bin" "$BACKUP_DIR"
  cp -l "$PREFIX/lib"/* "$BACKUP_DIR/lib"
  cp -al "$PREFIX/lib/postgresql/" "$BACKUP_DIR/lib"
  cp -al "$PREFIX/share/postgresql/" "$BACKUP_DIR/share"
fi

filter_netstat_listen()
{
  if [ -x /usr/sbin/ss ]; then
    ss -natp | egrep "LISTEN.*($1)"
  else
    netstat -natp | egrep "($1).*LISTEN"
  fi
}

#
# We check if there is a server listening on port 80 or port 443.
# If one is found, then we try to shut it down by calling
# $PREFIX/httpd/bin/apachectl stop
# If that does not work, we abort the installation.
#
HTTPD_RUNNING=`filter_netstat_listen ":80\s|:443\s"`
if [ ! -z "$HTTPD_RUNNING" ];
then
  cf_console echo "There seems to be a server listening on either port 80 or 443"
  cf_console echo "Checking if it is part of CFEngine Enterprise"
  if [ -x $PREFIX/httpd/bin/apachectl ];
  then
    cf_console echo "Trying to shut down the process using apachectl from CFEngine Enterprise"
    $PREFIX/httpd/bin/apachectl stop
    HTTPD_RUNNING=`filter_netstat_listen ":80\s|:443\s"`
    if [ ! -z "$HTTPD_RUNNING" ];
    then
      sleep 5s
      HTTPD_RUNNING=`filter_netstat_listen ":80\s|:443\s"`
      if [ ! -z "$HTTPD_RUNNING" ];
      then
        cf_console echo "Could not shutdown the process, aborting the installation"
        exit 1
      fi
    fi
  else
    cf_console echo "No apachectl found, aborting the installation!"
    cf_console echo "Please kill the following processes before attempting a new installation"
    fuser -n tcp 80
    fuser -n tcp 443
    exit 1
  fi
fi

ensure_postgres_terminated() {
  PSQL_RUNNING=`filter_netstat_listen ":5432\s"`
  if [ -z "$PSQL_RUNNING" ];
  then
    return 0;
  fi

  cf_console echo "There seems to be a server listening on port 5432"
  cf_console echo "This might mean that there is a PostgreSQL server running on the machine already"
  cf_console echo "Checking if the Postgres installation belongs to a previous CFEngine deployment"

  pgpid=$(echo "$PSQL_RUNNING" | sed -r -e '/pid=/!d' -e 's/.*pid=([0-9]+),.*/\1/' | tail -1)
  pgargs=$(ps -p $pgpid -o args=)
  if [ $? != 0 ];
  then
    cf_console echo "The PostgreSQL server terminated, moving on."
    return 0
  fi
  PSQL_COMMAND=$(echo "$pgargs" | cut -d' ' -f1)
  if [ ! -z "$PSQL_COMMAND" ];
  then
    if [ "$PSQL_COMMAND" = "$PREFIX/bin/postgres" ];
    then
      cf_console echo "The PostgreSQL server belongs to a previous CFEngine deployment, shutting it down."
      if [ -x "$PREFIX/bin/pg_ctl" ];
      then
        (cd /tmp &&
           su cfpostgres -c "$PREFIX/bin/pg_ctl stop -D $BACKUP_DIR/data -m smart" ||
             # '-m fast' quits directly, without proper session shutdown
             su cfpostgres -c "$PREFIX/bin/pg_ctl stop -D $BACKUP_DIR/data -m fast")
      else
        cf_console echo "No pg_ctl found at $PREFIX/bin/pg_ctl, aborting"
        return 1
      fi
    else
      cf_console echo "The PostgreSQL is not from a previous CFEngine deployment"
      cf_console echo "This scenario is not supported, aborting installation"
      ps -p `fuser -n tcp 5432 2>/dev/null` -o args=
      return 1
    fi
  else
    cf_console echo "There is a process listening on the PostgreSQL port but it is not PostgreSQL, aborting."
    cf_console echo -n "Command: $pgargs"
    cf_console echo "Please make sure that the process is not running before attempting the installation again."
    return 1
  fi
  PSQL_FINAL_CHECK=`filter_netstat_listen ":5432\s"`
  if [ ! -z "$PSQL_FINAL_CHECK" ];
  then
    cf_console echo "There is still a process listening on 5432, please kill it before retrying the installation. Aborting."
    return 1
  fi
}

#
# We check if there is still a PostgreSQL server running
#
ensure_postgres_terminated || exit 1

#
# We need a cfapache user and group for our web server
#
/usr/bin/getent passwd cfapache >/dev/null || /usr/sbin/useradd -M -r cfapache
/usr/bin/getent group cfapache >/dev/null || /usr/sbin/groupadd -r cfapache

#
# We make sure there is a cfpostgres user and group
#
/usr/bin/getent passwd cfpostgres >/dev/null || /usr/sbin/useradd -M -r cfpostgres
/usr/bin/getent group cfpostgres >/dev/null || /usr/sbin/groupadd -r cfpostgres

#
# We make sure that the cfapache user is part of the cfpostgres group so that
# the webserver can read from the socket ENT-2746
#
getent group cfpostgres && gpasswd --add cfapache cfpostgres

#
# Backup htdocs
#

generate_preserve_filter() {
  # generates filter for `find` command to exclude files and dirs listed in
  # "preserve_during_upgrade.txt" file: for each directory, prints
  # "-not \( -path "$PREFIX/httpd/htdocs/$NAME" -prune \)";
  # for each file, prints "-not \( -name "$NAME" \)".
  sed '
    /^\s*#/d  # skip lines beginning with #
    /^\s*$/d  # also skip empty lines
              # if line ends with /, treat it as dirname and exclude all files inside:
    s_\(.*\)/$_-not \( -path PREFIX/httpd/htdocs/\1 -prune \)_
    t         # if above commans was successful (line ended with /), done processing this line
              # otherwise, treat it as filename to be excluded:
    s_.*_-not \( -name & \)_
    ' $PREFIX/httpd/htdocs/preserve_during_upgrade.txt | sed "s_PREFIX_${PREFIX}_"
}

if [ -d $PREFIX/httpd/htdocs ]; then
  cf_console echo "A previous version of CFEngine Mission Portal was found,"
  cf_console echo "creating a backup of it at /tmp/cfengine-htdocs.tar.gz"
  tar zcf /tmp/cfengine-htdocs.tar.gz $PREFIX/httpd/htdocs

  cf_console echo "Purging old version from $PREFIX/httpd/htdocs"
  if [ -f $PREFIX/httpd/htdocs/preserve_during_upgrade.txt ]; then
    # Purge all files in httpd/htdocs with exceptions listed in preserve_during_upgrade.txt
    cf_console echo "Keeping only what's listed in preserve_during_upgrade.txt file"
    PRESERVE_FILTER="`generate_preserve_filter`"
    find "$PREFIX/httpd/htdocs" $PRESERVE_FILTER -type f -print0 | xargs -0 rm
  elif [ -d $PREFIX/share/GUI ]; then
    # Remove only files copied from share/GUI to httpd/htdocs
    cf_console echo "Using share/GUI as template"
    ( cd $PREFIX/share/GUI
      # Make list of files in share/GUI and remove "them" from httpd/htdocs
      find -type f -print0 | ( cd ../../httpd/htdocs/ && xargs -0 rm )
    )
  else
    # Purge all files in httpd/htdocs with hardcoded exceptions:
    # Preserve the tmp directory as it may contain scheduled or exported reports.
    # Preserve cf_robot.php and settings.ldap.php because they are generated.
    cf_console echo "No share/GUI found, purging all files except known exceptions"
    find "$PREFIX/httpd/htdocs" -not \( -path "$PREFIX/httpd/htdocs/tmp" -prune \) \
	    -not \( -name "cf_robot.php" \) \
	    -not \( -name "settings.ldap.php" \) \
	    -type f -print0 | xargs -0 rm
  fi
  if [ -d $PREFIX/share/GUI -a "x${PKG_TYPE}" = "xrpm" ]; then
    # Make sure old files are not copied over together with new files later
    # (this only happens during upgrade of RPMs)
    mv $PREFIX/share/GUI $PREFIX/share/GUI_old
  fi
  # Remove empty dirs in httpd/htdocs
  find $PREFIX/httpd/htdocs -depth -type d -exec rmdir {} \;
fi

# Make a backup of the key CFE_CLIENT_SECRET_KEY, if any, and restore the
# original file content.
#
if [ -f $PREFIX/share/GUI/application/config/appsettings.php ]; then
  # Tricky quotes, because we need to both prevent expansion of $config,
  # and keep the internal ' quotes.
  UUID_REGEX="[a-z0-9]{32}"
  fgrep '$config'"['MP_CLIENT_SECRET']" $PREFIX/httpd/htdocs/application/config/appsettings.php | sed -r -e "s/.*($UUID_REGEX).*/\1/i" > $PREFIX/CF_CLIENT_SECRET_KEY.tmp
  if [ "$(egrep -i "$UUID_REGEX" $PREFIX/CF_CLIENT_SECRET_KEY.tmp | wc -l)" -eq 1 ]; then
    UUID=$(tr -d '\n\r' < $PREFIX/CF_CLIENT_SECRET_KEY.tmp)
    for path in share/GUI httpd/htdocs; do
      sed -i s/"$UUID"/CFE_SESSION_KEY/ $PREFIX/$path/application/config/config.php
      sed -i s/"$UUID"/CFE_CLIENT_SECRET_KEY/ $PREFIX/$path/application/config/appsettings.php
      sed -i s/"$UUID"/LDAP_API_SECRET_KEY/ $PREFIX/$path/application/config/appsettings.php
      sed -i s/"$UUID"/LDAP_API_SECRET_KEY/ $PREFIX/$path/ldap/config/settings.php
      sed -i /LDAP_API_SECRET_KEY/s/"$UUID"// $PREFIX/$path/api/config/config.php
    done
    sed -i s/"$UUID"/CFE_CLIENT_SECRET_KEY/ $PREFIX/share/db/ootb_settings.sql
  else
    # Extraction failed. Remove file so that we generate a new UUID later.
    rm -f $PREFIX/CF_CLIENT_SECRET_KEY.tmp
  fi
fi

exit 0
