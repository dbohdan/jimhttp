#!/usr/bin/env jimsh
# A minimal HTTP server framework for Jim Tcl.
# Copyright (C) 2014 Danyil Bohdan.
# License: MIT
set http::DEBUG 1

source server.tcl
source html.tcl

proc handler::homepage {request routeVars} {
    return [list \
        200 \
        [html "" \
            [form {action /form method POST} \
                [h1 "Hello"] [br] \
                [input {name name type text value Anonymous}] [br] \
                [textarea {name message} "Your message here."] [br]\
                [input {type submit}]
            ]
        ]
    ]
}

proc handler::process-form {request routeVars} {
    return [list 200 [format \
        {You (%s) said:<br>%s} \
        [html::escape [dict get $request formPost name]] \
        [html::escape [dict get $request formPost message]]]]
}

proc handler::bye {request routeVars} {
    global http::done
    set http::done 1
    return "Bye!"
}

proc handler::greet {request routeVars} {
    return [list 200 "Hello, [dict get $routeVars name] from [dict get $routeVars town]!"]
}

proc handler::table-test {request routeVars} {
    return [list 200 \
        [html::make-table {1 2} {3 4}]
    ]
}

set http::routes [dict create {*}{
    / handler::homepage
    /quit handler::bye
    /form handler::process-form
    /hello/:name/:town handler::greet
    /table handler::table-test
}]
http::start-server 127.0.0.1 8080
