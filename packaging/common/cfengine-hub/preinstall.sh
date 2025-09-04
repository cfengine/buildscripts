
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

# When PostgreSQL changes major version we need to migrate. CFEngine 3.25 uses PostgreSQL 17.0 so any version 3.24 or older needs migration.
if is_upgrade && egrep '^3\.([6-9]|1[0-9]|2[0-4])\.' "$PREFIX/UPGRADED_FROM.txt" >/dev/null && [ -d "$PREFIX/state/pg/data" ]; then
  alias migrating_postgres='true'
else
  alias migrating_postgres='false'
fi

test -z "$BACKUP_DIR" && BACKUP_DIR=$PREFIX/state/pg/backup

if [ -d "$BACKUP_DIR" ] && [ -n "$(ls -A "$BACKUP_DIR")" ]; then
    # If the backup directory exists and is not empty we don't want to proceed,
    # that stale data can cause database migration problems.
    cf_console echo "Backup directory $BACKUP_DIR exists and is not empty."
    cf_console echo 'Please remove it, clean it, or set a different directory by setting a BACKUP_DIR env variable, like this:'
    cf_console echo 'export BACKUP_DIR=/mnt/plenty-of-free-space'
    exit 1
fi

if migrating_postgres; then
  mkdir -p "$BACKUP_DIR"
  # Try to check if free space on $BACKUP_DIR drive is not less than $PREFIX/state/pg/data contains
  if command -v df >/dev/null && command -v du >/dev/null && command -v awk >/dev/null; then
    # We have enough commands to test it.
    # Explanation of arguments:
    # `df`
    #   `-P` - use POSIX output format (free space in 4th column),
    #   `-BM` - print output in Megabytes
    # `awk`
    #   `FNR==2` - take record (line) number two (first line in `df` output is table header)
    #   `gsub(...)` - remove non-numbers from 4th column
    #   `print $4` - well, print 4th column
    # `du`
    #   `-s` - print only summary - i.e. only one line with total size of all
    #     files in direcrory passed as argument - unlike in normal case when it
    #     prints disk usage by each nested directory, recursively
    #   `-BM` - print output in Megabytes
    #
    # Example of `df -PBM .` output on my machine:
    # ```
    # Filesystem     1048576-blocks    Used Available Capacity Mounted on
    # /dev/sda1             246599M 210974M    24564M      90% /
    # ```
    # and awk would extract "24564" number from it
    # Example of `du -sBM .` output on my machine:
    # ```
    # 172831M	.
    # ```
    # and awk would extract "172831" number from it
    #
    megabytes_free="$(df -PBM $BACKUP_DIR | awk 'FNR==2{gsub(/[^0-9]/,"",$4);print $4}')"
    megabytes_need="$(du -sBM $PREFIX/state/pg/data | awk '{gsub(/[^0-9]/,"",$1);print $1}')"
    if [ "$megabytes_free" -le "$megabytes_need" ]; then
      cf_console echo "Not enough disk space to create DB backup:"
      cf_console echo "${megabytes_free}M available in $BACKUP_DIR want at least ${megabytes_need}M free"
      cf_console echo "${megabytes_need}M used by $PREFIX/state/pg/data"
      cf_console echo "You have the following options:"
      cf_console echo "* Free up some disk space before upgrading"
      cf_console echo "* Use another directory for database backup by exporting BACKUP_DIR env variable"
      cf_console echo "* Disable database upgrade by removing/renaming $PREFIX/state/pg/data prior to upgrade"
      exit 1
    fi
  fi
  cf_console echo "Attempting to migrate Mission Portal database. This can break stuff."
  cf_console echo "Copy will be created in $BACKUP_DIR dir."
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
# If an existing cert is not in place then:
# Before starting the installation process we need to check that
# hostname -f returns a valid name and hostname -s is shorter
# than 64 characters. If not we abort the installation.
#
NAME=$(hostname -f) || true
if [ -z "$NAME" ];
then
  cf_console echo "hostname -f does not return a valid name, but this is a requirement for generating a"
  cf_console echo "SSL certificate for the Mission Portal and API."
  cf_console echo "Please make sure that hostname -f returns a valid name (Add an entry to /etc/hosts or "
  cf_console echo "fix the name resolution)."
  exit 1
