#!/bin/sh
if [ "`id -u`" != 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

pre="$PWD"
cd "$(dirname "$0")"

# extract image to expected location
tar xf cfengine3.img.tar.gz -C /var

# setup systemd
cd systemd
chmod 664 *
cp * /etc/systemd/system/
systemctl daemon-reload
systemctl enable cfengine3
systemctl start cfengine3

# prepare to bootstrap
/var/cfengine/bin/cf-key

cd "$pre"
