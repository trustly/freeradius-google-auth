#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

ABSOLUTE_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

apt-get update
apt-get install build-essential libpam0g-dev freeradius git libqrencode3

cd /tmp
git clone https://code.google.com/p/google-authenticator/
cd google-authenticator/libpam/
make
make install

addgroup radius-disabled

patch -d -p1 < "$ABSOLUTE_PATH/etc.patch"

RADIUS_SECRET=`openssl rand -hex 32`
echo "RADIUS shared secret: $RADIUS_SECRET"
perl -s -i -p -e "s/testing123/$RADIUS_SECRET/g" /etc/freeradius/clients.conf

service freeradius restart
