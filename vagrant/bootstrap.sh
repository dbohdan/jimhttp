#!/bin/sh

# Get, build and install Jim Tcl if needed.
if test ! -x "$(which jimsh)"; then
    /vagrant/install-jimtcl.sh
fi

/vagrant/testserver.sh > /vagrant/testserver.log 2>&1 &
