A web microframework prototype for [Jim Tcl](http://jim.tcl.tk/). Provides a rough implementation of the HTTP protocol, routing, an HTML DSL and persistent storage powered by SQLite3.

# Use examples
```Tcl
source http.tcl

http::add-handler /hello/:name/:town {
    return [list "Hello, $routeVars(name) from $routeVars(town)!"]
}

http::start-server 127.0.0.1 8080
```

```Tcl
source http.tcl
source storage.tcl

http::add-handler /counter-persistent {{counter 0}} {
    storage::restore-statics

    incr counter

    storage::persist-statics
    return [list $counter]
}

storage::init
http::start-server 127.0.0.1 8080
```

# Requirements
Compile the latest Jim Tcl from the Git repository. The current stable release (0.75) or earlier releases will not work.

```
git clone https://github.com/msteveb/jimtcl.git
cd jimtcl
./configure --with-ext="oo tree binary sqlite3" --enable-utf8 --ipv6
make
sudo make install
```
