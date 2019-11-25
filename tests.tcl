#!/usr/bin/env jimsh
# Tests for the web framework and its modules.
# Copyright (c) 2014, 2015, 2016, 2018, 2019 dbohdan.
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


    assert-equal [::http::string-bytefirst c abcdef] 2
    assert-equal [::http::string-bytefirst f abcdef] 5
    assert-equal [::http::string-bytefirst е тест] 2
    assert-equal [::http::string-bytefirst world helloworld] 5
    assert-equal [::http::string-bytefirst тест мегатест] 8


    set seq ----sepfoo----сепbar----sepbaz\u0001----sep
    assert-equal [::http::string-pop seq ----sep] {}
    assert-equal [::http::string-pop seq ----сеп] foo
    assert-equal [::http::string-pop seq --sep]   bar--
    assert-equal [::http::string-pop seq ----sep] baz\u0001
    assert-equal [::http::string-pop seq ----sep] {}
    assert-equal $seq {}


    set postString "
Content-Disposition: form-data; name=\"image file\" filename=\"bar.png\"
Content-Type: application/octet-stream

\u00ff\u00ff\u00ff\u0001\u0002\u0003\u0004\u0005
------------------------38d79e1985ee3bbf"
    assert-equal [::http::string-pop postString \
                                     ------------------------38d79e1985ee3bbf] \
                "
Content-Disposition: form-data; name=\"image file\" filename=\"bar.png\"
Content-Type: application/octet-stream

\u00ff\u00ff\u00ff\u0001\u0002\u0003\u0004\u0005
"
    assert-equal $postString {}

    set contentType {multipart/form-data; boundary=------------------------38d79e1985ee3bbf}
    set formData "--------------------------38d79e1985ee3bbf
Content-Disposition: form-data; name=\"text\"

This is text.
--------------------------38d79e1985ee3bbf
Content-Disposition: form-data; name=\"text file\" filename=\"foo.txt\"

Hello.
--------------------------38d79e1985ee3bbf
Content-Disposition: form-data; name=\"image file\" filename=\"bar.png\"
Content-Type: application/octet-stream

\u00ff\u0001\u0002\u0003\u0004\u0005
--------------------------38d79e1985ee3bbf"
    set result [list \
        formPost \
        [list text "This is text." \
              {image file} \u00ff\u0001\u0002\u0003\u0004\u0005 \
              {text file} Hello.] \
    ]
    assert-equal [::http::parse-multipart-data $formData $contentType \n] \
                 $result
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

    # String escaping.

    assert-equal [::json::stringify {"Hello, world!"}] \
                 {"\"Hello, world!\""}
    assert-equal [::json::stringify2 "a\nb" \
                                     -schema string] \
                 {"a\nb"}

    assert-equal [::json::stringify2 "a/b/c/ c:\\b\\a\\" \
                                     -schema string] \
                 {"a/b/c/ c:\\b\\a\\"}

    assert-equal [::json::stringify2 "\b\f\n\r\t" \
                                     -schema string] \
                 {"\b\f\n\r\t"}

    set s {}
    for {set i 0} {$i < 32} {incr i} {
        append s [format %c $i]
    }
    assert-equal [::json::stringify2 $s -schema string] \
                 \"[join [list \\u0000 \\u0001 \\u0002 \\u0003 \
                               \\u0004 \\u0005 \\u0006 \\u0007 \
                               \\b     \\t     \\n     \\u000b \
                               \\f     \\r     \\u000e \\u000f \
                               \\u0010 \\u0011 \\u0012 \\u0013 \
                               \\u0014 \\u0015 \\u0016 \\u0017 \
                               \\u0018 \\u0019 \\u001a \\u001b \
                               \\u001c \\u001d \\u001e \\u001f] {}]\"
    assert-equal [::json::parse [::json::stringify2 $s -schema string]] \
                 $s
    unset s
    # Only perform the following test if [regexp] supports Unicode character
    # indices or this isn't a UTF-8 build.
    if {[regexp -inline -start 1 . こ] eq {}} {
        assert-equal [::json::parse {{"тест": "こんにちは世界"}}] \
        {тест こんにちは世界}
    }

    assert-equal [::json::stringify2 {{"key space"} value}] \
                 {{"\"key space\"": "value"}}

    assert-equal [::json::stringify2 {<script>"use strict";</script>} \
                                     -schema string] \
                 {"<script>\"use strict\";<\/script>"}

    # Tokenization errors.

    catch {::json::tokenize {blah blah blah}} errorResult
    assert-equal $errorResult {can't tokenize value as JSON: {blah blah blah}}

    catch [list ::json::tokenize [string repeat {blah } 299]blah] errorResult
    set s "can't tokenize value as JSON: \"[string repeat {blah } 30]... "
    append s [string repeat {blah } 29]blah\"
    assert-equal $errorResult $s
    unset s

    catch {::json::analyze-boolean-or-null nope 0} errorResult
    assert-equal $errorResult {can't parse value as JSON true/false/null: nope}

    catch {::json::analyze-string {\"trailin'} 0} errorResult
    assert-equal $errorResult {can't parse JSON string: {\"trailin'}}

    catch {::json::analyze-number NaN 0} errorResult
    assert-equal $errorResult {can't parse JSON number: NaN}
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
            set fileOrig /tmp/jimhttp.test
            set fileEcho /tmp/jimhttp.test.echo

            set s {}
            for {set i 0} {$i < 256} {incr i} {
                append s [binary format c [rand 256]]
            }
            set ch [open $fileOrig wb]
            puts -nonewline $ch $s
            close $ch

            test-url -o $fileEcho \
                     -X POST \
                     -F testfile=@$fileOrig \
                     $url/file-echo

            set contentsOrig [::http::read-file $fileOrig]
            set contentsEcho [::http::read-file $fileEcho]

            assert [list \
                    [string bytelength $contentsOrig] == \
                    [string bytelength $contentsEcho]] \
                    "file corruption test file size"
            assert [expr {$contentsOrig eq $contentsEcho}] \
                    "file corruption test file contents"

            file delete $fileOrig
            file delete $fileEcho
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
