if [ -f /etc/php.d/cfmod.ini ]; then
    rm -f /etc/php.d/cfmod.ini
    rm -f /etc/php.d/json.ini
    rm -f /etc/php.d/curl.ini
    rm -f /etc/php.d/cfengine-enterprise-api.ini
    rm -f /etc/php.d/mcrypt.ini
fi

if [ -f /etc/php5/conf.d/cfmod.ini ]; then
    rm -f /etc/php5/conf.d/cfmod.ini
    rm -f /etc/php5/conf.d/curl.ini
    rm -f /etc/php5/conf.d/cfengine-enterprise-api.ini
fi

if [ -f /usr/lib64/php/modules/cfmod.so ]; then
    rm -f /usr/lib64/php/modules/json.so
    rm -f /usr/lib64/php/modules/cfmod.so
    rm -f /usr/lib64/php/modules/curl.so
    rm -f /usr/lib64/php/modules/cfengine-enterprise-api.so
    rm -f /usr/lib64/php/modules/mcrypt.so
fi

if [ -f /usr/lib64/php5/extensions/cfmod.so ]; then
    rm -f /usr/lib64/php5/extensions/cfmod.so
    rm -f /usr/lib64/php5/extensions/curl.so
    rm -f /usr/lib64/php5/extensions/cfengine-enterprise-api.so
fi

if [ `os_type` != redhat ]; then
  # These links are handled in .spec file for RedHat
  for i in cf-agent cf-key cf-secret cf-promises cf-execd cf-serverd cf-monitord cf-net cf-check cf-support; do
    rm -f /usr/local/sbin/$i || true
  done
fi

# unload SELinux policy if not upgrading
if ! is_upgrade; then
  if [ `os_type` = "redhat" ] &&
     command -v semodule >/dev/null &&
     semodule -l | grep cfengine-enterprise >/dev/null;
  then
    semodule -n -r cfengine-enterprise
    if /usr/sbin/selinuxenabled; then
      /usr/sbin/load_policy
    fi
  fi
fi

exit 0
