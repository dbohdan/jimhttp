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
    set prevArg [lindex $args 0]
    foreach arg [lrange $args 1 end] {
        assert [list \"$arg\" eq \"$prevArg\"]
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

# html tests
source html.tcl

foreach t {{!@#$%^&*()_+} {<b>Hello!</b>}} {
    assert-all-equal [html::unescape [html::escape $t]] $t
}
