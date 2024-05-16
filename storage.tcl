# Simple persistent key-value storage.
# Copyright (c) 2014-2016 D. Bohdan.
# License: MIT.
namespace eval ::storage {
    variable version 0.2.0
}

set ::storage::db [proc ::storage::not-initialized args {
    error {::storage::db isn't initialized}
}]

# Open the SQLite3 database in the file $filename. Create the table if needed.
proc ::storage::init {{filename ""}} {
    if {$filename eq ""} {
        set filename [file join [file dirname [info script]] storage.sqlite3]
    }

    set ::storage::db [sqlite3.open $filename]
    $::storage::db query {
        CREATE TABLE IF NOT EXISTS storage(
            key TEXT PRIMARY KEY,
            value TEXT
        );
    }
}

# Store $value under $key.
proc ::storage::put {key value} {
    $::storage::db query {
        INSERT OR REPLACE INTO storage(key, value) VALUES ('%s', '%s');
    } $key $value
}

# Return the value under $key or "" if it doesn't exist.
proc ::storage::get {key} {

    # The return format of query is {{key value ...} ...}.
    lindex [lindex [$::storage::db query {
        SELECT value FROM storage WHERE key = '%s' LIMIT 1;
    } $key] 0] 1
}

# Return 1 if a value exists under $key or 0 otherwise.
proc ::storage::exists {key} {
    # The return format of query is {{key value ...} ...}.
    lindex [lindex [$::storage::db query {
        SELECT EXISTS(SELECT value FROM storage WHERE key = '%s' LIMIT 1);
    } $key] 0] 1
}

# Store the values of the variables listed in varNameList.
proc ::storage::persist-var {varNameList} {
    foreach varName $varNameList {
        ::storage::put $varName [set $varName]
    }
}

# Set the variables listed in varNameList to their stored values.
proc ::storage::restore-var {varNameList} {
    foreach varName $varNameList {
        set $varName [::storage::get $varName]
    }
}

proc ::storage::caller-full-name {{level 1}} {
    # Get the caller proc name without the namespace.
    set procName [lindex [split \
            [lindex [info level -$level] 0] ::] end]
    # Get the caller proc namespace. This is needed to handle nested
    # namespaces since [info level] will only tell us the direct parent
    # namespace of the proc.
    set procNamespace [uplevel $level {namespace current}]
    return ${procNamespace}::${procName}
}

# Store the values of the static variables either of proc $procName or the
# caller proc if $procName is "".
proc ::storage::persist-statics {{procName ""}} {
    if {$procName eq ""} {
        set procName [::storage::caller-full-name 2]
    }
    foreach {key value} [info statics $procName] {
        ::storage::put ${procName}::${key} $value
    }
}

# Set the static variables of the caller proc to their stored values.
proc ::storage::restore-statics {} {
    set procName [::storage::caller-full-name 2]
    foreach {varName _} [info statics $procName] {
        set key ${procName}::${varName}
        if {[::storage::exists $key]} {
            uplevel 1 [list set $varName [::storage::get $key]]
        }
    }
}
