# Schematic FPGA2/FPGA3 pages 09/11, all RF IO banks 1.8 V.
# rx_data pairs below intentionally follow FPGA->AD9361 net names, not old XDC.
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports rx_clk_in_p]
set_property -dict {IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports rx_clk_in_n]
set_property -dict {PACKAGE_PIN H13 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports rx_frame_in_p]
set_property -dict {IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports rx_frame_in_n]
# Negative pad locations are inferred from the device differential pairs.
set_property -dict {PACKAGE_PIN F12 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {rx_data_in_p[0]}]
set_property -dict {PACKAGE_PIN E10 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {rx_data_in_p[1]}]
set_property -dict {PACKAGE_PIN G10 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {rx_data_in_p[2]}]
set_property -dict {PACKAGE_PIN E11 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {rx_data_in_p[3]}]
set_property -dict {PACKAGE_PIN G12 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {rx_data_in_p[4]}]
set_property -dict {PACKAGE_PIN F13 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {rx_data_in_p[5]}]
set_property -dict {IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {rx_data_in_n[*]}]
set_property -dict {PACKAGE_PIN K13 IOSTANDARD LVDS} [get_ports tx_clk_out_p]
set_property -dict {IOSTANDARD LVDS} [get_ports tx_clk_out_n]
set_property -dict {PACKAGE_PIN K15 IOSTANDARD LVDS} [get_ports tx_frame_out_p]
set_property -dict {IOSTANDARD LVDS} [get_ports tx_frame_out_n]
set_property -dict {PACKAGE_PIN D15 IOSTANDARD LVDS} [get_ports {tx_data_out_p[0]}]
set_property -dict {PACKAGE_PIN F15 IOSTANDARD LVDS} [get_ports {tx_data_out_p[1]}]
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVDS} [get_ports {tx_data_out_p[2]}]
set_property -dict {PACKAGE_PIN E16 IOSTANDARD LVDS} [get_ports {tx_data_out_p[3]}]
set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVDS} [get_ports {tx_data_out_p[4]}]
set_property -dict {PACKAGE_PIN B17 IOSTANDARD LVDS} [get_ports {tx_data_out_p[5]}]
set_property -dict {IOSTANDARD LVDS} [get_ports {tx_data_out_n[*]}]
foreach {port pin} {
    spi_csn C11 spi_clk B11 spi_mosi A13 spi_miso A12
    resetb H16 en_agc G16 sync_in G15 enable G14 txnrx F14
    gpio_clksel Y12
    gpio_R1_LNA_EN M2 gpio_R2_LNA_EN L2 gpio_T1_PA_EN N4 gpio_T2_PA_EN M4
    {ctrl_in[0]} C2 {ctrl_in[1]} B1 {ctrl_in[2]} B2 {ctrl_in[3]} A2
    {gpio_status[0]} D13 {gpio_status[1]} C13 {gpio_status[2]} C14 {gpio_status[3]} B14
    {gpio_status[4]} A15 {gpio_status[5]} A14 {gpio_status[6]} C12 {gpio_status[7]} B12
} {
    set_property -dict [list PACKAGE_PIN $pin IOSTANDARD LVCMOS18] [get_ports $port]
}
set_property PULLUP TRUE [get_ports spi_csn]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
# AD9361 2R2T at 40 MSPS -> 160 MHz LVDS interface clock.
create_clock -name rx_clk -period 6.250 [get_ports rx_clk_in_p]
