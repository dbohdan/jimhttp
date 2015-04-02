[![Build Status](https://travis-ci.org/dbohdan/jimhttp.svg)](https://travis-ci.org/dbohdan/jimhttp)

A web microframework prototype for [Jim Tcl](http://jim.tcl.tk/). Provides a
rough implementation of the HTTP protocol as well as routing, templates, JSON
generation and parsing, an HTML DSL and persistent storage powered by SQLite3.

# Use examples
```Tcl
source http.tcl

::http::add-handler GET /hello/:name/:town {
    return [::http::make-response \
            "Hello, $routeVars(name) from $routeVars(town)!"]
}

::http::start-server 127.0.0.1 8080
```

```Tcl
source http.tcl
source storage.tcl

::http::add-handler GET /counter-persistent {{counter 0}} {
    ::storage::restore-statics

    incr counter

    ::storage::persist-statics
    return [::http::make-response $counter]
}

::storage::init
::http::start-server 127.0.0.1 8080
```
# Requirements

Compile Jim Tcl 0.76 or later from the Git repository. Previous stable
releases (0.75 or earlier) will not work. You will need an SQLite3 development
package (`libsqlite3-dev` on Debian/Ubuntu, `libsqlite3x-devel` on
Fedora) and `asciidoc` to create the documentation (don't use
`--disable-docs` then).

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

then pointing your web browser at <http://localhost:8080/>.

## Vagrant

The development environment can be set up for you automatically if you
have VirtualBox and [Vagrant](https://www.vagrantup.com/downloads.html)
installed.

Run the following commands in the terminal:

```sh
git clone https://github.com/dbohdan/jimhttp.git
cd jimhttp/vagrant
vagrant up
```

and open <http://localhost:8080/>. Go to <http://localhost:8080/quit> to restart
the server when you edit `example.tcl`.

Stop the VM with

    vagrant halt

Run the server again with

    vagrant up

# License

MIT.

`static.jpg` photo by [Steven Lewis](http://notsteve.com/). License:
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).
