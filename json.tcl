# JSON parser / encoder.
# Copyright (C) 2014 Danyil Bohdan.
# License: MIT

# Parse the string $str containing JSON into nested Tcl dictionaries.
# numberDicts: decode arrays as dictionaries with sequential integers starting
# with zero as keys; otherwise decode them as lists.
proc ::json::parse {str {numberDicts 0}} {
    set result [::json::decode-value $str $numberDicts]
    if {[lindex $result 1] eq ""} {
        return [lindex $result 0]
    } else {
        error "trailing garbage after JSON data: $str"
    }
}

# Serialize nested Tcl dictionaries as JSON.
# numberDicts: encode dictionaries with keys {0 1 2 3 ...} as arrays, e.g.,
# {0 a 1 b} to ["a", "b"].
proc ::json::stringify {dictionaryOrValue {numberDicts 1}} {
    set result {}
    if {[llength $dictionaryOrValue] <= 1} {
        if {[string is integer $dictionaryOrValue] || \
                [string is double $dictionaryOrValue]} {
            # Number.
            set result $dictionaryOrValue
        } else {
            # String.
            set result "\"$dictionaryOrValue\""
        }
    } else {
        # Dict.
        set allNumeric 1

        if {$numberDicts} {
            set values {}
            set i 0
            foreach {key value} $dictionaryOrValue {
                set allNumeric [expr {$allNumeric && ($key == $i)}]
                if {!$allNumeric} {
                    break
                }
                lappend values $value
                incr i
            }
        }

        if {$numberDicts && $allNumeric} {
            # Produce array.
            set arrayElements \
                    [lmap x $values {::json::stringify $x $numberDicts}]
            set result "\[[join $arrayElements {, }]\]"
        } else {
            # Produce object.
            set objectDict {}
            foreach {key value} $dictionaryOrValue {
                lappend objectDict "\"$key\": [::json::stringify \
                        $value $numberDicts]"
            }
            set result "{[join $objectDict {, }]}"
        }
    }
    return $result
}

# Choose how to decode a JSON value. Return a list consisting of the result of
# parsing the initial part of $str and the remainder of $str that was not
# parsed. E.g., ::json::decode-value {"string", 55} returns {{string} {, 55}}.
proc ::json::decode-value {str {numberDicts 0}} {
    set str [string trimleft $str]
    switch -regexp -- $str {
        {^\".*} {
            return [::json::decode-string $str]
        }
        {^[0-9-].*} {
            return [::json::decode-number $str]
        }
        {^\{.*} {
            return [::json::decode-object $str $numberDicts]
        }
        {^\[.*} {
            return [::json::decode-array $str $numberDicts]
        }
        {^(true|false|null)} {
            return [list $str {}]
        }
        default {
            error "cannot decode value as JSON: \"$str\""
        }
    }
}

# Return a list of two elements: the initial part of $str parsed as a JSON
# string and the remainder of $str that wasn't parsed.
proc ::json::decode-string {str} {
    if {[regexp {^"((?:[^"\\]|\\.)*)"} $str _ result]} {
        return [list \
                [subst -nocommands -novariables $result] \
                [string range $str [+ 2 [string length $result]] end]]
                # Add two to result length to account for the double quotes
                # around the string.
    } else {
        error "can't parse JSON string: $str"
    }
}

# Return a list of two elements: the initial part of $str parsed as a JSON
# number and the remainder of $str that wasn't parsed.
proc ::json::decode-number {str} {
    if {[regexp -- {^-?(?:0|[1-9][0-9]*)(?:\.[0-9]*)?(:?(?:e|E)[+-]?[0-9]*)?} \
            $str result]} {
        #            [][ integer part  ][ optional  ][  optional exponent  ]
        #            ^ sign             [ frac. part]
        return [list $result [string range $str [string length $result] end]]
    } else {
        error "can't parse JSON number: $str"
    }
}

# Return a list of two elements: the initial part of $str parsed as a JSON array
# and the remainder of $str that wasn't parsed. Arrays are parsed into
# dictionaries with numbers {0 1 2 ...} as keys if $numberDicts is true or lists
# if it is false. E.g., if $numberDicts == 1 then ["Hello, World" 2048] is
# converted to {0 {Hello, World!} 1 2048}; otherwise it is converted to
# {{Hello, World!} 2048}.
proc ::json::decode-array {str {numberDicts 0}} {
    set strInitial $str
    set result {}
    set value {}
    set i 0
    if {[string index $str 0] ne "\["} {
        error "can't parse JSON array: $strInitial"
    } else {
        set str [string range $str 1 end]
    }
    while 1 {
        # Value.
        lassign [::json::decode-value $str] value str
        set str [string trimleft $str]
        if {$numberDicts} {
            lappend result $i
        }
        lappend result $value

        # ","
        set sep [string index $str 0]
        set str [string range $str 1 end]
        if {$sep eq "\]"} {
            break
        } elseif {$sep ne ","} {
            error "can't parse JSON array: $strInitial"
        }
        incr i
    }
    return [list $result $str]
}

# Return a list of two elements: the initial part of $str parsed as a JSON
# object and the remainder of $str that wasn't parsed.
proc ::json::decode-object {str {numberDicts 0}} {
    set strInitial $str
    set result {}
    set value {}
    if {[string index $str 0] ne "\{"} {
        error "can't parse JSON object: $strInitial"
    } else {
        set str [string range $str 1 end]
    }
    while 1 {
        # Key string.
        set str [string trimleft $str]
        lassign [::json::decode-string $str] value str
        set str [string trimleft $str]
        lappend result $value

        # ":"
        set sep [string index $str 0]
        set str [string range $str 1 end]
        if {$sep ne ":"} {
            error "can't parse JSON object: $strInitial"
        }

        # Value.
        lassign [::json::decode-value $str $numberDicts] value str
        set str [string trimleft $str]
        lappend result $value

        # ","
        set sep [string index $str 0]
        set str [string range $str 1 end]
        if {$sep eq "\}"} {
            break
        } elseif {$sep ne ","} {
            error "can't parse JSON object: $str"
        }
    }
    return [list $result $str]
}
