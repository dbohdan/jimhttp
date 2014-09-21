A web microframework prototype for [Jim Tcl](http://jim.tcl.tk/). Provides a
rough implementation of the HTTP protocol, routing, templates, an HTML DSL and
persistent storage powered by SQLite3.

# Use examples
```Tcl
source http.tcl

http::add-handler GET /hello/:name/:town {
    return [http::make-response \
            "Hello, $routeVars(name) from $routeVars(town)!"]
}

http::start-server 127.0.0.1 8080
```

```Tcl
source http.tcl
source storage.tcl

http::add-handler GET /counter-persistent {{counter 0}} {
    storage::restore-statics

    incr counter

    storage::persist-statics
    return [http::make-response $counter]
}

storage::init
http::start-server 127.0.0.1 8080
```

# Requirements

Compile the latest Jim Tcl from the Git repository. The current stable release
(0.75) or earlier releases will not work.

```sh
git clone https://github.com/msteveb/jimtcl.git
cd jimtcl
./configure --with-ext="oo tree binary sqlite3" --enable-utf8 --ipv6
make
sudo make install
```

# License

MIT.

`static.jpg` photo by [Steven Lewis](http://notsteve.com/). License:
[CC0](https://creativecommons.org/publicdomain/zero/1.0/).
