#!/usr/bin/env jimsh
# An HTTP server and web framework for Jim Tcl.
# Copyright (C) 2014 Danyil Bohdan.
# License: MIT

proc assert {expression {message ""}} {
    if {![expr $expression]} {
        set errorMessage "Not true: $expression"
        if {$message ne ""} {
            append errorMessage " ($message)"
        }
        error $errorMessage
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

    set port 8080
    set url "http://localhost:$port"
    if {![catch {test-url $url}]} {
        error "Can't test example: port $port taken!"
    }

    exec jimsh example.tcl 0 &
    test-url $url
    test-url $url/does-not-exist
    test-url $url

    # Binary file corruption test.
    set tempFile1 /tmp/jimhttp.test
    set tempFile2 /tmp/jimhttp.test.echo
    exec dd if=/dev/urandom of=$tempFile1 bs=1024 count=1024
    exec curl -o "$tempFile2" -X POST -F "testfile=@$tempFile1" \
            $url/file-echo
    set fileContents1 [http::read-file $tempFile1]
    set fileContents2 [http::read-file $tempFile2]

    assert [list \
        [string bytelength $fileContents1] == \
        [string bytelength $fileContents2]] "file corruption test file size"
    assert [expr {$fileContents1 eq $fileContents2}] \
            "file corruption test file contents"
    file delete $tempFile1
    file delete $tempFile2
    # End file corruption test

    test-url $url/quit
}
