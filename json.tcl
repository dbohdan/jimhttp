# JSON parser/serializer.
# Copyright (c) 2014-2019, 2024 D. Bohdan.
# License: MIT.
#
# This library is compatible with Tcl 8.5-9 and Jim Tcl 0.76 and later.
# However, to work with unescaped UTF-8 JSON strings
# in a UTF-8 build of Jim Tcl,
# you will need version a more recent version: 0.79 or later.

### The public API: will remain backwards compatible
### for a major release version of this module.

namespace eval ::json {
    variable version 3.0.0

    variable everyElement *element*
    variable everyValue *value*
}

# Parse the string $str containing JSON into nested Tcl dictionaries.
#
# numberDictArrays: decode arrays as dictionaries with sequential integers
# starting at zero as keys; otherwise, decode them as lists.
proc ::json::parse {str {numberDictArrays 1}} {
    set tokens [::json::tokenize $str]
    set result [::json::decode $tokens $numberDictArrays]
    if {[lindex $result 1] == [llength $tokens]} {
        return [lindex $result 0]
    } else {
        error "trailing garbage after JSON data in [list $str]"
    }
}

# Serialize nested Tcl dictionaries as JSON.
#
# numberDictArrays: encode dictionaries with keys {0 1 2 3 ...} as arrays,
# e.g., {0 a 1 b} as ["a", "b"].
# If $numberDictArrays false,
# stringify will try to produce objects from all Tcl lists and dictionaries
# unless explicitly told not to in the schema.
#
# schema: data types for the values in $data.
# $schema consists of nested lists
# and/or dictionaries that mirror the structure of the data in $data.
# Each value in $schema specifies the data type of the corresponding value
# in $data.
# The type can be one of
# "array", "boolean, "null", "number", "object", or "string".
# The special dictionary key "*value*" in any dictionary in $schema
# sets the default data type for every value
# in the corresponding dictionary in $data.
# The key "*element*" does the same for the elements of an array.
# When $numberDictArrays is true,
# the key "*value*" forces a dictionary to be serialized as an object
# when it would have been serialized as an array by default
# (for example, the dictionary {0 foo 1 bar}).
# When $numberDictArrays is false,
# "*element*" forces a list to be serialized
# as an array rather than an object.
# A list that uses "*element*"  must start with it:
# {*element* defaultType type1 type2 ...}.
#
# strictSchema: generate an error if there is no schema for a value in $data.
#
# compact: no decorative whitespace.
proc ::json::stringify {
    data
    {numberDictArrays 1}
    {schema {}}
    {strictSchema 0}
    {compact 0}
} {
    if {$schema eq "string"} {
        return \"[::json::escape-string $data]\"
    }

    set validDict [expr {
        [llength $data] % 2 == 0
    }]
    set schemaValidDict [expr {
        [llength $schema] % 2 == 0
    }]

    set schemaForceArray [expr {
        ($schema eq "array") ||
        ([lindex $schema 0] eq $::json::everyElement) ||
        ($numberDictArrays && $schemaValidDict &&
                [dict exists $schema $::json::everyElement]) ||
        (!$numberDictArrays && $validDict && $schemaValidDict &&
                ([llength $schema] > 0) &&
                (![::json::subset [dict keys $schema] [dict keys $data]]))
    }]

    set schemaForceObject [expr {
        ($schema eq "object") ||
        ($schemaValidDict && [dict exists $schema $::json::everyValue])
    }]

    if {([llength $data] <= 1) &&
            !$schemaForceArray && !$schemaForceObject} {
        if {
                ($schema in {{} "number"}) &&
                ([string is integer -strict $data] ||
                        [string is double -strict $data])
        } {
            return $data
        } elseif {
                ($schema in {{} "boolean"}) &&
                ($data in {true false on off yes no 1 0})
        } {
            return [string map {
                0 false
                off false
                no false

                1 true
                on true
                yes true
            } $data]
        } elseif {
                ($schema in {{} "null"}) &&
                ($data eq "null")
        } {
            return $data
        } elseif {$schema eq {}} {
            return \"[escape-string $data]\"
        } else {
            error "invalid schema \"$schema\" for value \"$data\""
        }
    } else {
        # Dictionary or list.
        set isArray [expr {
            !$schemaForceObject &&
            (($numberDictArrays && $validDict &&
                            [::json::number-dict? $data]) ||
                    (!$numberDictArrays && !$validDict) ||
                    ($schemaForceArray && (!$numberDictArrays || $validDict)))
        }]

        if {$isArray} {
            return [::json::stringify-array $data \
                    $numberDictArrays $schema $strictSchema $compact]
        } elseif {$validDict} {
            return [::json::stringify-object $data \
                    $numberDictArrays $schema $strictSchema $compact]
        } else {
            error "invalid schema \"$schema\" for list \"$data\""
        }
    }
    error {this should not be reached}
}

