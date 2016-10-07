# Process command line arguments.
# Copyright (C) 2014, 2015, 2016 dbohdan.
# License: MIT
namespace eval ::arguments {
    variable version 1.0.0
}

# Return a dict mapping varNames to command line argument values.
# mandatoryArguments: a list {-arg varName ...}
# optionalArguments: a dict {-optArg varName defaultValue ...}
proc ::arguments::parse {mandatoryArguments optionalArguments argv} {
    set result {}
    set error [catch {
        foreach {argument key defaultValue} $optionalArguments {
            if {[dict exists $argv $argument]} {
                lappend result $key [dict get $argv $argument]
            } else {
                lappend result $key $defaultValue
            }
            dict unset argv $argument
        }
        foreach {argument key} $mandatoryArguments {
            if {[dict exists $argv $argument]} {
                lappend result $key [dict get $argv $argument]
            } else {
                error "missing argument: $argument"
            }
            dict unset argv $argument
        }
    } errorMessage]
    if {$error} {
        error "cannot parse arguments ($errorMessage)"
    }
    if {$argv ne ""} {
        error "unknown argument(s): $argv"
    }
    return [dict create {*}$result]
}

# Return a usage message.
proc ::arguments::usage {mandatoryArguments optionalArguments argv0} {
    set result {}
    append result "usage: $argv0"
    foreach {argument key} $mandatoryArguments {
        append result " $argument $key"
    }
    foreach {argument key defaultValue} $optionalArguments {
        append result " \[$argument $key\]"
    }
    return $result
}
