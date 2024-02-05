# (re)load SELinux policy if available and required before we start working with
# our daemons and services below
if [ `os_type` = "redhat" ] &&
   [ -f "$PREFIX/selinux/cfengine-enterprise.pp" ];
then
  if command -v /usr/sbin/selinuxenabled >/dev/null &&
      /usr/sbin/selinuxenabled;
  then
    command -v semodule >/dev/null || cf_console echo "warning! selinuxenabled exists and returns 0 but semodule not found"
    test -x /usr/sbin/load_policy  || cf_console echo "warning! selinuxenabled exists and returns 0 but load_policy not found"
    test -x /usr/sbin/restorecon   || cf_console echo "warning! selinuxenabled exists and returns 0 but restorecon not found"
  fi
  if ! cf_console semodule -n -i "$PREFIX/selinux/cfengine-enterprise.pp"; then
    cf_console echo "warning! semodule import failed, examine /var/log/CFE*log and \
consider installing selinux-policy-devel package and \
rebuilding policy with: \
\
cd $PREFIX/selinux \
make -f /usr/share/selinux/devel/Makefile -j1 \
semodule -n -i $PREFIX/selinux/cfengine-enterprise.pp \
\
and then restarting services with  \
\
systemctl restart cfengine3"
  fi
  if /usr/sbin/selinuxenabled; then
    /usr/sbin/load_policy
    /usr/sbin/restorecon -R /var/cfengine
  fi
fi

if [ -x /bin/systemctl ]; then
  # This is important in case any of the units have been replaced by the package
  # and we call them in the postinstall script.
  if ! /bin/systemctl daemon-reload; then
    cf_console echo "warning! /bin/systemctl daemon-reload failed."
    cf_console echo "systemd seems to be installed, but not working."
    cf_console echo "Relevant parts of CFEngine installation will fail."
    cf_console echo "Please fix systemd or use other ways to start CFEngine."
  fi
fi

#
# Make sure the cfapache user has a home folder and populate it
#
MP_APACHE_USER=cfapache
if [ -d "$PREFIX/$MP_APACHE_USER" ];
then
	cf_console echo "cfapache folder already exists, deleting it"
	rm -rf "$PREFIX/$MP_APACHE_USER"
fi
/usr/sbin/usermod -d "$PREFIX/$MP_APACHE_USER" $MP_APACHE_USER
mkdir -p "$PREFIX/$MP_APACHE_USER/.ssh"
chown -R $MP_APACHE_USER:$MP_APACHE_USER "$PREFIX/$MP_APACHE_USER"
echo "Host *
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null" >> "$PREFIX/$MP_APACHE_USER/.ssh/config"

#
# Generate a host key
#
if [ ! -f "$PREFIX/ppkeys/localhost.priv" ]; then
    "$PREFIX/bin/cf-key" >/dev/null || :
fi

if [ ! -f "$PREFIX/masterfiles/promises.cf" ]; then
    /bin/cp -R "$PREFIX/share/NovaBase/masterfiles" "$PREFIX"
    touch "$PREFIX/masterfiles/cf_promises_validated"
    find "$PREFIX/masterfiles" -type d -exec chmod 700 {} \;
    find "$PREFIX/masterfiles" -type f -exec chmod 600 {} \;
fi

if [ -f "$PREFIX/lib/php/mcrypt.so" ]; then
  /bin/rm -f "$PREFIX/lib/php"/mcrypt.*
fi

if [ -f "$PREFIX/lib/php/curl.so" ]; then
  /bin/rm -f "$PREFIX/lib/php"/curl.*
fi

# Hack around ENT-3520 In 3.12.0 we moved to php 7, this removes the old php
if [ -e "$PREFIX/httpd/modules/libphp5.so" ]; then
    rm "$PREFIX/httpd/modules/libphp5.so"
fi

