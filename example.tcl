#! /usr/bin/env jimsh
# A jimhttp use example.
# Copyright (c) 2014-2016 D. Bohdan.
# License: MIT

source arguments.tcl
source html.tcl
source http.tcl
source json.tcl
source storage.tcl
source template.tcl

# This file showcases the various features of the framework and the ways in
# which it can be used (e.g., HTML DSL vs. templates).

# An example of the HTML DSL from html.tcl. It also provides links to
# other examples.
::http::add-handler GET / {
    ::http::respond [::http::make-response \
            [html "" \n \
                [form {action /form method POST} \n \
                    [h1 "Hello"] [br] \n \
                    [input {name name type text value Anonymous}] [br] \n \
                    [textarea {name message} "Your message here."] [br] \n \
                    [input {type submit}]] [br] \n \
                [ul {} \
                    [li [a {href "/ajax"} /ajax]] \n \
                    [li [a {href "/cookie"} /cookie]] \n \
                    [li [a {href "/counter"} /counter]] \n \
                    [li [a {href "/counter-persistent"} \
                            /counter-persistent]] \n \
                    [li [a {href "/delay"} /delay]] \n \
                    [li [a {href "/file-echo"} \
                            /file-echo]] \n \
                    [li [a {href "/hello/John"} /hello/John]] \n \
                    [li [a {href "/hello/John/Smallville"} \
                            /hello/John/Smallville]] \n \
                    [li [a {href "/json"} /json]] \n \
                    [li [a {href "/static.jpg"} /static.jpg]] \n \
                    [li [a {href "/table"} /table]] \n \
                    [li [a {href "/template"} /template]] \n \
                    [li [a {href "/quit"} /quit]]]] {} $request]
}

# Process POST form data for the form at /.
::http::add-handler {GET POST} /form {
    if {[dict exists $request formPost name] && \
            [dict exists $request formPost message]} {
        ::http::respond [::http::make-response [format {You (%s) said:<br>%s} \
                    [::html::escape [dict get $request formPost name]] \
                    [::html::escape [dict get $request formPost message]]] \
                {} \
                $request]
    } else {
        ::http::respond [::http::make-response \
                "Please fill in the form at [a {href /} /]." {} $request]
    }
}

# Shut down the HTTP server.
::http::add-handler GET /quit {
    global ::http::done
    set ::http::done 1
    ::http::respond [::http::make-response "Bye!" {} $request]
}

# Process route variables. Their values are available to the handler script
# through the dict routeVars.
::http::add-handler GET {/hello/:name /hello/:name/:town} {
    set response "Hello, $routeVars(name)"
    if {[dict exists $routeVars town]} {
        append response " from $routeVars(town)"
    }
    append response !
    ::http::respond [::http::make-response $response {} $request]
}

# Table generation using html.tcl.
::http::add-handler GET /table {
    ::http::respond \
            [::http::make-response [::html::make-table {{a b} {1 2} {3 4}} 1] \
                    {} $request]
}

# Static variables in a handler.
::http::add-handler GET /counter {{counter 0}} {
    incr counter

    ::http::respond [::http::make-response $counter {} $request]
}

# Persistent storage.
::http::add-handler GET /counter-persistent {{counter 0}} {
    ::storage::restore-statics

    incr counter

    ::storage::persist-statics
    ::http::respond [::http::make-response $counter {} $request]
}

# AJAX requests.
::http::add-handler GET /ajax {
    ::http::respond [::http::make-response {
        <!DOCTYPE html>
        <html>
        <body>
            <script>
                var updateCounter = function() {
                    var xmlhttp = new XMLHttpRequest();
                    xmlhttp.open("GET", "/counter", false);
                    xmlhttp.send();
                    document.querySelector("#counter").innerHTML =
                            "Counter value: " + xmlhttp.responseText;
                }
            </script>
            <div style="width: 100%; margin-bottom: 10px;">
                <span id="counter">Click the button.</span>
            </div>
            <button onclick="javascript:updateCounter();">Update</button>
        </body>
        </html>
    } {} $request]
}

