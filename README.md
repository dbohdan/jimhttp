# jimhttp

A collection of standalone libraries and a web microframework prototype for
[Jim Tcl](http://jim.tcl-lang.org/).  Most of the libraries also work in
Tcl&nbsp;8.x.  The libraries implement command line and proc argument parsing,
an HTML DSL, parsing and generating JSON, templates, and persistent storage
powered by SQLite3.  The web microframework provides a rough implementation of
the HTTP/1.1 protocol and a routing DSL.

## Components

The components listed below work in Tcl 8.5, Tcl 8.6, Tcl 8.7a3, and Jim Tcl
0.76 or later unless indicated otherwise.  Each component is versioned
separately.  Component version numbers follow [semantic
versioning](http://semver.org/spec/v2.0.0.html).  A major version number of zero
indicates an unstable API.

| Filename | Function | Version |
|----------|----------|---------|
| [arguments.tcl](arguments.tcl) | Command line argument parsing. | 1.0.0 |
| [example.tcl](example.tcl)&#x200A;<sup>1</sup> | A sample web server that demonstrates the use of the other components. | — |
| [entities.tcl](entities.tcl) | A dictionary mapping characters to HTML entities. | 1.0.0 |
| [html.tcl](html.tcl) | A DSL for HTML generation.  Requires entities.tcl. | 0.2.1 |
| [http.tcl](http.tcl)&#x200A;<sup>1</sup> | The titular web microframework.  Requires mime.tcl. | 0.15.2 |
| [json.tcl](json.tcl) | JSON generation with schema support.&#x200A;<sup>3</sup>  JSON parsing.&#x200A;<sup>4</sup> | 2.1.3 |
| [mime.tcl](mime.tcl) | Rudimentary MIME type detection based on the file extension. | 1.2.0 |
| [rejim.tcl](rejim.tcl)&#x200A;<sup>2</sup> | A basic RESP2 Redis/Valkey client. | 0.2.0 |
| [storage.tcl](storage.tcl)&#x200A;<sup>1</sup> | SQLite persistence of static variables. | 0.2.0 |
| [template.tcl](template.tcl) | [tmpl_parser](https://wiki.tcl-lang.org/20363) templating. | 1.0.0 |
| [testing.tcl](testing.tcl) | A test framework with support for tcltest-style constraints. | 0.5.0 |
| [tests.tcl](tests.tcl) | Tests for the other components.&#x200A;<sup>5</sup> | — |

1\. Jim Tcl-only.

2\. Does not support Tcl 8.5.

3\. Schemas define data types.  See the example below.

4\. **Warning:** parsing is fairly slow in general and extremely slow in UTF-8
builds of Jim Tcl.  ([Obsolete benchmark](https://wiki.tcl-lang.org/48500).)
This may matter to you if you need to decode more than a few dozen KiB of JSON
at a time.  Since version 0.79 Jim Tcl can be built with a fast binary
extension for parsing and encoding JSON.   The
[jq module](https://wiki.tcl-lang.org/11630) is an option for faster JSON
parsing in earlier versions.  It requires an external binary.

5\. Only compatible components are tested in Tcl 8.

## Use examples

### http.tcl

```Tcl
source http.tcl

::http::add-handler GET /hello/:name/:town {
    ::http::respond [::http::make-response \
            "Hello, $routeVars(name) from $routeVars(town)!"]
}

::http::start-server 127.0.0.1 8080
```

### http.tcl and storage.tcl

```Tcl
source http.tcl
source storage.tcl

::http::add-handler GET /counter-persistent {{counter 0}} {
    ::storage::restore-statics

    incr counter

    ::storage::persist-statics
    ::http::respond [::http::make-response $counter]
}

::storage::init
::http::start-server 127.0.0.1 8080
```

### json.tcl

```Tcl
# This produces the output
# {"a": "123", "b": 123, "c": [123, 456], "d": "true", "e": true}
source json.tcl

puts [::json::stringify {
    a 123
    b 123
    c {123 456}
    d true
    e true
} 0 {
    a string
    c {N* number}
    d string
}]
```

## Requirements

Compile Jim Tcl 0.76 or later from its Git repository.  Stable releases prior
to that (0.75 and earlier) will not work.  You will need an SQLite3 development
package (`libsqlite3-dev` on Debian and Ubuntu, `libsqlite3x-devel` on
Fedora, `sqlite3-devel` on openSUSE Tumbleweed) to do this and optionally
AsciiDoc (`asciidoc` on Debian and Ubuntu, Fedora,  and openSUSE) to generate
the documentation (don't use the option `--disable-docs` in that case).

```sh
git clone https://github.com/msteveb/jimtcl.git
cd jimtcl
./configure --with-ext="oo tree binary sqlite3" --enable-utf8 --ipv6 --disable-docs
make
sudo make install
```

Once you have installed Jim Tcl you can clone this repository and try out the
example by running

```sh
git clone https://github.com/dbohdan/jimhttp.git
cd jimhttp
jimsh example.tcl
```

and then pointing your web browser at <http://localhost:8080/>.

## License

MIT.

`static.jpg` photo by [Steven Lewis](http://notsteve.com/). License:
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).