fi

CFENGINE_MP_DEFAULT_CERT_LOCATION="$PREFIX/httpd/ssl/certs"
CFENGINE_LOCALHOST=$(hostname -f | tr '[:upper:]' '[:lower:]')
CFENGINE_MP_CERT=$CFENGINE_MP_DEFAULT_CERT_LOCATION/$CFENGINE_LOCALHOST.cert
if [ ! -f "$CFENGINE_MP_CERT" ]; then
  CFENGINE_SHORTNAME=$(hostname -s | tr '[:upper:]' '[:lower:]')
  if [ $(echo -n "$CFENGINE_SHORTNAME" | wc -m) -gt 64 ]; then
    cf_console echo "hostname -s returned '$CFENGINE_SHORTNAME' which is longer than 64 characters and cannot be used to generate a self-signed cert common name (CN)."
    cf_console echo "Please make sure that hostname -s returns a name less than 64 characters long."
    exit 1
  fi
fi

#stop the remaining services on upgrade
if is_upgrade; then
  cf_console platform_service cfengine3 stop
  # CFE-2278: Migrate to split units
  if [ -x /bin/systemctl ] && [ -e /usr/lib/systemd/system/cfengine3-web.service ]; then
    # When using systemd, the services are split in two, and although both will
    # stop due to the command above, the web part may only do so after some
    # delay, which may cause problems in an upgrade situation, since this script
    # will immediately check whether the ports are in use.
    /bin/systemctl stop cfengine3-web.service
  fi
fi

filter_netstat_listen()
{
  set +e
  if command -v ss >/dev/null; then
    ss -natp | egrep "LISTEN.*($1)"
  else
    netstat -natp | egrep "($1).*LISTEN"
  fi
  set -e
  return 0
}

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
           su cfpostgres -c "$PREFIX/bin/pg_ctl stop -D $PREFIX/state/pg/data -m smart" ||
             # '-m fast' quits directly, without proper session shutdown
             su cfpostgres -c "$PREFIX/bin/pg_ctl stop -D $PREFIX/state/pg/data -m fast")
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

if migrating_postgres; then
  cf_console echo "Moving old data and copying old binaries to $BACKUP_DIR"
  # Now that PostgreSQL is shut down, move the old data out of the way.
  mkdir -p "$BACKUP_DIR/lib"
  mkdir -p "$BACKUP_DIR/share"

  if ! safe_mv "$PREFIX/state/pg" data "$BACKUP_DIR"; then
    # Copy failed
    cf_console echo "Backup creation failed"
    cf_console echo "Please fix it before upgrading or disable upgrade by removing/renaming $PREFIX/state/pg/data prior to upgrade."
    exit 1
  fi

  if ! diff "$BACKUP_DIR/data/postgresql.conf" "$PREFIX/share/postgresql/postgresql.conf.cfengine" > /dev/null; then
    # diff exits with 0 if the files are the same
    # the postgresql.conf file was modified, we should try to use it after migration
    cp -a "$BACKUP_DIR/data/postgresql.conf" "$BACKUP_DIR/data/postgresql.conf.modified"
  fi
  safe_cp "$PREFIX" bin "$BACKUP_DIR"
  on_files cp "$PREFIX/lib" "$BACKUP_DIR/lib"
  safe_cp "$PREFIX/lib" postgresql "$BACKUP_DIR/lib"
  safe_cp "$PREFIX/share" postgresql "$BACKUP_DIR/share"
fi