# A convenience wrapper for ::json::stringify with named parameters.
proc ::json::stringify2 {data args} {
    set numberDictArrays  [::json::get-option  -numberDictArrays 1  ]
    set schema            [::json::get-option  -schema {}           ]
    set strictSchema      [::json::get-option  -strictSchema 0      ]
    set compact           [::json::get-option  -compact 0           ]
    if {[llength [dict keys $args]] > 0} {
        error "unknown options: [dict keys $args]"
    }

    return [::json::stringify \
            $data $numberDictArrays $schema $strictSchema $compact]
}

### The private API: can change at any time.

## Utility procedures.

# If $option is a key in $args of the caller,
# unset it and return its value.
# If not, return $default.
proc ::json::get-option {option default} {
    upvar args dictionary
    if {[dict exists $dictionary $option]} {
        set result [dict get $dictionary $option]
        dict unset dictionary $option
    } else {
        set result $default
    }
    return $result
}

# Return 1 if the elements in $a are a subset of those in $b
# and 0 otherwise.
proc ::json::subset {a b} {
    set keySet {}
    foreach x $a {
        dict set keySet $x 1
    }
    foreach x $b {
        dict unset keySet $x
    }
    return [expr {[llength $keySet] == 0}]
}

## Procedures used by ::json::stringify.

# Return 1 if the keys in dictionary are numbers 0, 1, 2... and 0 otherwise.
proc ::json::number-dict? {dictionary} {
    set i 0
    foreach {key _} $dictionary {
        if {$key != $i} {
            return 0
        }
        incr i
    }
    return 1
}

# Return the value for key $key from $schema if the key is present.
# Otherwise, either return the default value {} or, if $strictSchema is true,
# generate an error.
proc ::json::get-schema-by-key {schema key {strictSchema 0}} {
    if {[dict exists $schema $key]} {
        set valueSchema [dict get $schema $key]
    } elseif {[dict exists $schema $::json::everyValue]} {
        set valueSchema [dict get $schema $::json::everyValue]
    } elseif {[dict exists $schema $::json::everyElement]} {
        set valueSchema [dict get $schema $::json::everyElement]
    } else {
        if {$strictSchema} {
            error "missing schema for key \"$key\""
        } else {
            set valueSchema {}
        }
    }
}

proc ::json::stringify-array {array {numberDictArrays 1} {schema {}}
        {strictSchema 0} {compact 0}} {
    set arrayElements {}
    if {$numberDictArrays} {
        foreach {key value} $array {
            if {($schema eq {}) || ($schema eq "array")} {
                set valueSchema {}
            } else {
                set valueSchema [::json::get-schema-by-key \
                        $schema $key $strictSchema]
            }
            lappend arrayElements [::json::stringify $value 1 \
                    $valueSchema $strictSchema]
        }
    } else { ;# list arrays
        set defaultSchema {}
        if {[lindex $schema 0] eq $::json::everyElement} {
            set defaultSchema [lindex $schema 1]
            set schema [lrange $schema 2 end]
        }
        foreach value $array valueSchema $schema {
            if {($schema eq {}) || ($schema eq "array")} {
                set valueSchema $defaultSchema
            }
            lappend arrayElements [::json::stringify $value 0 \
                    $valueSchema $strictSchema $compact]
        }
    }

    if {$compact} {
        set elementSeparator ,
    } else {
        set elementSeparator {, }
    }
    return "\[[join $arrayElements $elementSeparator]\]"
}

