#!/bin/sh
grep "variable version" *.tcl | awk '{ printf "%-15s %s\n", $1, $4 }'
