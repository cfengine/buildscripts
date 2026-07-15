#!/usr/bin/env bash
# bash is needed in order to use the "time" built-in and avoid needing
# an external utility.

set -e                                                   # exit on error

# Argument $1 is the size in megabytes
if [ x"$1" = x ]  ||  echo "$1" | grep -q '[^0-9]'
then
    exit 2
fi
SIZE="$1"

if swapon | grep /swapfile >/dev/null; then
  echo "/swapfile already configured and setup. Exiting."
  exit 0
fi

time dd if=/dev/zero of=/swapfile bs=1M count=$SIZE
chmod 0600 /swapfile

PATH=$PATH:/sbin:/usr/sbin
mkswap /swapfile
swapon /swapfile
