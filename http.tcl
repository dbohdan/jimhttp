# A minimal HTTP server framework for Jim Tcl.
# Copyright (C) 2014 Danyil Bohdan.
# License: MIT
set http::DEBUG 0

set http::statusCodePhrases [dict create {*}{
    200 OK
    201 {Created}
    301 {Moved Permanently}
    400 {Bad Request}
    401 {Unauthorized}
    403 {Forbidden}
    404 {Not Found}
    405 {Method Not Allowed}
}]

# Return the text of an HTTP response with body $body.
proc http::make-response {body {headers {}}} {
    global http::statusCodePhrases

    set http::responseTemplate \
        {HTTP/1.1 $headers(code) $http::statusCodePhrases($headers(code))
Content-Type: $headers(contentType)
Content-Length: $length

$body}

    set http::headerDefaults [dict create {*}{
        code 200
        contentType text/html
    }]

    set headers [dict merge $http::headerDefaults $headers]
    set length [string length $body]

    set response [subst $http::responseTemplate]

    return $response
}

# Write $message to stdout if $http::DEBUG is true.
proc http::debug-message message {
    global http::DEBUG

    if {$http::DEBUG} {
        puts $message
    }
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

# Handle HTTP requests over a channel and send responses. A very hacky HTTP
# implementation.
proc http::serve {channel clientaddr clientport routes} {
    http::debug-message "Client connected: $clientaddr"

    set request {}

    set get 0
    set post 0
    set postContentLength 0

    while {[gets $channel buf]} {
        set buf [string trimright $buf \r]
        http::debug-message [list $buf]
        # make this a switch statement
        if {![dict exists $request url]} {
            set bufArr [split $buf]
            dict set request method [lindex $bufArr 0]
            lassign [split [lindex $bufArr 1] ?] request(url) formData
            dict set request form [form-decode $formData]
            if {$request(form) ne ""} {
                set get 1
            }
            http::debug-message "GET request: [list $request(form)]"
        }
        if {!$post} {
            set postContentLength [scan $buf "Content-Length: %d"]
            if {[string is integer -strict $postContentLength]} {
                set post 1
            }
        }
        if {$buf eq ""} {
            break
        }
    }

    # Process POST data.
    if {$post} {
        set postString [read $channel $postContentLength]
        http::debug-message "POST request: $postString"
        dict set request formPost [form-decode $postString]
    } else {
        dict set request formPost {}
    }

    http::debug-message "Responding."
    puts -nonewline $channel [
        lassign [route $request $routes] body headers
        http::make-response $body $headers
    ]

    close $channel
}

# Start the HTTP server binding it to $ipAddress and $port.
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

# Call route handler for the request url if available and return its result.
# Otherwise return a 404 error message.
proc http::route {request routes} {
    http::debug-message "request: $request"

    set url [dict get $request url]

    set matchResult [http::match-route [dict keys $routes] $url]
    if {$matchResult != 0} {
        set procName [dict get $routes [lindex $matchResult 0]]
        set result [$procName $request [lindex $matchResult 1]]
        return $result
    } else {
        return {"<h1>Not found.</h1>" {code 404}}
    }
}

# Return route variables contained in the url if it can be parsed as route
# $route. Return 0 otherwise.
proc http::get-route-variables {route url} {
    set routeVars {}
    foreach routeSegment [split $route /] urlSegment [split $url /] {
        if {[string index $routeSegment 0] eq ":"} {
            dict set routeVars [string range $routeSegment 1 end] $urlSegment
        } else {
            # Static parts of the URL and the route should be equal.
            if {$urlSegment ne $routeSegment} {
                return 0
            }
        }
    }
    return $routeVars
}

# Return the first route out of the list $routeList that matches $url.
proc http::match-route {routeList url} {
    foreach route $routeList {
        set routeVars [http::get-route-variables $route $url]
        if {$routeVars != 0} {
            return [list $route $routeVars]
        }
    }
    return 0
}

# Create a proc to handle the route $route with body $script.
proc http::add-handler {route {statics {}} script} {
    global http::routes

    set procName "handler::$route"
    proc $procName {request routeVars} $statics $script
    dict set http::routes $route $procName
}
