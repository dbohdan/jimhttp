#!/usr/bin/env jimsh
# A minimal HTTP server framework for Jim Tcl.
# Copyright (C) 2014 Danyil Bohdan, https://github.com/dbohdan/
# License: MIT

proc make-http-response content {
    set httpResponseTemplate {
HTTP/1.1 200 OK
Content-Type: text/html
Content-Length: %d

%s
}
    set length [string length [string map {\n \r\n} $content]]
    set output [format $httpResponseTemplate $length $content]

    return $output
}

# From http://wiki.tcl.tk/14144.
proc uri-decode str {
    # rewrite "+" back to space
    # protect \ from quoting another '\'
    set str [string map [list + { } "\\" "\\\\"] $str]

    # prepare to process all %-escapes
    regsub -all -- {%([A-Fa-f0-9][A-Fa-f0-9])} $str {\\u00\1} str

    # process \u unicode mapped chars
    return [subst -novar -nocommand $str]
}

# Decode a POST/GET response.
# string -> dict
proc response-decode {postData} {
    lmap x [split $postData &] {
        lmap y [split $x =] { uri-decode $y }
    }
}

proc serve {channel clientaddr clientport routes} {
    global DEBUG

    puts "Client connected: $clientaddr"

    set url {}
    set get 0
    set getData {}
    set post 0
    set postData {}
    set postContentLength 0

    while {[gets $channel buf]} {
        set buf [string trimright $buf \r]
        if {$DEBUG} {
            puts [list $buf]
        }
        # make this a switch statement
        if {$url eq ""} {
            set bufArr [split $buf]
            set url [lindex $bufArr 1]
            if {[lindex $bufArr 0] eq "GET"} {
                set getData [response-decode \
                        [lindex [split [lindex $bufArr 1] ?] 1]]
                if {$getData ne ""} {
                    set get 1
                }
            }
            if {$DEBUG} {
                puts "GET request: [list $getData]"
            }
        }
        if {!$post} {
            set postContentLength [scan $buf "Content-Length: %d"]
            if {[string is integer -strict $postContentLength]} {
                set post 1
            } else {
                set postContentLength 0
            }
        }
        if {$buf eq ""} {
            break
        }
    }

    # Process POST data.
    if {$post} {
        set postString [read $channel $postContentLength]
        if {$DEBUG} {
            puts "POST request: $postString"
            puts [set postData [response-decode $postString]]
        }
    }

    set request [dict create url $url host 0.0.0.0 form $getData formPost $postData remoteAddress $clientaddr]

    puts "Responding."
    puts -nonewline $channel [
        make-http-response [route $request $routes]
    ]

    close $channel
}

proc start-server {ipAddress port serveProcName {argument ""}} {
    global httpServerSocket
    global httpServerDone

    set httpServerSocket [socket stream.server $ipAddress:$port]
    $httpServerSocket readable [format {
        set client [$httpServerSocket accept addr]
        %s $client {*}[split $addr :] [list %s]
    } $serveProcName $argument]
    vwait httpServerDone
}

proc route {request routes} {
    global DEBUG

    if {$DEBUG} {
        puts $request
    }
    switch -exact -- [dict get $request url] $routes
}
