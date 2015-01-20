# Simple persistent key-value storage.
# Copyright (C) 2014, 2015 Danyil Bohdan.
# License: MIT
namespace eval ::storage {}

set ::storage::db {}

# Open the SQLite3 database in the file $filename. Create the table if needed.
proc ::storage::init {{filename ""}} {
    global ::storage::db

    if {$filename eq  ""} {
        set filename [file join [file dirname [info script]] "storage.sqlite3"]
    }

    if {$::storage::db eq ""} {
        set ::storage::db [sqlite3.open $filename]
        $::storage::db query {
            CREATE TABLE IF NOT EXISTS storage(
                key TEXT PRIMARY KEY,
                value TEXT
            );
        }
    }
}

# Store $value under $key.
proc ::storage::put {key value} {
    global ::storage::db
    $::storage::db query {
        INSERT OR REPLACE INTO storage(key, value) VALUES ('%s', '%s');
    } $key $value
}

# Return the value under $key or "" if it doesn't exist.
proc ::storage::get {key} {
    global ::storage::db
    # The return format of query is {{key value ...} ...}.
    lindex [lindex [$::storage::db query {
        SELECT value FROM storage WHERE key = '%s' LIMIT 1;
    } $key] 0] 1
}

# Return 1 if a value exists under $key or 0 otherwise.
proc ::storage::exists {key} {
    global ::storage::db
    # The return format of query is {{key value ...} ...}.
    lindex [lindex [$::storage::db query {
        SELECT EXISTS(SELECT value FROM storage WHERE key = '%s' LIMIT 1);
    } $key] 0] 1
}

# Store the values of the global variables listed in varNameList.
proc ::storage::persist-globals {varNameList} {
    foreach varName $varNameList {
        global $varName
        ::storage::set $varName [set $varName]
    }
}

# Set the global variables listed in varNameList to their stored values.
proc ::storage::restore-globals {varNameList} {
    foreach varName $varNameList {
        global $varName
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
