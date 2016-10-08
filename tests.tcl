#!/usr/bin/env jimsh
# Tests for the web framework and its modules.
# Copyright (C) 2014, 2015, 2016 dbohdan.
# License: MIT

source testing.tcl
namespace import ::testing::*

# http.tcl tests
test http \
        -constraints jim \
        -body {
    source http.tcl

    assert-equal \
            [::http::get-route-variables \
                    {/hello/:name/:town} {/hello/john/smallville}] \
            [::http::get-route-variables \
                    {/hello/:name/:town} {/hello/john/smallville/}] \
            [::http::get-route-variables \
                    {/hello/there/:name/:town} {/hello/there/john/smallville/}]\
            [::http::get-route-variables \
                    {/hello/:name/from/:town} {/hello/john/from/smallville/}]

    assert-equal \
            [::http::get-route-variables \
                    {/bye/:name/:town} {/hello/john/smallville/}] \
            0

    assert-equal [::http::form-decode a=b&c=d] [dict create {*}{
        a b c d
    }]

    assert-equal \
            [::http::form-decode message=Hello%2C+world%21] \
            [dict create {*}{
                message {Hello, world!}
            }]
}

# html.tcl tests
test html \
        -body {
    source html.tcl

    foreach t {{!@#$%^&*()_+} {<b>Hello!</b>}} {
        assert-equal [::html::unescape [html::escape $t]] $t
    }

    assert-equal [b "Hello!"] [b "" "Hello!"] {<b>Hello!</b>}
    assert-equal [br] [br ""] {<br>}

    assert-equal [::html::make-table {{a b} {c d}}] \
    {<table><tr><td>a</td><td>b</td></tr><tr><td>c</td><td>d</td></tr></table>}
}

# json.tcl tests
test json \
        -body {
    source json.tcl

    set d [dict create {*}{
        array {0 Tokyo 1 Seoul 2 Shanghai}
        object {Tokyo 37.8 Seoul 25.62 Shanghai 24.75}
    }]

    assert-equal [::json::tokenize {"a"}] [list [list STRING a]]
    assert-equal [::json::tokenize {"ab\nc\"de"}] \
            [list [list STRING ab\nc\"de]]

    assert-equal [::json::tokenize {0}] [list [list NUMBER 0]]
    assert-equal [::json::tokenize {0.}] [list [list NUMBER 0.]]
    assert-equal [::json::tokenize {-0.1234567890}] \
            [list [list NUMBER -0.1234567890]]
    assert-equal [::json::tokenize {-525}] [list [list NUMBER -525]]
    assert-equal [::json::tokenize {1E100}] [list [list NUMBER 1E100]]
    assert-equal [::json::tokenize {1.23e-99}] [list [list NUMBER 1.23e-99]]
    assert-equal [::json::tokenize {1.23e-99, 0, 0}] [list \
            [list NUMBER 1.23e-99] COMMA \
            [list NUMBER 0] COMMA \
            [list NUMBER 0]]

    assert-equal [::json::tokenize true] [list [list RAW true]]
    assert-equal [::json::tokenize false] [list [list RAW false]]
    assert-equal [::json::tokenize null] [list [list RAW null]]

    assert-equal [::json::parse {[1.23e-99, 0, 0]} 0] \
            [list 1.23e-99 0 0]
    assert-equal [::json::parse {[ 1.23e-99,    0,     0 ]} 0] \
            [list 1.23e-99 0 0]
    assert-equal [::json::parse {[1.23e-99, "a", [1,2,3]]} 0] \
            [list 1.23e-99 a {1 2 3}]
    assert-equal [::json::parse {["alpha", "beta", "gamma"]} 0] \
            [list alpha beta gamma]
    assert-equal [::json::parse {["alpha", "beta", "gamma"]} 1] \
            [list 0 alpha 1 beta 2 gamma]
    assert-equal [::json::parse {[true,     false,null ]} 1] \
            [list 0 true 1 false 2 null]
    assert-equal [::json::parse {[]} 1] \
            [list]


    assert-equal [::json::parse {{"key": "value"}} 0] \
            [list key value]
    assert-equal \
            [::json::parse {{    "key"   :        "value"    }} 0] \
            [list key value]
    assert-equal [::json::parse "\t{\t \"key\"\t:    \n\"value\"\n\r}" 0] \
            [list key value]
    assert-equal [::json::parse {{"key": [1, 2, 3]}} 0] \
            [list key {1 2 3}]
    assert-equal \
            [::json::parse {{"k1": true, "k2": false, "k3": null}} 0] \
            [list k1 true k2 false k3 null]
    assert-equal [::json::parse {{}}] [list]
    assert-equal [::json::parse {[]         }] [list]

    assert-equal [::json::parse [::json::stringify $d 1] 1] $d

    assert-equal [::json::stringify 0] 0
    assert-equal [::json::stringify 0.5] 0.5
    assert-equal [::json::stringify Hello] {"Hello"}
    assert-equal [::json::stringify {key value}] {{"key": "value"}}
    assert-equal \
            [::json::stringify {0 a 1 b 2 c} 0] \
            {{"0": "a", "1": "b", "2": "c"}}
    assert-equal \
            [::json::stringify {0 a 1 b 2 c} 1] \
            {["a", "b", "c"]}

    # Invalid JSON.
    assert [catch {::json::parse x}]
    # Trailing garbage.
    assert [catch {::json::parse {"Hello" blah}}]

    assert-equal [::json::subset {a b c} {a b c d e f}] 1
    assert-equal [::json::subset {a b c d e f} {a b c}] 0
    assert-equal [::json::subset {a b c d e f} {}] 0
    assert-equal [::json::subset {} {a b c}] 1
    assert-equal [::json::subset a a] 1

    # Schema tests.

    assert-equal [::json::stringify 0 1 number] 0
    assert-equal [::json::stringify 0 1 string] \"0\"
    assert-equal [::json::stringify 0 1 boolean] false
    assert-equal [::json::stringify false 1 boolean] false
    assert-equal [::json::stringify 1 1 boolean] true
    assert-equal [::json::stringify true 1 boolean] true
    assert-equal [::json::stringify null 1 null] null

    assert [catch {::json::stringify 0 1 object}]
    assert [catch {::json::stringify 0 1 noise}]
    assert [catch {::json::stringify 0 1 array}]
    assert [catch {::json::stringify x 1 boolean}]
    assert [catch {::json::stringify x 1 null}]

    assert-equal \
            [::json::stringify \
                    {key1 true key2 0.5 key3 1} 1 \
                    {key1 boolean key2 number key3 number}] \
            {{"key1": true, "key2": 0.5, "key3": 1}}
    assert-equal \
            [::json::stringify \
                    {key1 true key2 0.5 key3 1} 1 \
                    {key1 string key2 string key3 string}] \
            {{"key1": "true", "key2": "0.5", "key3": "1"}}
    assert-equal \
            [::json::stringify {key1 {0 a 1 b}} 1 ""] \
            [::json::stringify {key1 {0 a 1 b}} 1 {key1 ""}] \
            [::json::stringify {key1 {0 a 1 b}} 1 {key1 {0 string 1 string}}] \
            {{"key1": ["a", "b"]}}
    assert [catch {
        ::json::stringify {key1 {0 a 1 b}} 1 {key1 {0 string 2 string}} 1
    }]
    assert [catch {
        ::json::stringify {key1 {0 a 1 b}} 1 {key1 {0 boolean}}
    }]

    assert-equal [::json::stringify {} 1 ""] {""}
    assert-equal [::json::stringify {} 1 string] {""}
    assert-equal [::json::stringify {key {}} 1 ""] {{"key": ""}}
    assert-equal [::json::stringify {0 {} 1 {}} 1 ""] {["", ""]}
    assert-equal [::json::stringify {} 1 array] {[]}
    assert-equal [::json::stringify {} 1 object] "{}"
    assert-equal \
            [::json::stringify \
                    {0 1 1 {0 1} 2 {0 x 1 null}} 1 \
                    {0 boolean 1 {0 boolean} 2 array}] \
            {[true, [true], ["x", null]]}
    assert-equal \
            [::json::stringify \
                    {key1 1 key2 {0 1} key3 {0 x 1 null}} 1 \
                    {0 boolean 1 {0 boolean} 2 array}] \
            {{"key1": 1, "key2": [1], "key3": ["x", null]}}

    assert-equal \
            [::json::stringify {1 {key 1} 2 {x null} 3} 0 array] \
            {[1, {"key": 1}, 2, {"x": null}, 3]}
    assert-equal \
            [::json::stringify {1 {key 1} 2 {x null} 3} 0 string] \
            {"1 {key 1} 2 {x null} 3"}
    assert-equal \
            [::json::stringify {1 {key 1} 2 {x null} 3} 0 \
                    {string string string string string}] \
            {["1", "key 1", "2", "x null", "3"]}
    assert-equal \
            [::json::stringify {0 {key 1} 1 {x null}} 1 {N* string}] \
            {["key 1", "x null"]}
    assert-equal \
            [::json::stringify {1 {key 1} 2 {x null}} 1 {* string}] \
            {{"1": "key 1", "2": "x null"}}
    assert-equal \
            [::json::stringify {key {true false null}} 0 \
                    {key {string string string}}]\
            {{"key": ["true", "false", "null"]}}
    assert-equal \
            [::json::stringify {0 {n 1 s 1}} 0 {0 {n number s string}}] \
            {{"0": {"n": 1, "s": "1"}}}

    assert-equal \
            [::json::stringify2 {1 {key 1} 2 {x null} 3} \
                    -numberDictArrays 0 \
                    -schema array \
                    -compact 1] \
            {[1,{"key":1},2,{"x":null},3]}
    assert-equal \
            [::json::stringify2 {1 {key 1} 2 {x null} 3} \
                    -numberDictArrays 0 \
                    -schema {string string string string string} \
                    -compact 1] \
            {["1","key 1","2","x null","3"]}
    assert-equal \
            [::json::stringify2 {1 {key 1} 2 {x null} 3 null} \
                    -numberDictArrays 0 \
                    -schema {string string string string string string} \
                    -compact 1] \
            {["1","key 1","2","x null","3","null"]}
    assert-equal \
            [::json::stringify2 {1 {key 1} 2 {x null}} \
                    -numberDictArrays 0 \
                    -schema {1 string 2 string} \
                    -compact 1] \
            {{"1":"key 1","2":"x null"}}
    assert-equal \
            [::json::stringify2 {0 {key 1} 1 {x null}} \
                    -numberDictArrays 1 \
                    -schema {N* string} \
                    -compact 1] \
            {["key 1","x null"]}
    assert-equal \
            [::json::stringify2 {1 {key 1} 2 {x null}} \
                    -numberDictArrays 0 \
                    -schema {1 string 2 string} \
                    -compact 1] \
            {{"1":"key 1","2":"x null"}}
    assert-equal \
            [::json::stringify2 {1 {key 1} 2 {x null}} \
                    -numberDictArrays 0 \
                    -schema {* string} \
                    -compact 1] \
            {{"1":"key 1","2":"x null"}}
    assert-equal \
            [::json::stringify2 {key {true false null}} \
                    -numberDictArrays 0 \
                    -schema {key {string string string}} \
                    -compact 1] \
            {{"key":["true","false","null"]}}
    assert-equal \
            [::json::stringify2 {a 0 b 1 c 2} \
                    -numberDictArrays 1 \
                    -schema {* string c number} \
                    -compact 1] \
            {{"a":"0","b":"1","c":2}}
    assert-equal \
            [::json::stringify2 {a 123 b {456 789}} \
                    -numberDictArrays 0 \
                    -schema {a string b {N* number}} \
                    -strictSchema 1] \
            {{"a": "123", "b": [456, 789]}}
    assert-equal \
            [::json::stringify2 {a b c d} \
                    -numberDictArrays 0 \
                    -schema {N* {}} \
                    -strictSchema 1] \
            {["a", "b", "c", "d"]}
    assert [catch {::json::stringify2 {a 0 b 1} \
            -numberDictArrays 0 \
            -schema {a string} \
            -strictSchema 1]}]
    assert-equal \
            [::json::stringify2 {a 0 b 1} \
                    -numberDictArrays 0 \
                    -schema {a string * string } \
                    -strictSchema 1] \
            {{"a": "0", "b": "1"}}
    assert [catch {::json::stringify2 {a 0 b 1} -foo bar]}]
}

# arguments.tcl tests
test arguments \
        -body {
    source arguments.tcl

    assert-equal \
            [::arguments::parse \
                    {-a first} \
                    {-b second 2 -c third blah} \
                    {-a 1 -c 3}] \
            [dict create {*}{second 2 third 3 first 1}]
    assert-equal \
            [::arguments::usage {-a first} {-b second 2 -c third blah} \
                    "./sample.tcl"] \
            {usage: ./sample.tcl -a first [-b second] [-c third]}
}

# example web application (example.tcl) and http tests
test example \
        -constraints jim \
        -body {
    source http.tcl

    set curlAvailable [expr {![catch {exec curl -V}]}]
    if {$curlAvailable} {
        proc test-url args {
            set result [exec curl --compressed -S {*}$args 2>/dev/null]
            return $result
        }

        set port 8080
        set url "http://localhost:$port"
        if {![catch {test-url $url}]} {
            error "Can't test example: port $port taken!"
        }

        set index {<!DOCTYPE html><html>
<form action="/form" method="POST">
<h1>Hello</h1><br>
<input name="name" type="text" value="Anonymous"><br>
<textarea name="message">Your message here.</textarea><br>
<input type="submit"></form><br>
<ul><li><a href="/ajax">/ajax</a></li>
<li><a href="/cookie">/cookie</a></li>
<li><a href="/counter">/counter</a></li>
<li><a href="/counter-persistent">/counter-persistent</a></li>
<li><a href="/delay">/delay</a></li>
<li><a href="/file-echo">/file-echo</a></li>
<li><a href="/hello/John">/hello/John</a></li>
<li><a href="/hello/John/Smallville">/hello/John/Smallville</a></li>
<li><a href="/json">/json</a></li>
<li><a href="/static.jpg">/static.jpg</a></li>
<li><a href="/table">/table</a></li>
<li><a href="/template">/template</a></li>
<li><a href="/quit">/quit</a></li></ul></html>}

        set handle [open {| jimsh example.tcl -v 99}]
        set pid [pid $handle]
        # Wait until the server is ready to respond.
        $handle readable { set ::ready 1 }
        vwait ::ready

        proc test-server {url index} {
            assert-equal [test-url $url] $index
            assert-equal \
                    [test-url $url/does-not-exist] \
                    {<h1>Error 404: Not Found</h1> }
            assert-equal [test-url $url] $index

            # Static file handler test.
            test-url $url/static.jpg

            # Keeping the channel open.
            test-url $url/delay

            # Binary file corruption test.
            set tempFile1 /tmp/jimhttp.test
            set tempFile2 /tmp/jimhttp.test.echo
            exec dd if=/dev/urandom of=$tempFile1 bs=1024 count=1024
            test-url -o "$tempFile2" -X POST -F "testfile=@$tempFile1" \
                    $url/file-echo
            set fileContents1 [::http::read-file $tempFile1]
            set fileContents2 [::http::read-file $tempFile2]

            assert [list \
                    [string bytelength $fileContents1] == \
                    [string bytelength $fileContents2]] \
                    "file corruption test file size"
            assert [expr {$fileContents1 eq $fileContents2}] \
                    "file corruption test file contents"
            file delete $tempFile1
            file delete $tempFile2
            # End file corruption test
        }

        try {
            test-server $url $index
            test-url -X POST -d enable=1 $url/compression
            exec curl --compressed -v $url |& grep {Content-Encoding: gzip}
            test-server $url $index
            assert-equal [test-url $url/quit] {Bye!}
        } finally {
            kill $pid
        }
    }
}

# storage.tcl tests
test storage \
        -constraints jim \
        -body {
    source storage.tcl

    proc foo args {{a 555}} {
        ::storage::restore-statics
        incr a
        ::storage::persist-statics
        return $a
    }
    assert-equal [
        try {
            foo
        } on error v {
            lindex $v
        }
    ] {::storage::db isn't initialized}
    ::storage::init :memory:
    assert-equal [foo] 556
    assert-equal [foo] 557
    rename foo {}

    set ::ns::bar 7890
    ::storage::persist-var ::ns::bar
    set ::ns::bar 0
    ::storage::restore-var ::ns::bar
    assert-equal $::ns::bar 7890
}

run-tests $argv
