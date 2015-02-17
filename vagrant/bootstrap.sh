#!/bin/sh

# Get, build and install Jim Tcl if needed.
if test ! -x "$(which jimsh)"; then
    /vagrant/install-jimtcl.sh
fi

# Run jimhttp in a loop. curl localhost:8080/quit to restart.
cd /jimhttp
echo Starting example.tcl on port 8080.
while true; do
    jimsh example.tcl -i 0.0.0.0 -p 8080 -v 5
    echo Restarting example.tcl on port 8080.
    sleep 1
done
