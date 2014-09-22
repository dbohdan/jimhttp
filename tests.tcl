#!/usr/bin/env jimsh
# An HTTP server and web framework for Jim Tcl.
# Copyright (C) 2014 Danyil Bohdan.
# License: MIT

proc assert expression {
    if {![expr $expression]} {
        error "Not true: $expression"
    }
}

proc assert-all-equal args {
    set firstArg [lindex $args 0]
    foreach arg [lrange $args 1 end] {
        assert [list \"$arg\" eq \"$firstArg\"]
    }
}

# http tests
source http.tcl

assert-all-equal \
        [http::get-route-variables \
                {/hello/:name/:town} {/hello/john/smallville}] \
        [http::get-route-variables \
                {/hello/:name/:town} {/hello/john/smallville/}] \
        [http::get-route-variables \
                {/hello/there/:name/:town} {/hello/there/john/smallville/}] \
        [http::get-route-variables \
                {/hello/:name/from/:town} {/hello/john/from/smallville/}]

assert-all-equal \
        [http::get-route-variables \
                {/bye/:name/:town} {/hello/john/smallville/}] \
        0

assert-all-equal [http::form-decode a=b&c=d] [dict create {*}{
    a b c d
}]

assert-all-equal [http::form-decode message=Hello%2C+world%21] [dict create {*}{
    message {Hello, world!}
}]

# html tests
source html.tcl

foreach t {{!@#$%^&*()_+} {<b>Hello!</b>}} {
    assert-all-equal [html::unescape [html::escape $t]] $t
}

assert-all-equal [b "Hello!"] [b "" "Hello!"] {<b>Hello!</b>}
assert-all-equal [br] [br ""] {<br>}

# example code and http tests
set curlAvailable [expr {![catch {exec curl -V}]}]
if {$curlAvailable} {
    proc test-url args {
        puts [exec curl -v {*}$args]\n
    }
    exec jimsh example.tcl 0 &
    test-url http://localhost:8080/
    test-url http://localhost:8080/does-not-exist
    test-url http://localhost:8080/
    test-url http://localhost:8080/quit
}