#
#Copy necessary Files and permissions
#
cp "$PREFIX/lib/php"/*.ini "$PREFIX/httpd/php/lib"
EXTENSIONS_DIR="$(ls -d -1 "$PREFIX/httpd/php/lib/php/extensions/no-debug-non-zts-"*|tail -1)"
cp "$PREFIX/lib/php"/*.so "$EXTENSIONS_DIR"

#
#Create a secrets file
#
true "Creating httpd/secrets.ini file"
touch "$PREFIX/httpd/secrets.ini"
chmod 400 "$PREFIX/httpd/secrets.ini"
chown cfapache "$PREFIX/httpd/secrets.ini"
pwgen() {
dd if=/dev/urandom bs=1024 count=1 2>/dev/null | tr -dc 'a-zA-Z0-9' | fold -w $1 | head -n 1
}
( set +x
  cat >"$PREFIX/httpd/secrets.ini" <<EOF
; Comments should start with semicolon
[passwords]
cf_robot_password=$(pwgen 32)

[tokens]
mp_client_secret=$(pwgen 32)
ldap_api_secret=$(pwgen 32)
CFE_SESSION_KEY=$(pwgen 32)
EOF
)
true "Done creating httpd/secrets.ini file"

cp -r --remove-destination $PREFIX/share/GUI/* $PREFIX/httpd/htdocs

# If old files were moved aside during upgrade, we should move them back so that
# rpm can do its cleanup procedures. But avoid overwriting new files with the
# old ones (hence cp -n).
if [ -d $PREFIX/share/GUI_old ]; then
    cp -rn $PREFIX/share/GUI_old/* $PREFIX/share/GUI/
    rm -rf $PREFIX/share/GUI_old/
fi

mkdir -p $PREFIX/httpd/htdocs/public/tmp
mv $PREFIX/httpd/htdocs/Apache-htaccess $PREFIX/httpd/htdocs/.htaccess
chmod 755 $PREFIX/httpd
chown -R root:$MP_APACHE_USER $PREFIX/httpd/htdocs
chmod -R ug=rX,o= $PREFIX/httpd/htdocs # 440 for files, 550 for dirs
chmod a+rx $PREFIX/httpd/htdocs/api/dc-scripts/*.sh

#
# Cleanup deprecated plugins directory
#
if ! rmdir $PREFIX/plugins 2> /dev/null; then
    # CFE-3618
    echo "$PREFIX/plugins has been removed from the default distribution, we \
tried to clean up the unused directory but found it was not empty. Please \
review your policy, if you believe this directory should remain part of the \
default distribution, please open a ticket in the CFEngine bug tracker."
fi

#these directories should be write able by apache
chown $MP_APACHE_USER:$MP_APACHE_USER $PREFIX/httpd/logs
chmod 750 $PREFIX/httpd/logs
chown -R $MP_APACHE_USER:$MP_APACHE_USER $PREFIX/httpd/htdocs/public/tmp
chown -R root:$MP_APACHE_USER $PREFIX/httpd/htdocs/api/static
chmod 770 $PREFIX/httpd/htdocs/api/static

if [ -d "$PREFIX/httpd/htdocs/application/logs" ]; then
    mkdir -p "$PREFIX/httpd/logs/application/logs"
    mv "$PREFIX/httpd/htdocs/application/logs/"* "$PREFIX/httpd/logs/application/logs/"
    rm -rf "$PREFIX/httpd/htdocs/application/logs"
fi
if [ ! -d "$PREFIX/httpd/logs/application" ]; then
    mkdir -p "$PREFIX/httpd/logs/application"
fi
chown $MP_APACHE_USER:$MP_APACHE_USER $PREFIX/httpd/logs/application
chmod 750 $PREFIX/httpd/logs/application

#
# VCS setup
#
DCWORKDIR="/opt/cfengine"
DCPARAMS="$DCWORKDIR/dc-scripts/params.sh"
if ! test -f "$DCPARAMS"; then
  # Create new DC params.sh
  mkdir -p "$(dirname "$DCPARAMS")"

  cat > "$DCPARAMS" <<EOHIPPUS
ROOT="$DCWORKDIR/masterfiles_staging"
GIT_URL="$DCWORKDIR/masterfiles.git"
GIT_REFSPEC="master"
GIT_USERNAME=""
GIT_PASSWORD=""
GIT_WORKING_BRANCH="CF_WORKING_BRANCH"
PKEY="$DCWORKDIR/userworkdir/admin/.ssh/id_rsa.pvt"
SCRIPT_DIR="$PREFIX/httpd/htdocs/api/dc-scripts"
VCS_TYPE="GIT"

export PATH="\${PATH}:$PREFIX/bin"
export PKEY
export GIT_USERNAME
export GIT_PASSWORD
export GIT_SSH="\${SCRIPT_DIR}/ssh-wrapper.sh"
export GIT_ASKPASS="\${SCRIPT_DIR}/git-askpass.sh"
EOHIPPUS

else
  # Migrate DC params.sh
  # change GIT_BRANCH to GIT_REFSPEC, if it exists
  # or add it after first line
  if ! grep 'GIT_REFSPEC=' $DCPARAMS >/dev/null; then
    if grep 'GIT_BRANCH=' $DCPARAMS >/dev/null; then
      sed -i 's/GIT_BRANCH=/GIT_REFSPEC=/' $DCPARAMS
    else
      sed -i '1a GIT_REFSPEC="master"' $DCPARAMS
    fi
  fi
  # Add git username and password, if they're missing
  if ! grep 'GIT_USERNAME=' $DCPARAMS >/dev/null; then
    sed -i '1a GIT_USERNAME=""' $DCPARAMS
  fi
  if ! grep 'GIT_PASSWORD=' $DCPARAMS >/dev/null; then
    sed -i '1a GIT_PASSWORD=""' $DCPARAMS
  fi
  # Add export lines at the end, if they're missing
  if ! grep 'export GIT_USERNAME' $DCPARAMS >/dev/null; then
    echo 'export GIT_USERNAME' >>$DCPARAMS
  fi
  if ! grep 'export GIT_PASSWORD' $DCPARAMS >/dev/null; then
    echo 'export GIT_PASSWORD' >>$DCPARAMS
  fi
  if ! grep 'export GIT_ASKPASS' $DCPARAMS >/dev/null; then
    echo 'export GIT_ASKPASS="${SCRIPT_DIR}/git-askpass.sh"' >>$DCPARAMS
  fi

fi

# Dir to store SSH key to access git repo
mkdir -p "$DCWORKDIR/userworkdir/admin/.ssh"
chmod -R 700 $DCWORKDIR/userworkdir

# Dir for notification/alert scripts
mkdir -p "$DCWORKDIR/notification_scripts"
chmod -R 700 "$DCWORKDIR/notification_scripts"

chown -R $MP_APACHE_USER:$MP_APACHE_USER "$DCWORKDIR"

# Dir for build projects
mkdir -p "$DCWORKDIR/build"
chown -R root:$MP_APACHE_USER "$DCWORKDIR/build"

if [ -f $PREFIX/bin/cf-twin ]; then
    /bin/rm $PREFIX/bin/cf-twin
fi

#
#MAN PAGE RELATED
#
MAN_CONFIG=""
MAN_PATH=""
case "`package_type`" in
  rpm)
    if [ -f /etc/SuSE-release ];
    then
      # SuSE
      MAN_CONFIG="/etc/manpath.config"
      MAN_PATH="MANDATORY_MANPATH"
    else
      # RH/CentOS
      MAN_CONFIG="/etc/man.config"
      MAN_PATH="MANPATH"
    fi
    ;;
  deb)
    MAN_CONFIG="/etc/manpath.config"
    MAN_PATH="MANDATORY_MANPATH"
    ;;
  *)
    echo "Unknown manpath, should not happen!"
    ;;
esac

if [ -f "$MAN_CONFIG" ];
then
  if grep cfengine "$MAN_CONFIG" >/dev/null; then
    echo "$MAN_PATH     $PREFIX/share/man" >> "$MAN_CONFIG"
  fi
fi

for i in cf-agent cf-promises cf-key cf-secret cf-execd cf-serverd cf-monitord cf-runagent \
         cf-hub cf-reactor \
         cf-net cf-check cf-support \
         cfbs;
do
  if [ -f $PREFIX/bin/$i -a -d /usr/local/sbin ]; then
    ln -sf $PREFIX/bin/$i /usr/local/sbin/$i || true
  fi
  if [ -f /usr/share/man/man8/$i.8.gz ]; then
    rm -f /usr/share/man/man8/$i.8.gz
  fi
  if $PREFIX/bin/$i -M > /usr/share/man/man8/$i.8; then
    gzip /usr/share/man/man8/$i.8 || true
  fi
done

#
# Generate a certificate for Mission Portal
# The certificate will be named $(hostname -f).cert and the corresponding key should be named $(hostname -f).key.
#
CFENGINE_MP_DEFAULT_CERT_LOCATION="$PREFIX/httpd/ssl/certs"
CFENGINE_MP_DEFAULT_CERT_LINK_LOCATION="$PREFIX/ssl"
CFENGINE_MP_DEFAULT_KEY_LOCATION="$PREFIX/httpd/ssl/private"
CFENGINE_MP_DEFAULT_CSR_LOCATION="$PREFIX/httpd/ssl/csr"
if [ -x "$PREFIX/bin/openssl" ]; then
  CFENGINE_OPENSSL="$PREFIX/bin/openssl"
elif [ -x "/usr/bin/openssl" ]; then
  CFENGINE_OPENSSL="/usr/bin/openssl"
else
  cf_console echo "No 'openssl' binary found!"
  exit 1
fi
if [ -f "${PREFIX}/ssl/openssl.cnf" ]; then
  OPENSSL_CNF="-config ${PREFIX}/ssl/openssl.cnf"
else
  # otherwise use default config
  OPENSSL_CNF=""
fi
mkdir -p $CFENGINE_MP_DEFAULT_CERT_LOCATION
mkdir -p $CFENGINE_MP_DEFAULT_KEY_LOCATION
mkdir -p $CFENGINE_MP_DEFAULT_CSR_LOCATION
mkdir -p $CFENGINE_MP_DEFAULT_CERT_LINK_LOCATION
CFENGINE_LOCALHOST=$(hostname -f | tr '[:upper:]' '[:lower:]')
CFENGINE_SSL_KEY_SIZE="4096"
CFENGINE_SSL_DAYS_VALID="3650"
CFENGINE_MP_CERT=$CFENGINE_MP_DEFAULT_CERT_LOCATION/$CFENGINE_LOCALHOST.cert
CFENGINE_MP_CERT_LINK=$CFENGINE_MP_DEFAULT_CERT_LINK_LOCATION/cert.pem
CFENGINE_MP_CSR=$CFENGINE_MP_DEFAULT_CSR_LOCATION/$CFENGINE_LOCALHOST.csr
CFENGINE_MP_PASS_KEY=$CFENGINE_MP_DEFAULT_KEY_LOCATION/$CFENGINE_LOCALHOST.pass.key
CFENGINE_MP_KEY=$CFENGINE_MP_DEFAULT_KEY_LOCATION/$CFENGINE_LOCALHOST.key

if [ ! -f $CFENGINE_MP_CERT ]; then

  # Generate a password protected key in ${CFENGINE_MP_PASS_KEY}
    ${CFENGINE_OPENSSL} genrsa -passout pass:x -out ${CFENGINE_MP_PASS_KEY} ${CFENGINE_SSL_KEY_SIZE}

  # Strip password from key in ${CFENGINE_MP_PASS_KEY} and produce ${CFENGINE_MP_KEY}
  ${CFENGINE_OPENSSL} rsa -passin pass:x -in ${CFENGINE_MP_PASS_KEY} -out ${CFENGINE_MP_KEY}

  # Generate a CSR in ${CFENGINE_MP_CSR} with key ${CFENGINE_MP_KEY}
  ${CFENGINE_OPENSSL} req -utf8 -sha256 -nodes -new -subj "/CN=$CFENGINE_LOCALHOST" -key ${CFENGINE_MP_KEY} -out ${CFENGINE_MP_CSR} ${OPENSSL_CNF}

  # Generate CRT
  ${CFENGINE_OPENSSL} x509 -req -days ${CFENGINE_SSL_DAYS_VALID} -in ${CFENGINE_MP_CSR} -signkey ${CFENGINE_MP_KEY} -out ${CFENGINE_MP_CERT}

  ln -sf $CFENGINE_MP_CERT $CFENGINE_MP_CERT_LINK
fi

#
# If we are upgrading and the link is not there make sure to create it
#
if [ ! -h $CFENGINE_MP_CERT_LINK ]; then
  ln -sf $CFENGINE_MP_CERT $CFENGINE_MP_CERT_LINK
fi
#
# Modify the Apache configuration with the corresponding key and certificate
#
sed -i -e s:INSERT_CERT_HERE:$CFENGINE_MP_CERT:g $PREFIX/httpd/conf/httpd.conf
sed -i -e s:INSERT_CERT_KEY_HERE:$CFENGINE_MP_KEY:g $PREFIX/httpd/conf/httpd.conf
sed -i -e s:INSERT_FQDN_HERE:$CFENGINE_LOCALHOST:g $PREFIX/httpd/conf/httpd.conf

#
# POSTGRES RELATED
#

generate_new_postgres_conf() {
  # Generating a new postgresql.conf if enough total memory is present
  #
  # If total memory is lower than 3GB, we use the default pgsql conf file
  # If total memory is beyond 64GB, we use a shared_buffers of 16G
  # Otherwise, we use a shared_buffers equal to 25% of total memory
  total=`cat /proc/meminfo |grep "^MemTotal:.*[0-9]\+ kB"|awk '{print $2}'`

  if ! echo "$total" | grep -q '^[0-9]\+$' >/dev/null; then
    cf_console echo "Error calculating total memory for setting postgresql shared_buffers";
  else
    upper=$(( 64 * 1024 * 1024 ))  #in KB
    lower=$(( 3 * 1024 * 1024 ))   #in KB

    if [ "$total" -gt "$lower" ]; then
      maint="2GB"
      if [ "$total" -ge "$upper" ]; then
        # larger shared buffers provide minor performance improvement
        shared="16GB"
      else
        shared=$(( $total * 25 / 100 / 1024 ))   #in MB
        shared="$shared""MB"
      fi

      # effective_cache_size: 50% of total memory is conservative value
      # 75% is more aggressive, keeping 70% of total memory
      effect=$(( $total * 70 / 100 / 1024 ))   #in MB
      effect="$effect""MB"

      sed -i -e "s/^.effective_cache_size.*/effective_cache_size=$effect/" $PREFIX/share/postgresql/postgresql.conf.cfengine
      sed -i -e "s/^shared_buffers.*/shared_buffers=$shared/" $PREFIX/share/postgresql/postgresql.conf.cfengine
      sed -i -e "s/^maintenance_work_mem.*/maintenance_work_mem=$maint/" $PREFIX/share/postgresql/postgresql.conf.cfengine
      echo "$PREFIX/share/postgresql/postgresql.conf.cfengine"
    else
      cf_console echo "Warning: not enough total memory needed to use the CFEngine"
      cf_console echo "recommended PostgreSQL configuration, using the defaults."
      echo "$PREFIX/share/postgresql/postgresql.conf.sample"
    fi
  fi
}

