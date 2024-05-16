#! /usr/bin/env jimsh
# A test framework with constraints.
# Copyright (c) 2014-2016, 2019 D. Bohdan.
# License: MIT.

namespace eval ::testing {
    variable version 0.5.0

    namespace export *
    variable tests {}
    variable constraints {}
}
namespace eval ::testing::tests {}

# Generate an error with $expression is not true.
proc ::testing::assert {expression {message ""}} {
    if {![uplevel 1 [list expr $expression]]} {
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
proc ::testing::engine {} {
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

proc ::testing::unsat-constraints test {
    variable tests
    variable constraints

    set unsat {}

    foreach constraint [dict get $tests $test constraints] {
        if {$constraint ni $constraints} {
            lappend unsat $constraint
        }
    }

    return $unsat
}


# Run all or selected tests.
proc ::testing::run-tests argv {
    variable constraints
    lappend constraints [::testing::engine]

    set testsToRun $argv
    set tests {}
    foreach testProc [lsort [info procs ::testing::tests::*]] {
        lappend tests [namespace tail $testProc]
    }
    if {$testsToRun in {"" "all"}} {
        set testsToRun $tests
    }

    set failed {}
    set skipped {}

    puts {running tests:}
    foreach test $tests {
        if {$test ni $testsToRun} {
            lappend skipped $test {user choice}
            continue
        }

        set unsat [::testing::unsat-constraints $test]
        if {$unsat eq {}} {
            puts "- $test"
            if {[catch {
                ::testing::tests::$test
            } msg opts]} {
                set stacktrace [expr {
                    [::testing::engine] eq {jim}
                    ? [errorInfo $msg [dict get $opts -errorinfo]]
                    : [dict get $opts -errorinfo]
                }]
                puts "failed: $stacktrace"
                lappend failed $test $opts
            }
        } else {
            lappend skipped $test [concat constraints: $unsat]
        }
    }

    if {$skipped ne {}} {
        puts \nskipped:
    }
    foreach {test reason} $skipped {
        puts "- $test ($reason)"
    }

    set n(total)    [llength $tests]
    set n(skipped)  [expr {[llength $skipped] / 2}]
    set n(failed)   [expr {[llength $failed] / 2}]
    set n(passed)   [expr {$n(total) - $n(skipped) - $n(failed)}]
    puts \n[list total    $n(total) \
                 passed   $n(passed) \
                 skipped  $n(skipped) \
                 failed   $n(failed)]

    if {$failed ne {}} {
        exit 1
    }
}
