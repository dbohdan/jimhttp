# Templating engine.
# Copyright (c) 2014-2016 D. Bohdan.
# License: MIT.
namespace eval ::template {
    variable version 1.0.0
}

# Convert a template into Tcl code.
proc ::template::parse {template} {
    set result {}
    set regExpr {^(.*?)<%(.*?)%>(.*)$}
    set listing "set _output {}\n"
    while {[regexp $regExpr $template \
            match preceding token template]} {
        append listing [list append _output $preceding]\n
        switch -exact -- [string index $token 0] {
            = {
                append listing \
                        [format {append _output [expr %s]} \
                                [list [string range $token 1 end]]]
            }
            ! {
                append listing \
                        [format {append _output [%s]} \
                                [string range $token 1 end]]
            }
            default {
                append listing $token
            }
        }
        append listing \n
    }
    append listing [list append _output $template]\n
    return $listing
}