init_postgres_dir()
{
  test "$#" = 2 || exit 1
  new_pgconfig_file="$1"
  pgconfig_type="$2"

  if test -e $PREFIX/state/pg/data; then
    if ! rm -rf $PREFIX/state/pg/data; then
      cf_console echo "Warning: $PREFIX/state/pg/data couldn't be deleted"
    fi
  fi
  mkdir -p $PREFIX/state/pg/data
  chown -R cfpostgres $PREFIX/state/pg

  # Note: postgres expects $PWD to be writeable, so all postgres commands
  # should be executed from cfpostgres-writeable directory.
  # /tmp is such directory on most cases
  (cd /tmp && su cfpostgres -c "$PREFIX/bin/initdb -D $PREFIX/state/pg/data")
  touch /var/log/postgresql.log
  chown cfpostgres:cfpostgres /var/log/postgresql.log
  chmod 600 /var/log/postgresql.log

  if ! is_upgrade; then
    # Not an upgrade, just use the recommended or default file (see generate_new_postgres_conf())
    cp -a "$new_pgconfig_file" $PREFIX/state/pg/data/postgresql.conf
    chown cfpostgres $PREFIX/state/pg/data/postgresql.conf
  else
    # Always use the original pg_*.conf files, they define access control to PostgreSQL
    cp -a "$BACKUP_DIR"/data/pg_*.conf "$PREFIX/state/pg/data/"
    chown cfpostgres "$PREFIX"/state/pg/data/pg_*.conf

    # Determine which postgresql.conf file to use and put it in the right place.
    if [ -f "$BACKUP_DIR/data/postgresql.conf.modified" ]; then
      # User-modified file from the previous old version of CFEngine exists, try to use it.
      cp -a "$BACKUP_DIR/data/postgresql.conf.modified" "$PREFIX/state/pg/data/postgresql.conf"
      failure=0
      (cd /tmp && su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data -l /var/log/postgresql.log start") || failure=1
      if [ $failure = 0 ]; then
        wait_for_cf_postgres || failure=1
      fi
      if [ $failure = 0 ]; then
        # Started successfully, stop it again, the migration requires it to be not running.
        (cd /tmp && su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data -l /var/log/postgresql.log stop") || failure=1
        if [ $failure = 0 ]; then
          wait_for_cf_postgres_down || failure=1
        fi
        if [ $failure != 0 ]; then
          cf_console echo "Error: unable to shutdown postgresql server. Showing last of /var/log/postgresql.log for clues."
          cf_console tail /var/log/postgresql.log
          # this is a fatal error and so we exit instead of return
          # steps after this init_postgres_dir() function should not continue if we can't start/stop the server
          exit 1
        fi
        # Copy over the new config as well, user should take at look at it.
        cf_console echo "Installing the $pgconfig_type postgresql.conf file as $PREFIX/state/pg/data/postgresql.conf.new."
        cf_console echo "Please review it and update $PREFIX/state/pg/data/postgresql.conf accordingly."
        cp -a "$new_pgconfig_file" "$PREFIX/state/pg/data/postgresql.conf.new"
        chown cfpostgres "$PREFIX/state/pg/data/postgresql.conf.new"
      else
        # Failed to start, move the old file aside and use the new one.
        mv "$PREFIX/state/pg/data/postgresql.conf" "$PREFIX/state/pg/data/postgresql.conf.old"
        cf_console echo "Warning: failed to use the old postgresql.conf file, using the $pgconfig_type one."
        cf_console echo "Please review the $PREFIX/state/pg/data/postgresql.conf file and update it accordingly."
        cf_console echo "The original file was saved as $PREFIX/state/pg/data/postgresql.conf.old"
        cf_console echo "last 10 lines of /var/log/postgresql.log for determining cause of failure"
        cf_console tail /var/log/postgresql.log
        cp -a "$new_pgconfig_file" "$PREFIX/state/pg/data/postgresql.conf"
        chown cfpostgres "$PREFIX/state/pg/data/postgresql.conf"
      fi
    else
      # No user-modified file, just use the new recommended or default config (see generate_new_postgres_conf())
      cp -a "$new_pgconfig_file" "$PREFIX/state/pg/data/postgresql.conf"
      chown cfpostgres "$PREFIX/state/pg/data/postgresql.conf"
    fi

    # Preserve the recovery.conf file if it existed, it defines how this
    # PostgreSQL should behave as a slave (has to be done AFTER checking/writing
    # the postgresql.conf file above).
    if [ -f "$BACKUP_DIR/data/recovery.conf" ]; then
      cp -a "$BACKUP_DIR/data/recovery.conf" "$PREFIX/state/pg/data/recovery.conf"
      chown cfpostgres "$PREFIX/state/pg/data/recovery.conf"
    fi

    # Make sure the 'pg_arch' directory exists if it existed before the
    # upgrade. This directory is used in HA setups. Files from the directory
    # should be discarded so we can just recreate the directory if needed.
    if [ -d "$BACKUP_DIR/data/pg_arch" ]; then
      mkdir "$PREFIX/state/pg/data/pg_arch"
      chown cfpostgres:cfpostgres "$PREFIX/state/pg/data/pg_arch"
    fi
  fi
}

check_disk_space() {
  # checks disk space, prints warning if needed, and returns:
  # 0 (true) if it's enough disk space
  # 1 (false) if we need to abort due to low disk space
  megabytes_free="$(df -PBM $PREFIX | awk 'FNR==2{gsub(/[^0-9]/,"",$4);print $4}')"
  # note that if df or awk is not installed, or df has different format,
  # or something else, then $megabytes_free will be empty string.
  if [ -z "$megabytes_free" ]; then
    cf_console echo "Please check your disk space."
    return 0
  elif [ "$megabytes_free" -lt 100 ]; then
    cf_console echo "Please check your disk space."
    return 1
  else
    return 0
  fi
}

# Here we attempt three upgrade mechanisms, in this order:
# * using pg_upgrade utility
# * running two databases side-by-side (old and new),
#   and dumping from old one into new one via pipe
# * first dumping from old database into *.sql file,
#   and then importing it into new one

migrate_db_using_pg_upgrade() {
   su cfpostgres -c "$PREFIX/bin/pg_upgrade --old-bindir=$BACKUP_DIR/bin --new-bindir=$PREFIX/bin --old-datadir=$BACKUP_DIR/data --new-datadir=$PREFIX/state/pg/data"
}

migrate_db_using_pipe() {
  set +e
  (
    set -e
    # setting up: starting postgres servers and creating fifo
    su cfpostgres -c "LD_LIBRARY_PATH=$BACKUP_DIR/lib/ $BACKUP_DIR/bin/pg_ctl -w -D $BACKUP_DIR/data/ -o '-p 5433' -l /tmp/postgresql-old.log start"
    su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data/ -o '-p 5434' -l /tmp/postgresql-new.log start"
    su cfpostgres -c "mkfifo pg_stream"
    # dump from old database to pg_stream
    su cfpostgres -c "LD_LIBRARY_PATH=$BACKUP_DIR/lib/ $BACKUP_DIR/bin/pg_dumpall --clean --port=5433 >pg_stream" &
    dump_pid=$!
    # read into new database from pg_stream
    su cfpostgres -c "$PREFIX/bin/psql --port=5434 postgres <pg_stream" &
    restore_pid=$!
    # wait for processes to finish and save their results
    set +e
    wait $dump_pid
    dump_result=$?
    wait $restore_pid
    restore_result=$?
    set -e
    # analyze the results
    # return code 141 from pg_dumpall means that the process was killed by signal 13 (141=128+13), which is SIGPIPE -
    # i.e. downstream process was terminated and pipe was closed - hence, not an error in this process (probably)
    if [ $dump_result != 0 -a $dump_result != 141 ]; then
      cf_console echo "Error dumping from old database"
      return 1
    fi
    if [ $restore_result != 0 ]; then
      cf_console echo "Error restoring to new database"
      return 2
    fi
  )
  result=$?
  set -e
  # cleaning up: stopping servers and removing fifo
  su cfpostgres -c "LD_LIBRARY_PATH=$BACKUP_DIR/lib/ $BACKUP_DIR/bin/pg_ctl -w -D $BACKUP_DIR/data/ -o '-p 5433' stop"
  su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data/ -o '-p 5434' -l /tmp/postgresql-new.log stop"
  rm pg_stream # ok to do it as root
  return $result
}

migrate_db_using_dump_file() {
  test "$#" = 2 || exit 1
  new_pgconfig_file="$1"
  pgconfig_type="$2"
  set +e
  ( # wrap it in (...) so we could restore stuff if it fails
    set -e
    # restore old binaries, run pg_dumpall there, restore new binaries, run psql there, and hope we not run out of disk space
    cf_console echo "Restoring old database..."
    # move new binaries out of the way
    rm -rf "$PREFIX/state/pg/data"
    mkdir -p "$PREFIX/lib.new"
    mkdir -p "$PREFIX/share.new"
    mv "$PREFIX/bin" "$PREFIX/bin.new"
    on_files mv "$PREFIX/lib" "$PREFIX/lib.new"
    safe_mv "$PREFIX/lib" postgresql "$PREFIX/lib.new"
    safe_mv "$PREFIX/share" postgresql "$PREFIX/share.new"
    # restore old backup
    safe_cp "$BACKUP_DIR" data "$PREFIX/state/pg"
    safe_cp "$BACKUP_DIR" bin "$PREFIX"
    on_files cp "$BACKUP_DIR/lib" "$PREFIX/lib"
    safe_cp "$BACKUP_DIR/lib" postgresql "$PREFIX/lib"
    safe_cp "$BACKUP_DIR/share" postgresql "$PREFIX/share"
    cf_console echo "Dumping old database to SQL file..."
    # run pg_dumpall
    su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D '$PREFIX/state/pg/data/' -l /tmp/postgresql-old.log start"
    su cfpostgres -c "$PREFIX/bin/pg_dumpall --clean" >"$BACKUP_DIR/db_dump.sql"
  )
  dump_result=$?
  set -e
  # restore new binaries
  cf_console echo "Cleaning up..."
  set +e
  # Each of the following groups is set -e, so if, for example, `rm` fails,
  # `mv` will not be executed. All the groups are `set +e` on the outside,
  # so we'll do the next one if previous fails - we'll check their success
  # afterwards.
  su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D '$PREFIX/state/pg/data/' stop"
  ( set -e
    # rename "bin.new" to "bin" (if "bin.new" exists)
    test -d "$PREFIX/bin.new"
    rm -rf "$PREFIX/bin"
    mv "$PREFIX/bin.new" "$PREFIX/bin"
  )
  ( set -e
    # move "postgresql" from "lib.new" to "lib" (if it exists there)
    test -d "$PREFIX/lib.new/postgresql/"
    rm -rf "$PREFIX/lib/postgresql/"
    mv "$PREFIX/lib.new/postgresql/" "$PREFIX/lib"
  )
  ( set -e
    # move all files (no dirs) from "lib.new" to "lib" (if "lib.new" is not empty)
    ! test -z "$(ls -A "$PREFIX/lib.new")"
    on_files rm "$PREFIX/lib"
    on_files mv "$PREFIX/lib.new" "$PREFIX/lib"
  )
  ( set -e
    # move "postgresql" from "share.new" to "share" (if it exists there)
    test -d "$PREFIX/share.new/postgresql/"
    rm -rf "$PREFIX/share/postgresql/"
    mv "$PREFIX/share.new/postgresql/" "$PREFIX/share"
  )
  set -e
  # Check outcome of above commands
  set +e
  (
    # delete old backup
    rm -rf "$PREFIX/state/pg/data"
    # check that new binaries restored:
    # these dirs should be empty
    test ! -d "$PREFIX/lib.new/postgresql" || rmdir "$PREFIX/lib.new/postgresql"
    rmdir "$PREFIX/lib.new"
    rmdir "$PREFIX/share.new"
    # this dir should not exist
    test ! -d "$PREFIX/bin.new"
    # and there should be no server running
    ! su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D '$PREFIX/state/pg/data/' status" >/dev/null
  )
  restore_result=$?
  set -e
  # did pg_dumpall go well?
  if [ "$dump_result" != 0 -o "$DEBUG" = 3 ]; then
    cf_console echo "pg_dumpall failed."
    rm "$BACKUP_DIR/db_dump.sql"
    return 1
  fi
  # did new binaries restored correctly?
  if [ "$restore_result" != 0 -o "$DEBUG" = 5 ]; then
    cf_console echo "Failed restoring new binaries."
    cf_console echo "Your system might be in a borked state."
    cf_console echo "Please inspect CFEngine install log for failed commands."
    return 3
  fi
  # run import
  cf_console echo "Importing SQL file into new database..."
  init_postgres_dir "$new_pgconfig_file" "$pgconfig_type"
  su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data/ -l /tmp/postgresql-new.log start"
  if ! su cfpostgres -c "$PREFIX/bin/psql postgres" <"$BACKUP_DIR/db_dump.sql"; then
    restore_failed=1
  fi
  su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data/ -l /tmp/postgresql-new.log stop"
  if [ -n "$restore_failed" -o $DEBUG = 4 ]; then
    cf_console echo "Importing failed."
    return 2
  fi
  # migration succeeded
  rm "$BACKUP_DIR/db_dump.sql"
}

do_migration() {
  test "$#" = 2 || exit 1
  new_pgconfig_file="$1"
  pgconfig_type="$2"
  set +e
  (
    set -e
    # DEBUG variable controls which of migration methods fail:
    # 0 - do nothing special (usually pg_upgrade, which is first method, succeeds)
    # 1 - fail first method (so we get a chance to run second method, migration via pipe)
    # 2 - fail first two methods (so we get a chance to run third method, migration via dump)
    # 3 - fail first two methods, and third one on "dumping" stage
    #     (so we get a chance to see error message with instructions
    #      how to dump and import manually)
    # 4 - fail first two methods, and third one on "importing" stage
    #     (so we get a chance to see error message with instructions
    #      how to import existing dump file)
    # 5 - fail first two methods, and third one on "restoring" stage
    #     (so we get a chance to see error message about system in borked state)
    if [ -f $PREFIX/postgres-10-migration-test ]; then
      DEBUG="$(cat $PREFIX/postgres-10-migration-test)"
    else
      DEBUG=0
    fi
    cd /tmp
    cf_console echo "Migrating database using pg_upgrade utility..."
    cf_console echo
    if migrate_db_using_pg_upgrade && [ $DEBUG -lt 1 ]; then
      # Succeeded
      exit 0 # exits only from (...)
    fi
    cf_console echo "Migration using pg_upgrade failed."
    # skip ubuntu-16, debian-9 and debian-12 since there is an expected failure there
    # check for "/var/cfengine/state/pg/backup/bin/postgres" failed: cannot execute
    if { [ "$BUILT_ON_OS" = "debian" ] && [ "$BUILT_ON_OS_VERSION" = "9" ]; } || \
       { [ "$BUILT_ON_OS" = "debian" ] && [ "$BUILT_ON_OS_VERSION" = "12" ]; } || \
       { [ "$BUILT_ON_OS" = "ubuntu" ] && [ "$BUILT_ON_OS_VERSION" = "16" ]; }; then
      true # no-op
    else
      # here pg_upgrade probably said something like
      # Consult the last few lines of "/var/cfengine/state/pg/data/pg_upgrade_output.d/20230913T150025.959/log/pg_upgrade_server.log" for the probable cause of the failure.
      cf_console echo "Showing last lines of any related log files:"
      _daysearch=$(date +%Y%m%d)
      find "$PREFIX"/state/pg/data/pg_upgrade_output.d -name '*.log' | grep "$_daysearch" | cf_console xargs tail
    fi
    cf_console echo
    check_disk_space # will abort if low on disk space
    init_postgres_dir "$new_pgconfig_file" "$pgconfig_type"
    cf_console echo "Migrating database using dumpall | psql way..."
    if migrate_db_using_pipe && [ $DEBUG -lt 2 ]; then
      exit 0
    fi
    cf_console echo "Migration using dumpall | psql failed."
    cf_console echo
    check_disk_space
    cf_console echo "Migrating database using dumpall && psql way..."
    if migrate_db_using_dump_file "$new_pgconfig_file" "$pgconfig_type"; then
      exit 0
    fi
    # if migrate_db_using_dump_file failed, it will print why
    check_disk_space
    exit 1
  )
  result=$?
  set -e
  if [ "$result" = 0 ]; then
    cf_console echo "Migration done, cleaning up"
    # TODO: an option to preserve this directory
    rm -rf "$BACKUP_DIR"
    return 0
  fi
  cf_console echo
  cf_console echo "Migration failed. Backup is saved in $BACKUP_DIR."
  if [ -f "$BACKUP_DIR/db_dump.sql" ]; then
    DUMP_FILENAME="$BACKUP_DIR/db_dump.sql"
    cf_console echo "Plaintext dump of the database is in $DUMP_FILENAME file."
    cf_console echo "You can import it by running these commands as 'cfpostgres' user (cfengine3 service should be stopped):"
  else
    DUMP_FILENAME="/tmp/db_dump.sql"
    cf_console echo "Run these commands as 'cfpostgres' user to produce a plaintext dump of the database:"
    cf_console echo
    cf_console echo "LD_LIBRARY_PATH=$BACKUP_DIR/lib/ $BACKUP_DIR/bin/pg_ctl -w -D $BACKUP_DIR/data/ -l /tmp/postgresql-old.log start"
    cf_console echo "LD_LIBRARY_PATH=$BACKUP_DIR/lib/ $BACKUP_DIR/bin/pg_dumpall --clean >$DUMP_FILENAME"
    cf_console echo "LD_LIBRARY_PATH=$BACKUP_DIR/lib/ $BACKUP_DIR/bin/pg_ctl -w -D $BACKUP_DIR/data/ stop"
    cf_console echo
    cf_console echo "Then, you can import it using these commands (cfengine3 service should be stopped):"
  fi
  cf_console echo
  cf_console echo "rm -rf $PREFIX/state/pg/data/*"
  cf_console echo "$PREFIX/bin/initdb -D $PREFIX/state/pg/data"
  cf_console echo "cp $BACKUP_DIR/data/*.conf $PREFIX/state/pg/data"
  cf_console echo "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data/ -l /tmp/postgresql-new.log start"
  cf_console echo "$PREFIX/bin/psql postgres <$DUMP_FILENAME"
  cf_console echo "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data/ stop"
  cf_console echo
  cf_console echo "Alternatively, reinstall CFEngine Enterprise Policy Server version $(cat "$PREFIX/UPGRADED_FROM.txt"),"
  cf_console echo "and run these commands as 'root' to restore database (cfengine3 service should be stopped):"
  cf_console echo
  cf_console echo "rm -rf $PREFIX/state/pg/data"
  cf_console echo "mv $BACKUP_DIR/data $PREFIX/state/pg/data"
  cf_console echo
  cf_console echo "And now installation will proceed with clean (empty) database"
  init_postgres_dir "$new_pgconfig_file" "$pgconfig_type"
}

# make sure cfpostgres can access state/pg
mkdir -p "$PREFIX/state/pg"
chown root:cfpostgres "$PREFIX/state" "$PREFIX/state/pg"
chmod 0750 "$PREFIX/state" "$PREFIX/state/pg"

test -z "$BACKUP_DIR" && BACKUP_DIR=$PREFIX/state/pg/backup
if [ ! -f $PREFIX/state/pg/data/postgresql.conf ]; then
  new_pgconfig_file=`generate_new_postgres_conf`
  if [ `basename "$new_pgconfig_file"` = "postgresql.conf.cfengine" ]; then
    pgconfig_type="CFEngine recommended"
  else
    pgconfig_type="PostgreSQL default"
  fi
  init_postgres_dir "$new_pgconfig_file" "$pgconfig_type"
fi
if is_upgrade && [ -d "$BACKUP_DIR/data" ]; then
  do_migration "$new_pgconfig_file" "$pgconfig_type"
fi

(cd /tmp && su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data -l /var/log/postgresql.log start")

#make sure that server is up and listening
TRYNO=1
LISTENING=no
echo -n "pinging pgsql server"
set +e
while [ $TRYNO -le 10 ]
do
  echo -n .
  ALIVE=$(cd /tmp && su cfpostgres -c "$PREFIX/bin/psql -l 1>/dev/null 2>/dev/null")

  if [ $? -eq 0 ];then
    LISTENING=yes
    break
  fi

  sleep 1
  TRYNO=`expr $TRYNO + 1`
done
set -e
echo done

if [ "$LISTENING" = "no" ]
then
  cf_console echo "Could not create necessary database and users, make sure Postgres server is running.."
  # If upgrading from a version below 3.10 that has PostgreSQL.
  if is_upgrade && egrep '^3\.[6-9]\.' "$PREFIX/UPGRADED_FROM.txt" >/dev/null; then
    cf_console echo "Database migration also failed for the above reason. Backups are in $PREFIX/state/pg/*.sql.gz"
  fi
else
  (
    cd /tmp

    db_name_list=$(su cfpostgres -c "$PREFIX/bin/psql --list")
    for db_name in cfdb cfmp cfsettings; do
      if ! echo "$db_name_list" | grep ${db_name} >/dev/null; then
        su cfpostgres -c "$PREFIX/bin/createdb -E SQL_ASCII --lc-collate=C --lc-ctype=C -T template0 ${db_name}"
      fi
    done

    db_user_list=$(su cfpostgres -c "$PREFIX/bin/psql -d postgres -c '\du'")
    if ! echo "$db_user_list" | grep $MP_APACHE_USER >/dev/null; then
        su cfpostgres -c "$PREFIX/bin/createuser -S -D -R -w $MP_APACHE_USER"
    fi
    if ! echo "$db_user_list" | grep root >/dev/null; then
      su cfpostgres -c "$PREFIX/bin/createuser -d -s -w root"
    fi
  )

  # Create the cfengine mission portal postgres user
  (
    cd /tmp &&
      if ! su cfpostgres -c "$PREFIX/bin/psql  -d postgres -c '\du' | grep cfmppostgres >/dev/null"; then
        su cfpostgres -c "$PREFIX/bin/psql cfmp" < $PREFIX/share/GUI/phpcfenginenova/create_cfmppostgres_user.sql
      fi
  )

  # Ensure cfpostgres can read the sql files it will import. And that they are
  # restored to restrictive state after import ENT-2684
  chown cfpostgres $PREFIX/share/db/*.sql

  #create database for MISSION PORTAL
  (cd /tmp && su cfpostgres -c "$PREFIX/bin/psql cfmp" < $PREFIX/share/GUI/phpcfenginenova/pgschema.sql)
  (cd /tmp && su cfpostgres -c "$PREFIX/bin/psql cfmp" < $PREFIX/share/GUI/phpcfenginenova/ootb_import.sql)


  #create database for hub internal data
  (
    set -e
    cd /tmp
    chown cfpostgres "$PREFIX/share/db/schema_settings.sql" && su cfpostgres -c "$PREFIX/bin/psql cfsettings -f $PREFIX/share/db/schema_settings.sql" && chown root "$PREFIX/share/db/schema_settings.sql"
    chown cfpostgres "$PREFIX/share/db/ootb_settings.sql" && su cfpostgres -c "$PREFIX/bin/psql cfsettings -f $PREFIX/share/db/ootb_settings.sql" && chown root "$PREFIX/share/db/ootb_settings.sql"
    # cfdb schema relies on cfsettings already existing for a foreign data wrapper association for shared and personal host groups tables
    chown cfpostgres "$PREFIX/share/db/schema.sql" && su cfpostgres -c "$PREFIX/bin/psql cfdb -f $PREFIX/share/db/schema.sql" && chown root "$PREFIX/share/db/schema.sql"
    chown cfpostgres "$PREFIX/share/db/ootb_import.sql" && su cfpostgres -c "$PREFIX/bin/psql cfdb -f $PREFIX/share/db/ootb_import.sql" && chown root "$PREFIX/share/db/ootb_import.sql"
  )

  (
    cd /tmp
    su cfpostgres -c "$PREFIX/bin/psql cfdb" << EOF
\set ON_ERROR_STOP true
-- revoke create permission on public schema for cfdb database
REVOKE CREATE ON SCHEMA public FROM public;

-- grant permission for apache user to use the cfdb database
GRANT ALL ON DATABASE cfdb TO $MP_APACHE_USER;
GRANT SELECT, DELETE ON ALL TABLES IN SCHEMA PUBLIC TO $MP_APACHE_USER;
ALTER DEFAULT PRIVILEGES FOR ROLE root,cfpostgres IN SCHEMA PUBLIC GRANT SELECT ON TABLES TO PUBLIC;
EOF
   )

  (
    cd /tmp
    su cfpostgres -c "$PREFIX/bin/psql cfsettings" << EOF
-- grant permission for apache user to use the cfsettings database
GRANT ALL ON DATABASE cfsettings TO $MP_APACHE_USER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $MP_APACHE_USER;
ALTER DEFAULT PRIVILEGES FOR ROLE root,cfpostgres IN SCHEMA PUBLIC GRANT SELECT ON TABLES TO PUBLIC;
EOF

  )

fi

#
# Apache related
#
mkdir -p $PREFIX/config

# Fix Mission Portal application permissions ENT-3035
# Replication of https://github.com/cfengine/masterfiles/blob/8e8c648713d947ad9c2412584b238b8c8743130e/cfe_internal/enterprise/CFE_knowledge.cf
find $PREFIX/httpd/htdocs/ -type f ! -name '.htaccess' -exec chown -R root:$MP_APACHE_USER {} +
find $PREFIX/httpd/htdocs/ -type f ! -name '.htaccess' -exec chmod 0440 {} +

# Tmp
chown -R $MP_APACHE_USER:$MP_APACHE_USER $PREFIX/httpd/htdocs/public/tmp/
find $PREFIX/httpd/htdocs/public/tmp/ -type d -exec chmod 0770 {} +
find $PREFIX/httpd/htdocs/public/tmp/ -type f -exec chmod 0440 {} +

# logs (if any)
if [ -d $PREFIX/httpd/htdocs/logs/ ]; then
  find $PREFIX/httpd/htdocs/logs/ -type f -exec chown -R root:root {} +
  find $PREFIX/httpd/htdocs/logs/ -type f -exec chmod 0600 {} +
fi

# application
chown -R root:$MP_APACHE_USER $PREFIX/httpd/htdocs/application/
chmod -R ug=rX,o= $PREFIX/httpd/htdocs/application/ # 440 for files, 550 for dirs

# API dirs ENT-4250
# Note that this will include the 'api' dir itself
find $PREFIX/httpd/htdocs/api/ -type d ! -name 'static' -exec chown root:$MP_APACHE_USER {} +
find $PREFIX/httpd/htdocs/api/ -type d ! -name 'static' -exec chmod 0550 {} +

# API non-executable
find $PREFIX/httpd/htdocs/api/ -type f ! -name '*.sh' -exec chown -R root:$MP_APACHE_USER {} +
find $PREFIX/httpd/htdocs/api/ -type f ! -name '*.sh' -exec chmod 0440 {} +

# API executable
find $PREFIX/httpd/htdocs/api/ -type f -name '*.sh' -exec chown -R root:$MP_APACHE_USER {} +
find $PREFIX/httpd/htdocs/api/ -type f -name '*.sh' -exec chmod 0550 {} +

# API static non htaccess
find $PREFIX/httpd/htdocs/api/static -type f ! -name '.htaccess' -exec chown -R root:$MP_APACHE_USER {} +
find $PREFIX/httpd/htdocs/api/static -type f ! -name '.htaccess' -exec chmod 0440 {} +
find $PREFIX/httpd/htdocs/api/static -type f \( -name '.status' -o -name '.pid' -o -name '.abort' \) -exec chmod 0660 {} +

chown root:$MP_APACHE_USER $PREFIX/httpd/htdocs/api/static
chmod 0660 $PREFIX/httpd/htdocs/api/static

# HTTPD logs
find $PREFIX/httpd/logs/ -type f -exec chown root:root {} +
find $PREFIX/httpd/logs/ -type f -exec chmod 0600 {} +

# HTTPD application logs
find $PREFIX/httpd/logs/application/ -type f -exec chown $MP_APACHE_USER:$MP_APACHE_USER {} +
find $PREFIX/httpd/logs/application/ -type f -exec chmod 0600 {} +

# SSL
find $PREFIX/httpd/ssl/ -type f -exec chown -R root:root {} +
find $PREFIX/httpd/ssl/ -type f -exec chmod 0440 {} +

# htaccess TODO Remove this, htaccess unusued since 3.10+
find $PREFIX/httpd/htdocs -type f -name '.htaccess' -exec chown -R root:$MP_APACHE_USER {} +
find $PREFIX/httpd/htdocs -type f -name '.htaccess' -exec chmod 0440 {} +

# All dirs need to be group executable
find $PREFIX/httpd/htdocs -type d -exec chmod g+x {} +

# Restrict access to application source
find $PREFIX/share/GUI -type f -exec chmod 0400 {} +

##
# Ldap config
#

(cd "$PREFIX/httpd/htdocs/ldap"; sh scripts/post-install.sh)
# ENT-3645: `ldap/config/settings.ldap.php` must be writable by the webserver user or we will be unable to modify settings.
chown $MP_APACHE_USER:$MP_APACHE_USER -R $PREFIX/httpd/htdocs/ldap
chmod 0700 -R $PREFIX/httpd/htdocs/ldap/config

# changed permissions and owner of PHP and JS dependencies
chown root:$MP_APACHE_USER -R $PREFIX/httpd/htdocs/vendor
chown root:$MP_APACHE_USER -R $PREFIX/httpd/htdocs/public/scripts/node_modules

chmod -R ug=rX,o= $PREFIX/httpd/htdocs/vendor # 440 for files, 550 for dirs
chmod -R ug=rX,o= $PREFIX/httpd/htdocs/public/scripts/node_modules

##
# Start Apache server
#
$PREFIX/httpd/bin/apachectl start

#Mission portal
#

if ! is_upgrade; then
  true "Adding CFE_ROBOT user"
  ( set +x
    $PREFIX/httpd/php/bin/php $PREFIX/httpd/htdocs/public/index.php cli_tasks create_cfe_robot_user
  )
  true "Done adding user"
else
  true "Updating CFE_ROBOT password"
  ( set +x
    pwhash() {
        echo -n "$1" | "$PREFIX/bin/openssl" dgst -sha256 | awk '{print $2}'
    }
    CFE_ROBOT_PW="$(sed '/^cf_robot_password=/!d;s/.*=//' "$PREFIX/httpd/secrets.ini")"
    test -n "$CFE_ROBOT_PW" || { echo "ERROR reading cf_robot_password from secrets.ini"; exit 1; }
    CFE_ROBOT_PW_SALT=`pwgen 10`
    CFE_ROBOT_PW_HASH=`pwhash "$CFE_ROBOT_PW_SALT$CFE_ROBOT_PW"`

    # note that here we `echo "..." | psql` instead of `psql -c "..."` to avoid
    # leaking secrets in `ps -ef` output.
   echo "UPDATE users SET password = 'SHA=$CFE_ROBOT_PW_HASH', salt = '$CFE_ROBOT_PW_SALT' WHERE username = 'CFE_ROBOT'" | "$PREFIX/bin/psql" cfsettings
  )
  true "Done updating password"
fi

true "Updating MP password"
( set +x
  MP_PW="$(sed '/^mp_client_secret=/!d;s/.*=//' "$PREFIX/httpd/secrets.ini")"
  test -n "$MP_PW" || { echo "ERROR reading mp_client_secret from secrets.ini"; exit 1; }
  echo "UPDATE oauth_clients SET client_secret='$MP_PW' WHERE client_id='MP'" | "$PREFIX/bin/psql" cfsettings
)
true "Done updating password"

su $MP_APACHE_USER -c "$PREFIX/httpd/php/bin/php $PREFIX/httpd/htdocs/public/index.php cli_tasks migrate_ldap_settings https://localhost/ldap"

$PREFIX/httpd/php/bin/php $PREFIX/httpd/htdocs/public/index.php cli_tasks inventory_variables_refresh

# Shut down Apache and Postgres again, because we may need them to start through
# systemd later.
$PREFIX/httpd/bin/apachectl stop

# The above sometimes fails to stop the httpd processes properly. Let's make
# sure none are left behind.
httpds="$(ps -eo pid,cmd|awk '/\/var\/cfengine\/httpd\/bin\/httpd/ { print $1; }')"
if [ -n "$httpds" ]; then
  echo "$httpds" | xargs kill || true "kill failed, but moving on"
  sleep 1s
  httpds="$(ps -eo pid,cmd|awk '/\/var\/cfengine\/httpd\/bin\/httpd/ { print $1; }')"
  if [ -n "$httpds" ]; then
    echo "$httpds" | xargs kill -9 || true "kill -9 failed, but moving on"
  fi
fi

(cd /tmp && su cfpostgres -c "$PREFIX/bin/pg_ctl stop -D $PREFIX/state/pg/data -m smart" || su cfpostgres -c "$PREFIX/bin/pg_ctl stop -D $PREFIX/state/pg/data -m fast")

##
# ENT-3921: Make bin/runalerts.php executable
#
chmod 755 $PREFIX/bin/runalerts.php

# ENT-9711: Ensure $PREFIX/httpd/php/runalerts-stamp is created and has proper owner/permissions
# Have to be careful here because httpd/php/bin wants to be root:root
mkdir -p "$PREFIX/httpd/php/runalerts-stamp"
chown root:$MP_APACHE_USER $PREFIX/httpd/php
chown -R root:$MP_APACHE_USER $PREFIX/httpd/php/runalerts-stamp
chmod g+rX "$PREFIX/httpd/php"
chmod -R g+rX "$PREFIX/httpd/php/runalerts-stamp"

#
# Register CFEngine initscript, if not yet.
#
if ! is_upgrade; then
  if [ -x /bin/systemctl ]; then
    # Reload systemd config to pick up newly installed units
    /bin/systemctl daemon-reload > /dev/null 2>&1
    # Enable cfengine3 service (starts all the other services)
    # Enabling the service is OK to fail (can be masked, for example)
    /bin/systemctl enable cfengine3.service > /dev/null 2>&1 || true
  else
    case "`os_type`" in
      redhat)
        chkconfig --add cfengine3
        ;;
      debian)
        update-rc.d cfengine3 defaults
        ;;
    esac
  fi
fi

# Do not test for existence of $PREFIX/policy_server.dat, since we want the
# web service to start. The script should take care of detecting that we are
# not bootstrapped.
if ! [ -f "$PREFIX/UPGRADED_FROM.txt" ] || egrep '3\.([0-6]\.|7\.0)' "$PREFIX/UPGRADED_FROM.txt" > /dev/null; then
  # Versions <= 3.7.0 are unreliable in their daemon killing. Kill them one
  # more time now that we have upgraded.
  cf_console platform_service cfengine3 stop
fi

# Let's make sure all files and directories created above have correct SELinux
# labels. We do this while the database is stopped on purpose, restorecon caches its list of
# files up-front and the database often adds/removes files as it starts up, especially pg_internal.init
# files inside /var/cfengine/state/pg/data/base/<oid> directories. ENT-10429
if command -v restorecon >/dev/null; then
  restorecon -iR /var/cfengine /opt/cfengine
fi

if is_upgrade && [ -f "$PREFIX/UPGRADED_FROM_STATE.txt" ]; then
    cf_console restore_cfengine_state "$PREFIX/UPGRADED_FROM_STATE.txt"
    rm -f "$PREFIX/UPGRADED_FROM_STATE.txt"
else
    cf_console platform_service cfengine3 start
fi

rm -f "$PREFIX/UPGRADED_FROM.txt"

exit 0
