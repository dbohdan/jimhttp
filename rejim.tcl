# A basic RESP2 Redis/Valkey client library.
# Pronounced "regime" for some reason.
# Copyright (c) 2019, 2020, 2024 D. Bohdan
# License: MIT

namespace eval rejim {
    variable version 0.2.0

    variable jim [expr { ![catch {
        proc x y {} {}
        rename x {}
    }] }]

    if {$jim} {
        proc byte-range {string first last} {
            string byterange $string $first $last
        }
        proc byte-length string {
            string bytelength $string
        }
    } else {
        proc byte-range {string first last} {
            string range $string $first $last
        }
        proc byte-length string {
            string length $string
        }
    }
}


proc rejim::command {handle commandList} {
    fconfigure $handle -translation binary -buffering none

    puts -nonewline $handle [serialize $commandList]
    set result [parse $handle]
    return $result
}


proc rejim::parse handle {
    fconfigure $handle -translation binary -buffering none

    set typeByte [read $handle 1]
    set firstData [byte-range [read-until $handle \r] 0 end-1]
    read $handle 1  ;# Discard \n.

    switch -- $typeByte {
        + -
        - {
            set type [expr { $typeByte eq {+} ? {simple} : {error} }]
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

            set data [read $handle $len]
            read $handle 2  ;# Discard \r\n.

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
    fconfigure $handle -translation binary -buffering none

    # We only use this proc to find short strings.  The performance of reading
    # one byte at a time shouldn't matter.
    if {[byte-length $needle] != 1} {
        error [list $needle isn't one byte]
    }

    set data {}

    while 1 {
        if {[eof $handle]} break
        set last [read $handle 1]
        append data $last
        if {$last eq $needle} break
    }

    if {[info exists last] && $last ne $needle} {
        error [list stream ended before $needle]
    }

    return $data
}


proc rejim::serialize list {
    set resp *[llength $list]\r\n
    foreach el $list {
        append resp $[byte-length $el]\r\n$el\r\n
    }

    return $resp
}


proc rejim::serialize-tagged tagged {
    set data [lassign $tagged tag]
    unset tagged

    switch -- $tag {
        array {
            return *[llength $data]\r\n[join [lmap x $data {
                serialize-tagged $x
            }] {}]
        }

        bulk {
            return \$[byte-length $data]\r\n$data\r\n
        }

        error -
        integer -
        simple {
            set c [dict get {
                error -
                integer :
                simple +
            } $tag]

            return $c$data\r\n
        }

        null {
            return \$-1\r\n
        }

        default {
            error [list unknown tag: $tag]
        }
    }
}


proc rejim::strip-tags {response {null %NULL%}} {
    set tag [lindex $response 0]

    switch -- $tag {
        bulk -
        error -
        integer -
        simple {
            return [lindex $response 1]
        }

        null {
            return $null
        }

        array {
            return [lmap x [lrange $response 1 end] {
                strip-tags $x $null
            }]
        }

        default {
            error [list unknown tag: $tag]
        }
    }
}
