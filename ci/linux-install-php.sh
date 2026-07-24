#!/usr/bin/env bash
set -e

php_version=8.3.20

if command -v php; then
  if php -r "version_compare(PHP_VERSION, \""$php_version"\") >= 0 || exit(1);"; then
    echo "host has php version >= $php_version. will skip install."
    exit
  fi
fi

# install PHP 8.3 from source
sudo apt-get -y install gcc g++ make pkg-config libxml2-dev libsqlite3-dev \
libcurl4-openssl-dev libpng-dev libonig-dev libldap2-dev libzip-dev \
zlib1g-dev libssl-dev

cd /tmp
wget https://www.php.net/distributions/php-$php_version.tar.gz
tar xzf php-$php_version.tar.gz
cd php-$php_version

# --enable-bcmath is needed by tecnickcom/tc-lib-barcode and tecnickcom/tc-lib-pdf
./configure --prefix=/usr/local --with-curl --enable-bcmath --enable-gd --enable-mbstring --with-ldap --with-openssl --with-zlib

make -j"$(nproc)"
sudo make install

php -v
# END of PHP installation