proc ::json::stringify-object {dictionary {numberDictArrays 1} {schema {}}
        {strictSchema 0} {compact 0}} {
    set objectDict {}
    if {$compact} {
        set elementSeparator ,
        set keyValueSeparator :
    } else {
        set elementSeparator {, }
        set keyValueSeparator {: }
    }

    foreach {key value} $dictionary {
        if {($schema eq {}) || ($schema eq "object")} {
            set valueSchema {}
        } else {
            set valueSchema [::json::get-schema-by-key \
                $schema $key $strictSchema]
        }
        lappend objectDict "\"[escape-string \
                $key]\"$keyValueSeparator[::json::stringify \
                $value $numberDictArrays $valueSchema $strictSchema $compact]"
    }

    return "{[join $objectDict $elementSeparator]}"
}

proc ::json::escape-string s {
    return [string map {
        \u0000 \\u0000
        \u0001 \\u0001
        \u0002 \\u0002
        \u0003 \\u0003
        \u0004 \\u0004
        \u0005 \\u0005
        \u0006 \\u0006
        \u0007 \\u0007
        \u0008 \\b
        \u0009 \\t
        \u000a \\n
        \u000b \\u000b
        \u000c \\f
        \u000d \\r
        \u000e \\u000e
        \u000f \\u000f
        \u0010 \\u0010
        \u0011 \\u0011
        \u0012 \\u0012
        \u0013 \\u0013
        \u0014 \\u0014
        \u0015 \\u0015
        \u0016 \\u0016
        \u0017 \\u0017
        \u0018 \\u0018
        \u0019 \\u0019
        \u001a \\u001a
        \u001b \\u001b
        \u001c \\u001c
        \u001d \\u001d
        \u001e \\u001e
        \u001f \\u001f
        \" \\\"
        \\ \\\\
        </  <\\/
    } $s]
}

## Procedures used by ::json::parse.

# Returns a list consisting of two elements:
# the decoded value and a number indicating
# how many tokens from $tokens were consumed to obtain that value.
proc ::json::decode {tokens numberDictArrays {startingOffset 0}} {
    set i $startingOffset
    set nextToken [list {} {
        uplevel 1 {
            set token [lindex $tokens $i]
            lassign $token type arg
            incr i
        }
    }]
    set errorMessage [list message {
        upvar 1 tokens tokens
        upvar 1 i i
        if {[llength $tokens] - $i > 0} {
            set max 5
            set context [lrange $tokens $i [expr {$i + $max - 1}]]
            if {[llength $tokens] - $i >= $max} {
                lappend context ...
            }
            append message " before $context"
        } else {
            append message " at the end of the token list"
        }
        uplevel 1 [list error $message]
    }]

    apply $nextToken

    if {$type in {STRING NUMBER RAW}} {
        return [list $arg [expr {$i - $startingOffset}]]
    } elseif {$type eq "OPEN_CURLY"} {
        # Object.
        set object {}
        set first 1

        while 1 {
            apply $nextToken

            if {$type eq "CLOSE_CURLY"} {
                return [list $object [expr {$i - $startingOffset}]]
            }

            if {!$first} {
                if {$type eq "COMMA"} {
                    apply $nextToken
                } else {
                    apply $errorMessage "object expected a comma, got $token"
                }
            }

            if {$type eq "STRING"} {
                set key $arg
            } else {
                apply $errorMessage "wrong key for object: $token"
            }

            apply $nextToken

            if {$type ne "COLON"} {
                apply $errorMessage "object expected a colon, got $token"
            }

            lassign [::json::decode $tokens $numberDictArrays $i] \
                    value tokensInValue
            lappend object $key $value
            incr i $tokensInValue

            set first 0
        }
    } elseif {$type eq "OPEN_BRACKET"} {
        # Array.
        set array {}
        set j 0

        while 1 {
            apply $nextToken

            if {$type eq "CLOSE_BRACKET"} {
                return [list $array [expr {$i - $startingOffset}]]
            }

            if {$j > 0} {
                if {$type eq "COMMA"} {
                    apply $nextToken
                } else {
                    apply $errorMessage "array expected a comma, got $token"
                }
            }

            # Use the last token as part of the value for recursive decoding.
            incr i -1

            lassign [::json::decode $tokens $numberDictArrays $i] \
                    value tokensInValue
            if {$numberDictArrays} {
                lappend array $j $value
            } else {
                lappend array $value
            }
            incr i $tokensInValue

            incr j
        }
    } else {
        if {$token eq {}} {
            apply $errorMessage "missing token"
        } else {
            apply $errorMessage "can't parse $token"
        }
    }

    error {this should not be reached}
}

