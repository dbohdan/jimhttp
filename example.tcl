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
http::add-handler / {
    return [list \
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
                    [li [a {href "/hello/John/Smallville"} \
                            /hello/John/Smallville]] \n \
                    [li [a {href "/table"} /table]] \n \
                    [li [a {href "/quit"} /quit]]]]]
}

# Process POST form data for the form at /.
http::add-handler /form {
    return [list \
            [format \
                {You (%s) said:<br>%s} \
                [html::escape [dict get $request formPost name]] \
                [html::escape [dict get $request formPost message]]]]
}

# Shut down the HTTP server.
http::add-handler /quit {
    global http::done
    set http::done 1
    return [list "Bye!"]
}

# Process route variables. Their values are available to the handler script
# through the dict routeVars.
http::add-handler /hello/:name/:town {
    return [list "Hello, $routeVars(name) from $routeVars(town)!"]
}

# Table generation using html.tcl.
http::add-handler /table {
    return [list [html::make-table {1 2} {3 4}]]
}

# Static variables in a handler.
http::add-handler /counter {{counter 0}} {
    incr counter

    return [list $counter]
}

# Persistent storage.
http::add-handler /counter-persistent {{pcounter 0}} {
    storage::restore-statics

    incr pcounter

    storage::persist-statics
    return [list $pcounter]
}

# AJAX requests.
http::add-handler /ajax {
    return [list {
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

storage::init
http::start-server 127.0.0.1 8080
