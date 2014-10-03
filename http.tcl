# An HTTP server and web framework for Jim Tcl.
# Copyright (C) 2014 Danyil Bohdan.
# License: MIT
source mime.tcl

set ::http::verbosity 0
set ::http::crashOnError 0
set ::http::maxRequestLength [expr 16*1024*1024]

set ::http::statusCodePhrases [dict create {*}{
    100 Continue
    200 OK
    201 {Created}
    301 {Moved Permanently}
    400 {Bad Request}
    401 {Unauthorized}
    403 {Forbidden}
    404 {Not Found}
    405 {Method Not Allowed}
    413 {Request Entity Too Large}
    500 {Internal Server Error}
}]

set ::http::requestFormat [dict create {*}{
    Accept:                 accept
    Accept-Charset:         acceptCharset
    Accept-Encoding:        acceptEncoding
    Accept-Language:        acceptLanguage
    Connection:             connection
    Content-Disposition:    contentDisposition
    Content-Length:         contentLength
    Content-Type:           contentType
    Cookie:                 cookie
    Expect:                 expect
    Host:                   host
    Referer:                referer
    User-Agent:             userAgent
}]

set ::http::cookieFields [dict create {*}{
    Domain                  domain
    Path                    path
    Expires                 expires
    Max-Age                 maxAge
    Secure                  secure
    HttpOnly                httpOnly
}]
set ::http::cookieFieldsInv [lreverse $::http::cookieFields]
set ::http::cookieDateFormat {%a, %d-%b-%Y %H:%M:%S GMT}

set ::http::requestFormatLowerCase {}
foreach {key value} $::http::requestFormat {
    dict set ::http::requestFormatLowerCase [string tolower $key] $value
}

set ::http::methods [list {*}{
    OPTIONS GET HEAD POST PUT DELETE TRACE CONNECT
}]

# Return the text of an HTTP response with body $body.
proc ::http::make-response {body {headers {}}} {
    global ::http::statusCodePhrases

    set ::http::responseTemplate \
        {HTTP/1.1 $headers(code) $::http::statusCodePhrases($headers(code))
Content-Type: $headers(contentType)
Content-Length: $length}

    set ::http::headerDefaults [dict create {*}{
        code 200
        contentType text/html
    }]

    set headers [dict merge $::http::headerDefaults $headers]
    set length [string bytelength $body]

    set response [subst $::http::responseTemplate]
    if {[dict exists $headers cookies]} {
        foreach cookie $headers(cookies) {
            append response "\nSet-Cookie: [::http::make-cookie $cookie]"
        }
    }
    append response "\n\n$body"
    return $response
}

# Write $message to stdout if $level <= $::http::verbosity. Levels 0 and lower
# are for errors that are always reported.
proc ::http::log {level message} \
        [list [list levelNumber [dict create {*}{
            debug 3 info 2 warning 1 error 0 critical -1
        }]]] {
    global ::http::verbosity
    set levelNumber

    if {$levelNumber($level) <= $::http::verbosity} {
        puts [format "%-9s %s" "[string toupper $level]:" $message]
    }
}