# HTML templates.
::http::add-handler GET /template {
    ::http::respond [::http::make-response [eval [::template::parse {
        <!DOCTYPE html>
        <html>
        <body>
            The most populous metropolitan areas in the world are:
            <dl>
            <% foreach {city population} \
                    {Tokyo 37.8 Seoul 25.62 Shanghai 24.75} { %>
                <dt><%= $city %></dt><dd><%= $population %> million people</dd>
            <% } %>
            </dl>
        </body>
        </html>
    }]] {} $request]
}

# File uploading. Sends the uploaded file back to the client.
::http::add-handler {GET POST} /file-echo {
    if {($request(method) eq "POST") &&
            [dict exists $request files testfile content]} {
        ::http::respond [::http::make-response \
                [dict get $request files testfile content] \
                        [list contentType \
                                [mime::type \
                                        [dict get $request \
                                                files testfile filename]]]]
    } else {
        ::http::respond [::http::make-response \
                [html "" \n \
                    [form {action /file-echo method POST
                            enctype {multipart/form-data}} \n \
                    [input {type hidden name test value blah}] \
                    [input {type file name testfile}] " " \
                    [input {type submit}]]]
                {} \
                $request]
    }
}

# JSON generation and parsing.
::http::add-handler {GET POST} /json {
    if {$request(method) eq "POST"} {
        set error [catch {set result [::json::parse $request(formPost) 1]}]
        if {!$error} {
            ::http::respond [::http::make-response \
                    "Decoded JSON:\n[list $result]\n" \
                    {contentType text/plain} \
                    $request]
        } else {
            ::http::respond [::http::error-response \
                    400 \
                    "<p>Couldn't parse JSON.</p>" \
                    $request]
        }
    } else {
        set json [dict create {*}{
            objectSample {Tokyo 37.8 Seoul 25.62 Shanghai 24.75}
            arraySample {0 Tokyo 1 Seoul 2 Shanghai}
        }]
        ::http::respond [::http::make-response \
                [::json::stringify $json 1] {} $request]
    }
}

# Cookies.
::http::add-handler GET /cookie {
    set cookies {}
    catch {set cookies [dict get $request cookies]}

    set cookieTable [tr "" [th name] [th value]]
    foreach {name value} $cookies {
        append cookieTable [tr "" [td $name] [td $value]]
    }

    ::http::respond [::http::make-response \
            [html [body [table $cookieTable]]] \
            {
                cookies {
                    {name alpha value {cookie 1} maxAge 360}
                    {name beta value {cookie 2} expires 1727946435 httpOnly 1}
                }
            } \
            $request]
}

# Keeping the channel open. We get a connection and respond later in an [after]
# script.
::http::add-handler GET /delay {
    after 25 [list apply {{channel t1 request} {
        set message "You waited $([clock milliseconds] - $t1) milliseconds\
                for your response."
        ::http::respond [::http::make-response \
                [html [body {} [p $message]]] \
                {} \
                $request]
        close $channel
    }} $channel [clock milliseconds] $request]
}
dict set ::http::routes /delay GET close 0

# Activate or deactivate GZip compression of responses.
::http::add-handler {GET POST} /compression {
    set gzipFilter [dict get $::http::sampleFilters gzipExternal]

    if {($request(method) eq {POST}) &&
            [dict exists $request formPost enable]} {
        if {[dict get $request formPost enable]} {
            set ::http::responseFilters [list $gzipFilter]
        } else {
            set ::http::responseFilters {}
        }
    }

    set enabled [expr {
        $gzipFilter in $::http::responseFilters ? "on" : "off"
    }]
    ::http::respond [::http::make-response \
            [html [body [h1 "Compression is $enabled"]]] \
            {} \
            $request]
}

# Static file.
::http::add-static-file /static.jpg

proc main {} {
    global argv
    global argv0
    global ::http::crashOnError
    global ::http::verbosity

    stdout buffering line

    set ::http::crashOnError 1 ;# exit if an error occurs.

    set optionalArgs [list -p port 8080 -i ip 127.0.0.1 -v verbosity 3]
    set error [catch {
        set args [::arguments::parse {} $optionalArgs $argv]
    } errorMessage]
    if {$error} {
        puts "Error: $errorMessage"
        puts [::arguments::usage {} $optionalArgs $argv0]
        exit 1
    }
    set ::http::verbosity $args(verbosity)

    ::storage::init
    ::http::start-server $args(ip) $args(port)
}

main
