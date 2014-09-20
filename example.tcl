#!/usr/bin/env jimsh
# An HTTP server and web framework for Jim Tcl.
# Copyright (C) 2014 Danyil Bohdan.
# License: MIT
source http.tcl
source html.tcl
source storage.tcl

set http::DEBUG [lindex $argv 0]
if {$http::DEBUG eq ""} {
    set http::DEBUG 1
}

# This file showcases the various features of the framework and the different
# styles in which it can be used.

# An example of the HTML DSL from html.tcl. It also provides links to
# other examples.
http::add-handler GET / {
    return [http::make-response \
            [html "" \n \
                [form {action /form method POST} \n \
                    [h1 "Hello"] [br] \n \
                    [input {name name type text value Anonymous}] [br] \n \
                    [textarea {name message} "Your message here."] [br] \n \
                    [input {type submit}]] [br] \n \
                [ul "" \
                    [li [a {href "/ajax"} /ajax]] \n \
                    [li [a {href "/counter"} /counter]] \n \
                    [li [a {href "/counter-persistent"} \
                            /counter-persistent]] \n \
                    [li [a {href "/hello/John"} /hello/John]] \n \
                    [li [a {href "/hello/John/Smallville"} \
                            /hello/John/Smallville]] \n \
                    [li [a {href "/table"} /table]] \n \
                    [li [a {href "/static.jpg"} /static.jpg]] \n \
                    [li [a {href "/quit"} /quit]]]]]
}

# Process POST form data for the form at /.
http::add-handler {GET POST} /form {
    if {[dict exists $request formPost name] && \
            [dict exists $request formPost message]} {
        return [http::make-response [format {You (%s) said:<br>%s} \
                [html::escape [dict get $request formPost name]] \
                [html::escape [dict get $request formPost message]]]]
    } else {
        return [http::make-response \
                "Please fill in the form at [a {href /} /]."]
    }
}

# Shut down the HTTP server.
http::add-handler GET /quit {
    global http::done
    set http::done 1
    return [http::make-response "Bye!"]
}

# Process route variables. Their values are available to the handler script
# through the dict routeVars.
http::add-handler GET {/hello/:name /hello/:name/:town} {
    set response "Hello, $routeVars(name)"
    if {[dict exists $routeVars town]} {
        append response " from $routeVars(town)"
    }
    append response !
    return [http::make-response $response]
}

# Table generation using html.tcl.
http::add-handler GET /table {
    return [http::make-response [html::make-table {1 2} {3 4}]]
}

# Static variables in a handler.
http::add-handler GET /counter {{counter 0}} {
    incr counter

    return [http::make-response $counter]
}

# Persistent storage.
http::add-handler GET /counter-persistent {{counter 0}} {
    storage::restore-statics

    incr counter

    storage::persist-statics
    return [http::make-response $counter]
}

# AJAX requests.
http::add-handler GET /ajax {
    return [http::make-response {
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
    }]
}

# Static file.
http::add-static-file /static.jpg

storage::init
http::start-server 127.0.0.1 8080
