# JSON parser / encoder.
# Copyright (C) 2014, 2015 Danyil Bohdan.
# License: MIT

### The public API: will remain backwards compatible for a major release
### version of this module.

namespace eval ::json {
    variable version 1.3.2
}

# Parse the string $str containing JSON into nested Tcl dictionaries.
# numberDictArrays: decode arrays as dictionaries with sequential integers
# starting with zero as keys; otherwise decode them as lists.
proc ::json::parse {str {numberDictArrays 0}} {
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
# numberDictArrays: encode dictionaries with keys {0 1 2 3 ...} as arrays, e.g.,
# {0 a 1 b} to ["a", "b"]. If numberDictArrays is not true stringify will try to
# produce objects from all Tcl lists and dictionaries unless explicitly told
# otherwise in the schema.
#
# schema: data types for values in $dictionaryOrValue. $schema consists of
# nested dictionaries where the keys are either those in $dictionaryOrValue or
# their superset and the values specify data types. Those values can each be
# one of "array", "boolean", "null", "number", "object" or "string" as well as
# "array:(element type)" and "object:(element type)".
#
# strictSchema: generate an error if there is no schema for a value in
# $dictionaryOrValue.
#
# compact: no decorative whitespace.
proc ::json::stringify {dictionaryOrValue {numberDictArrays 1} {schema ""}
        {strictSchema 0} {compact 0}} {
    lassign [::json::array-schema $schema] schemaArray _
    lassign [::json::object-schema $schema] schemaObject _

    if {$schema eq "string"} {
        return "\"$dictionaryOrValue\""
    }

    if {([llength $dictionaryOrValue] <= 1) &&
            !$schemaArray && !$schemaObject} {
        if {
                ($schema in {"" "number"}) &&
                ([string is integer -strict $dictionaryOrValue] ||
                        [string is double -strict $dictionaryOrValue])
        } {
            return $dictionaryOrValue
        } elseif {
                ($schema in {"" "boolean"}) &&
                ($dictionaryOrValue in {"true" "false" 0 1})
        } {
            return [string map {0 false 1 true} $dictionaryOrValue]
        } elseif {
                ($schema in {"" "null"}) &&
                ($dictionaryOrValue eq "null")
        } {
            return $dictionaryOrValue
        } elseif {$schema eq ""} {
            return "\"$dictionaryOrValue\""
        } else {
            error "invalid schema \"$schema\" for value \"$dictionaryOrValue\""
        }
    } else {
        # Dictionary or list.
        set validDict [expr { [llength $dictionaryOrValue] % 2 == 0 }]
        set isArray [expr {
            ($numberDictArrays &&
                    !$schemaObject &&
                    $validDict &&
                    [::json::number-dict? $dictionaryOrValue]) ||

            (!$numberDictArrays && $schemaArray)
        }]

        if {$isArray} {
            return [::json::stringify-array $dictionaryOrValue \
                    $numberDictArrays $schema $strictSchema $compact]
        } elseif {$validDict} {
            return [::json::stringify-object $dictionaryOrValue \
                    $numberDictArrays $schema $strictSchema $compact]
        } else {
            error "invalid schema \"$schema\" for value \"$dictionaryOrValue\""
        }
    }
    error {this should not be reached}
}

# A convenience wrapper for ::json::stringify with named parameters.
proc ::json::stringify2 {dictionaryOrValue args} {
    set numberDictArrays [::json::get-arg $args -numberDictArrays 1]
    set schema [::json::get-arg $args -schema {}]
    set strictSchema [::json::get-arg $args -strictSchema 0]
    set compact [::json::get-arg $args -compact 0]

    return [::json::stringify \
            $dictionaryOrValue $numberDictArrays $schema $strictSchema $compact]
}

### The private API: can change at any time.

## Utility procedures.

# If $argument is a key in $dictionary return its value. If not, return
# $default.
proc ::json::get-arg {dictionary argument default} {
    if {[dict exists $dictionary $argument]} {
        return [dict get $dictionary $argument]
    } else {
        return $default
    }
}

## Procedures used by ::json::stringify.

# Returns a list of two values: whether the $schema is a schema for an array and
# the "subschema" after "array:", if any.
proc ::json::array-schema {schema {numberDictArrays 1}} {
    return [list [expr {
        ($schema eq "array") || [string match "array:*" $schema]
    }] [string range $schema 6 end]]
}

# Returns a list of two values: whether the $schema is a schema for an object
# and the "subschema" after "object:", if any.
proc ::json::object-schema {schema {numberDictArrays 1}} {
    return [list [expr {
        ($schema eq "object") || [string match "object:*" $schema]
    }] [string range $schema 7 end]]
}

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

# Return the value for key $key from $schema if the key is present. Otherwise
# either return the default value "" or, if $strictSchema is true, generate an
# error.
proc ::json::get-schema-by-key {schema key {strictSchema 0}} {
    if {[dict exists $schema $key]} {
        set valueSchema [dict get $schema $key]
    } else {
        if {$strictSchema} {
            error "missing schema for key \"$key\""
        } else {
            set valueSchema {}
        }
    }
}

proc ::json::stringify-array {array {numberDictArrays 1} {schema ""}
        {strictSchema 0} {compact 0}} {
    set arrayElements {}
    lassign [json::array-schema $schema] schemaArray subschema

    if {$numberDictArrays} {
        foreach {key value} $array {
            if {($schema eq "") || $schemaArray} {
                set valueSchema $subschema
            } else {
                set valueSchema [::json::get-schema-by-key \
                        $schema $key $strictSchema]
            }
            lappend arrayElements [::json::stringify $value 1 \
                    $valueSchema $strictSchema]
        }
    } else { ;# list arrays
        foreach value $array valueSchema $schema {
            if {($schema eq "") || $schemaArray} {
                set valueSchema $subschema
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

proc ::json::stringify-object {dictionary {numberDictArrays 1} {schema ""}
        {strictSchema 0} {compact 0}} {
    set objectDict {}
    lassign [::json::object-schema $schema] schemaObject subschema

    if {$compact} {
        set elementSeparator ,
        set keyValueSeparator :
    } else {
        set elementSeparator {, }
        set keyValueSeparator {: }
    }

    foreach {key value} $dictionary {
        if {($schema eq "") || $schemaObject} {
            set valueSchema $subschema
        } else {
            set valueSchema [::json::get-schema-by-key \
                    $schema $key $strictSchema]
        }
        lappend objectDict "\"$key\"$keyValueSeparator[::json::stringify \
                $value $numberDictArrays $valueSchema $strictSchema $compact]"
    }

    return "{[join $objectDict $elementSeparator]}"
}

## Procedures used by ::json::parse.

# Returns a list consisting of two elements: the decoded value and a number
# indicating how many tokens from $tokens were consumed to obtain that value.
proc ::json::decode {tokens numberDictArrays} {
    set tokensConsumed 0
    set nextToken [list {} {
        uplevel 1 {
            set token [lindex $tokens 0]
            set tokens [lrange $tokens 1 end]
            lassign $token type arg
            incr tokensConsumed
        }
    }]
    set errorMessage [list message {
        upvar 1 tokens tokens
        if {[llength $tokens] > 0} {
            set max 5
            set context [lrange $tokens 0 $max-1]
            if {[llength $tokens] >= $max} {
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
        return [list $arg $tokensConsumed]
    } elseif {$type eq "OPEN_CURLY"} {
        # Object.
        set object {}
        set first 1

        while 1 {
            apply $nextToken

            if {$type eq "CLOSE_CURLY"} {
                return [list $object $tokensConsumed]
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

            lassign [::json::decode $tokens $numberDictArrays] \
                    value tokensInValue
            lappend object $key $value
            set tokens [lrange $tokens $tokensInValue end]
            incr tokensConsumed $tokensInValue

            set first 0
        }
    } elseif {$type eq "OPEN_BRACKET"} {
        # Array.
        set array {}
        set i 0

        while 1 {
            apply $nextToken

            if {$type eq "CLOSE_BRACKET"} {
                return [list $array $tokensConsumed]
            }

            if {$i > 0} {
                if {$type eq "COMMA"} {
                    apply $nextToken
                } else {
                    apply $errorMessage "array expected a comma, got $token"
                }
            }

            # Put the last token back into the token list for recursive
            # decoding.
            set tokens [list $token {*}$tokens]
            incr tokensConsumed -1

            lassign [::json::decode $tokens $numberDictArrays] \
                    value tokensInValue
            if {$numberDictArrays} {
                lappend array $i $value
            } else {
                lappend array $value
            }
            set tokens [lrange $tokens $tokensInValue end]
            incr tokensConsumed $tokensInValue

            incr i
        }
    } else {
        if {$token eq ""} {
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
                set value [::json::analyze-string [string range $json $i end]]
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
                    set value [::json::analyze-number \
                            [string range $json $i end]]
                    lappend tokens [list NUMBER $value]

                    incr i [expr {[string length $value] - 1}]
                } elseif {$char in {t f n}} {
                    set value [::json::analyze-boolean-or-null \
                            [string range $json $i end]]
                    lappend tokens [list RAW $value]

                    incr i [expr {[string length $value] - 1}]
                } else {
                    error "can't tokenize value as JSON: [list $json]"
                }
            }
        }
    }
    return $tokens
}

# Return the beginning of $str parsed as "true", "false" or "null".
proc ::json::analyze-boolean-or-null str {
    regexp {^(true|false|null)} $str value
    if {![info exists value]} {
        error "can't parse value as JSON true/false/null: [list $str]"
    }
    return $value
}

# Return the beginning of $str parsed as a JSON string.
proc ::json::analyze-string str {
    if {[regexp {^"((?:[^"\\]|\\.)*)"} $str _ result]} {
        return $result
    } else {
        error "can't parse JSON string: [list $str]"
    }
}

# Return $str parsed as a JSON number.
proc ::json::analyze-number str {
    if {[regexp -- {^-?(?:0|[1-9][0-9]*)(?:\.[0-9]*)?(:?(?:e|E)[+-]?[0-9]*)?} \
            $str result]} {
        #            [][ integer part  ][ optional  ][  optional exponent  ]
        #            ^ sign             [ frac. part]
        return $result
    } else {
        error "can't parse JSON number: [list $str]"
    }
}