# Transform a JSON blob into a list of tokens.
proc ::json::tokenize json {
    if {$json eq {}} {
        error {empty JSON input}
    }

    set tokens {}
    for {set i 0} {$i < [string length $json]} {incr i} {
        set char [string index $json $i]
        switch -exact -- $char {
            \" {
                set value [::json::analyze-string $json $i]
                lappend tokens \
                        [list STRING [subst -nocommand -novariables $value]]

                incr i [string length $value]
                incr i ;# For the closing quote.
            }
            \{ {
                lappend tokens OPEN_CURLY
            }
            \} {
                lappend tokens CLOSE_CURLY
            }
            \[ {
                lappend tokens OPEN_BRACKET
            }
            \] {
                lappend tokens CLOSE_BRACKET
            }
            , {
                lappend tokens COMMA
            }
            : {
                lappend tokens COLON
            }
            { } {}
            \t {}
            \n {}
            \r {}
            default {
                if {$char in {- 0 1 2 3 4 5 6 7 8 9}} {
                    set value [::json::analyze-number $json $i]
                    lappend tokens [list NUMBER $value]

                    incr i [expr {[string length $value] - 1}]
                } elseif {$char in {t f n}} {
                    set value [::json::analyze-boolean-or-null $json $i]
                    lappend tokens [list RAW $value]

                    incr i [expr {[string length $value] - 1}]
                } else {
                    parse-error {can't tokenize value as JSON: %s} $json
                }
            }
        }
    }
    return $tokens
}

# Return the beginning of $str parsed as "true", "false" or "null".
proc ::json::analyze-boolean-or-null {str start} {
    regexp -start $start {(true|false|null)} $str value
    if {![info exists value]} {
        parse-error {can't parse value as JSON true/false/null: %s} \
                    $str
    }
    return $value
}

# Return the beginning of $str parsed as a JSON string.
proc ::json::analyze-string {str start} {
    if {[regexp -start $start {"((?:[^"\\]|\\.)*)"} $str _ result]} {
        return $result
    } else {
        parse-error {can't parse JSON string: %s} $str
    }
}

# Return $str parsed as a JSON number.
proc ::json::analyze-number {str start} {
    if {[regexp -start $start -- \
            {-?(?:0|[1-9][0-9]*)(?:\.[0-9]*)?(:?(?:e|E)[+-]?[0-9]*)?} \
            $str result]} {
        #    [][ integer part  ][ optional  ][  optional exponent  ]
        #    ^ sign             [ frac. part]
        return $result
    } else {
        parse-error {can't parse JSON number: %s} $str
    }
}

# Return the error $formatString formatted with $str as its argument.
# $str is quoted and, if long, truncated.
proc ::json::parse-error {formatString json} {
    if {[string length $json] > 300} {
        set truncated "\"[string trimright [string range $json 0 149]] ... "
        append truncated [string trimleft [string range $json end-149 end]]\"
    } else {
        set truncated [list $json]
    }
    error [format $formatString $truncated]
}
