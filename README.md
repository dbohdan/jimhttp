A prototype of a web framework for [Jim Tcl](http://jim.tcl.tk/).

# Use example
```Tcl
source http.tcl

http::add-handler /hello/:name/:town {
    return [list \
        200 \
        "Hello, [dict get $routeVars name] from [dict get $routeVars town]!"]
}

http::start-server 127.0.0.1 8080
```
