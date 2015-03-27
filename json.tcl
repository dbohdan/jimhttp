# JSON parser / encoder.
# Copyright (C) 2014, 2015 Danyil Bohdan.
# License: MIT

# Parse the string $str containing JSON into nested Tcl dictionaries.
# numberDictArrays: decode arrays as dictionaries with sequential integers
# starting with zero as keys; otherwise decode them as lists.
namespace eval ::json {}

proc ::json::parse {str {numberDictArrays 0}} {
    set result [::json::decode-value $str $numberDictArrays]
    if {[lindex $result 1] eq ""} {
        return [lindex $result 0]
    } else {
        error "trailing garbage after JSON data: $str"
    }
}

proc ::json::number-dict? {dictionary} {
    set allNumericKeys 1
    set i 0
    foreach {key value} $dictionary {
        set allNumericKeys [expr {$allNumericKeys && ($key == $i)}]
        if {!$allNumericKeys} {
            return 0
        }
        incr i
    }
    return 1
}

# Serialize nested Tcl dictionaries as JSON.
#
# numberDictArrays: encode dictionaries with keys {0 1 2 3 ...} as arrays, e.g.,
# {0 a 1 b} to ["a", "b"]. Without numberDictArrays set stringify will *only*
# try to produce objects from Tcl lists or dictionaries.
#
# schema: data types for values in $dictionaryOrValue. $schema consists of
# nested dictionaries where the keys are either those in $dictionaryOrValue or
# their superset and the values specify data types. Those values can each be
# one of "array", "boolean", "null", "number", "object" or "string".
proc ::json::stringify {dictionaryOrValue {numberDictArrays 1} {schema ""}} {
    set result {}
    if {([llength $dictionaryOrValue] <= 1) &&
            ($schema ni {"array" "object"})} {
        # Value.
        set isNumber [expr {
            ($schema in {"" "number"}) &&
            ([string is integer $dictionaryOrValue] ||
                    [string is double $dictionaryOrValue])
        }]
        set isBoolean [expr {
            ($schema in {"" "boolean"}) &&
            ($dictionaryOrValue in {"true" "false" 0 1})
        }]
        set isNull [expr {
            ($schema in {"" "null"}) &&
            ($dictionaryOrValue eq "null")
        }]

        if {$isNumber || $isBoolean || $isNull} {
            # Map 0/1 values explicitly marked as boolean to false/true.
            if {($schema eq "boolean") && ($dictionaryOrValue in {0 1})} {
                set dictionaryOrValue \
                        [string map {0 false 1 true} $dictionaryOrValue]
            }
            set result $dictionaryOrValue
        } elseif {$schema in {"" "string"}} {
            set result "\"$dictionaryOrValue\""
        } else {
            error "invalid schema \"$schema\" for value \"$dictionaryOrValue\""
        }
    } else {
        # Dictionary.
        set isArray [expr {
            ($schema eq "array") ||
            (($schema ne "object") &&
                    $numberDictArrays &&
                    [number-dict? $dictionaryOrValue])
        }]
        set isObject [expr {
            ($schema eq "object") ||
            ([llength $dictionaryOrValue] % 2 == 0)
        }]

        if {$isArray} {
            # Produce array.
            set arrayElements {}
            foreach {key value} $dictionaryOrValue {
                if {$schema ne ""} {
                    set valueSchema [list [dict get $schema $key]]
                } else {
                    set valueSchema ""
                }
                lappend arrayElements [::json::stringify $value 1 $valueSchema]
            }
            set result "\[[join $arrayElements {, }]\]"
        } elseif {$isObject} {
            # Produce object.
            set objectDict {}
            foreach {key value} $dictionaryOrValue {
                if {$schema ne ""} {
                    set valueSchema [dict get $schema $key]
                } else {
                    set valueSchema ""
                }
                lappend objectDict "\"$key\": [::json::stringify $value \
                        $numberDictArrays $valueSchema]"
            }
            set result "{[join $objectDict {, }]}"
        } else {
            error "invalid schema \"$schema\" for value \"$dictionaryOrValue\""
        }
    }
    return $result
}

# Choose how to decode a JSON value. Return a list consisting of the result of
# parsing the initial part of $str and the remainder of $str that was not
# parsed. E.g., ::json::decode-value {"string", 55} returns {{string} {, 55}}.
proc ::json::decode-value {str {numberDictArrays 0}} {
    set str [string trimleft $str]
    switch -regexp -- $str {
        {^\"} {
            return [::json::decode-string $str]
        }
        {^[0-9-]} {
            return [::json::decode-number $str]
        }
        {^\{} {
            return [::json::decode-object $str $numberDictArrays]
        }
        {^\[} {
            return [::json::decode-array $str $numberDictArrays]
        }
        {^(true|false|null)} {
            return [::json::decode-boolean-or-null $str]
        }
        default {
            error "cannot decode value as JSON: \"$str\""
        }
    }
}

# Return a list of two elements: the initial part of $str parsed as "true",
# "false" or "null" and the remainder of $str that wasn't parsed.
proc ::json::decode-boolean-or-null {str} {
    regexp {^(true|false|null)} $str value
    return [list $value [string range $str [string length $value] end]]
}

# Return a list of two elements: the initial part of $str parsed as a JSON
# string and the remainder of $str that wasn't parsed.
proc ::json::decode-string {str} {
    if {[regexp {^"((?:[^"\\]|\\.)*)"} $str _ result]} {
        return [list \
                [subst -nocommands -novariables $result] \
                [string range $str [expr {2 + [string length $result]}] end]]
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
# dictionaries with numbers {0 1 2 ...} as keys if $numberDictArrays is true
# or lists if it is false. E.g., if $numberDictArrays == 1 then
# ["Hello, World" 2048] is converted to {0 {Hello, World!} 1 2048}; otherwise
# it is converted to {{Hello, World!} 2048}.
proc ::json::decode-array {str {numberDictArrays 0}} {
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
        # Empty array => break out of the loop.
        if {[string index [string trimleft $str] 0] eq "\]"} {
            set str [string range [string trimleft $str] 1 end]
            break
        }

        # Value.
        lassign [::json::decode-value $str $numberDictArrays] value str
        set str [string trimleft $str]
        if {$numberDictArrays} {
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
proc ::json::decode-object {str {numberDictArrays 0}} {
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
        # Empty object => break out of the loop.
        if {[string index $str 0] eq "\}"} {
            set str [string range $str 1 end]
            break
        }
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
        lassign [::json::decode-value $str $numberDictArrays] value str
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
