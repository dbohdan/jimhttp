# A basic Redis client library.  Pronounced "regime" for some reason.
# Copyright (c) 2019 D. Bohdan
# License: MIT

namespace eval rejim {
    variable version 0.0.0
}


proc rejim::parse {message {start 0}} {
    set typeChar [string byterange $message $start $start]
    set newlineIndex [first-char $message \r $start]
    if {$newlineIndex == -1} {
        error [list can't find \\r in [string byterange $message $start end]]
    }
    set firstData [string byterange $message $start+1 $newlineIndex-1]
    set nextIndex $($newlineIndex + 2)

    set end {}
    set type {}
    set contents {}

    switch -- $typeChar {
        + -
        - {
            set type $($typeChar eq {+} ? {simple} : {error})
            return [list $nextIndex $type $firstData]
        }

        : {
            return [list $nextIndex integer $firstData]
        }

        $ {
            set len $firstData
            if {$len == -1} {
                return [list $nextIndex null]
            }
            if {$len < -1} {
                error [list invalid bulk string length: $len]
            }

            set data [string byterange $message \
                                       $nextIndex \
                                       $($nextIndex + $len - 1)]
            return [list $($nextIndex + $len + 2) bulk $data]
        }

        * {
            set n $firstData
            if {$n < 0} {
                error [list invalid number of array elements: $n]
            }

            set list {}
            for {set i 0} {$i < $n} {incr i} {
                set el [lassign [parse $message $nextIndex] nextIndex]
                lappend list $el
            }

            return [concat $nextIndex array $list]
        }

        default {
            error [list unknown message type: $typeChar]
        }
    }
}


proc rejim::first-char {str c {start 0}} {
    # We can't use [string first] or [regexp] here.  In a UTF-8 build
    # [string first] counts Unicode characters.  [regexp] will stop at the
    # first \0.  We could make a wrapper around [regexp] for performance, but
    # it should not matter.  We only use this proc to find short string
    # fragments.
    set bytes [string bytelength $str]
    for {set i $start} {$i < $bytes} {incr i} {
        if {[string byterange $str $i $i] eq $c} {
            return $i
        }
    }

    return -1
}


proc rejim::serialize list {
    set resp *[llength $list]\r\n
    foreach el $list {
        append resp $[string bytelength $el]\r\n$el\r\n
    }

    return $resp
}
