if is_upgrade; then
  # This is nice to know to provide fixes for bugs in already released
  # package scripts.
  "$PREFIX/bin/cf-agent" -V | grep '^CFEngine Core' | sed -e 's/^CFEngine Core \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/' > "$PREFIX/UPGRADED_FROM.txt"
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
    if $PREFIX/bin/cf-agent -V | egrep '^CFEngine Core 3\.([0-5]|6\.[01])' > /dev/null; then
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
  echo "hostname -f does not return a valid name, but this is a requirement for generating a"
  echo "SSL certificate for the Mission Portal and API."
  echo "Please make sure that hostname -f returns a valid name (Add an entry to /etc/hosts or "
  echo "fix the name resolution)."
  exit 1
fi

#stop the remaining services on upgrade
if is_upgrade; then
  platform_service cfengine3 stop
  if [ -x /bin/systemctl ]; then
    # When using systemd, the services are split in two, and although both will
    # stop due to the command above, the web part may only do so after some
    # delay, which may cause problems in an upgrade situation, since this script
    # will immediately check whether the ports are in use.
    /bin/systemctl stop cfengine3-web
  fi
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
  echo "There seems to be a server listening on either port 80 or 443"
  echo "Checking if it is part of CFEngine Enterprise"
  if [ -x $PREFIX/httpd/bin/apachectl ];
  then
    echo "Trying to shut down the process using apachectl from CFEngine Enterprise"
    $PREFIX/httpd/bin/apachectl stop
    HTTPD_RUNNING=`filter_netstat_listen ":80\s|:443\s"`
    if [ ! -z "$HTTPD_RUNNING" ];
    then
      echo "Could not shutdown the process, aborting the installation"
      exit 1
    fi
  else
    echo "No apachectl found, aborting the installation!"
    echo "Please kill the following processes before attempting a new installation"
    fuser -n tcp 80
    fuser -n tcp 443
    exit 1
  fi
fi

#
# We check if there is a postgres db server running already
#
PSQL_RUNNING=`filter_netstat_listen ":5432\s"`
if [ ! -z "$PSQL_RUNNING" ];
then
  echo "There seems to be a server listening on port 5432"
  echo "This might mean that there is a PostgreSQL server running on the machine already"
  echo "Checking if the Postgres installation belongs to a previous CFEngine deployment"
  PSQL_COMMAND=$(ps -p $(fuser -n tcp 5432 2>/dev/null) -o args=|cut -d' ' -f1)
  if [ ! -z "$PSQL_COMMAND" ];
  then
    if [ "$PSQL_COMMAND" = "$PREFIX/bin/postgres" ];
    then
      echo "The PostgreSQL server belongs to a previous CFEngine deployment, shutting it down."
      if [ -x "$PREFIX/bin/pg_ctl" ];
      then
	(cd /tmp && su cfpostgres -c "$PREFIX/bin/pg_ctl stop -D $PREFIX/state/pg/data -m smart")
      else
	echo "No pg_ctl found at $PREFIX/bin/pg_ctl, aborting"
	exit 1
      fi
    else
      echo "The PostgreSQL is not from a previous CFEngine deployment"
      echo "This scenario is not supported, aborting installation"
      ps -p `fuser -n tcp 5432 2>/dev/null` -o args=
      exit 1
    fi
  else
    echo "There is a process listening on the PostgreSQL port but it is not PostgreSQL, aborting."
    echo -n "Command: "
    ps -p `fuser -n tcp 5432 2>/dev/null` -o args=
    echo "Please make sure that the process is not running before attempting the installation again."
    exit 1
  fi
  PSQL_FINAL_CHECK=`filter_netstat_listen ":5432\s"`
  if [ ! -z "$PSQL_FINAL_CHECK" ];
  then
    echo "There is still a process listening on 5432, please kill it before retrying the installation. Aborting."
    exit 1
  fi
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
if [ -d $PREFIX/httpd/htdocs ]; then
  echo "A previous version of CFEngine Mission Portal was found,"
  echo "creating a backup of it at /tmp/cfengine-htdocs.tar.gz"
  tar zcf /tmp/cfengine-htdocs.tar.gz $PREFIX/httpd/htdocs
fi

#
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
    done
    sed -i s/"$UUID"/CFE_CLIENT_SECRET_KEY/ $PREFIX/share/db/ootb_settings.sql
  else
    # Extraction failed. Remove file so that we generate a new UUID later.
    rm -f $PREFIX/CF_CLIENT_SECRET_KEY.tmp
  fi
fi

exit 0
