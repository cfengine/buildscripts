if [ -x /bin/systemctl ]; then
  # This is important in case any of the units have been replaced by the package
  # and we call them in the postinstall script.
  /bin/systemctl daemon-reload
fi

#
# Make sure the cfapache user has a home folder and populate it
#
MP_APACHE_USER=cfapache
if [ -d "$PREFIX/$MP_APACHE_USER" ];
then
	cf_console echo "cfapache folder already exists, deleting it"
	rm -rf $PREFIX/$MP_APACHE_USER
fi
/usr/sbin/usermod -d $PREFIX/$MP_APACHE_USER $MP_APACHE_USER
mkdir -p $PREFIX/$MP_APACHE_USER/.ssh
chown -R $MP_APACHE_USER:$MP_APACHE_USER $PREFIX/$MP_APACHE_USER
echo "Host *
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null" >> $PREFIX/$MP_APACHE_USER/.ssh/config

#
# Generate a host key
#
if [ ! -f $PREFIX/ppkeys/localhost.priv ]; then
    $PREFIX/bin/cf-key >/dev/null || :
fi

if [ ! -f $PREFIX/masterfiles/promises.cf ]; then
    /bin/cp -R $PREFIX/share/NovaBase/masterfiles $PREFIX/
    touch $PREFIX/masterfiles/cf_promises_validated
    find $PREFIX/masterfiles -type d -exec chmod 700 {} \;
    find $PREFIX/masterfiles -type f -exec chmod 600 {} \;
fi

#
# Copy the stock package modules for the new installations
#
(
  if ! [ -d $PREFIX/modules/packages ]; then
    mkdir -p $PREFIX/modules/packages
  fi
  if cd $PREFIX/share/NovaBase/modules/packages; then
    for module in *; do
      if ! [ -f $PREFIX/modules/packages/$module ]; then
        cp $module $PREFIX/modules/packages
      fi
    done
  fi
)

if [ -f $PREFIX/lib/php/mcrypt.so ]; then
  /bin/rm -f $PREFIX/lib/php/mcrypt.*
fi

if [ -f $PREFIX/lib/php/curl.so ]; then
  /bin/rm -f $PREFIX/lib/php/curl.*
fi

# Hack around ENT-3520 In 3.12.0 we moved to php 7, this removes the old php
if [ -e "$PREFIX/httpd/modules/libphp5.so" ]; then
    rm "$PREFIX/httpd/modules/libphp5.so"
fi

