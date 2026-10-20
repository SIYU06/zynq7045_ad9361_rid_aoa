# Upgrade the user's dma_project in place after all IP have been packaged.
set script_dir [file normalize [file dirname [info script]]]
set root [file normalize $script_dir/..]
set ::ow_stage [file normalize $root/ow]
set action [lindex $argv 0]
if {$action eq ""} {set action validate}
if {$action ni {validate synth impl}} {error "Use validate, synth or impl"}
if {[version -short] ne "2022.2"} {error "Use Vivado 2022.2"}
foreach name {openofdm_rx openofdm_tx rx_intf tx_intf xpu side_ch} {
    if {![file exists $::ow_stage/board/ip_repo/$name/component.xml]} {error "Package $name first"}
}
if {![file exists $root/baseline_before_openwifi/sha256.json]} {error "Run prepare.py first to back up project inputs"}
open_project $root/dma_project/dma_project.xpr
set_property part xc7z045fbg676-1 [current_project]
# Remove registered old inputs, leaving their files on disk for recovery.
set old_bd [get_files -quiet *.bd]
if {[llength $old_bd]} {remove_files $old_bd}
set old [get_files -of_objects [get_filesets sources_1]]
if {[llength $old]} {remove_files $old}
set old_xdc [get_files -of_objects [get_filesets constrs_1]]
if {[llength $old_xdc]} {remove_files $old_xdc}
set_property ip_repo_paths [list $::ow_stage/adi-hdl/library $::ow_stage/board/ip_repo] [current_project]
update_ip_catalog -rebuild
add_files -norecurse $::ow_stage/board/src/system.bd
open_bd_design $::ow_stage/board/src/system.bd
source $script_dir/retarget.tcl
set bd_ips [get_ips -quiet]
set locked [get_ips -quiet -filter {IS_LOCKED == 1}]
if {[llength $locked]} {upgrade_ip $locked}
validate_bd_design
save_bd_design
generate_target all [get_files $::ow_stage/board/src/system.bd]
set wrapper [make_wrapper -files [get_files $::ow_stage/board/src/system.bd] -top]
add_files -norecurse $wrapper
add_files -norecurse $::ow_stage/board/src/system_top.v
add_files -fileset constrs_1 [list $::ow_stage/board/src/board.xdc $::ow_stage/board/src/openwifi_timing.xdc]
set_property top system_top [get_filesets sources_1]
set_property top_auto_set 0 [get_filesets sources_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property incremental_checkpoint {} [get_runs synth_1]
update_compile_order -fileset sources_1
report_ip_status -file $root/openwifi/ip_status.rpt
write_bd_tcl -force $root/openwifi/system_generated.tcl
set fd [open $root/openwifi/address_map.txt w]
foreach seg [get_bd_addr_segs -hierarchical] {
    puts $fd "$seg OFFSET=[get_property -quiet OFFSET $seg] RANGE=[get_property -quiet RANGE $seg]"
}
close $fd
close_project
open_project $root/dma_project/dma_project.xpr
if {$action ne "validate"} {
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    if {![string match *Complete* [get_property STATUS [get_runs synth_1]]]} {error "Synthesis failed"}
    open_run synth_1
    report_drc -file $root/openwifi/synth_drc.rpt
    close_design
}
if {$action eq "impl"} {
    launch_runs impl_1 -to_step route_design -jobs 4
    wait_on_run impl_1
    if {![string match *Complete* [get_property STATUS [get_runs impl_1]]]} {error "Implementation failed"}
    open_run impl_1
    report_timing_summary -file $root/openwifi/timing_summary.rpt
    report_drc -file $root/openwifi/impl_drc.rpt
    # Deliberately separate bitstream generation from timing/DRC review.
}
exit
