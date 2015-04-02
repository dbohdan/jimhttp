#!/bin/sh

# Get, build and install Jim Tcl if needed.
if test ! -x "$(which jimsh)"; then
    /vagrant/install-jimtcl.sh
fi

/vagrant/test-server.sh > /vagrant/test-server.log 2>&1 &
