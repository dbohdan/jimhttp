# An HTML DSL for Jim Tcl.
# Copyright (C) 2014 Danyil Bohdan.
# License: MIT

# HTML entities processing code based on http://wiki.tcl.tk/26403.
source entities.tcl

set ::html::entitiesInverse [lreverse $::html::entities]

# Escape HTML entities in $text.
proc ::html::escape text {
    global ::html::entities
    string map $::html::entities $text
}

proc ::html::unescape text {
    global ::html::entitiesInverse
    string map $::html::entitiesInverse $text
}

# [::html::tag tag {attr1 val1} content] returns <tag attr1=val1>content</tag>
# [::html::tag tag content] returns <tag>content</tag>
proc ::html::tag {tag args} {
    # If there's only argument given treat it as tag content. If there is more
    # than one argument treat the first one as a tag attribute dict and the
    # rest as content.
    set attribs {}
    if {[llength $args] > 1} {
        set attribs [lindex $args 0]
        set args [lrange $args 1 end]
    }

    set attribText {}
    foreach {name value} $attribs {
        append attribText " $name=\"$value\""
    }
    return "<$tag$attribText>[join $args ""]</$tag>"
}

# [::html::tag tag {attr1 val1}] returns <tag attr1=val1>
proc ::html::tag-no-content {tag {attribs {}}} {
    set attribText {}
    foreach {name value} $attribs {
        append attribText " $name=\"$value\""
    }
    return "<$tag$attribText>"
}

proc ::html::make-tags {tagList {withContent 1}} {
    if {$withContent} {
        set procName ::html::tag
    } else {
        set procName ::html::tag-no-content
    }
    foreach tag $tagList {
        # Proc static variables are not use for the sake of Tcl compatibility.
        uplevel 1 [list proc $tag args [
            format {%s %s {*}$args} $procName $tag
        ]]
    }
}

# Here we actually create the tag procs.
::html::make-tags {head body table td tr ul li a div pre form textarea \
        h1 h2 h3 h4 h5 b i u s tt} 1
::html::make-tags {input submit br hr} 0
# Create the html tag proc as a special case.
proc html args {
    set result "<!DOCTYPE html>"
    append result [::html::tag html {*}$args]
    return $result
}

# Zip together (transpose) lists.
proc ::html::zip args {
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
    return $result
}

proc ::html::make-table-row args {
    tr "" {*}[lmap cell $args { td $cell }]
}

# Return an HTML table. Each argument is converted to a table row.
proc ::html::make-table args {
    table {} {*}[
        lmap row [::html::zip {*}$args] {
            ::html::make-table-row {*}$row
        }
    ]
}
