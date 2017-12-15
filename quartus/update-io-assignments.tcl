# -----------------------------------------------------------------
# 2/21/2012 D. W. Hawkins (dwh@ovro.caltech.edu)
#
# The Tcl procedures in this constraints file can be used by
# project synthesis files to setup the default device constraints
# and pinout.
#
# Modified by Golovchenko Aleksey, 06/2017
# -----------------------------------------------------------------

package require Tcl 8.5
package require cmdline
package require ::quartus::project

# -----------------------------------------------------------------
# Set default assignments
# -----------------------------------------------------------------
#
proc set_default_io_assignments {unused_io default_io_std dual_purpose_pins} {

    # Tri-state unused I/O
    set_global_assignment -name RESERVE_ALL_UNUSED_PINS $unused_io

    # Default IO_STANDARD 2.5 V
    set_global_assignment -name STRATIX_DEVICE_IO_STANDARD $default_io_std

    # Dual-purpose pins
    set_global_assignment -name CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION \
        $dual_purpose_pins
}

# -----------------------------------------------------------------
# Set Quartus pin assignments
# -----------------------------------------------------------------
#
# This procedure parses the entries in the Tcl pin constraints
# array and issues Quartus Tcl constraints commands.
#
proc set_pin_assignments {pinarr} {
    upvar $pinarr pin

    # Loop over each pin in the design
    foreach port [array names pin] {

        # Convert the pin assignments into an options list,
        # eg., {PIN = AV22} { IOSTD = LVDS}
        set options [split $pin($port) ,]

        foreach option $options {

            # Split each option into a key/value pair
            set keyval [split $option =]
            set key [lindex $keyval 0]
            set val [lindex $keyval 1]

            # Strip leading and trailing whitespace
            # and force to uppercase
            set key [string toupper [string trim $key]]
            set val [string toupper [string trim $val]]

            # Make the Quartus assignments
            #
            # The keys used in the assignments list are an abbreviation of
            # the Quartus setting name. The abbreviations supported are;
            #
            #   DRIVE   = drive current
            #   HOLD    = bus hold (ON/OFF)
            #   IOSTD   = I/O standard
            #   PIN     = pin number/name
            #   PULLUP  = weak pull-up (ON/OFF)
            #   SLEW    = slew rate (a number between 0 and 3)
            #   TERMIN  = input termination (string value)
            #   TERMOUT = output termination (string value)
            #
            switch $key {
                DRIVE   {set_instance_assignment -name CURRENT_STRENGTH_NEW $val -to $port}
                HOLD    {set_instance_assignment -name ENABLE_BUS_HOLD_CIRCUITRY $val -to $port}
                IOSTD   {set_instance_assignment -name IO_STANDARD $val -to $port}
                PIN     {set_location_assignment -to $port "Pin_$val"}
                PULLUP  {set_instance_assignment -name WEAK_PULL_UP_RESISTOR $val -to $port}
                SLEW    {set_instance_assignment -name SLEW_RATE $val -to $port}
                TERMIN  {set_instance_assignment -name INPUT_TERMINATION $val -to $port}
                TERMOUT {set_instance_assignment -name OUTPUT_TERMINATION $val -to $port}
                default {error "Unknown setting: KEY = '$key', VALUE = '$val'"}
            }
        }
    }
}

# -----------------------------------------------------------------
# Remove all I/O assignments
# -----------------------------------------------------------------
#

proc remove_all_pin_assignments {} {

    set assignment_names { \
        CURRENT_STRENGTH_NEW \
        ENABLE_BUS_HOLD_CIRCUITRY \
        IO_STANDARD \
        LOCATION \
        WEAK_PULL_UP_RESISTOR \
        SLEW_RATE \
        INPUT_TERMINATION \
        OUTPUT_TERMINATION}

    foreach name $assignment_names {
        remove_all_instance_assignments -name $name -to *
    }
}

# -----------------------------------------------------------------
# Update I/O assignments
# -----------------------------------------------------------------
#

# Setup command line interface
set cmdline_params {
    {p.arg        ""  "Name of Quartus II project"}
    {f.arg        ""  "Script with user I/O assignments"}
}

set cmdline_usage ": utility for update Quartus II project I/O assignment"

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

set qprj_name                 $cmdline_options(p)
set qprj_name_def             [llength $qprj_name]
set user_assignments_file     $cmdline_options(f)
set user_assignments_file_def [llength $user_assignments_file]

# Check arguments
if {!($qprj_name_def && $user_assignments_file_def)} {
    puts "You should define command line arguments!"
    puts ""
    puts [cmdline::usage $cmdline_params $cmdline_usage]
    exit 1
}

# Check that file 'design_files_script' exists
if {![file exists $user_assignments_file]} {
    error "\nUser assignments file does not exists!\n"
}

# If project name defined, check Quartus II project
if {[is_project_open]} {
    # Compare opened and specified projects
    if {[string compare $quartus(project) $qprj_name]} {
        error "\nQuartus II project opened, but it is not '$qprj_name'!\n"
    }
} else {
    if {[project_exists $qprj_name]} {
        project_open -current_revision $qprj_name
    } else {
        error "\nProject '$qprj_name' does not exists!\n"
    }
}

# variables must be defined in '$user_assignments_file':
# UNUSED_IO
# DEFAULT_IO_STD
# DUAL_PURPOSE_PINS
# PIN array
source $user_assignments_file

# remove previous assignments
remove_all_pin_assignments

# Set new I/O assignments
set_default_io_assignments $UNUSED_IO $DEFAULT_IO_STD $DUAL_PURPOSE_PINS
set_pin_assignments PIN

# Commit assignments
export_assignments

project_close
