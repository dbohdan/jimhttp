# An HTML templating DSL for Jim Tcl.
# Copyright (C) 2014 Danyil Bohdan, https://github.com/dbohdan/
# License: MIT

proc html::escape text {
    # A relatively slow hack.
    exec recode utf8..html << $text
}

proc html::tag {tag args} {
    set params {}
    if {[llength $args] > 1} {
        set params [lindex $args 0]
        set args [lrange $args 1 end]
    }

    set paramText {}
    foreach {name value} $params {
        append paramText " $name=\"$value\""
    }
    return "<$tag$paramText>[join $args ""]</$tag>"
}

proc html::tag-single {tag {params {}}} {
    set paramText {}
    foreach {name value} $params {
        append paramText " $name=\"$value\""
    }
    return "<$tag$paramText>"
}

# Zip together (transpose) lists.
proc html::zip args {
    set columns $args
    set nColumns [llength $columns]
    set loopArgument {}

    # Generate loop command argument in the form of v0 list0 v1 list1, etc.
    set variables [lmap i [range $nColumns] { list v$i }]
    foreach i [range $nColumns] column $columns {
        lappend loopArgument v$i [lindex $args $i]
    }

    set result {}
    foreach {*}$loopArgument {
        lappend result [lmap var $variables { set $var }]
    }
    puts $result
    return $result
}

# Don't use static variables for Tcl compatibility.
foreach tag {html body table td tr a div pre form textarea h1} {
    proc $tag args [
        format {html::tag %s {*}$args} $tag
    ]
}
foreach tag {input submit br hr} {
    proc $tag args [
        format {html::tag-single %s {*}$args} $tag
    ]
}

proc html::table-row args {
    tr "" {*}[lmap cell $args { td "" $cell }]
}

proc html::table args {
    table {} {*}[
        lmap row [html::zip {*}$args] {
            html::table-row {*}$row
        }
    ]
}
