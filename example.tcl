#!/usr/bin/env jimsh
# A minimal HTTP server framework for Jim Tcl.
# Copyright (C) 2014 Danyil Bohdan.
# License: MIT
set http::DEBUG 1

source http.tcl
source html.tcl

http::add-handler / {
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

http::add-handler /form {
    return [list 200 [format \
        {You (%s) said:<br>%s} \
        [html::escape [dict get $request formPost name]] \
        [html::escape [dict get $request formPost message]]]]
}

http::add-handler /quit {
    global http::done
    set http::done 1
    return "Bye!"
}

http::add-handler /hello/:name/:town {
    return [list 200 "Hello, [dict get $routeVars name] from [dict get $routeVars town]!"]
}

http::add-handler /table {
    return [list 200 \
        [html::make-table {1 2} {3 4}]
    ]
}

http::start-server 127.0.0.1 8080
