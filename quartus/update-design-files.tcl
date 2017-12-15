
package require Tcl 8.5
package require cmdline
package require ::quartus::project

# -----------------------------------------------------------------
# Most frequently used Quartus II file types
# -----------------------------------------------------------------
#
set file_type_assignment_name(.sv)   SYSTEMVERILOG_FILE
set file_type_assignment_name(.v)    VERILOG_FILE
set file_type_assignment_name(.vhd)  VHDL_FILE
set file_type_assignment_name(.qsys) QSYS_FILE
set file_type_assignment_name(.qip)  QIP_FILE
set file_type_assignment_name(.sdc)  SDC_FILE
set file_type_assignment_name(.tcl)  TCL_FILE
set file_type_assignment_name(.stp)  SIGNALTAP_FILE

# -----------------------------------------------------------------
# Remove previous source files assignments from Quartus project
# -----------------------------------------------------------------
#
proc remove_file_assignments {} {
    global file_type_assignment_name

    foreach idx [array names file_type_assignment_name] {
        remove_all_global_assignments -name $file_type_assignment_name($idx)
    }

    remove_all_global_assignments -name USE_SIGNALTAP_FILE
    remove_all_global_assignments -name ENABLE_SIGNALTAP
}

# -----------------------------------------------------------------
# Get assignment name from file extension
# -----------------------------------------------------------------
#
proc get_file_assignment_name {fname} {
    global file_type_assignment_name

    set ext [file extension $fname]

    if {[info exists file_type_assignment_name($ext)]} {
        return $file_type_assignment_name($ext)
    } else {
        error "File '$fname' has unknown design file type\n"
    }
}

# -----------------------------------------------------------------
# Update files assignments for Quartus II project
# -----------------------------------------------------------------
#
proc update_file_assignments {file_list} {

    foreach file $file_list {
        set file_type [get_file_assignment_name $file]

        set_global_assignment -name $file_type $file

        # Enable SignalTap for project
        if {[string match [file extension $file] ".stp"]} {
            set_global_assignment -name USE_SIGNALTAP_FILE $file
            set_global_assignment -name ENABLE_SIGNALTAP ON
        }
    }
}

# -----------------------------------------------------------------
# Apply assignments to Quartus II project
# -----------------------------------------------------------------
#

# Setup command line interface
set cmdline_params {
    {p.arg        ""  "Name of Quartus II project"}
}

set cmdline_usage "\nUsage: $argv0 -p <project> <list of filenames>"

set usage_sel [catch {
    array set cmdline_options [ \
        cmdline::getoptions ::argv $cmdline_params $cmdline_usage \
    ]
}]

# Display usage message
if {$usage_sel} {
    puts ""
    puts [cmdline::usage $cmdline_params $cmdline_usage]
    exit 0
}

set qprj_name               $cmdline_options(p)
set qprj_name_is_def        [llength $qprj_name]

set design_files            $argv
set design_files_is_def     [llength $design_files]

# Check arguments
if {!($qprj_name_is_def && $design_files_is_def)} {
    puts "You should define command line arguments!"
    puts ""
    puts [cmdline::usage $cmdline_params $cmdline_usage]
    exit 1
}

set update_ena        0
set need_to_close_prj 0

# If project name defined, check Quartus II project
if {[is_project_open]} {
    # Compare opened and specified projects
    if {[string compare $quartus(project) $qprj_name]} {
        error "\nQuartus II project opened, but it is not '$qprj_name'!\n"
    } else {
        set update_ena 1
    }
} else {
    if {[project_exists $qprj_name]} {
        project_open -current_revision $qprj_name
        set update_ena        1
        set need_to_close_prj 1
    } else {
        error "\nProject '$qprj_name' does not exists!\n"
    }
}

if {$update_ena} {
    # Remove previous assignments
    remove_file_assignments

    # New assignments
    update_file_assignments $design_files

    # Commit assignments
    export_assignments
}

if {$need_to_close_prj} {
    project_close
}

