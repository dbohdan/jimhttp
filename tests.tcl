#!/usr/bin/env jimsh
# A minimal HTTP server framework for Jim Tcl.
# Copyright (C) 2014 Danyil Bohdan, https://github.com/dbohdan/
# License: MIT

source server.tcl

proc assert truth {
	if {![expr $truth]} {
		error "Not true: $truth"
	}
}

proc assert-all-equal args {
    set prevArg [lindex $args 0]
    foreach arg [lrange $args 1 end] {
        assert [list \"$arg\" eq \"$prevArg\"]
    }
}

assert-all-equal \
		[http::get-route-variables {/hello/:name/:town} {/hello/john/smallville}] \
		[http::get-route-variables {/hello/:name/:town} {/hello/john/smallville/}] \
		[http::get-route-variables {/hello/there/:name/:town} {/hello/there/john/smallville/}] \
		[http::get-route-variables {/hello/:name/from/:town} {/hello/john/from/smallville/}]

assert-all-equal \
	[http::get-route-variables {/bye/:name/:town} {/hello/john/smallville/}] \
	0
