# Native equivalents for the few POSIX file commands in upstream IP scripts.
# All mutations are restricted to the disposable ow/ staging tree.
set ::ow_stage [file normalize [file join [file dirname [info script]] ../ow]]
proc ow_check_path {path} {
    set p [file normalize $path]
    if {![string match -nocase "${::ow_stage}/*" $p]} {
        error "Refusing build mutation outside ow staging tree: $p"
    }
    return $p
}
rename exec ow_native_exec
proc exec {args} {
    set cmd [lindex $args 0]
    if {$cmd eq "rm"} {
        foreach p [lrange $args 1 end] {
            if {[string match -* $p]} {continue}
            file delete -force [ow_check_path $p]
        }
        return ""
    }
    if {$cmd eq "cp"} {
        set paths {}
        foreach p [lrange $args 1 end] {
            if {![string match -* $p]} {lappend paths $p}
        }
        if {[llength $paths] != 2} {error "Unsupported cp form: $args"}
        lassign $paths src dst
        ow_check_path $dst
        if {[string match */. $src]} {
            file mkdir $dst
            foreach f [glob -nocomplain -directory [string range $src 0 end-2] *] {
                file copy -force $f $dst
            }
        } else {
            file copy -force $src $dst
        }
        return ""
    }
    return [uplevel 1 [list ow_native_exec {*}$args]]
}