# From http://wiki.tcl.tk/14144.
proc ::http::uri-decode str {
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
proc ::http::form-decode {formData} {
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
proc ::http::string-pop {stringVarName separator} {
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

# Parse a cookie dict in the format of
# {{name somecookie value "some value" expires 1727946435 domain foo path /
# secure 0 httpOnly 1} ...} into an HTTP header Set-Cookie value.
proc ::http::make-cookie cookieDict {
    global ::http::cookieFieldsInv
    global ::http::cookieDateFormat

    set result {}
    append result "$cookieDict(name)=$cookieDict(value)"
    dict unset cookieDict name
    dict unset cookieDict value
    foreach {field value} $cookieDict {
        if {($field eq "secure") || ($field eq "httpOnly")} {
            if {$value} {
                append result "; $::http::cookieFieldsInv($field)"
            }
        } else {
            append result "; $::http::cookieFieldsInv($field)"
            if {$field eq "expires"} {
                # TODO: adjust for the local timezone. clock format does not yet
                # support the -gmt switch in Jim Tcl.
                append result "=[clock format $value \
                        -format $::http::cookieDateFormat]"
            } else {
                append result "=$value"
            }
        }
    }
    return $result
}

# Parse HTTP request headers presented as a list of lines into a dict.
proc ::http::parse-headers {headerLines} {
    global ::http::requestFormatLowerCase
    global ::http::methods

    set headers {}
    set field {}
    set value {}

    foreach line $headerLines {
        # Split $line on its first space.
        regexp {^(.*?) (.*)$} $line _ field value
        ::http::log debug [list $line]

        if {[lsearch -exact $::http::methods $field] > -1} {
            dict set headers method $field
            lassign [split [lindex [split $value] 0] ?] headers(url) formData
            dict set headers form [form-decode $formData]
        } else {
            # Translate "Content-Type:" to "contentType", etc.
            set field [string tolower $field]
            if {$field eq "cookie:"} {
                if {![dict exists $headers cookies]} {
                    dict set headers cookies {}
                }
                dict set headers cookies [dict merge $headers(cookies) \
                        [::http::parse-value $value]]
            } elseif {[dict exists $::http::requestFormatLowerCase $field]} {
                dict set headers $::http::requestFormatLowerCase($field) $value
            }
        }
    }
    return $headers
}

# Convert an HTTP request value of type {string;key1=value1; key2="value2"} to
# dict.
proc ::http::parse-value {str} {
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
# Very hacky.
proc ::http::parse-multipart-data {postString contentType newline} {
    set result {}
    if {[catch {set boundary [dict get \
            [::http::parse-value $contentType] boundary]}]} {
        error {no boundary specified in Content-Type}
    }
    set boundaryLength [string length $boundary]
    while {[set part [string-pop postString $boundary]] ne ""} {
        set partHeader [::http::parse-headers \
                [split [string-pop part "$newline$newline"] $newline]]
        # Trim "(\r)\n--" in content.
        set part [string range $part 0 end-[string length "$newline--"]]
        if {$part ne ""} {
            set m [::http::parse-value $partHeader(contentDisposition)]
            if {[dict exists $m form-data] &&
                        [dict exists $m name]} {
                # Store files and form fields separately.
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

# Return error responses.
proc ::http::error-response {code {customMessage ""}} {
    global ::http::statusCodePhrases
    return [::http::make-response \
            "<h1>Error $code: $::http::statusCodePhrases($code)</h1>\
                    $customMessage" \
            [list code $code]]
}

# Call ::http::serve. Catch and report any unhandled errors.
proc ::http::serve-and-trap-errors {channel clientAddr clientPort routes} {
    set error [catch {
        ::http::serve $channel $clientAddr $clientPort $routes
    } errorMessage]
    if {$error} {
        ::http::log critical \
                "Unhandled ::http::serve error: $errorMessage."
        catch {close $channel}
        global ::http::crashOnError
        if {$::http::crashOnError} {
            ::http::log info "Exiting due to error."
            exit 1
        }
    }
}

# Handle HTTP requests over a channel and send responses. A hacky HTTP
# implementation.
proc ::http::serve {channel clientAddr clientPort routes} {
    global ::http::maxRequestLength

    ::http::log info "Client connected: $clientAddr"

    set newline \r\n

    set headerLines {}
    set firstLine 1
    while {[gets $channel buf]} {
        if {$firstLine} {
            # Change the newline variable when the incoming request has
            # nonstandard \n newlines. This happens, e.g., when you use netcat.
            if {[string index $buf end] ne "\r"} {
                set newline "\n"
                ::http::log debug \
                        {The client uses \n instead of \r\n for newline.}
            }
            set firstLine 0
        }
        if {$newline eq "\r\n"} {
            set buf [string trimright $buf \r]
        }
        if {$buf eq ""} {
            break
        }
        lappend headerLines $buf
    }

    set request [::http::parse-headers $headerLines]
    set error 0

    if {(![dict exists $request method]) || (![dict exists $request url])} {
        ::http::log error "Bad request."
        set error 400
    }

    # Process POST data.
    if {($error == 0) && ($request(method) eq "POST")} {
        set request [dict merge {contentType application/x-www-form-urlencoded
                contentLength 0} $request]

        if {[string is integer $request(contentLength)] &&
                ($request(contentLength) > 0)} {
            if {$request(contentLength) <= $::http::maxRequestLength} {
                if {[dict exists $request expect] &&
                            ($request(expect) eq "100-continue")} {
                    puts $channel "HTTP/1.1 100 Continue\n"
                }

                set postString [read $channel $request(contentLength)]
                if {$request(contentType) eq
                        "application/x-www-form-urlencoded"} {
                    ::http::log debug "POST request: {$postString}\n"
                    dict set request formPost [form-decode $postString]
                } elseif {[string match "multipart/form-data*" \
                        $request(contentType)]} {
                    ::http::log debug \
                            "POST request: (multipart/form-data skipped)"
                    # Call ::http::parse-multipart-data to parse the data.
                    set multipartDataError [catch {
                        set request [dict merge $request \
                                [::http::parse-multipart-data \
                                        $postString \
                                        $request(contentType) \
                                        $newline]]
                    } errorMessage]
                    if {$multipartDataError} {
                        ::http::log error \
                                "Bad request: multipart/form-data parse error:\
                                        $errorMessage."
                        set error 400
                    }
                } else {
                    # Put content of other types (e.g., application/json) into
                    # request(formPost) as is.
                    ::http::log debug \
                            "POST request: ($request(contentType) skipped)"
                    dict set request formPost $postString
                }
            } else {
                ::http::log error \
                        "Request too large: $request(contentLength)."
                set error 413
            }
        } else {
            ::http::log error "Bad request: Content-Length is invalid\
                    (\"$request(contentLength)\")."
            set error 400
        }
    } else {
        dict set request formPost {}
    }

    if {[dict exists $request cookies]} {
        ::http::log debug "cookies: $request(cookies)"
    }

    if {!$error} {
        ::http::log info "Responding."
        puts -nonewline $channel [::http::route $request $routes]
    } else {
        puts -nonewline $channel [::http::error-response $error]
    }

    close $channel
}

# Start the HTTP server binding it to $ipAddress and $port.
proc ::http::start-server {ipAddress port} {
    global ::http::serverSocket
    global ::http::done

    set ::http::serverSocket [socket stream.server $ipAddress:$port]
    $::http::serverSocket readable {
        set client [$::http::serverSocket accept addr]
        ::http::serve-and-trap-errors $client {*}[split $addr :] $::http::routes
    }
    ::http::log info "Started server on $ipAddress:$port."
    vwait ::http::done
    ::http::log info "The server has shut down."
}

# Call route handler for the request url if available and return its result.
# Otherwise return a 404 error message.
proc ::http::route {request routes} {
    # Don't show the contents of large files in the debug message.
    if {[dict exists $request files] &&
                [string length $request(files)] > 8*1024} {
        set requestPrime $request
        dict set requestPrime files "(not shown here)"
        ::http::log debug "request: $requestPrime"
        set requestPrime {}
    } else {
        ::http::log debug "request: $request"
    }

    set url [dict get $request url]
    if {$url eq ""} {
        set url /
    }

    set matchResult [::http::match-route \
            [dict keys $routes($request(method))] $url]
    if {$matchResult != 0} {
        set procName [dict get $routes $request(method) [lindex $matchResult 0]]
        set result [$procName $request [lindex $matchResult 1]]
        return $result
    } else {
        return [::http::error-response 404]
    }
}

# Return route variables contained in the url if it can be parsed as route
# $route. Return 0 otherwise.
proc ::http::get-route-variables {route url} {
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
proc ::http::match-route {routeList url} {
    foreach route $routeList {
        set routeVars [::http::get-route-variables $route $url]
        if {$routeVars != 0} {
            return [list $route $routeVars]
        }
    }
    return 0
}

# Create a proc to handle the route $route with body $script.
proc ::http::add-handler {methods routes {statics {}} script} {
    global ::http::routes

    set procName "handler::${methods}::${routes}"
    proc $procName {request routeVars} $statics $script
    foreach method $methods {
        foreach route $routes {
            dict set ::http::routes $method $route $procName
        }
    }
}

# Return the contents of $filename.
proc ::http::read-file {filename} {
    set fpvar [open $filename r]
    fconfigure $fpvar -translation binary
    set content [read $fpvar]
    close $fpvar
    return $content
}

# Add handler to return the contents of a static file. The file is either
# $filename or [file tail $route] if no filename is given.
proc ::http::add-static-file {route {filename {}}} {
    if {$filename eq ""} {
        set filename [file tail $route]
    }
    ::http::add-handler GET $route [format {
        ::http::make-response [::http::read-file %s] {contentType %s}
    } $filename [::mime::type $filename]]
}
