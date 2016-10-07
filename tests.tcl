#!/usr/bin/env jimsh
# Tests for the web framework and its modules.
# Copyright (C) 2014, 2015, 2016 dbohdan.
# License: MIT

source testing.tcl
namespace import ::testing::*

# http tests
test http \
        -constraints jim \
        -body {
    source http.tcl

    assert-all-equal \
            [::http::get-route-variables \
                    {/hello/:name/:town} {/hello/john/smallville}] \
            [::http::get-route-variables \
                    {/hello/:name/:town} {/hello/john/smallville/}] \
            [::http::get-route-variables \
                    {/hello/there/:name/:town} {/hello/there/john/smallville/}]\
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
}

# html tests
test html \
        -body {
    source html.tcl

    foreach t {{!@#$%^&*()_+} {<b>Hello!</b>}} {
        assert-all-equal [::html::unescape [html::escape $t]] $t
    }

    assert-all-equal [b "Hello!"] [b "" "Hello!"] {<b>Hello!</b>}
    assert-all-equal [br] [br ""] {<br>}

    assert-all-equal [::html::make-table {{a b} {c d}}] \
    {<table><tr><td>a</td><td>b</td></tr><tr><td>c</td><td>d</td></tr></table>}
}

# json tests
test json \
        -body {
    source json.tcl

    set d [dict create {*}{
        array {0 Tokyo 1 Seoul 2 Shanghai}
        object {Tokyo 37.8 Seoul 25.62 Shanghai 24.75}
    }]

    assert-all-equal [::json::tokenize {"a"}] [list [list STRING a]]
    assert-all-equal [::json::tokenize {"ab\nc\"de"}] \
            [list [list STRING ab\nc\"de]]

    assert-all-equal [::json::tokenize {0}] [list [list NUMBER 0]]
    assert-all-equal [::json::tokenize {0.}] [list [list NUMBER 0.]]
    assert-all-equal [::json::tokenize {-0.1234567890}] \
            [list [list NUMBER -0.1234567890]]
    assert-all-equal [::json::tokenize {-525}] [list [list NUMBER -525]]
    assert-all-equal [::json::tokenize {1E100}] [list [list NUMBER 1E100]]
    assert-all-equal [::json::tokenize {1.23e-99}] [list [list NUMBER 1.23e-99]]
    assert-all-equal [::json::tokenize {1.23e-99, 0, 0}] [list \
            [list NUMBER 1.23e-99] COMMA \
            [list NUMBER 0] COMMA \
            [list NUMBER 0]]

    assert-all-equal [::json::tokenize true] [list [list RAW true]]
    assert-all-equal [::json::tokenize false] [list [list RAW false]]
    assert-all-equal [::json::tokenize null] [list [list RAW null]]

    assert-all-equal [::json::parse {[1.23e-99, 0, 0]}] \
            [list 1.23e-99 0 0]
    assert-all-equal [::json::parse {[ 1.23e-99,    0,     0 ]}] \
            [list 1.23e-99 0 0]
    assert-all-equal [::json::parse {[1.23e-99, "a", [1,2,3]]}] \
            [list 1.23e-99 a {1 2 3}]
    assert-all-equal [::json::parse {["alpha", "beta", "gamma"]} 0] \
            [list alpha beta gamma]
    assert-all-equal [::json::parse {["alpha", "beta", "gamma"]} 1] \
            [list 0 alpha 1 beta 2 gamma]
    assert-all-equal [::json::parse {[true,     false,null ]} 1] \
            [list 0 true 1 false 2 null]
    assert-all-equal [::json::parse {[]} 1] \
            [list]


    assert-all-equal [::json::parse {{"key": "value"}}] \
            [list key value]
    assert-all-equal \
            [::json::parse {{    "key"   :        "value"    }}] \
            [list key value]
    assert-all-equal [::json::parse "\t{\t \"key\"\t:    \n\"value\"\n\r}"] \
            [list key value]
    assert-all-equal [::json::parse {{"key": [1, 2, 3]}}] \
            [list key {1 2 3}]
    assert-all-equal \
            [::json::parse {{"k1": true, "k2": false, "k3": null}}] \
            [list k1 true k2 false k3 null]
    assert-all-equal [::json::parse {{}}] [list]
    assert-all-equal [::json::parse {[]         }] [list]

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
    assert [catch {::json::parse x}]
    # Trailing garbage.
    assert [catch {::json::parse {"Hello" blah}}]

    # Schema tests.

    assert-all-equal [::json::stringify 0 1 number] 0
    assert-all-equal [::json::stringify 0 1 string] \"0\"
    assert-all-equal [::json::stringify 0 1 boolean] false
    assert-all-equal [::json::stringify false 1 boolean] false
    assert-all-equal [::json::stringify 1 1 boolean] true
    assert-all-equal [::json::stringify true 1 boolean] true
    assert-all-equal [::json::stringify null 1 null] null

    assert [catch {::json::stringify 0 1 object}]
    assert [catch {::json::stringify 0 1 noise}]
    assert [catch {::json::stringify 0 1 array}]
    assert [catch {::json::stringify x 1 boolean}]
    assert [catch {::json::stringify x 1 null}]

    assert-all-equal \
            [::json::stringify \
                    {key1 true key2 0.5 key3 1} 1 \
                    {key1 boolean key2 number key3 number}] \
            {{"key1": true, "key2": 0.5, "key3": 1}}
    assert-all-equal \
            [::json::stringify \
                    {key1 true key2 0.5 key3 1} 1 \
                    {key1 string key2 string key3 string}] \
            {{"key1": "true", "key2": "0.5", "key3": "1"}}
    assert-all-equal \
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

    assert-all-equal [::json::stringify {} 1 ""] {""}
    assert-all-equal [::json::stringify {} 1 string] {""}
    assert-all-equal [::json::stringify {key {}} 1 ""] {{"key": ""}}
    assert-all-equal [::json::stringify {0 {} 1 {}} 1 ""] {["", ""]}
    assert-all-equal [::json::stringify {} 1 array] {[]}
    assert-all-equal [::json::stringify {} 1 object] "{}"
    assert-all-equal \
            [::json::stringify \
                    {0 1 1 {0 1} 2 {0 x 1 null}} 1 \
                    {0 boolean 1 {0 boolean} 2 array}] \
            {[true, [true], ["x", null]]}

    assert-all-equal \
            [::json::stringify {1 {key 1} 2 {x null} 3} 0 array] \
            {[1, {"key": 1}, 2, {"x": null}, 3]}
    assert-all-equal \
            [::json::stringify {1 {key 1} 2 {x null} 3} 0 string] \
            {"1 {key 1} 2 {x null} 3"}
    assert-all-equal \
            [::json::stringify {1 {key 1} 2 {x null} 3} 0 array:string] \
            {["1", "key 1", "2", "x null", "3"]}
    assert-all-equal \
            [::json::stringify {1 {key 1} 2 {x null}} 0 object:string] \
            {{"1": "key 1", "2": "x null"}}
    assert-all-equal \
            [::json::stringify {0 {key 1} 1 {x null}} 1 array:string] \
            {["key 1", "x null"]}
    assert-all-equal \
            [::json::stringify {1 {key 1} 2 {x null}} 1 object:string] \
            {{"1": "key 1", "2": "x null"}}
    assert-all-equal \
            [::json::stringify {key {true false null}} 0 object:array:string] \
            {{"key": ["true", "false", "null"]}}

    assert-all-equal \
            [::json::stringify2 {1 {key 1} 2 {x null} 3} \
                    -numberDictArrays 0 \
                    -schema array \
                    -compact 1] \
            {[1,{"key":1},2,{"x":null},3]}
    assert-all-equal \
            [::json::stringify2 {1 {key 1} 2 {x null} 3} \
                    -numberDictArrays 0 \
                    -schema array:string \
                    -compact 1] \
            {["1","key 1","2","x null","3"]}
    assert-all-equal \
            [::json::stringify2 {1 {key 1} 2 {x null}} \
                    -numberDictArrays 0 \
                    -schema object:string \
                    -compact 1] \
            {{"1":"key 1","2":"x null"}}
    assert-all-equal \
            [::json::stringify2 {0 {key 1} 1 {x null}} \
                    -schema array:string \
                    -compact 1] \
            {["key 1","x null"]}
    assert-all-equal \
            [::json::stringify2 {1 {key 1} 2 {x null}} \
                    -schema object:string \
                    -compact 1] \
            {{"1":"key 1","2":"x null"}}
    assert-all-equal \
            [::json::stringify2 {key {true false null}} \
                    -numberDictArrays 0 \
                    -schema object:array:string \
                    -compact 1] \
            {{"key":["true","false","null"]}}
}

# arguments tests
test arguments \
        -body {
    source arguments.tcl

    assert-all-equal \
            [::arguments::parse \
                    {-a first} \
                    {-b second 2 -c third blah} \
                    {-a 1 -c 3}] \
            [dict create {*}{second 2 third 3 first 1}]
    assert-all-equal \
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
            assert-all-equal [test-url $url] $index
            assert-all-equal \
                    [test-url $url/does-not-exist] \
                    {<h1>Error 404: Not Found</h1> }
            assert-all-equal [test-url $url] $index

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
            assert-all-equal [test-url $url/quit] {Bye!}
        } finally {
            kill $pid
        }
    }
}

run-tests $argv
