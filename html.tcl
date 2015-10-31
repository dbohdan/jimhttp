# An HTML DSL for Jim Tcl.
# Copyright (C) 2014, 2015 Danyil Bohdan.
# License: MIT

namespace eval ::html {
    variable version 0.2.1
}

# HTML entities processing code based on http://tcl.wiki/26403.
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
        proc [namespace parent]::$tag args [
            format {%s %s {*}$args} $procName $tag
        ]
    }
}

# Here we actually create the tag procs.
::html::make-tags {head title body table td tr th ul li a div pre p form \
        textarea h1 h2 h3 h4 h5 b i u s tt} 1
::html::make-tags {input submit br hr} 0
# Create the html tag proc as a special case.
proc html args {
    set result "<!DOCTYPE html>"
    append result [::html::tag html {*}$args]
    return $result
}

proc ::html::make-table-row {items {header 0}} {
    if {$header} {
        set command th
    } else {
        set command td
    }
    set cells {}
    foreach item $items {
        lappend cells [$command $item]
    }
    tr "" {*}$cells
}

# Return an HTML table. Each argument is converted to a table row.
proc ::html::make-table {rows {makeHeader 0}} {
    set rowsProcessed {}
    set header $makeHeader
    foreach row $rows {
        lappend rowsProcessed [::html::make-table-row $row $header]
        set header 0
    }
    table {} {*}$rowsProcessed
}
