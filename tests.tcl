#!/usr/bin/env jimsh
# Tests for the web framework and its modules.
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
        [::http::get-route-variables \
                {/hello/:name/:town} {/hello/john/smallville}] \
        [::http::get-route-variables \
                {/hello/:name/:town} {/hello/john/smallville/}] \
        [::http::get-route-variables \
                {/hello/there/:name/:town} {/hello/there/john/smallville/}] \
        [::http::get-route-variables \
                {/hello/:name/from/:town} {/hello/john/from/smallville/}]

assert-all-equal \
        [::http::get-route-variables \
                {/bye/:name/:town} {/hello/john/smallville/}] \
        0

assert-all-equal [::http::form-decode a=b&c=d] [dict create {*}{
    a b c d
}]

assert-all-equal \
        [::http::form-decode message=Hello%2C+world%21] \
        [dict create {*}{
            message {Hello, world!}
        }]


# html tests
source html.tcl

foreach t {{!@#$%^&*()_+} {<b>Hello!</b>}} {
    assert-all-equal [::html::unescape [html::escape $t]] $t
}

assert-all-equal [b "Hello!"] [b "" "Hello!"] {<b>Hello!</b>}
assert-all-equal [br] [br ""] {<br>}


# json tests
source json.tcl

set d [dict create {*}{
    array {0 Tokyo 1 Seoul 2 Shanghai}
    object {Tokyo 37.8 Seoul 25.62 Shanghai 24.75}
}]

assert-all-equal [::json::decode-string {"ab\nc\"de"}] [list "ab\nc\"de" {}]
assert-all-equal [::json::decode-string {"a" b c}] [list "a" { b c}]

assert-all-equal [::json::decode-number {0}] [list 0 {}]
assert-all-equal [::json::decode-number {0.}] [list 0. {}]
assert-all-equal [::json::decode-number {-0.1234567890}] [list -0.1234567890 {}]
assert-all-equal [::json::decode-number {-525}] [list -525 {}]
assert-all-equal [::json::decode-number {1E100}] [list 1E100 {}]
assert-all-equal [::json::decode-number {1.23e-99}] [list 1.23e-99 {}]
assert-all-equal [::json::decode-number {1.23e-99, 0, 0}] \
        [list 1.23e-99 {, 0, 0}]

assert-all-equal [::json::decode-array {[1.23e-99, 0, 0]}] \
        [list {1.23e-99 0 0} {}]
assert-all-equal [::json::decode-array {[ 1.23e-99,    0,     0 ]}] \
        [list {1.23e-99 0 0} {}]
assert-all-equal [::json::decode-array {[1.23e-99, "a", [1,2,3]]}] \
        [list {1.23e-99 a {1 2 3}} {}]
assert-all-equal [::json::decode-array {["alpha", "beta", "gamma"]} 0] \
        [list {alpha beta gamma} {}]
assert-all-equal [::json::decode-array {["alpha", "beta", "gamma"]} 1] \
        [list {0 alpha 1 beta 2 gamma} {}]

assert-all-equal [::json::decode-object {{"key": "value"}}] \
        [list {key value} {}]
assert-all-equal [::json::decode-object {{    "key"   :        "value"    }}] \
        [list {key value} {}]
assert-all-equal [::json::decode-object {{"key": [1, 2, 3]}}] \
        [list {key {1 2 3}} {}]

assert-all-equal [::json::parse [::json::stringify $d 1] 1] $d

assert-all-equal [::json::stringify 0] 0
assert-all-equal [::json::stringify 0.5] 0.5
assert-all-equal [::json::stringify Hello] {"Hello"}
assert-all-equal [::json::stringify {key value}] {{"key": "value"}}
assert-all-equal \
        [::json::stringify {0 a 1 b 2 c} 0] \
        {{"0": "a", "1": "b", "2": "c"}}
assert-all-equal \
        [::json::stringify {0 a 1 b 2 c} 1] \
        {["a", "b", "c"]}

# Invalid JSON.
assert [catch {[::json::parse x]}]
# Trailing garbage.
assert [catch {[::json::parse {"Hello" blah}]}]


# arguments tests
source arguments.tcl

assert-all-equal \
        [::arguments::parse {-a first} {-b second 2 -c third blah} {-a 1 -c 3}]\
        [dict create {*}{first 1 second 2 third 3}]
assert-all-equal \
        [::arguments::usage {-a first} {-b second 2 -c third blah} \
                "./sample.tcl"] \
        {usage: ./sample.tcl -a first [-b second] [-c third]}


# example web application (example.tcl) and http tests
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

    exec jimsh example.tcl -v 0 &
    test-url $url
    test-url $url/does-not-exist
    test-url $url

    # Binary file corruption test.
    set tempFile1 /tmp/jimhttp.test
    set tempFile2 /tmp/jimhttp.test.echo
    exec dd if=/dev/urandom of=$tempFile1 bs=1024 count=1024
    exec curl -o "$tempFile2" -X POST -F "testfile=@$tempFile1" \
            $url/file-echo
    set fileContents1 [::http::read-file $tempFile1]
    set fileContents2 [::http::read-file $tempFile2]

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
