set script_dir [file normalize [file dirname [info script]]]
source $script_dir/windows_exec.tcl
set stage $::ow_stage
if {[version -short] ne "2022.2"} {error "This baseline requires Vivado 2022.2"}
set mode [lindex $argv 0]
if {$mode eq "adi"} {
    foreach relative {axi_ad9361 util_pack/util_cpack2 util_pack/util_upack2 util_wfifo util_rfifo util_tdd_sync xilinx/util_clkdiv} {
        set name [file tail $relative]
        set folder $stage/adi-hdl/library/$relative
        if {[file exists $folder/component.xml]} {puts "SKIP $name"; continue}
        cd $folder
        source ${name}_ip.tcl
        close_project
    }
} elseif {$mode eq "openwifi"} {
    set board $stage/board
    file mkdir $board/ip_repo
    foreach {name value} {
        clock_speed.v {`define NUM_CLK_PER_US 100}
        fpga_scale.v {// XC7Z045: full BRAM side channel}
        has_side_ch_flag.v {`define HAS_SIDE_CH 1}
        spi_command.v {`define SPI_HIGH 24'h088A01
`define SPI_LOW 24'h008A01}
        openwifi_hw_git_rev.v {`define OPENWIFI_HW_GIT_REV (32'hfa6c8968)}
    } {
        set fd [open $board/ip_repo/$name w]; puts $fd $value; close $fd
    }
    file copy -force $stage/ip/board_def.v $board/ip_repo/board_def.v
    foreach ip_name {openofdm_rx openofdm_tx rx_intf tx_intf xpu side_ch} {
        set ip_dir $board/ip_repo/$ip_name
        if {[file exists $ip_dir/component.xml]} {puts "SKIP $ip_name"; continue}
        if {[file exists $ip_dir]} {file delete -force [ow_check_path $ip_dir]}
        set src_dir $stage/ip/$ip_name
        if {$ip_name ne "openofdm_rx"} {
            foreach name {board_def.v clock_speed.v fpga_scale.v has_side_ch_flag.v spi_command.v openwifi_hw_git_rev.v} {
                file copy -force $board/ip_repo/$name $src_dir/src/$name
            }
            file copy -force $board/ip_config/${ip_name}_pre_def.v $src_dir/src/${ip_name}_pre_def.v
        }
        cd $src_dir
        set argv [list an_xc7z045 100]
        set argc 2
        source ./${ip_name}.tcl
        update_compile_order -fileset sources_1
        ipx::package_project -root_dir $ip_dir -vendor user.org -library user -taxonomy /UserIP -import_files -set_current false
        ipx::unload_core $ip_dir/component.xml
        close_project
        if {![file exists $ip_dir/component.xml]} {error "Packaging failed: $ip_name"}
        puts "PACKAGED $ip_name"
    }
} else {error "Use -tclargs adi or openwifi"}
exit
