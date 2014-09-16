#!/usr/bin/env jimsh
set http::DEBUG 1

source server.tcl
source html.tcl

proc handler::greet {request routeVars} {
    return [list \
        200 \
        [html "" \
            [form {action /form method POST} \
                [h1 "" "Hello"] [br] \
                [input {name name type text value Anonymous}] [br] \
                [textarea {name message} "Your message here."] [br]\
                [input {type submit}]
            ]
        ]
    ]
}

proc handler::process-form {request routeVars} {
    return [list 200 [pre "" "You ([html::escape [dict get $request formPost name]]) said: [html::escape [dict get $request formPost message]]."]]
}

proc handler::bye {request routeVars} {
    global http::done
    set http::done 1
    return "Bye!"
}

set routes [dict create {*}{
    / handler::greet
    /quit handler::bye
    /form handler::process-form
    /hello/:name/:town unknown
}]
http::start-server 127.0.0.1 8080 http::serve $routes
