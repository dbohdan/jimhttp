# A basic Redis client library.  Pronounced "regime" for some reason.
# Copyright (c) 2019 D. Bohdan
# License: MIT

namespace eval rejim {
    variable version 0.0.0
}


proc rejim::parse handle {
    set typeByte [$handle read 1]
    set firstData [string byterange [read-until $handle \r] 0 end-1]
    $handle read 1  ;# Discard \n.

    set type {}
    set contents {}

    switch -- $typeByte {
        + -
        - {
            set type $($typeByte eq {+} ? {simple} : {error})
            return [list $type $firstData]
        }

        : {
            return [list integer $firstData]
        }

        $ {
            set len $firstData
            if {$len == -1} {
                return null
            }
            if {$len < -1} {
                error [list invalid bulk string length: $len]
            }

            set data [$handle read $len]
            $handle read 2  ;# Discard \r\n.

            return [list bulk $data]
        }

        * {
            set n $firstData
            if {$n < 0} {
                error [list invalid number of array elements: $n]
            }

            set list {}
            for {set i 0} {$i < $n} {incr i} {
                lappend list [parse $handle]
            }

            return [concat array $list]
        }

        default {
            error [list unknown message type: $typeByte]
        }
    }
}


proc rejim::read-until {handle needle} {
    # We only use this proc to find short strings.  The performance of reading
    # one byte at a time shouldn't matter.
    if {[string bytelength $needle] != 1} {
        error [list $needle isn't one byte]
    }

    set data {}

    while true {
        if {[$handle eof]} break
        set last [$handle read 1]
        append data $last
        if {$last eq $needle} break
    }

    if {$last ne $needle} {
        error [list stream ended before $needle]
    }

    return $data
}


proc rejim::serialize list {
    set resp *[llength $list]\r\n
    foreach el $list {
        append resp $[string bytelength $el]\r\n$el\r\n
    }

    return $resp
}
