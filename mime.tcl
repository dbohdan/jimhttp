# MIME type detection by filename extension.
# Copyright (C) 2014, 2015 Danyil Bohdan.
# License: MIT

namespace eval ::mime {
    variable version 1.2.0

    variable mimeDataInverted {
        text/plain {
            makefile
            COPYING
            LICENSE
            README
            Makefile
            .c
            .conf
            .h
            .log
            .md
            .sh
            .tcl
            .terms
            .tm
            .txt
            .wiki
            .LICENSE
            .README
        }
        text/css                .css
        text/csv                .csv
        image/gif               .gif
        application/gzip        .gz
        text/html {
            .htm
            .html
        }
        image/jpeg {
            .jpg
            .jpeg
        }
        application/javascript  .js
        application/json        .json
        application/pdf         .pdf
        image/png               .png
        application/postscript  .ps
        application/xhtml       .xhtml
        application/xml         .xml
        application/zip         .zip
    }

    variable byFilename {}
    variable byExtension {}
    foreach {mimeType files} $mimeDataInverted {
        foreach file $files {
            if {[string index $file 0] eq "."} {
                lappend byExtension $file $mimeType
            } else {
                lappend byFilename $file $mimeType
            }
        }
    }
    unset mimeDataInverted
}

proc ::mime::type {filename} {
    variable byFilename
    variable byExtension
    set tail [file tail $filename]
    set ext [file extension $filename]
    if {[dict exists $byFilename $tail]} {
        return [dict get $byFilename $tail]
    } elseif {[dict exists $byExtension $ext]} {
        return [dict get $byExtension $ext]
    } else {
        return application/octet-stream
    }
}