#
# We check if there is a server listening on port 9000.
# If one is found and belongs to CFEngine,
# then we try to shut it down using fuser.
# If that does not work, we abort the installation.
#
ensure_php_fpm_terminated() {
  PHP_FPM_RUNNING=$(filter_netstat_listen ":9000\\s")
  if [ -z "$PHP_FPM_RUNNING" ]; then
    return 0;
  fi

  cf_console echo "There seems to be a server listening on port 9000."
  
  phpfpmpid=$(echo "$PHP_FPM_RUNNING" | sed -r -e '/pid=/!d' -e 's/.*pid=([0-9]+),.*/\1/' | tail -1)
  phpfpmargs=$(ps -p "$phpfpmpid" -o args=)
  
  if echo "$phpfpmargs" | grep -q "cfengine"; then
    cf_console echo "The PHP-FPM process belongs to a previous CFEngine deployment, shutting it down."
    cf_console echo "Attempting to terminate the process using fuser."
    if ! command -v fuser >/dev/null; then
      cf_console echo "fuser not available, can't kill!"
      return 1
    fi

    fuser -k -TERM -n tcp 9000
        
    sleep 5s
    PHP_FPM_FINAL_CHECK=$(filter_netstat_listen ":9000\\s")
    if [ -n "$PHP_FPM_FINAL_CHECK" ]; then
      cf_console echo "There is still a process listening on port 9000. Please kill it manually before retrying. Aborting."
      return 1
    fi
  else
    cf_console echo "The PHP-FPM process is not from a previous CFEngine deployment"
    cf_console echo "This scenario is not supported, aborting installation"
    ps -p `fuser -n tcp 9000 2>/dev/null` -o args=
    return 1
  fi

  return 0
}

ensure_php_fpm_terminated || exit 1

#
# We check if there is a server listening on port 80 or port 443.
# If one is found, then we try to shut it down by calling
# $PREFIX/httpd/bin/apachectl stop
# If that does not work, we abort the installation.
#
ensure_apache_terminated() {
  HTTPD_RUNNING=`filter_netstat_listen ":80\s|:443\s"`
  [ -z "$HTTPD_RUNNING" ] && return 0
  cf_console echo "There seems to be a server listening on either port 80 or 443"
  cf_console echo "Checking if it is part of CFEngine Enterprise"
  if [ ! -x $PREFIX/httpd/bin/apachectl ];
  then
    cf_console echo "No apachectl found, aborting the installation!"
    return 1
  fi
  cf_console echo "Trying to shut down the process using apachectl from CFEngine Enterprise"
  $PREFIX/httpd/bin/apachectl stop
  HTTPD_RUNNING=`filter_netstat_listen ":80\s|:443\s"`
  [ -z "$HTTPD_RUNNING" ] && return 0
  cf_console echo "Still running: $HTTPD_RUNNING, waiting 5 sec"
  sleep 5s
  HTTPD_RUNNING=`filter_netstat_listen ":80\s|:443\s"`
  [ -z "$HTTPD_RUNNING" ] && return 0
  if ! command -v fuser >/dev/null; then
    cf_console echo "fuser not available, can't kill!"
    return 1
  fi
  cf_console echo "Still running: $HTTPD_RUNNING, killing with fuser -TERM"
  fuser -k -TERM -n tcp 80
  fuser -k -TERM -n tcp 443
  HTTPD_RUNNING=`filter_netstat_listen ":80\s|:443\s"`
  [ -z "$HTTPD_RUNNING" ] && return 0
  cf_console echo "Still running: $HTTPD_RUNNING, waiting 5 sec"
  sleep 5s
  HTTPD_RUNNING=`filter_netstat_listen ":80\s|:443\s"`
  [ -z "$HTTPD_RUNNING" ] && return 0
  cf_console echo "Still running: $HTTPD_RUNNING, killing with fuser -KILL"
  fuser -k -KILL -n tcp 80
  fuser -k -KILL -n tcp 443
  HTTPD_RUNNING=`filter_netstat_listen ":80\s|:443\s"`
  [ -z "$HTTPD_RUNNING" ] && return 0
  cf_console echo "Still running: $HTTPD_RUNNING, waiting 5 sec"
  sleep 5s
  HTTPD_RUNNING=`filter_netstat_listen ":80\s|:443\s"`
  [ -z "$HTTPD_RUNNING" ] && return 0
  cf_console echo "Still running: $HTTPD_RUNNING."
  cf_console echo "Could not shutdown the process, aborting the installation"
  return 1
}

if ! ensure_apache_terminated; then
  cf_console echo "Please kill the following processes before attempting a new installation"
  if command -v fuser >/dev/null; then
    cf_console fuser -n tcp 80
    cf_console fuser -n tcp 443
  else
    cf_console filter_netstat_listen ":80\s|:443\s"
  fi
  true "process tree saved in log file"
  ps -efH
  exit 1
