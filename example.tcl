#!/usr/bin/env jimsh
set DEBUG 1

source server.tcl
source html.tcl

proc greet {} {
    return [html "" \
            [form {action / method POST} \
                [h1 "" "Hello"] \
                [input {name yo type text}] \
                [input {type submit}]
            ]
        ]
}

proc bye {} {
    global httpServerDone
    set httpServerDone 1
    return "Bye!"
}

set routes {/ greet /quit bye}
start-server 127.0.0.1 8080 serve $routes
