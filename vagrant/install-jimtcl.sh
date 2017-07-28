#!/bin/sh

apt-get update
apt-get -y install git build-essential libsqlite3-dev

git clone https://github.com/msteveb/jimtcl.git
cd jimtcl || exit 1
git checkout --detach 0.77
./configure --with-ext="oo tree binary sqlite3" --enable-utf8 --ipv6 --disable-docs
make
make install
cd .. || exit 1
