# A minimal HTTP server framework for Jim Tcl.
# Copyright (C) 2014 Danyil Bohdan.
# License: MIT
source mime.tcl

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

set http::requestFormat [dict create {*}{
    Connection:             connection
    Accept:                 accept
    Accept-Charset:         acceptCharset
    Accept-Encoding:        acceptEncoding
    Accept-Language:        acceptLanguage
    Host:                   host
    Referer:                referer
    User-Agent:             userAgent
    Content-Length:         contentLength
    Content-Type:           contentType
    Content-Disposition:    contentDisposition
}]

set http::methods [list {*}{
    OPTIONS GET HEAD POST PUT DELETE TRACE CONNECT
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
    set length [string bytelength $body]

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

# Return the content up to but not including $separator in variable
# $stringVarName. Remove this content and the separator following it from the
# $stringVarName. If $separator isn't in $stringVarName's value return the whole
# string.
proc http::string-pop {stringVarName separator} {
    upvar 1 $stringVarName str
    set substrLength [string first $separator $str]
    if {$substrLength > -1} {
        set substr [string range $str 1 $substrLength-1]
        set str [string range $str $substrLength+[string length $separator] end]
    } else {
        set substr $str
        set str ""
    }
    return $substr
}

# Parse HTTP request headers presented as a list of lines into a dict.
proc http::parse-headers {headerLines} {
    global http::requestFormat
    global http::methods

    set headers {}
    set field {}
    set value {}

    foreach line $headerLines {
        # Split $line on its first space.
        regexp {^(.*?) (.*)$} $line _ field value
        http::debug-message [list $line]

        if {[lsearch -exact $http::methods $field] > -1} {
            dict set headers method $field
            lassign [split [lindex [split $value] 0] ?] headers(url) formData
            dict set headers form [form-decode $formData]
        } else {
            # Translate "Content-Type:" to "contentType", etc.
            if {[dict exists $http::requestFormat $field]} {
                dict set headers $http::requestFormat($field) $value
            }
        }
    }
    return $headers
}

# Convert an HTTP request value of type {string;key1=value1; key2="value2"} to
# dict.
proc http::parse-value {str} {
    set result {}
    foreach x [split $str ";"] {
        set x [string trimleft $x " "] ;# For "; ".
        if {[regexp {(.*?)="?([^"]*)"?} $x _ name value]} {
            dict set result $name $value
        } else {
            dict set result $x 1
        }
    }
    return $result
}

# Return the files and formPost fields in encoded in a multipart/form-data form.
proc http::parse-multipart-data {postString contentType newline} {
    set result {}
    set boundary [dict get \
            [http::parse-value $contentType] boundary]
    set boundaryLength [string length $boundary]
    while {[set part [string-pop postString $boundary]] ne ""} {
        set hdr [http::parse-headers \
                [split [string-pop part "$newline$newline"] $newline]]
        # Trim "(\r)\n--" from content.
        set part [string range $part 0 end-[string length "$newline--"]]
        if {$part ne ""} {
            set m [http::parse-value $hdr(contentDisposition)]
            if {[dict exists $m form-data] && [dict exists $m name]} {
                # File or form field?
                if {[dict exists $m filename]} {
                    dict set result files \
                            $m(name) filename $m(filename)
                    dict set result files \
                            $m(name) content $part
                } else {
                    dict set result formPost $m(name) $part
                }
            }
        }
    }
    return $result
}

# Handle HTTP requests over a channel and send responses. A very hacky HTTP
# implementation.
proc http::serve {channel clientAddr clientPort routes} {
    http::debug-message "Client connected: $clientAddr"

    set newline \r\n ;# TODO: accept requests with nonstandard \n newlines.

    set headerLines {}
    while {[gets $channel buf]} {
        set buf [string trimright $buf \r]
        if {$buf eq ""} {
            break
        }
        lappend headerLines $buf
    }

    set request [http::parse-headers $headerLines]

    # Process POST data.
    if {$request(method) eq "POST"} {
        set request [dict merge {contentType application/x-www-form-urlencoded
                contentLength 0} $request]
        # TODO: limit max length.
        set postString [read $channel $request(contentLength)]
        if {$request(contentType) eq "application/x-www-form-urlencoded"} {
            http::debug-message "POST request: {\n$postString}\n"
            dict set request formPost [form-decode $postString]
        } elseif {[string match "multipart/form-data*" $request(contentType)]} {
            http::debug-message "POST request: (multipart/form-data skipped)"
            set request [dict merge $request [http::parse-multipart-data \
                    $postString $request(contentType) $newline]]
        }
    } else {
        dict set request formPost {}
    }

    http::debug-message "Responding."
    puts -nonewline $channel [http::route $request $routes]

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
    http::debug-message "Started server on $ipAddress:$port."
    vwait http::done
    http::debug-message "The server has shut down."
}

# Call route handler for the request url if available and return its result.
# Otherwise return a 404 error message.
proc http::route {request routes} {
    # Don't show the contents of large files in the debug message.
    if {[dict exists $request files] &&
                [string length $request(files)] > 8*1024} {
        set requestPrime $request
        dict set requestPrime files "(not shown here)"
        http::debug-message "request: $requestPrime"
    } else {
        http::debug-message "request: $request"
    }

    set url [dict get $request url]
    if {$url eq ""} {
        set url /
    }

    set matchResult [http::match-route \
            [dict keys $routes($request(method))] $url]
    if {$matchResult != 0} {
        set procName [dict get $routes $request(method) [lindex $matchResult 0]]
        set result [$procName $request [lindex $matchResult 1]]
        return $result
    } else {
        return [http::make-response "<h1>Not found.</h1>" {code 404}]
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
proc http::add-handler {methods routes {statics {}} script} {
    global http::routes

    set procName "handler::${methods}::${routes}"
    proc $procName {request routeVars} $statics $script
    foreach method $methods {
        foreach route $routes {
            dict set http::routes $method $route $procName
        }
    }
}

# Return the contents of $filename.
proc http::read-file {filename} {
    set fpvar [open $filename r]
    fconfigure $fpvar -translation binary
    set content [read $fpvar]
    close $fpvar
    return $content
}

# Add handler to return the contents of a static file. The file is either
# $filename or [file tail $route] if no filename is given.
proc http::add-static-file {route {filename {}}} {
    if {$filename eq ""} {
        set filename [file tail $route]
    }
    http::add-handler GET $route [format {
        http::make-response [http::read-file %s] {contentType %s}
    } $filename [mime::type $filename]]
}
