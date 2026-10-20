# Applied to a local copy of the ZC706 openwifi BD, never to upstream sources.
source $::ow_stage/board/ps_settings.tcl
set_property -dict $board_ps_settings [get_bd_cells sys_ps7]
# The reference graph has a legacy dummy HDMI/audio port group tied to ground.
# Those ports are not board pins and have no function on this hardware.
foreach p {hdmi_out_clk hdmi_hsync hdmi_vsync hdmi_data_e hdmi_data spdif} {
    delete_bd_objs [get_bd_ports -quiet $p]
}
# No FMC I2C devices on the custom board. Keep the unused AXI slot terminated
# by the original IIC core but remove physical I2C pins from the design.
delete_bd_objs [get_bd_intf_ports -quiet iic_main]
proc ow_tie {target value} {
    set pin [get_bd_pins $target]
    if {[llength [get_bd_nets -quiet -of_objects $pin]]} {return}
    set left [get_property LEFT $pin]
    set right [get_property RIGHT $pin]
    set width 1
    if {$left ne "" && $right ne ""} {set width [expr {abs($left-$right)+1}]}
    set name ow_tie_[string map {/ _} $target]
    if {![llength [get_bd_cells -quiet $name]]} {
        create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 $name
    }
    set_property -dict [list CONFIG.CONST_WIDTH $width CONFIG.CONST_VAL $value] [get_bd_cells $name]
    connect_bd_net [get_bd_pins $name/dout] $pin
}
foreach pin {openwifi_ip/dma_data openwifi_ip/dma_valid openwifi_ip/openofdm_rx_0/para_valid openwifi_ip/openofdm_rx_0/para_rx_sensitivity_th openwifi_ip/side_ch_0/openofdm_tx_iq1} {
    ow_tie $pin 0
}
ow_tie axi_iic_main/scl_i 1
ow_tie axi_iic_main/sda_i 1
set_property -dict [list CONFIG.PRIM_IN_FREQ 40.000 CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 100.000] [get_bd_cells clk_wiz_0]
set_property CONFIG.FREQ_HZ 40000000 [get_bd_pins util_ad9361_divclk/clk_out]
validate_bd_design
save_bd_design