#
#Copy necessary Files and permissions
#
cp $PREFIX/lib/php/*.ini $PREFIX/httpd/php/lib
cp $PREFIX/lib/php/*.so $PREFIX/httpd/php/lib/php/extensions/no-debug-non-zts-20170718

#Change keys in files
if [ -f $PREFIX/CF_CLIENT_SECRET_KEY.tmp ]; then
  UUID=$(tr -d '\n\r' < $PREFIX/CF_CLIENT_SECRET_KEY.tmp)
else
  UUID=$(dd if=/dev/urandom bs=1024 count=1 2>/dev/null | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
fi
sed -i s/CFE_SESSION_KEY/"$UUID"/ $PREFIX/share/GUI/application/config/config.php
sed -i s/CFE_CLIENT_SECRET_KEY/"$UUID"/ $PREFIX/share/GUI/application/config/appsettings.php
sed -i s/CFE_CLIENT_SECRET_KEY/"$UUID"/ $PREFIX/share/db/ootb_settings.sql
sed -i s/LDAP_API_SECRET_KEY/"$UUID"/ $PREFIX/share/GUI/application/config/appsettings.php
sed -i s/LDAP_API_SECRET_KEY/"$UUID"/ $PREFIX/share/GUI/ldap/config/settings.php
sed -i /LDAP_API_SECRET_KEY/s/\'\'/"'$UUID'"/ $PREFIX/share/GUI/api/config/config.php

cp -r $PREFIX/share/GUI/* $PREFIX/httpd/htdocs

# If old files were moved aside during upgrade, we should move them back so that
# rpm can do its cleanup procedures. But avoid overwriting new files with the
# old ones (hence cp -n).
if [ -d $PREFIX/share/GUI_old ]; then
    cp -rn $PREFIX/share/GUI_old/* $PREFIX/share/GUI/
    rm -rf $PREFIX/share/GUI_old/
fi

mkdir -p $PREFIX/httpd/htdocs/tmp
mv $PREFIX/httpd/htdocs/Apache-htaccess $PREFIX/httpd/htdocs/.htaccess
chmod 755 $PREFIX/httpd
chown -R $MP_APACHE_USER:$MP_APACHE_USER $PREFIX/httpd/htdocs
chmod a+rx $PREFIX/httpd/htdocs/api/dc-scripts/*.sh
chmod a+rx $PREFIX/httpd/htdocs/api/dc-scripts/*.pl

# plugins directory, empty by default
mkdir -p ${PREFIX}/plugins
chown -R root:root ${PREFIX}/plugins
chmod 700 ${PREFIX}/plugins

#these directories should be write able by apache
chown root:$MP_APACHE_USER $PREFIX/httpd/logs
chmod 775 $PREFIX/httpd/logs
chown $MP_APACHE_USER:$MP_APACHE_USER $PREFIX/httpd/htdocs/tmp
chown -R $MP_APACHE_USER:$MP_APACHE_USER $PREFIX/httpd/htdocs/api/static

if [ -d "$PREFIX/httpd/htdocs/application/logs" ]; then
    mv "$PREFIX/httpd/htdocs/application/logs" "$PREFIX/httpd/logs/application"
fi
if [ ! -d "$PREFIX/httpd/logs/application" ]; then
    mkdir -p "$PREFIX/httpd/logs/application"
fi
chown $MP_APACHE_USER:$MP_APACHE_USER $PREFIX/httpd/logs/application

#
# Do all the prelimenary Design Center setup only on the first install of cfengine package
#
if ! is_upgrade; then
  # This folder is required for Design Center and Mission Portal to talk to each other
  DCWORKDIR=/opt/cfengine
  $PREFIX/design-center/bin/cf-sketch --inputs=$PREFIX/design-center --installsource=$PREFIX/share/NovaBase/sketches/cfsketches.json --install-all
  mkdir -p $DCWORKDIR/userworkdir/admin/.ssh
  mkdir -p $DCWORKDIR/stage_backup
  mkdir -p $DCWORKDIR/dc-scripts
  mkdir -p $DCWORKDIR/masterfiles_staging
  mkdir -p $DCWORKDIR/masterfiles.git

  touch $DCWORKDIR/userworkdir/admin/.ssh/id_rsa.pvt
  chmod 600 $DCWORKDIR/userworkdir/admin/.ssh/id_rsa.pvt

  cat > $DCWORKDIR/dc-scripts/params.sh <<EOHIPPUS
#!/bin/bash
ROOT="$DCWORKDIR/masterfiles_staging"
GIT_URL="$DCWORKDIR/masterfiles.git"
GIT_BRANCH="master"
GIT_WORKING_BRANCH="CF_WORKING_BRANCH"
GIT_EMAIL="default-committer@your-cfe-site.com"
GIT_AUTHOR="Default Committer"
PKEY="$DCWORKDIR/userworkdir/admin/.ssh/id_rsa.pvt"
SCRIPT_DIR="$PREFIX/httpd/htdocs/api/dc-scripts"
VCS_TYPE="GIT"
export PATH="\${PATH}:$PREFIX/bin"
export PKEY="\${PKEY}"
export GIT_SSH="\${SCRIPT_DIR}/ssh-wrapper.sh"
EOHIPPUS

  # The runfile key in the below JSON is not needed anymore, all the
  # values in it are OK by default, especially the runfile location,
  # which is the first element of repolist plus `/meta/api-runfile.cf`.

  cat > $DCWORKDIR/userworkdir/admin/api-config.json <<EOHIPPUS
{
  "log":"STDERR",
  "log_level":"3",
  "repolist":["sketches"],
  "recognized_sources":["$PREFIX/design-center/sketches"],
  "constdata":"$PREFIX/design-center/tools/cf-sketch/constdata.conf",
  "vardata":"$DCWORKDIR/userworkdir/admin/masterfiles/sketches/meta/vardata.conf",
  "runfile": {"location":"$DCWORKDIR/userworkdir/admin/masterfiles/sketches/meta/api-runfile.cf"}
}
EOHIPPUS

  chmod 700 $DCWORKDIR/dc-scripts/params.sh

  chown -R $MP_APACHE_USER:$MP_APACHE_USER $DCWORKDIR/userworkdir
  chown -R $MP_APACHE_USER:$MP_APACHE_USER $DCWORKDIR/dc-scripts
  chown -R $MP_APACHE_USER:$MP_APACHE_USER $DCWORKDIR/stage_backup
  chown -R $MP_APACHE_USER:$MP_APACHE_USER $DCWORKDIR/masterfiles.git

  chown $MP_APACHE_USER:$MP_APACHE_USER $DCWORKDIR
  cp -R $PREFIX/masterfiles/* $DCWORKDIR/masterfiles_staging
  chown -R $MP_APACHE_USER:$MP_APACHE_USER $DCWORKDIR/masterfiles_staging

  chmod 700 $DCWORKDIR/stage_backup
  chmod -R 700 $DCWORKDIR/userworkdir

  GIT=$PREFIX/bin/git
  (cd $DCWORKDIR/masterfiles_staging && su $MP_APACHE_USER -c "$GIT init")
  (cd $DCWORKDIR/masterfiles_staging && su $MP_APACHE_USER -c "$GIT config user.email admin@cfengine.com")
  (cd $DCWORKDIR/masterfiles_staging && su $MP_APACHE_USER -c "$GIT config user.name admin")
  (cd $DCWORKDIR/masterfiles_staging && su $MP_APACHE_USER -c "(echo '/cf_promises_*'; echo '.*.sw[po]'; echo '*~'; echo '\\#*#') >.gitignore")
  (cd $DCWORKDIR/masterfiles_staging && su $MP_APACHE_USER -c "$GIT add .gitignore")
  (cd $DCWORKDIR/masterfiles_staging && su $MP_APACHE_USER -c "$GIT commit -m 'Ignore cf_promise_*'")
  (cd $DCWORKDIR/masterfiles_staging && su $MP_APACHE_USER -c "$GIT add *")
  (cd $DCWORKDIR/masterfiles_staging && su $MP_APACHE_USER -c "$GIT commit -m 'Initial pristine masterfiles'")

  (cd $DCWORKDIR/ && su $MP_APACHE_USER -c "$GIT clone --no-hardlinks --bare $DCWORKDIR/masterfiles_staging $DCWORKDIR/masterfiles.git")
  find "$DCWORKDIR/masterfiles.git" -type d -exec chmod 700 {} \;
  find "$DCWORKDIR/masterfiles.git" -type f -exec chmod 600 {} \;

  (cd $DCWORKDIR/masterfiles_staging && su $MP_APACHE_USER -c "$GIT branch CF_WORKING_BRANCH")
  (cd $DCWORKDIR/masterfiles_staging && su $MP_APACHE_USER -c "$GIT remote rm origin")
  (cd $DCWORKDIR/masterfiles_staging && su $MP_APACHE_USER -c "$GIT remote add origin $DCWORKDIR/masterfiles.git")

  if [ ! -f /usr/bin/curl ]; then
    ln -sf $PREFIX/bin/curl /usr/bin/curl
  fi
fi

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
  MAN=`cat "$MAN_CONFIG"| grep cfengine`
  if [ -z "$MAN" ]; then
    echo "$MAN_PATH     $PREFIX/share/man" >> "$MAN_CONFIG"
  fi
fi

for i in cf-agent cf-promises cf-key cf-execd cf-serverd cf-monitord cf-runagent cf-hub cf-net;
do
  if [ -f $PREFIX/bin/$i -a -d /usr/local/sbin ]; then
    ln -sf $PREFIX/bin/$i /usr/local/sbin/$i || true
  fi
  if [ -f /usr/share/man/man8/$i.8.gz ]; then
    rm -f /usr/share/man/man8/$i.8.gz
  fi
  $PREFIX/bin/$i -M > /usr/share/man/man8/$i.8 && gzip /usr/share/man/man8/$i.8
done

#
# Generate a certificate for Mission Portal
# The certificate will be named $(hostname -f).cert and the corresponding key should be named $(hostname -f).key.
#
CFENGINE_MP_DEFAULT_CERT_LOCATION="$PREFIX/httpd/ssl/certs"
CFENGINE_MP_DEFAULT_CERT_LINK_LOCATION="$PREFIX/ssl"
CFENGINE_MP_DEFAULT_KEY_LOCATION="$PREFIX/httpd/ssl/private"
CFENGINE_MP_DEFAULT_CSR_LOCATION="$PREFIX/httpd/ssl/csr"
CFENGINE_OPENSSL="$PREFIX/bin/openssl"
mkdir -p $CFENGINE_MP_DEFAULT_CERT_LOCATION
mkdir -p $CFENGINE_MP_DEFAULT_KEY_LOCATION
mkdir -p $CFENGINE_MP_DEFAULT_CSR_LOCATION
CFENGINE_LOCALHOST=$(hostname -f)
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
  ${CFENGINE_OPENSSL} req -utf8 -sha256 -nodes -new -subj "/CN=$CFENGINE_LOCALHOST" -key ${CFENGINE_MP_KEY} -out ${CFENGINE_MP_CSR} -config ${PREFIX}/ssl/openssl.cnf

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

generate_new_postgres_conf() {
  # Generating a new postgresql.conf if enough total memory is present
  #
  # If total memory is lower than 3GB, we use the default pgsql conf file
  # If total memory is beyond 64GB, we use a shared_buffers of 16G
  # Otherwise, we use a shared_buffers equal to 25% of total memory
  total=`cat /proc/meminfo |grep "^MemTotal:.*[0-9]\+ kB"|awk '{print $2}'`

  echo "$total" | grep -q '^[0-9]\+$'
  if [ $? -ne 0 ] ;then
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

#POSTGRES RELATED
BACKUP_DIR=$PREFIX/backup-before-postgres10-migration
if [ ! -d $PREFIX/state/pg/data ]; then
  mkdir -p $PREFIX/state/pg/data
  chown -R cfpostgres $PREFIX/state/pg
  # Note: postgres expects $PWD to be writeable, so all postgres commands
  # should be executed from cfpostgres-writeable directory.
  # /tmp is such directory on most cases
  (cd /tmp && su cfpostgres -c "$PREFIX/bin/initdb -D $PREFIX/state/pg/data")
  touch /var/log/postgresql.log
  chown cfpostgres /var/log/postgresql.log

  new_pgconfig_file=`generate_new_postgres_conf`
  if [ `basename "$new_pgconfig_file"` = "postgresql.conf.cfengine" ]; then
    pgconfig_type="CFEngine recommended"
  else
    pgconfig_type="PostgreSQL default"
  fi

  if ! is_upgrade; then
    # Not an upgrade, just use the recommended or default file (see generate_new_postgres_conf())
    cp -a "$new_pgconfig_file" $PREFIX/state/pg/data/postgresql.conf
    chown cfpostgres $PREFIX/state/pg/data/postgresql.conf
  else
    # Always use the original pg_hba.conf file, it defines access control to PostgreSQL
    cp -a "$BACKUP_DIR/data/pg_hba.conf" "$PREFIX/state/pg/data/pg_hba.conf"
    chown cfpostgres "$PREFIX/state/pg/data/pg_hba.conf"

    # Determine which postgresql.conf file to use and put it in the right place.
    if [ -f "$BACKUP_DIR/data/postgresql.conf.modified" ]; then
      # User-modified file from the previous old version of CFEngine exists, try to use it.
      cp -a "$BACKUP_DIR/data/postgresql.conf.modified" "$PREFIX/state/pg/data/postgresql.conf"
      (cd /tmp && su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data -l /var/log/postgresql.log start")
      if [ $? = 0 ]; then
        # Started successfully, stop it again, the migration requires it to be not running.
        (cd /tmp && su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data -l /var/log/postgresql.log stop")

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
  fi
fi

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
  (cd /tmp
   su cfpostgres -c "$PREFIX/bin/pg_upgrade --old-bindir=$BACKUP_DIR/bin --new-bindir=$PREFIX/bin --old-datadir=$BACKUP_DIR/data --new-datadir=$PREFIX/state/pg/data"
  )
  result=$?
  return $result
}

migrate_db_using_pipe() {
  (cd /tmp
    # setting up: starting postgres servers and creating fifo
    su cfpostgres -c "LD_LIBRARY_PATH=$BACKUP_DIR/lib/ $BACKUP_DIR/bin/pg_ctl -w -D $BACKUP_DIR/data/ -o '-p 5433' -l /tmp/postgresql-old.log start"
    rm -rf $PREFIX/state/pg/data/*
    su cfpostgres -c "$PREFIX/bin/initdb -D $PREFIX/state/pg/data"
    su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data/ -o '-p 5434' -l /tmp/postgresql-new.log start"
    su cfpostgres -c "mkfifo pg_stream"
    # dump from old database to pg_stream
    su cfpostgres -c "LD_LIBRARY_PATH=$BACKUP_DIR/lib/ $BACKUP_DIR/bin/pg_dumpall --clean --port=5433 >pg_stream" &
    dump_pid=$!
    # read into new database from pg_stream
    su cfpostgres -c "$PREFIX/bin/psql --port=5434 postgres <pg_stream" &
    restore_pid=$!
    # wait for processes to finish and save their results
    wait $dump_pid
    dump_result=$?
    wait $restore_pid
    restore_result=$?
    # cleaning up: stopping servers and removing fifo
    su cfpostgres -c "LD_LIBRARY_PATH=$BACKUP_DIR/lib/ $BACKUP_DIR/bin/pg_ctl -w -D $BACKUP_DIR/data/ -o '-p 5433' stop"
    su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data/ -o '-p 5434' -l /tmp/postgresql-new.log stop"
    rm pg_stream # ok to do it as root
    # analyze the results
    # return code 141 from pg_dumpall means that the process was killed by signal 13 (141=128+13), which is SIGPIPE -
    # i.e. downstream process was terminated and pipe was closed - hence, not an error in this process (probably)
    if [ $dump_result != 0 -a $dump_result != 141 ]; then
      cf_console echo "Error dumping from old database"
      exit 1 # this exits only from subshell, i.e. (...) block
    fi
    if [ $restore_result != 0 ]; then
      cf_console echo "Error restoring to new database"
      exit 2
    fi
  )
  result=$?
  return $result
}

migrate_db_using_dump_file() {
  (cd /tmp
    # restore old binaries, run pg_dumpall there, restore new binaries, run psql there, and hope we not run out of disk space
    cf_console echo "Restoring old database..."
    # move new binaries out of the way
    rm -rf "$PREFIX/state/pg/data"
    mkdir -p "$BACKUP_DIR.new/lib"
    mkdir -p "$BACKUP_DIR.new/share"
    mv "$PREFIX/bin" "$BACKUP_DIR.new"
    cp -l "$PREFIX/lib"/* "$BACKUP_DIR.new/lib"
    rm "$PREFIX/lib"/*
    mv "$PREFIX/lib/postgresql/" "$BACKUP_DIR.new/lib"
    mv "$PREFIX/share/postgresql/" "$BACKUP_DIR.new/share"
    # restore old backup
    cp -al "$BACKUP_DIR/data" "$PREFIX/state/pg"
    cp -al "$BACKUP_DIR/bin" "$PREFIX"
    cp -l "$BACKUP_DIR/lib"/* "$PREFIX/lib"
    cp -al "$BACKUP_DIR/lib/postgresql/" "$PREFIX/lib"
    cp -al "$BACKUP_DIR/share/postgresql/" "$PREFIX/share"
    cf_console echo "Dumping old database to SQL file..."
    # run pg_dumpall
    su cfpostgres -c "LD_LIBRARY_PATH=$BACKUP_DIR/lib/ $BACKUP_DIR/bin/pg_ctl -w -D $BACKUP_DIR/data/ -o '-p 5433' -l /tmp/postgresql-old.log start"
    su cfpostgres -c "LD_LIBRARY_PATH=$BACKUP_DIR/lib/ $BACKUP_DIR/bin/pg_dumpall --clean --port=5433" >$BACKUP_DIR/db_dump.sql
    dump_result=$?
    su cfpostgres -c "LD_LIBRARY_PATH=$BACKUP_DIR/lib/ $BACKUP_DIR/bin/pg_ctl -w -D $BACKUP_DIR/data/ -o '-p 5433' stop"
    # restore new binaries
    rm -rf "$PREFIX/bin"
    rm -f "$PREFIX/lib"/*
    rm -rf "$PREFIX/lib/postgresql/"
    rm -rf "$PREFIX/share/postgresql/"
    rm -rf "$PREFIX/state/pg/data"
    mv "$BACKUP_DIR.new/bin" "$PREFIX"
    mv "$BACKUP_DIR.new/lib"/* "$PREFIX/lib"
    mv "$BACKUP_DIR.new/share/postgresql/" "$PREFIX/share"
    rm -rf "$BACKUP_DIR.new"
    # did pg_dumpall went well?
    if [ $dump_result != 0 -o $DEBUG = 3 ]; then
      cf_console echo "Dumping failed."
      rm $BACKUP_DIR/db_dump.sql
      exit 1
    fi
    # run psql there
    cf_console echo "Importing SQL file into new database..."
    rm -rf $PREFIX/state/pg/data/*
    su cfpostgres -c "$PREFIX/bin/initdb -D $PREFIX/state/pg/data"
    su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data/ -o '-p 5434' -l /tmp/postgresql-new.log start"
    su cfpostgres -c "$PREFIX/bin/psql --port=5434 postgres" <$BACKUP_DIR/db_dump.sql
    restore_result=$?
    su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data/ -o '-p 5434' -l /tmp/postgresql-new.log stop"
    if [ $restore_result != 0 -o $DEBUG = 4 ]; then
      cf_console echo "Importing failed."
      exit 2
    fi
  )
  result=$?
  return $result
}

if is_upgrade && [ -d "$BACKUP_DIR" ]; then
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
  if [ -f $PREFIX/postgres-10-migration-test ]; then
    DEBUG="$(cat $PREFIX/postgres-10-migration-test)"
  else
    DEBUG=0
  fi
  export DEBUG
  MIGRATED=0 # flag that migration succeded
  cf_console echo "Migrating database using pg_upgrade utility..."
  cf_console echo
  migrate_db_using_pg_upgrade
  result=$?
  if [ $result = 0 -a $DEBUG -lt 1 ]; then
    MIGRATED=1
  else
    cf_console echo "Migration using pg_upgrade failed."
    cf_console echo
    if check_disk_space; then
      cf_console echo "Migrating database using dumpall | psql way..."
      migrate_db_using_pipe
      result=$?
      if [ $result = 0 -a $DEBUG -lt 2 ]; then
        MIGRATED=1
      else
        cf_console echo "Migration using dumpall | psql failed."
        cf_console echo
        if check_disk_space; then
          cf_console echo "Migrating database using dumpall && psql way..."
          migrate_db_using_dump_file
          result=$?
          if [ $result = 0 ]; then
            MIGRATED=1
	  else
            check_disk_space
          fi # $result of migrate_db_using_dump_file = 0
        fi # check_disk_space after Migration using dumpall | psql failed.
      fi # $result of migrate_db_using_pipe = 0
    fi # check_disk_space after Migration using pg_upgrade failed.
  fi # $result of migrate_db_using_pg_upgrade = 0
  if [ $MIGRATED = 1 ]; then
    cf_console echo "Migration done, cleaning up"
    rm -rf $BACKUP_DIR
  else
    cf_console echo
    cf_console echo "Migration failed. Backup is saved in $BACKUP_DIR."
    if [ -f $BACKUP_DIR/db_dump.sql ]; then
      DUMP_FILENAME="$BACKUP_DIR/db_dump.sql"
      cf_console echo "Plaintext dump of the database is in $DUMP_FILENAME file."
      cf_console echo "You can import it by running these commands as 'cfpostgres' user (cfengine3 service should be stopped):"
    else
      DUMP_FILENAME="/tmp/db_dump.sql"
      cf_console echo "Run these commands as 'cfpostgres' user to produce a plaintext dump of the database:"
      cf_console echo
      cf_console echo "LD_LIBRARY_PATH=$BACKUP_DIR/lib/ $BACKUP_DIR/bin/pg_ctl -w -D $BACKUP_DIR/data/ -o '-p 5433' -l /tmp/postgresql-old.log start"
      cf_console echo "LD_LIBRARY_PATH=$BACKUP_DIR/lib/ $BACKUP_DIR/bin/pg_dumpall --clean --port=5433 >$DUMP_FILENAME"
      cf_console echo "LD_LIBRARY_PATH=$BACKUP_DIR/lib/ $BACKUP_DIR/bin/pg_ctl -w -D $BACKUP_DIR/data/ -o '-p 5433' stop"
      cf_console echo
      cf_console echo "Then, you can import it using these commands (cfengine3 service should be stopped):"
    fi
    cf_console echo
    cf_console echo "rm -rf $PREFIX/state/pg/data/*"
    cf_console echo "$PREFIX/bin/initdb -D $PREFIX/state/pg/data"
    cf_console echo "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data/ -o '-p 5434' -l /tmp/postgresql-new.log start"
    cf_console echo "$PREFIX/bin/psql --port=5434 postgres <$DUMP_FILENAME"
    cf_console echo "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data/ -o '-p 5434' -l /tmp/postgresql-new.log stop"
    cf_console echo
    cf_console echo "Alternatively, reinstall CFEngine Enterprise Policy Server version $(cat "$PREFIX/UPGRADED_FROM.txt"),"
    cf_console echo "and run these commands as 'root' to restore database (cfengine3 service should be stopped):"
    cf_console echo
    cf_console echo "rm -rf $PREFIX/state/pg/data"
    cf_console echo "mv $BACKUP_DIR/data $PREFIX/state/pg/data"
    cf_console echo
    cf_console echo "And now installation will proceed with clean (empty) database"
    (cd /tmp && su cfpostgres -c "$PREFIX/bin/initdb -D $PREFIX/state/pg/data")
  fi
fi

(cd /tmp && su cfpostgres -c "$PREFIX/bin/pg_ctl -w -D $PREFIX/state/pg/data -l /var/log/postgresql.log start")

#make sure that server is up and listening
TRYNO=1
LISTENING=no
echo -n "pinging pgsql server"
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
echo done

if [ "$LISTENING" = "no" ]
then
  cf_console echo "Could not create necessary database and users, make sure Postgres server is running.."
  # If upgrading from a version below 3.10 that has PostgreSQL.
  if is_upgrade && egrep '^3\.[6-9]\.' "$PREFIX/UPGRADED_FROM.txt" >/dev/null; then
    cf_console echo "Database migration also failed for the above reason. Backups are in $PREFIX/state/pg/*.sql.gz"
  fi
else
  (cd /tmp && su cfpostgres -c "$PREFIX/bin/createdb -E SQL_ASCII --lc-collate=C --lc-ctype=C -T template0 cfdb")
  (cd /tmp && su cfpostgres -c "$PREFIX/bin/createuser -S -D -R -w $MP_APACHE_USER")
  (cd /tmp && su cfpostgres -c "$PREFIX/bin/createuser -d -a -w root")
  (cd /tmp && su cfpostgres -c "$PREFIX/bin/createdb -E SQL_ASCII --lc-collate=C --lc-ctype=C -T template0 cfmp")
  (cd /tmp && su cfpostgres -c "$PREFIX/bin/createdb -E SQL_ASCII --lc-collate=C --lc-ctype=C -T template0 cfsettings")

  # Create the cfengine mission portal postgres user
  (cd /tmp && su cfpostgres -c "$PREFIX/bin/psql cfmp" < $PREFIX/share/GUI/phpcfenginenova/create_cfmppostgres_user.sql)

  # Ensure cfpostgres can read the sql files it will import. And that they are
  # restored to restrictive state after import ENT-2684
  (chown cfpostgres "$PREFIX/share/db/*.sql")
  (cd /tmp && chown cfpostgres "$PREFIX/share/db/schema.sql" && su cfpostgres -c "$PREFIX/bin/psql cfdb -f $PREFIX/share/db/schema.sql" && chown root "$PREFIX/share/db/schema.sql")

  #create database for MISSION PORTAL
  (cd /tmp && su cfpostgres -c "$PREFIX/bin/psql cfmp" < $PREFIX/share/GUI/phpcfenginenova/pgschema.sql)
  (cd /tmp && su cfpostgres -c "$PREFIX/bin/psql cfmp" < $PREFIX/share/GUI/phpcfenginenova/ootb_import.sql)


  #create database for hub internal data
  (cd /tmp && chown cfpostgres "$PREFIX/share/db/schema_settings.sql" && su cfpostgres -c "$PREFIX/bin/psql cfsettings -f $PREFIX/share/db/schema_settings.sql" && chown root "$PREFIX/share/db/schema_settings.sql")
  (cd /tmp && chown cfpostgres "$PREFIX/share/db/ootb_settings.sql" && su cfpostgres -c "$PREFIX/bin/psql cfsettings -f $PREFIX/share/db/ootb_settings.sql" && chown root "$PREFIX/share/db/ootb_settings.sql")
  (cd /tmp && chown cfpostgres "$PREFIX/share/db/ootb_import.sql" && su cfpostgres -c "$PREFIX/bin/psql cfdb -f $PREFIX/share/db/ootb_import.sql" && chown root "$PREFIX/share/db/ootb_import.sql")

  #revoke create permission on public schema for cfdb database
  (cd /tmp && su cfpostgres -c "$PREFIX/bin/psql cfdb") << EOF
    REVOKE CREATE ON SCHEMA public FROM public;
EOF

  #grant permission for apache user to use the cfdb database
  (cd /tmp && su cfpostgres -c "$PREFIX/bin/psql cfdb") << EOF
    GRANT ALL ON DATABASE cfdb TO $MP_APACHE_USER;
EOF

  (cd /tmp && su cfpostgres -c "$PREFIX/bin/psql cfdb") << EOF
    GRANT SELECT, DELETE ON ALL TABLES IN SCHEMA PUBLIC TO $MP_APACHE_USER;
EOF

  (cd /tmp && su cfpostgres -c "$PREFIX/bin/psql cfdb") << EOF
    ALTER DEFAULT PRIVILEGES FOR ROLE root,cfpostgres IN SCHEMA PUBLIC GRANT SELECT ON TABLES TO PUBLIC;
EOF

  #grant permission for apache user to use the cfsettings database
  (cd /tmp && su cfpostgres -c "$PREFIX/bin/psql cfsettings") << EOF
    GRANT ALL ON DATABASE cfsettings TO $MP_APACHE_USER;
EOF

  (cd /tmp && su cfpostgres -c "$PREFIX/bin/psql cfsettings") << EOF
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $MP_APACHE_USER;
EOF

  (cd /tmp && su cfpostgres -c "$PREFIX/bin/psql cfsettings") << EOF
    ALTER DEFAULT PRIVILEGES FOR ROLE root,cfpostgres IN SCHEMA PUBLIC GRANT SELECT ON TABLES TO PUBLIC;
EOF

fi

#
# Apache related
#
mkdir -p $PREFIX/config

# Fix Mission Portal application permissions ENT-3035
# Replication of https://github.com/cfengine/masterfiles/blob/8e8c648713d947ad9c2412584b238b8c8743130e/cfe_internal/enterprise/CFE_knowledge.cf
find $PREFIX/httpd/htdocs/ -type f ! -name '.htaccess' -exec chown -R root:$MP_APACHE_USER {} +
find $PREFIX/httpd/htdocs/ -type f ! -name '.htaccess' -exec chmod 0440 {} +

# Scripts
find $PREFIX/httpd/htdocs/scripts/ -type f -exec chown -R root:$MP_APACHE_USER {} +
find $PREFIX/httpd/htdocs/scripts/ -type f -exec chmod 0440 {} +

# Tmp
find $PREFIX/httpd/htdocs/tmp/ -type f -exec chown -R root:$MP_APACHE_USER {} +
find $PREFIX/httpd/htdocs/tmp/ -type f -exec chmod 0660 {} +

# logs
find $PREFIX/httpd/htdocs/logs/ -type f -exec chown -R $MP_APACHE_USER:$MP_APACHE_USER {} +
find $PREFIX/httpd/htdocs/logs/ -type f -exec chmod 0640 {} +

# application
find $PREFIX/httpd/htdocs/application/ -type f -exec chown -R root:$MP_APACHE_USER {} +
find $PREFIX/httpd/htdocs/application/ -type f -exec chmod 0440 {} +

# API non-executable
find $PREFIX/httpd/htdocs/api/ -type f ! -name '*.sh' -o ! -name '*.pl' -exec chown -R root:$MP_APACHE_USER {} +
find $PREFIX/httpd/htdocs/api/ -type f ! -name '*.sh' -o ! -name '*.pl' -exec chmod 0440 {} +

# API executable
find $PREFIX/httpd/htdocs/api/ -type f -name '*.sh' -o -name '*.pl' -exec chown -R root:$MP_APACHE_USER {} +
find $PREFIX/httpd/htdocs/api/ -type f -name '*.sh' -o -name '*.pl' -exec chmod 0550 {} +

# API static non htaccess
find $PREFIX/httpd/htdocs/api/static -type f ! -name '.htaccess' -exec chown -R root:$MP_APACHE_USER {} +
find $PREFIX/httpd/htdocs/api/static -type f ! -name '.htaccess' -exec chmod 0440 {} +
chown root:$MP_APACHE_USER $PREFIX/httpd/htdocs/api/static
chmod 0660 $PREFIX/httpd/htdocs/api/static

# HTTPD logs
find $PREFIX/httpd/logs/ -type f -exec chown -R $MP_APACHE_USER:$MP_APACHE_USER {} +
find $PREFIX/httpd/logs/ -type f -exec chmod 0640 {} +

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

(cd /var/cfengine/httpd/htdocs/ldap; sh scripts/post-install.sh)
# ENT-3645: `ldap/config/settings.ldap.php` must be writable by the webserver user or we will be unable to modify settings.
chown $MP_APACHE_USER:$MP_APACHE_USER -R $PREFIX/httpd/htdocs/ldap
chmod 0700 -R $PREFIX/httpd/htdocs/ldap/config

##
# Start Apache server
#
$PREFIX/httpd/bin/apachectl start

#Mission portal
#

CFE_ROBOT_PWD=$(dd if=/dev/urandom bs=1024 count=1 2>/dev/null | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
$PREFIX/httpd/php/bin/php $PREFIX/httpd/htdocs/index.php cli_tasks create_cfe_robot_user $CFE_ROBOT_PWD
su $MP_APACHE_USER -c "$PREFIX/httpd/php/bin/php $PREFIX/httpd/htdocs/index.php cli_tasks migrate_ldap_settings https://localhost/ldap"

$PREFIX/httpd/php/bin/php $PREFIX/httpd/htdocs/index.php cli_tasks inventory_refresh

# Shut down Apache and Postgres again, because we may need them to start through
# systemd later.
$PREFIX/httpd/bin/apachectl stop
(cd /tmp && su cfpostgres -c "$PREFIX/bin/pg_ctl stop -D $PREFIX/state/pg/data -m smart")

#
# Delete temporarily stored key.
#
rm -f $PREFIX/CF_CLIENT_SECRET_KEY.tmp

##
# ENT-3921: Make bin/runalerts.php executable
#
chmod 755 $PREFIX/bin/runalerts.php

#
# Register CFEngine initscript, if not yet.
#
if ! is_upgrade; then
  if [ -x /bin/systemctl ]; then
    # Reload systemd config to pick up newly installed units
    /bin/systemctl daemon-reload > /dev/null 2>&1
    # Enable service units
    /bin/systemctl enable cf-apache.service > /dev/null 2>&1
    /bin/systemctl enable cf-execd.service > /dev/null 2>&1
    /bin/systemctl enable cf-serverd.service > /dev/null 2>&1
    /bin/systemctl enable cf-runalerts.service > /dev/null 2>&1
    /bin/systemctl enable cf-monitord.service > /dev/null 2>&1
    /bin/systemctl enable cf-postgres.service > /dev/null 2>&1
    /bin/systemctl enable cf-hub.service > /dev/null 2>&1
    /bin/systemctl enable cfengine3.service > /dev/null 2>&1
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

if is_upgrade && [ -f "$PREFIX/UPGRADED_FROM_STATE.txt" ]; then
    cf_console restore_cfengine_state "$PREFIX/UPGRADED_FROM_STATE.txt"
    rm -f "$PREFIX/UPGRADED_FROM_STATE.txt"
else
    cf_console platform_service cfengine3 start
fi

rm -f "$PREFIX/UPGRADED_FROM.txt"

exit 0