fi

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
    find "$PREFIX/httpd/htdocs" $PRESERVE_FILTER -type f -print0 | xargs --no-run-if-empty -0 rm
  elif [ -d $PREFIX/share/GUI ]; then
    # Remove only files copied from share/GUI to httpd/htdocs
    cf_console echo "Using share/GUI as template"
    ( cd $PREFIX/share/GUI
      # Make list of files in share/GUI and remove "them" from httpd/htdocs
      find -type f -print0 | ( cd ../../httpd/htdocs/ && xargs --no-run-if-empty -0 rm -f )
    )
  else
    # Purge all files in httpd/htdocs with hardcoded exceptions:
    # Preserve the tmp directory as it may contain scheduled or exported reports.
    # Preserve cf_robot.php and settings.ldap.php because they are generated.
    cf_console echo "No share/GUI found, purging all files except known exceptions"
    find "$PREFIX/httpd/htdocs" -not \( -path "$PREFIX/httpd/htdocs/public/tmp" -prune \) \
	    -not \( -name "cf_robot.php" \) \
	    -not \( -name "settings.ldap.php" \) \
	    -type f -print0 | xargs --no-run-if-empty -0 rm
  fi
  if [ -d $PREFIX/share/GUI -a "x${PKG_TYPE}" = "xrpm" ]; then
    # Make sure old files are not copied over together with new files later
    # (this only happens during upgrade of RPMs)
    mv $PREFIX/share/GUI $PREFIX/share/GUI_old
  fi
  # Remove empty dirs in httpd/htdocs
  find $PREFIX/httpd/htdocs -depth -type d -empty -exec rmdir {} \;
fi

if [ -d $PREFIX/httpd/php/lib/php/extensions/no-debug-non-zts-20170718 ]; then
  rm $PREFIX/httpd/php/lib/php/extensions/no-debug-non-zts-20170718/* || true # if nothing there, fine
fi

# starting with 3.16, we no longer patch php/sql files
if is_upgrade && egrep '^3\.([2-9]|1[012345])\.' "$PREFIX/UPGRADED_FROM.txt" >/dev/null; then
  true "Removing keys from files maintained by package manager"
  test -f "$PREFIX/share/db/ootb_settings.sql" && \
    sed -i "/INSERT INTO oauth_clients VALUES ('MP',/s/.*/INSERT INTO oauth_clients VALUES ('MP', 'CFE_CLIENT_SECRET_KEY', '', 'password refresh_token', NULL, NULL);/" "$PREFIX/share/db/ootb_settings.sql"
  for path in share/GUI httpd/htdocs; do
    test -f "$PREFIX/$path/application/config/config.php" && \
      sed -i "/\$config.'encryption_key'/s/.*/\$config['encryption_key'] = 'CFE_SESSION_KEY';/" \
        "$PREFIX/$path/application/config/config.php"
    test -f "$PREFIX/$path/application/config/appsettings.php" && \
      sed -i "/\$config.'MP_CLIENT_SECRET'/s/.*/\$config['MP_CLIENT_SECRET'] = 'CFE_CLIENT_SECRET_KEY';/" \
        "$PREFIX/$path/application/config/appsettings.php"
    test -f "$PREFIX/$path/application/config/appsettings.php" && \
      sed -i "/\$config.'LDAP_API_SERVER_SECRET'/s/.*/\$config['LDAP_API_SERVER_SECRET'] = 'LDAP_API_SECRET_KEY';/" \
        "$PREFIX/$path/application/config/appsettings.php"
    test -f "$PREFIX/$path/ldap/config/settings.php" && \
      sed -i "/'accessToken'/s/.*/    'accessToken' => 'LDAP_API_SECRET_KEY',/" \
        "$PREFIX/$path/ldap/config/settings.php"
    test -f "$PREFIX/$path/api/config/config.php" && \
      sed -i "/define('LDAP_API_SECRET_KEY',/s/.*/define('LDAP_API_SECRET_KEY', '');/" \
        "$PREFIX/$path/api/config/config.php"
  done
  true "Done removing keys"
fi

# Since 3.24.0 runalerts is part of cf-reactor with no stamp files
if is_upgrade && test -d "$PREFIX/httpd/php/runalerts-stamp"; then
  rm -rf "$PREFIX/httpd/php/runalerts-stamp"
fi

exit 0
