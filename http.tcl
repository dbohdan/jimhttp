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

# Handle HTTP requests over a channel and send responses.
proc http::serve {channel clientaddr clientport routes} {
    http::debug-message "Client connected: $clientaddr"

    set method {}
    set url {}
    set get 0
    set getData {}
    set post 0
    set postData {}
    set postContentLength 0

    while {[gets $channel buf]} {
        set buf [string trimright $buf \r]
        http::debug-message [list $buf]
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

            http::debug-message "GET request: [list $getData]"
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
        http::debug-message "POST request: $postString"
        set postData [form-decode $postString]
    }

    set request [dict create \
            method $method \
            url $url \
            host 0.0.0.0 \
            form $getData \
            formPost $postData \
            remoteAddress $clientaddr]

    http::debug-message "Responding."
    puts -nonewline $channel [
        lassign [route $request $routes] body headers
        http::make-response $body $headers
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
    foreach route $routeList {
        set routeVars [http::get-route-variables $route $url]
        if {$routeVars != 0} {
            return [list $route $routeVars]
        }
    }
    return 0
}

proc http::add-handler {route {statics {}} script} {
    global http::routes

    set procName "handler::$route"
    proc $procName {request routeVars} $statics $script
    dict set http::routes $route $procName
}
