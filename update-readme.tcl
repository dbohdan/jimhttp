#!/usr/bin/env jimsh
# Update jimhttp components' versions in README.md.
# Copyright (C) 2015, 2016 dbohdan.
# License: MIT

proc read-file filename {
    set channel [open $filename]
    set data [read $channel]
    close $channel
    return $data
}

proc write-file {filename data} {
    set channel [open $filename w]
    puts -nonewline $channel $data
    close $channel
}

proc get-component-version filename {
    set sourceCode [read-file $filename]
    if {![regexp {variable version ([0-9]+\.[0-9]+\.[0-9]+)} $sourceCode \
            _ version]} {
        set version —
    }
    return $version
}

set updatedReadme {}
foreach line [split [read-file README.md] \n] {
    if {[regexp {\| \[([a-z]+.tcl)\]\([a-z]+.tcl\)} $line _ filename]} {
        set row [split $line |]
        lset row 3 " [get-component-version $filename] "
        lappend updatedReadme [join $row |]
    } else {
        lappend updatedReadme $line
    }
}
write-file README.md [join $updatedReadme \n]
