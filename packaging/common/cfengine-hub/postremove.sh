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

for i in cf-agent cf-key cf-keycrypt cf-promises cf-execd cf-serverd cf-monitord cf-net;
do
    rm -f /usr/local/sbin/$i || true
done

exit 0
