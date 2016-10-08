#!/usr/bin/env jimsh
# A test framework similar to tcltest.
# Copyright (C) 2014, 2015, 2016 dbohdan.
# License: MIT

namespace eval ::testing {
    variable version 0.2.0

    namespace export *
    variable tests {}
    variable constraints {}
}
namespace eval ::testing::tests {}

# Generate an error with $expression is not true.
proc ::testing::assert {expression {message ""}} {
    if {![expr $expression]} {
        set errorMessage "Not true: $expression"
        if {$message ne ""} {
            append errorMessage " ($message)"
        }
        error $errorMessage
    }
}

# Compare all args for equality.
proc ::testing::assert-equal args {
    set firstArg [lindex $args 0]
    foreach arg [lrange $args 1 end] {
        assert [list \"$arg\" eq \"$firstArg\"]
    }
}

# Tell if we are running Tcl 8.x or Jim Tcl.
proc ::testing::interpreter {} {
    if {[catch {info tclversion}]} {
        return jim
    } else {
        return tcl
    }
}

# Return a value from dictionary like dict get would if it is there.
# Otherwise return the default value.
proc ::testing::dict-default-get {default dictionary args} {
    if {[dict exists $dictionary {*}$args]} {
        dict get $dictionary {*}$args
    } else {
        return $default
    }
}

# Create a new test $name with code $code.
proc ::testing::test args {
    variable tests

    set name [lindex $args 0]
    set options [lrange $args 1 end]
    proc ::testing::tests::$name {} [dict get $options -body]
    dict set tests $name constraints [dict-default-get "" $options -constraints]
}

# Return 1 if all constraints listed for test $test are satisfied in
# $::testing::constraints.
proc ::testing::constraints-satisfied? test {
    variable tests
    variable constraints

    foreach constraint [dict get $tests $test constraints] {
        if {$constraint ni $constraints} {
            return 0
        }
    }
    return 1
}


# Run all or selected tests.
proc ::testing::run-tests argv {
    variable constraints
    lappend constraints [::testing::interpreter]

    lassign $argv testsToRun
    set tests {}
    foreach testProc [info procs ::testing::tests::*] {
        lappend tests [namespace tail $testProc]
    }
    if {$testsToRun in {"" "all"}} {
        set testsToRun $tests
    }
    foreach test $testsToRun {
        if {[::testing::constraints-satisfied? $test]} {
            puts "running test \"$test\""
            ::testing::tests::$test
        }
    }
}
