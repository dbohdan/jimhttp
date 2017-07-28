#! /bin/sh

# Run jimhttp in a loop. curl localhost:8080/quit to restart.
cd /jimhttp || exit 1
echo Starting example.tcl on port 8080.
while true; do
    jimsh example.tcl -i 0.0.0.0 -p 8080 -v 5
    echo Restarting example.tcl on port 8080.
    sleep 1
done
