#!/bin/sh
if [ "`id -u`" != 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

pre="$PWD"
cd "$(dirname "$0")"

# delete systemd services
systemctl disable cfengine3
systemctl stop cfengine3
systemctl stop var-cfengine.mount
cd systemd
for service in *; do
  rm /etc/systemd/system/$service
  test -d /etc/systemd/system/$service.wants && rm -rf /etc/systemd/system/$service.wants
done
systemctl daemon-reload

# delete extracted image
rm /var/cfengine3.img
rmdir /var/cfengine

cd "$pre"
