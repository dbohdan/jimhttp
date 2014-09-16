# A minimal HTTP server framework for Jim Tcl.
# Copyright (C) 2014 Danyil Bohdan.
# License: MIT

proc http::make-response {{code 200} content} {
    set httpResponseTemplate {
HTTP/1.1 %d OK
Content-Type: text/html
Content-Length: %d

%s
}
    set length [+ 1 [string length [string map {\n \r\n} $content]]]
    set output [format $httpResponseTemplate $code $length $content]

    return $output
}

# From http://wiki.tcl.tk/14144.
proc http::uri-decode str {
    # rewrite "+" back to space
    # protect \ from quoting another '\'
    set str [string map [list + { } "\\" "\\\\"] $str]

    # prepare to process all %-escapes
    regsub -all -- {%([A-Fa-f0-9][A-Fa-f0-9])} $str {\\u00\1} str

    # process \u unicode mapped chars
    return [subst -novar -nocommand $str]
}

# Decode a POST/GET form.
# string -> dict
proc http::form-decode {formData} {
    set result {}
    foreach x [split $formData &] {
        lassign [lmap y [split $x =] { uri-decode $y }] key value
        dict set result $key $value
    }
    return $result
}

# Handle HTTP requests over a channel and send responses.
proc http::serve {channel clientaddr clientport routes} {
    global http::DEBUG

    if {$http::DEBUG} {
        puts "Client connected: $clientaddr"
    }

    set method {}
    set url {}
    set get 0
    set getData {}
    set post 0
    set postData {}
    set postContentLength 0

    while {[gets $channel buf]} {
        set buf [string trimright $buf \r]
        if {$http::DEBUG} {
            puts [list $buf]
        }
        # make this a switch statement
        if {$url eq ""} {
            set bufArr [split $buf]
            set method [lindex $bufArr 0]
            set url [lindex $bufArr 1]

            set getData [form-decode \
                    [lindex [split [lindex $bufArr 1] ?] 1]]
            if {$getData ne ""} {
                set get 1
            }

            if {$http::DEBUG} {
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
        if {$http::DEBUG} {
            puts "POST request: $postString"
            puts [set postData [form-decode $postString]]
        }
    }

    set request [dict create \
            method $method \
            url $url \
            host 0.0.0.0 \
            form $getData \
            formPost $postData \
            remoteAddress $clientaddr]

    puts "Responding."
    puts -nonewline $channel [
        http::make-response {*}[route $request $routes]
    ]

    close $channel
}

proc http::start-server {ipAddress port} {
    global http::serverSocket
    global http::done

    set http::serverSocket [socket stream.server $ipAddress:$port]
    $http::serverSocket readable {
        set client [$http::serverSocket accept addr]
        http::serve $client {*}[split $addr :] $http::routes
    }
    vwait http::done
}

# Call route handler for the request url if available and returns its result.
# Otherwise return 404 error message.
proc http::route {request routes} {
    global http::DEBUG

    if {$http::DEBUG} {
        puts "request: $request"
    }

    set url [dict get $request url]

    set matchResult [http::match-route [dict keys $routes] $url]
    if {$matchResult != 0} {
        puts -$matchResult-[lindex $matchResult 0]
        set procName [dict get $routes [lindex $matchResult 0]]
        set result [$procName $request [lindex $matchResult 1]]
        return $result
    } else {
        return {404 "<h1>Not found.</h1>"}
    }
}

# Return route variables contained in url if it can be parsed as a route $route.
# Return 0 otherwise.
proc http::get-route-variables {route url} {
    # set route [string trimright $route /]
    # set url [string trimright $url /]

    set routeVars {}
    foreach routeSegment [split $route /] urlSegment [split $url /] {
        if {[string index $routeSegment 0] eq ":"} {
            dict set routeVars [string range $routeSegment 1 end] $urlSegment
        } else {
            # Static parts of the URL and route should be equal
            if {$urlSegment ne $routeSegment} {
                return 0
            }
        }
    }
    return $routeVars
}

# Return the first route out of list routeList that matches url.
proc http::match-route {routeList url} {
    puts $routeList

    foreach route $routeList {
        set routeVars [http::get-route-variables $route $url]
        if {$routeVars != 0} {
            return [list $route $routeVars]
        }
    }
    return 0
}

proc http::add-handler {route script} {
    global http::handlersNumber
    global http::routes

    incr http::handlersNumber
    set procName "handler::$http::handlersNumber"

    proc $procName {request routeVars} $script
    dict set http::routes $route $procName

    puts $procName
}