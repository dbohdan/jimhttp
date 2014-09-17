# Simple persistent storage for Jim Tcl.
# Copyright (C) 2014 Danyil Bohdan.
# License: MIT

set storage::db {}
set storage::varsToPersist {}

proc storage::init {{filename ""}} {
    global storage::db

    if {$filename eq  ""} {
        set filename [file join [file dirname [info script]] "storage.sqlite3"]
    }

    if {$storage::db eq ""} {
        set storage::db [sqlite3.open $filename]
        $storage::db query {
            CREATE TABLE IF NOT EXISTS storage(
                key TEXT PRIMARY KEY,
                value TEXT
            );
        }

        global storage::varsToPersist
        storage::restore-globals $storage::varsToPersist
    }
}

proc storage::put {key value} {
    global storage::db
    $storage::db query {
        INSERT OR REPLACE INTO storage(key, value) VALUES ('%s', '%s');
    } $key $value
}

proc storage::get {key} {
    global storage::db
    # The return format of query is {{key value ...} ...}.
    lindex [lindex [$storage::db query {
        SELECT value FROM storage WHERE key = '%s' LIMIT 1;
    } $key] 0] 1
}

proc storage::exists {key} {
    global storage::db
    # The return format of query is {{key value ...} ...}.
    lindex [lindex [$storage::db query {
        SELECT EXISTS(SELECT value FROM storage WHERE key = '%s' LIMIT 1);
    } $key] 0] 1
}

proc storage::persist-globals {varNameList} {
    foreach varName $varNameList {
        global $varName
        storage::set $varName [set $varName]
    }
}

proc storage::restore-globals {varNameList} {
    foreach varName $varNameList {
        global $varName
        set $varName [storage::get $varName]
    }
}

proc storage::caller-full-name {{level 1}} {
    # Get the caller proc name without the namespace.
    set procName [lindex [split \
            [lindex [info level -$level] 0] ::] end]
    # Get the caller proc namespace. This is needed to handle nested
    # namespaces since [info level] will only tell us the direct parent
    # namespace of the proc.
    set procNamespace [uplevel $level {namespace current}]
    return ${procNamespace}::${procName}
}

proc storage::persist-statics {{procName ""}} {
    if {$procName eq ""} {
        set procName [storage::caller-full-name 2]
    }
    foreach {key value} [info statics $procName] {
        storage::put ${procName}::${key} $value
    }
}

proc storage::restore-statics {} {
    set procName [storage::caller-full-name 2]
    foreach {varName _} [info statics $procName] {
        set key ${procName}::${varName}
        if {[storage::exists $key]} {
            uplevel 1 [list set $varName [storage::get $key]]
        }
    }
}
