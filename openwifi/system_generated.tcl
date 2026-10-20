
################################################################
# This is a generated script based on design: system
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2022.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source system_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xc7z045fbg676-1
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name system

# This script was generated for a remote BD. To create a non-remote design,
# change the variable <run_remote_bd_flow> to <0>.

set run_remote_bd_flow 1
if { $run_remote_bd_flow == 1 } {
  # Set the reference directory for source file relative paths (by default 
  # the value is script directory path)
  set origin_dir ./src

  # Use origin directory path location variable, if specified in the tcl shell
  if { [info exists ::origin_dir_loc] } {
     set origin_dir $::origin_dir_loc
  }

  set str_bd_folder [file normalize ${origin_dir}]
  set str_bd_filepath ${str_bd_folder}/${design_name}/${design_name}.bd

  # Check if remote design exists on disk
  if { [file exists $str_bd_filepath ] == 1 } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2030 -severity "ERROR" "The remote BD file path <$str_bd_filepath> already exists!"}
     common::send_gid_msg -ssname BD::TCL -id 2031 -severity "INFO" "To create a non-remote BD, change the variable <run_remote_bd_flow> to <0>."
     common::send_gid_msg -ssname BD::TCL -id 2032 -severity "INFO" "Also make sure there is no design <$design_name> existing in your current project."

     return 1
  }

  # Check if design exists in memory
  set list_existing_designs [get_bd_designs -quiet $design_name]
  if { $list_existing_designs ne "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2033 -severity "ERROR" "The design <$design_name> already exists in this project! Will not create the remote BD <$design_name> at the folder <$str_bd_folder>."}

     common::send_gid_msg -ssname BD::TCL -id 2034 -severity "INFO" "To create a non-remote BD, change the variable <run_remote_bd_flow> to <0> or please set a different value to variable <design_name>."

     return 1
  }

  # Check if design exists on disk within project
  set list_existing_designs [get_files -quiet */${design_name}.bd]
  if { $list_existing_designs ne "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2035 -severity "ERROR" "The design <$design_name> already exists in this project at location:
    $list_existing_designs"}
     catch {common::send_gid_msg -ssname BD::TCL -id 2036 -severity "ERROR" "Will not create the remote BD <$design_name> at the folder <$str_bd_folder>."}

     common::send_gid_msg -ssname BD::TCL -id 2037 -severity "INFO" "To create a non-remote BD, change the variable <run_remote_bd_flow> to <0> or please set a different value to variable <design_name>."

     return 1
  }

  # Now can create the remote BD
  # NOTE - usage of <-dir> will create <$str_bd_folder/$design_name/$design_name.bd>
  create_bd_design -dir $str_bd_folder $design_name
} else {

  # Create regular design
  if { [catch {create_bd_design $design_name} errmsg] } {
     common::send_gid_msg -ssname BD::TCL -id 2038 -severity "INFO" "Please set a different value to variable <design_name>."

     return 1
  }
}

current_bd_design $design_name

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:xlconstant:1.1\
analog.com:user:axi_ad9361:1.0\
analog.com:user:util_rfifo:1.0\
xilinx.com:ip:axi_iic:2.1\
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:xlconcat:2.1\
xilinx.com:ip:processing_system7:5.5\
xilinx.com:ip:proc_sys_reset:5.0\
analog.com:user:util_wfifo:1.0\
analog.com:user:util_cpack2:1.0\
analog.com:user:util_upack2:1.0\
analog.com:user:util_clkdiv:1.0\
xilinx.com:ip:util_reduced_logic:2.0\
analog.com:user:util_tdd_sync:1.0\
xilinx.com:ip:axi_dma:7.1\
user.org:user:openofdm_rx:1.0\
user.org:user:openofdm_tx:1.0\
user.org:user:rx_intf:1.0\
user.org:user:side_ch:1.0\
user.org:user:tx_intf:1.0\
xilinx.com:ip:xlslice:1.0\
user.org:user:xpu:1.0\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################


# Hierarchical cell: openwifi_ip
proc create_hier_cell_openwifi_ip { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_openwifi_ip() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M00_AXI

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M00_AXI1

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S00_AXI


  # Create pins
  create_bd_pin -dir I -type clk adc_clk
  create_bd_pin -dir I -from 63 -to 0 adc_data
  create_bd_pin -dir I -type rst adc_rst
  create_bd_pin -dir I adc_valid
  create_bd_pin -dir O -from 63 -to 0 dac_data
  create_bd_pin -dir I dac_ready
  create_bd_pin -dir O dac_valid
  create_bd_pin -dir I -from 63 -to 0 dma_data
  create_bd_pin -dir O dma_ready
  create_bd_pin -dir I dma_valid
  create_bd_pin -dir I -type rst ext_reset_in
  create_bd_pin -dir I -from 7 -to 0 gpio_status
  create_bd_pin -dir I -type clk m_axi_mm2s_aclk
  create_bd_pin -dir O -type intr mm2s_introut
  create_bd_pin -dir O -type intr mm2s_introut1
  create_bd_pin -dir I -type clk ps_clk
  create_bd_pin -dir O -type intr rx_pkt_intr
  create_bd_pin -dir O -type intr s2mm_introut
  create_bd_pin -dir O -type intr s2mm_introut1
  create_bd_pin -dir O spi0_clk_o
  create_bd_pin -dir I spi0_csn
  create_bd_pin -dir O spi0_csn_0_o
  create_bd_pin -dir I spi0_mosi
  create_bd_pin -dir I spi0_sclk
  create_bd_pin -dir O spi0_sdo_o
  create_bd_pin -dir O tx_itrpt

  # Create instance: axi_dma_0, and set properties
  set axi_dma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0 ]
  set_property -dict [list \
    CONFIG.c_include_mm2s_dre {1} \
    CONFIG.c_include_s2mm_dre {1} \
    CONFIG.c_include_sg {1} \
    CONFIG.c_m_axi_mm2s_data_width {64} \
    CONFIG.c_m_axis_mm2s_tdata_width {64} \
    CONFIG.c_mm2s_burst_size {256} \
    CONFIG.c_s2mm_burst_size {256} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
  ] $axi_dma_0


  # Create instance: axi_dma_1, and set properties
  set axi_dma_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_1 ]
  set_property -dict [list \
    CONFIG.c_include_mm2s_dre {1} \
    CONFIG.c_include_s2mm_dre {1} \
    CONFIG.c_include_sg {1} \
    CONFIG.c_m_axi_mm2s_data_width {64} \
    CONFIG.c_m_axis_mm2s_tdata_width {64} \
    CONFIG.c_mm2s_burst_size {256} \
    CONFIG.c_s2mm_burst_size {256} \
    CONFIG.c_sg_include_stscntrl_strm {0} \
  ] $axi_dma_1


  # Create instance: axi_interconnect_0, and set properties
  set axi_interconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0 ]
  set_property -dict [list \
    CONFIG.ENABLE_ADVANCED_OPTIONS {0} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {3} \
  ] $axi_interconnect_0


  # Create instance: axi_interconnect_1, and set properties
  set axi_interconnect_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_1 ]
  set_property -dict [list \
    CONFIG.ENABLE_ADVANCED_OPTIONS {1} \
    CONFIG.NUM_MI {8} \
  ] $axi_interconnect_1


  # Create instance: axi_interconnect_2, and set properties
  set axi_interconnect_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_2 ]
  set_property -dict [list \
    CONFIG.ENABLE_ADVANCED_OPTIONS {0} \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {3} \
  ] $axi_interconnect_2


  # Create instance: openofdm_rx_0, and set properties
  set openofdm_rx_0 [ create_bd_cell -type ip -vlnv user.org:user:openofdm_rx:1.0 openofdm_rx_0 ]

  # Create instance: openofdm_tx_0, and set properties
  set openofdm_tx_0 [ create_bd_cell -type ip -vlnv user.org:user:openofdm_tx:1.0 openofdm_tx_0 ]

  # Create instance: rx_intf_0, and set properties
  set rx_intf_0 [ create_bd_cell -type ip -vlnv user.org:user:rx_intf:1.0 rx_intf_0 ]

  # Create instance: side_ch_0, and set properties
  set side_ch_0 [ create_bd_cell -type ip -vlnv user.org:user:side_ch:1.0 side_ch_0 ]

  # Create instance: sys_rstgen1, and set properties
  set sys_rstgen1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 sys_rstgen1 ]
  set_property CONFIG.C_EXT_RST_WIDTH {1} $sys_rstgen1


  # Create instance: tx_intf_0, and set properties
  set tx_intf_0 [ create_bd_cell -type ip -vlnv user.org:user:tx_intf:1.0 tx_intf_0 ]

  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]

  # Create instance: xlconcat_1, and set properties
  set xlconcat_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_1 ]

  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
  set_property CONFIG.CONST_VAL {0} $xlconstant_0


  # Create instance: xlconstant_1, and set properties
  set xlconstant_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_1 ]
  set_property CONFIG.CONST_VAL {0} $xlconstant_1


  # Create instance: xlslice_0, and set properties
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {31} \
    CONFIG.DIN_TO {16} \
    CONFIG.DOUT_WIDTH {16} \
  ] $xlslice_0


  # Create instance: xlslice_1, and set properties
  set xlslice_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_1 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {15} \
    CONFIG.DIN_TO {0} \
    CONFIG.DOUT_WIDTH {16} \
  ] $xlslice_1


  # Create instance: xlslice_2, and set properties
  set xlslice_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_2 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {7} \
    CONFIG.DIN_TO {7} \
    CONFIG.DIN_WIDTH {8} \
    CONFIG.DOUT_WIDTH {1} \
  ] $xlslice_2


  # Create instance: xpu_0, and set properties
  set xpu_0 [ create_bd_cell -type ip -vlnv user.org:user:xpu:1.0 xpu_0 ]

  # Create interface connections
  connect_bd_intf_net -intf_net S00_AXI_6 [get_bd_intf_pins axi_dma_1/M_AXI_MM2S] [get_bd_intf_pins axi_interconnect_2/S00_AXI]
  connect_bd_intf_net -intf_net S01_AXI_1 [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_0/S01_AXI]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXIS_MM2S [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S] [get_bd_intf_pins tx_intf_0/s00_axis]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_MM2S [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] [get_bd_intf_pins axi_interconnect_0/S00_AXI]
  connect_bd_intf_net -intf_net axi_dma_0_M_AXI_SG [get_bd_intf_pins axi_dma_0/M_AXI_SG] [get_bd_intf_pins axi_interconnect_0/S02_AXI]
  connect_bd_intf_net -intf_net axi_dma_1_M_AXIS_MM2S [get_bd_intf_pins axi_dma_1/M_AXIS_MM2S] [get_bd_intf_pins side_ch_0/s00_axis]
  connect_bd_intf_net -intf_net axi_dma_1_M_AXI_S2MM [get_bd_intf_pins axi_dma_1/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_2/S01_AXI]
  connect_bd_intf_net -intf_net axi_dma_1_M_AXI_SG [get_bd_intf_pins axi_dma_1/M_AXI_SG] [get_bd_intf_pins axi_interconnect_2/S02_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_1_M00_AXI [get_bd_intf_pins axi_dma_0/S_AXI_LITE] [get_bd_intf_pins axi_interconnect_1/M00_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_1_M01_AXI [get_bd_intf_pins axi_interconnect_1/M01_AXI] [get_bd_intf_pins tx_intf_0/s00_axi]
  connect_bd_intf_net -intf_net axi_interconnect_1_M02_AXI [get_bd_intf_pins axi_interconnect_1/M02_AXI] [get_bd_intf_pins openofdm_tx_0/s00_axi]
  connect_bd_intf_net -intf_net axi_interconnect_1_M03_AXI [get_bd_intf_pins axi_dma_1/S_AXI_LITE] [get_bd_intf_pins axi_interconnect_1/M03_AXI]
  connect_bd_intf_net -intf_net axi_interconnect_1_M04_AXI [get_bd_intf_pins axi_interconnect_1/M04_AXI] [get_bd_intf_pins rx_intf_0/s00_axi]
  connect_bd_intf_net -intf_net axi_interconnect_1_M05_AXI [get_bd_intf_pins axi_interconnect_1/M05_AXI] [get_bd_intf_pins openofdm_rx_0/s00_axi]
  connect_bd_intf_net -intf_net axi_interconnect_1_M06_AXI [get_bd_intf_pins axi_interconnect_1/M06_AXI] [get_bd_intf_pins xpu_0/s00_axi]
  connect_bd_intf_net -intf_net axi_interconnect_1_M07_AXI [get_bd_intf_pins axi_interconnect_1/M07_AXI] [get_bd_intf_pins side_ch_0/s00_axi]
  connect_bd_intf_net -intf_net openwifi_ip_M00_AXI [get_bd_intf_pins M00_AXI] [get_bd_intf_pins axi_interconnect_2/M00_AXI]
  connect_bd_intf_net -intf_net openwifi_ip_M00_AXI1 [get_bd_intf_pins M00_AXI1] [get_bd_intf_pins axi_interconnect_0/M00_AXI]
  connect_bd_intf_net -intf_net rx_intf_0_m00_axis [get_bd_intf_pins axi_dma_1/S_AXIS_S2MM] [get_bd_intf_pins rx_intf_0/m00_axis]
  connect_bd_intf_net -intf_net side_ch_0_m00_axis [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM] [get_bd_intf_pins side_ch_0/m00_axis]
  connect_bd_intf_net -intf_net sys_ps7_M_AXI_GP1 [get_bd_intf_pins S00_AXI] [get_bd_intf_pins axi_interconnect_1/S00_AXI]

  # Create port connections
  connect_bd_net -net Net [get_bd_pins openofdm_rx_0/ht_aggr_last] [get_bd_pins rx_intf_0/ht_aggr_last] [get_bd_pins xpu_0/rx_ht_aggr_last]
  connect_bd_net -net adc_clk_1 [get_bd_pins adc_clk] [get_bd_pins rx_intf_0/adc_clk] [get_bd_pins tx_intf_0/dac_clk]
  connect_bd_net -net adc_data_1 [get_bd_pins adc_data] [get_bd_pins rx_intf_0/adc_data]
  connect_bd_net -net adc_rst_1 [get_bd_pins adc_rst] [get_bd_pins rx_intf_0/adc_rst] [get_bd_pins tx_intf_0/dac_rst]
  connect_bd_net -net adc_valid_1 [get_bd_pins adc_valid] [get_bd_pins rx_intf_0/adc_valid]
  connect_bd_net -net dac_ready_1 [get_bd_pins dac_ready] [get_bd_pins tx_intf_0/dac_ready]
  connect_bd_net -net dma_data_1 [get_bd_pins dma_data] [get_bd_pins tx_intf_0/dma_data]
  connect_bd_net -net dma_valid_1 [get_bd_pins dma_valid] [get_bd_pins tx_intf_0/dma_valid]
  connect_bd_net -net gpio_status_1 [get_bd_pins gpio_status] [get_bd_pins rx_intf_0/gpio_status_rf]
  connect_bd_net -net openofdm_rx_0_byte_count [get_bd_pins openofdm_rx_0/byte_count] [get_bd_pins rx_intf_0/byte_count] [get_bd_pins xpu_0/byte_count]
  connect_bd_net -net openofdm_rx_0_byte_out [get_bd_pins openofdm_rx_0/byte_out] [get_bd_pins rx_intf_0/byte_in] [get_bd_pins xpu_0/byte_in]
  connect_bd_net -net openofdm_rx_0_byte_out_strobe [get_bd_pins openofdm_rx_0/byte_out_strobe] [get_bd_pins rx_intf_0/byte_in_strobe] [get_bd_pins xpu_0/byte_in_strobe]
  connect_bd_net -net openofdm_rx_0_csi [get_bd_pins openofdm_rx_0/csi] [get_bd_pins side_ch_0/csi]
  connect_bd_net -net openofdm_rx_0_csi_valid [get_bd_pins openofdm_rx_0/csi_valid] [get_bd_pins side_ch_0/csi_valid]
  connect_bd_net -net openofdm_rx_0_demod_is_ongoing [get_bd_pins openofdm_rx_0/demod_is_ongoing] [get_bd_pins side_ch_0/demod_is_ongoing] [get_bd_pins xpu_0/demod_is_ongoing]
  connect_bd_net -net openofdm_rx_0_equalizer [get_bd_pins openofdm_rx_0/equalizer] [get_bd_pins side_ch_0/equalizer]
  connect_bd_net -net openofdm_rx_0_equalizer_valid [get_bd_pins openofdm_rx_0/equalizer_valid] [get_bd_pins side_ch_0/equalizer_valid]
  connect_bd_net -net openofdm_rx_0_fcs_ok [get_bd_pins openofdm_rx_0/fcs_ok] [get_bd_pins rx_intf_0/fcs_ok] [get_bd_pins side_ch_0/fcs_ok] [get_bd_pins xpu_0/fcs_ok]
  connect_bd_net -net openofdm_rx_0_fcs_out_strobe [get_bd_pins openofdm_rx_0/fcs_out_strobe] [get_bd_pins rx_intf_0/fcs_in_strobe] [get_bd_pins side_ch_0/fcs_in_strobe] [get_bd_pins tx_intf_0/fcs_in_strobe] [get_bd_pins xpu_0/fcs_in_strobe]
  connect_bd_net -net openofdm_rx_0_ht_aggr [get_bd_pins openofdm_rx_0/ht_aggr] [get_bd_pins rx_intf_0/ht_aggr] [get_bd_pins xpu_0/rx_ht_aggr]
  connect_bd_net -net openofdm_rx_0_ht_sgi [get_bd_pins openofdm_rx_0/ht_sgi] [get_bd_pins rx_intf_0/ht_sgi]
  connect_bd_net -net openofdm_rx_0_ht_unsupport [get_bd_pins openofdm_rx_0/ht_unsupport] [get_bd_pins rx_intf_0/ht_unsupport] [get_bd_pins side_ch_0/ht_unsupport] [get_bd_pins xpu_0/ht_unsupport]
  connect_bd_net -net openofdm_rx_0_long_preamble_detected [get_bd_pins openofdm_rx_0/long_preamble_detected] [get_bd_pins side_ch_0/long_preamble_detected]
  connect_bd_net -net openofdm_rx_0_n_bit_in_last_sym [get_bd_pins openofdm_rx_0/n_bit_in_last_sym] [get_bd_pins xpu_0/n_bit_in_last_sym]
  connect_bd_net -net openofdm_rx_0_n_ofdm_sym [get_bd_pins openofdm_rx_0/n_ofdm_sym] [get_bd_pins xpu_0/n_ofdm_sym]
  connect_bd_net -net openofdm_rx_0_ofdm_symbol_eq_out_pulse [get_bd_pins openofdm_rx_0/ofdm_symbol_eq_out_pulse] [get_bd_pins side_ch_0/ofdm_symbol_eq_out_pulse]
  connect_bd_net -net openofdm_rx_0_phase_offset_taken [get_bd_pins openofdm_rx_0/phase_offset_taken] [get_bd_pins rx_intf_0/phase_offset_taken] [get_bd_pins side_ch_0/phase_offset_taken]
  connect_bd_net -net openofdm_rx_0_phy_len_valid [get_bd_pins openofdm_rx_0/phy_len_valid] [get_bd_pins xpu_0/phy_len_valid]
  connect_bd_net -net openofdm_rx_0_pkt_header_valid [get_bd_pins openofdm_rx_0/pkt_header_valid] [get_bd_pins rx_intf_0/pkt_header_valid] [get_bd_pins side_ch_0/pkt_header_valid] [get_bd_pins xpu_0/pkt_header_valid]
  connect_bd_net -net openofdm_rx_0_pkt_header_valid_strobe [get_bd_pins openofdm_rx_0/pkt_header_valid_strobe] [get_bd_pins rx_intf_0/pkt_header_valid_strobe] [get_bd_pins side_ch_0/pkt_header_valid_strobe] [get_bd_pins xpu_0/pkt_header_valid_strobe]
  connect_bd_net -net openofdm_rx_0_pkt_len [get_bd_pins openofdm_rx_0/pkt_len] [get_bd_pins rx_intf_0/pkt_len] [get_bd_pins side_ch_0/pkt_len] [get_bd_pins xpu_0/pkt_len]
  connect_bd_net -net openofdm_rx_0_pkt_rate [get_bd_pins openofdm_rx_0/pkt_rate] [get_bd_pins rx_intf_0/pkt_rate] [get_bd_pins side_ch_0/pkt_rate] [get_bd_pins xlslice_2/Din] [get_bd_pins xpu_0/pkt_rate]
  connect_bd_net -net openofdm_rx_0_short_preamble_detected [get_bd_pins openofdm_rx_0/short_preamble_detected] [get_bd_pins side_ch_0/short_preamble_detected]
  connect_bd_net -net openofdm_tx_0_bram_addr [get_bd_pins openofdm_tx_0/bram_addr] [get_bd_pins tx_intf_0/bram_addr]
  connect_bd_net -net openofdm_tx_0_result_i [get_bd_pins openofdm_tx_0/result_i] [get_bd_pins tx_intf_0/rf_i_from_acc] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net openofdm_tx_0_result_iq_valid [get_bd_pins openofdm_tx_0/result_iq_valid] [get_bd_pins side_ch_0/openofdm_tx_iq_valid] [get_bd_pins tx_intf_0/rf_iq_valid_from_acc]
  connect_bd_net -net openofdm_tx_0_result_q [get_bd_pins openofdm_tx_0/result_q] [get_bd_pins tx_intf_0/rf_q_from_acc] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net openwifi_ip_mm2s_introut [get_bd_pins mm2s_introut] [get_bd_pins axi_dma_0/mm2s_introut]
  connect_bd_net -net openwifi_ip_mm2s_introut1 [get_bd_pins mm2s_introut1] [get_bd_pins axi_dma_1/mm2s_introut]
  connect_bd_net -net openwifi_ip_rx_pkt_intr [get_bd_pins rx_pkt_intr] [get_bd_pins rx_intf_0/rx_pkt_intr]
  connect_bd_net -net openwifi_ip_s2mm_introut [get_bd_pins s2mm_introut] [get_bd_pins axi_dma_1/s2mm_introut] [get_bd_pins rx_intf_0/s2mm_intr]
  connect_bd_net -net openwifi_ip_s2mm_introut1 [get_bd_pins s2mm_introut1] [get_bd_pins axi_dma_0/s2mm_introut]
  connect_bd_net -net phy_tx_0_phy_tx_done [get_bd_pins openofdm_tx_0/phy_tx_done] [get_bd_pins side_ch_0/phy_tx_done] [get_bd_pins tx_intf_0/tx_end_from_acc] [get_bd_pins xpu_0/phy_tx_done]
  connect_bd_net -net phy_tx_0_phy_tx_started [get_bd_pins openofdm_tx_0/phy_tx_started] [get_bd_pins side_ch_0/phy_tx_started] [get_bd_pins tx_intf_0/tx_start_from_acc] [get_bd_pins xpu_0/phy_tx_started]
  connect_bd_net -net ps_clk_1 [get_bd_pins ps_clk] [get_bd_pins xpu_0/ps_clk]
  connect_bd_net -net rx_intf_0_gpio_status_bb [get_bd_pins rx_intf_0/gpio_status_bb] [get_bd_pins xpu_0/gpio_status]
  connect_bd_net -net rx_intf_0_gpio_status_bb_raw [get_bd_pins rx_intf_0/gpio_status_bb_raw] [get_bd_pins side_ch_0/gpio_status]
  connect_bd_net -net rx_intf_0_sample [get_bd_pins openofdm_rx_0/sample_in] [get_bd_pins rx_intf_0/sample0] [get_bd_pins side_ch_0/sample0_in] [get_bd_pins xlslice_0/Din] [get_bd_pins xlslice_1/Din]
  connect_bd_net -net rx_intf_0_sample1 [get_bd_pins rx_intf_0/sample1] [get_bd_pins side_ch_0/sample1_in]
  connect_bd_net -net rx_intf_0_sample_strobe [get_bd_pins openofdm_rx_0/sample_in_strobe] [get_bd_pins rx_intf_0/sample_strobe] [get_bd_pins side_ch_0/sample_in_strobe] [get_bd_pins xpu_0/ddc_iq_valid]
  connect_bd_net -net s_axi_lite_aclk_1 [get_bd_pins m_axi_mm2s_aclk] [get_bd_pins axi_dma_0/m_axi_mm2s_aclk] [get_bd_pins axi_dma_0/m_axi_s2mm_aclk] [get_bd_pins axi_dma_0/m_axi_sg_aclk] [get_bd_pins axi_dma_0/s_axi_lite_aclk] [get_bd_pins axi_dma_1/m_axi_mm2s_aclk] [get_bd_pins axi_dma_1/m_axi_s2mm_aclk] [get_bd_pins axi_dma_1/m_axi_sg_aclk] [get_bd_pins axi_dma_1/s_axi_lite_aclk] [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins axi_interconnect_0/S01_ACLK] [get_bd_pins axi_interconnect_0/S02_ACLK] [get_bd_pins axi_interconnect_1/ACLK] [get_bd_pins axi_interconnect_1/M00_ACLK] [get_bd_pins axi_interconnect_1/M01_ACLK] [get_bd_pins axi_interconnect_1/M02_ACLK] [get_bd_pins axi_interconnect_1/M03_ACLK] [get_bd_pins axi_interconnect_1/M04_ACLK] [get_bd_pins axi_interconnect_1/M05_ACLK] [get_bd_pins axi_interconnect_1/M06_ACLK] [get_bd_pins axi_interconnect_1/M07_ACLK] [get_bd_pins axi_interconnect_1/S00_ACLK] [get_bd_pins axi_interconnect_2/ACLK] [get_bd_pins axi_interconnect_2/M00_ACLK] [get_bd_pins axi_interconnect_2/S00_ACLK] [get_bd_pins axi_interconnect_2/S01_ACLK] [get_bd_pins axi_interconnect_2/S02_ACLK] [get_bd_pins openofdm_rx_0/s00_axi_aclk] [get_bd_pins openofdm_tx_0/clk] [get_bd_pins openofdm_tx_0/s00_axi_aclk] [get_bd_pins rx_intf_0/m00_axis_aclk] [get_bd_pins rx_intf_0/s00_axi_aclk] [get_bd_pins side_ch_0/m00_axis_aclk] [get_bd_pins side_ch_0/s00_axi_aclk] [get_bd_pins side_ch_0/s00_axis_aclk] [get_bd_pins sys_rstgen1/slowest_sync_clk] [get_bd_pins tx_intf_0/s00_axi_aclk] [get_bd_pins tx_intf_0/s00_axis_aclk] [get_bd_pins xpu_0/s00_axi_aclk]
  connect_bd_net -net spi0_csn_1 [get_bd_pins spi0_csn] [get_bd_pins xpu_0/spi0_csn]
  connect_bd_net -net spi0_mosi_1 [get_bd_pins spi0_mosi] [get_bd_pins xpu_0/spi0_mosi]
  connect_bd_net -net spi0_sclk_1 [get_bd_pins spi0_sclk] [get_bd_pins xpu_0/spi0_sclk]
  connect_bd_net -net sys_ps7_FCLK_RESET2_N [get_bd_pins ext_reset_in] [get_bd_pins sys_rstgen1/ext_reset_in]
  connect_bd_net -net sys_rstgen1_peripheral_aresetn [get_bd_pins axi_dma_0/axi_resetn] [get_bd_pins axi_dma_1/axi_resetn] [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_pins axi_interconnect_0/S00_ARESETN] [get_bd_pins axi_interconnect_0/S01_ARESETN] [get_bd_pins axi_interconnect_0/S02_ARESETN] [get_bd_pins axi_interconnect_1/ARESETN] [get_bd_pins axi_interconnect_1/M00_ARESETN] [get_bd_pins axi_interconnect_1/M01_ARESETN] [get_bd_pins axi_interconnect_1/M02_ARESETN] [get_bd_pins axi_interconnect_1/M03_ARESETN] [get_bd_pins axi_interconnect_1/M04_ARESETN] [get_bd_pins axi_interconnect_1/M05_ARESETN] [get_bd_pins axi_interconnect_1/M06_ARESETN] [get_bd_pins axi_interconnect_1/M07_ARESETN] [get_bd_pins axi_interconnect_1/S00_ARESETN] [get_bd_pins axi_interconnect_2/ARESETN] [get_bd_pins axi_interconnect_2/M00_ARESETN] [get_bd_pins axi_interconnect_2/S00_ARESETN] [get_bd_pins axi_interconnect_2/S01_ARESETN] [get_bd_pins axi_interconnect_2/S02_ARESETN] [get_bd_pins openofdm_rx_0/s00_axi_aresetn] [get_bd_pins openofdm_tx_0/phy_tx_arestn] [get_bd_pins openofdm_tx_0/s00_axi_aresetn] [get_bd_pins rx_intf_0/m00_axis_aresetn] [get_bd_pins rx_intf_0/s00_axi_aresetn] [get_bd_pins side_ch_0/m00_axis_aresetn] [get_bd_pins side_ch_0/s00_axi_aresetn] [get_bd_pins side_ch_0/s00_axis_aresetn] [get_bd_pins sys_rstgen1/peripheral_aresetn] [get_bd_pins tx_intf_0/s00_axi_aresetn] [get_bd_pins tx_intf_0/s00_axis_aresetn] [get_bd_pins xpu_0/s00_axi_aresetn]
  connect_bd_net -net tx_intf_0_bram_addr_to_xpu [get_bd_pins tx_intf_0/bram_addr_to_xpu] [get_bd_pins xpu_0/bram_addr]
  connect_bd_net -net tx_intf_0_cts_toself_bb_is_ongoing [get_bd_pins tx_intf_0/cts_toself_bb_is_ongoing] [get_bd_pins xpu_0/cts_toself_bb_is_ongoing]
  connect_bd_net -net tx_intf_0_cts_toself_rf_is_ongoing [get_bd_pins tx_intf_0/cts_toself_rf_is_ongoing] [get_bd_pins xpu_0/cts_toself_rf_is_ongoing]
  connect_bd_net -net tx_intf_0_dac_data [get_bd_pins dac_data] [get_bd_pins tx_intf_0/dac_data]
  connect_bd_net -net tx_intf_0_dac_valid [get_bd_pins dac_valid] [get_bd_pins tx_intf_0/dac_valid]
  connect_bd_net -net tx_intf_0_data_to_acc [get_bd_pins openofdm_tx_0/bram_din] [get_bd_pins tx_intf_0/data_to_acc]
  connect_bd_net -net tx_intf_0_dma_ready [get_bd_pins dma_ready] [get_bd_pins tx_intf_0/dma_ready]
  connect_bd_net -net tx_intf_0_douta [get_bd_pins tx_intf_0/douta] [get_bd_pins xpu_0/douta]
  connect_bd_net -net tx_intf_0_high_trigger [get_bd_pins tx_intf_0/high_trigger] [get_bd_pins xpu_0/high_trigger]
  connect_bd_net -net tx_intf_0_iq0_for_check [get_bd_pins rx_intf_0/iq0_from_tx_intf] [get_bd_pins side_ch_0/tx_intf_iq0] [get_bd_pins tx_intf_0/iq0_for_check]
  connect_bd_net -net tx_intf_0_iq1_for_check [get_bd_pins rx_intf_0/iq1_from_tx_intf] [get_bd_pins side_ch_0/tx_intf_iq1] [get_bd_pins tx_intf_0/iq1_for_check]
  connect_bd_net -net tx_intf_0_iq_valid_for_check [get_bd_pins rx_intf_0/iq_valid_from_tx_intf] [get_bd_pins side_ch_0/tx_intf_iq_valid] [get_bd_pins tx_intf_0/iq_valid_for_check]
  connect_bd_net -net tx_intf_0_phy_tx_start [get_bd_pins openofdm_tx_0/phy_tx_start] [get_bd_pins side_ch_0/phy_tx_start] [get_bd_pins tx_intf_0/phy_tx_start] [get_bd_pins xpu_0/phy_tx_start]
  connect_bd_net -net tx_intf_0_quit_retrans [get_bd_pins tx_intf_0/quit_retrans] [get_bd_pins xpu_0/quit_retrans]
  connect_bd_net -net tx_intf_0_reset_backoff [get_bd_pins tx_intf_0/reset_backoff] [get_bd_pins xpu_0/reset_backoff]
  connect_bd_net -net tx_intf_0_tx_hold [get_bd_pins openofdm_tx_0/result_iq_hold] [get_bd_pins tx_intf_0/tx_hold]
  connect_bd_net -net tx_intf_0_tx_iq_fifo_empty [get_bd_pins tx_intf_0/tx_iq_fifo_empty] [get_bd_pins xpu_0/tx_iq_fifo_empty]
  connect_bd_net -net tx_intf_0_tx_itrpt [get_bd_pins tx_itrpt] [get_bd_pins tx_intf_0/tx_itrpt]
  connect_bd_net -net tx_intf_0_tx_pkt_iq_to_dac_ongoing [get_bd_pins side_ch_0/tx_pkt_iq_to_dac_ongoing] [get_bd_pins tx_intf_0/tx_pkt_iq_to_dac_ongoing]
  connect_bd_net -net tx_intf_0_tx_pkt_need_ack [get_bd_pins side_ch_0/tx_pkt_need_ack] [get_bd_pins tx_intf_0/tx_pkt_need_ack] [get_bd_pins xpu_0/tx_pkt_need_ack]
  connect_bd_net -net tx_intf_0_tx_pkt_retrans_limit [get_bd_pins tx_intf_0/tx_pkt_retrans_limit] [get_bd_pins xpu_0/tx_pkt_retrans_limit]
  connect_bd_net -net tx_intf_0_tx_queue_idx_to_xpu [get_bd_pins tx_intf_0/tx_queue_idx_to_xpu] [get_bd_pins xpu_0/tx_queue_idx]
  connect_bd_net -net tx_intf_0_use_ht_aggr [get_bd_pins tx_intf_0/use_ht_aggr] [get_bd_pins xpu_0/tx_ht_aggr]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins side_ch_0/openofdm_tx_iq0] [get_bd_pins xlconcat_0/dout]
  connect_bd_net -net xlconcat_1_dout [get_bd_pins side_ch_0/phy_type] [get_bd_pins xlconcat_1/dout]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins xlconcat_1/In1] [get_bd_pins xlconstant_0/dout]
  connect_bd_net -net xlconstant_1_dout [get_bd_pins openofdm_rx_0/trigger_mode_setting_en] [get_bd_pins xlconstant_1/dout]
  connect_bd_net -net xlslice_0_Dout [get_bd_pins xlslice_0/Dout] [get_bd_pins xpu_0/ddc_i]
  connect_bd_net -net xlslice_1_Dout [get_bd_pins xlslice_1/Dout] [get_bd_pins xpu_0/ddc_q]
  connect_bd_net -net xlslice_2_Dout [get_bd_pins xlconcat_1/In0] [get_bd_pins xlslice_2/Dout]
  connect_bd_net -net xpu_0_FC_DI [get_bd_pins side_ch_0/FC_DI] [get_bd_pins xpu_0/FC_DI]
  connect_bd_net -net xpu_0_FC_DI_valid [get_bd_pins side_ch_0/FC_DI_valid] [get_bd_pins xpu_0/FC_DI_valid]
  connect_bd_net -net xpu_0_ack_tx_flag [get_bd_pins tx_intf_0/ack_tx_flag] [get_bd_pins xpu_0/ack_tx_flag]
  connect_bd_net -net xpu_0_addr1 [get_bd_pins side_ch_0/addr1] [get_bd_pins xpu_0/addr1]
  connect_bd_net -net xpu_0_addr1_valid [get_bd_pins side_ch_0/addr1_valid] [get_bd_pins xpu_0/addr1_valid]
  connect_bd_net -net xpu_0_addr2 [get_bd_pins side_ch_0/addr2] [get_bd_pins xpu_0/addr2]
  connect_bd_net -net xpu_0_addr2_valid [get_bd_pins side_ch_0/addr2_valid] [get_bd_pins xpu_0/addr2_valid]
  connect_bd_net -net xpu_0_addr3 [get_bd_pins side_ch_0/addr3] [get_bd_pins xpu_0/addr3]
  connect_bd_net -net xpu_0_addr3_valid [get_bd_pins side_ch_0/addr3_valid] [get_bd_pins xpu_0/addr3_valid]
  connect_bd_net -net xpu_0_addra [get_bd_pins tx_intf_0/addra_from_xpu] [get_bd_pins xpu_0/addra]
  connect_bd_net -net xpu_0_backoff_done [get_bd_pins tx_intf_0/backoff_done] [get_bd_pins xpu_0/backoff_done]
  connect_bd_net -net xpu_0_band [get_bd_pins tx_intf_0/band] [get_bd_pins xpu_0/band]
  connect_bd_net -net xpu_0_block_rx_dma_to_ps [get_bd_pins rx_intf_0/block_rx_dma_to_ps] [get_bd_pins side_ch_0/block_rx_dma_to_ps] [get_bd_pins xpu_0/block_rx_dma_to_ps]
  connect_bd_net -net xpu_0_block_rx_dma_to_ps_valid [get_bd_pins rx_intf_0/block_rx_dma_to_ps_valid] [get_bd_pins side_ch_0/block_rx_dma_to_ps_valid] [get_bd_pins xpu_0/block_rx_dma_to_ps_valid]
  connect_bd_net -net xpu_0_ch_idle_final [get_bd_pins side_ch_0/ch_idle_final] [get_bd_pins xpu_0/ch_idle_final]
  connect_bd_net -net xpu_0_channel [get_bd_pins openofdm_rx_0/Fc_in_MHz] [get_bd_pins tx_intf_0/channel] [get_bd_pins xpu_0/channel]
  connect_bd_net -net xpu_0_cw [get_bd_pins tx_intf_0/cw] [get_bd_pins xpu_0/cw]
  connect_bd_net -net xpu_0_dina [get_bd_pins tx_intf_0/dina_from_xpu] [get_bd_pins xpu_0/dina]
  connect_bd_net -net xpu_0_gpio_status_lock_by_sig_valid [get_bd_pins rx_intf_0/gpio_status_lock_by_sig_valid] [get_bd_pins xpu_0/gpio_status_lock_by_sig_valid]
  connect_bd_net -net xpu_0_mac_addr [get_bd_pins tx_intf_0/mac_addr] [get_bd_pins xpu_0/mac_addr]
  connect_bd_net -net xpu_0_mute_adc_out_to_bb [get_bd_pins rx_intf_0/mute_adc_out_to_bb] [get_bd_pins xpu_0/mute_adc_out_to_bb]
  connect_bd_net -net xpu_0_num_slot_random [get_bd_pins tx_intf_0/num_slot_random] [get_bd_pins xpu_0/num_slot_random]
  connect_bd_net -net xpu_0_pkt_for_me [get_bd_pins side_ch_0/pkt_for_me] [get_bd_pins xpu_0/pkt_for_me]
  connect_bd_net -net xpu_0_retrans_in_progress [get_bd_pins side_ch_0/retrans_in_progress] [get_bd_pins tx_intf_0/retrans_in_progress] [get_bd_pins xpu_0/retrans_in_progress]
  connect_bd_net -net xpu_0_rssi_half_db [get_bd_pins openofdm_rx_0/rssi_half_db] [get_bd_pins side_ch_0/rssi_half_db] [get_bd_pins xpu_0/rssi_half_db]
  connect_bd_net -net xpu_0_rssi_half_db_lock_by_sig_valid [get_bd_pins rx_intf_0/rssi_half_db_lock_by_sig_valid] [get_bd_pins xpu_0/rssi_half_db_lock_by_sig_valid]
  connect_bd_net -net xpu_0_slice_en [get_bd_pins tx_intf_0/slice_en] [get_bd_pins xpu_0/slice_en]
  connect_bd_net -net xpu_0_spi_csn [get_bd_pins spi0_csn_0_o] [get_bd_pins xpu_0/spi_csn]
  connect_bd_net -net xpu_0_spi_mosi [get_bd_pins spi0_sdo_o] [get_bd_pins xpu_0/spi_mosi]
  connect_bd_net -net xpu_0_spi_sclk [get_bd_pins spi0_clk_o] [get_bd_pins xpu_0/spi_sclk]
  connect_bd_net -net xpu_0_start_retrans [get_bd_pins tx_intf_0/start_retrans] [get_bd_pins xpu_0/start_retrans]
  connect_bd_net -net xpu_0_start_tx_ack [get_bd_pins tx_intf_0/start_tx_ack] [get_bd_pins xpu_0/start_tx_ack]
  connect_bd_net -net xpu_0_tsf_pulse_1M [get_bd_pins rx_intf_0/tsf_pulse_1M] [get_bd_pins tx_intf_0/tsf_pulse_1M] [get_bd_pins xpu_0/tsf_pulse_1M]
  connect_bd_net -net xpu_0_tsf_runtime_val [get_bd_pins rx_intf_0/tsf_runtime_val] [get_bd_pins side_ch_0/tsf_runtime_val] [get_bd_pins tx_intf_0/tsf_runtime_val] [get_bd_pins xpu_0/tsf_runtime_val]
  connect_bd_net -net xpu_0_tx_bb_is_ongoing [get_bd_pins side_ch_0/tx_bb_is_ongoing] [get_bd_pins tx_intf_0/tx_bb_is_ongoing] [get_bd_pins xpu_0/tx_bb_is_ongoing]
  connect_bd_net -net xpu_0_tx_control_state [get_bd_pins side_ch_0/tx_control_state] [get_bd_pins xpu_0/tx_control_state]
  connect_bd_net -net xpu_0_tx_control_state_idle [get_bd_pins tx_intf_0/tx_control_state_idle] [get_bd_pins xpu_0/tx_control_state_idle]
  connect_bd_net -net xpu_0_tx_rf_is_ongoing [get_bd_pins side_ch_0/tx_rf_is_ongoing] [get_bd_pins xpu_0/tx_rf_is_ongoing]
  connect_bd_net -net xpu_0_tx_status [get_bd_pins tx_intf_0/tx_status] [get_bd_pins xpu_0/tx_status]
  connect_bd_net -net xpu_0_tx_try_complete [get_bd_pins tx_intf_0/tx_try_complete] [get_bd_pins xpu_0/tx_try_complete]
  connect_bd_net -net xpu_0_wea [get_bd_pins tx_intf_0/wea_from_xpu] [get_bd_pins xpu_0/wea]

  # Restore current instance
  current_bd_instance $oldCurInst
}


# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set ddr [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 ddr ]

  set fixed_io [ create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 fixed_io ]


  # Create ports
  set enable [ create_bd_port -dir O enable ]
  set gpio_i [ create_bd_port -dir I -from 63 -to 0 gpio_i ]
  set gpio_o [ create_bd_port -dir O -from 63 -to 0 gpio_o ]
  set gpio_status [ create_bd_port -dir I -from 7 -to 0 gpio_status ]
  set gpio_t [ create_bd_port -dir O -from 63 -to 0 gpio_t ]
  set rx_clk_in_n [ create_bd_port -dir I rx_clk_in_n ]
  set rx_clk_in_p [ create_bd_port -dir I rx_clk_in_p ]
  set rx_data_in_n [ create_bd_port -dir I -from 5 -to 0 rx_data_in_n ]
  set rx_data_in_p [ create_bd_port -dir I -from 5 -to 0 rx_data_in_p ]
  set rx_frame_in_n [ create_bd_port -dir I rx_frame_in_n ]
  set rx_frame_in_p [ create_bd_port -dir I rx_frame_in_p ]
  set spi0_clk_i [ create_bd_port -dir I spi0_clk_i ]
  set spi0_clk_o [ create_bd_port -dir O spi0_clk_o ]
  set spi0_csn_0_o [ create_bd_port -dir O spi0_csn_0_o ]
  set spi0_csn_1_o [ create_bd_port -dir O spi0_csn_1_o ]
  set spi0_csn_2_o [ create_bd_port -dir O spi0_csn_2_o ]
  set spi0_csn_i [ create_bd_port -dir I spi0_csn_i ]
  set spi0_sdi_i [ create_bd_port -dir I spi0_sdi_i ]
  set spi0_sdo_i [ create_bd_port -dir I spi0_sdo_i ]
  set spi0_sdo_o [ create_bd_port -dir O spi0_sdo_o ]
  set spi1_clk_i [ create_bd_port -dir I spi1_clk_i ]
  set spi1_clk_o [ create_bd_port -dir O spi1_clk_o ]
  set spi1_csn_0_o [ create_bd_port -dir O spi1_csn_0_o ]
  set spi1_csn_1_o [ create_bd_port -dir O spi1_csn_1_o ]
  set spi1_csn_2_o [ create_bd_port -dir O spi1_csn_2_o ]
  set spi1_csn_i [ create_bd_port -dir I spi1_csn_i ]
  set spi1_sdi_i [ create_bd_port -dir I spi1_sdi_i ]
  set spi1_sdo_i [ create_bd_port -dir I spi1_sdo_i ]
  set spi1_sdo_o [ create_bd_port -dir O spi1_sdo_o ]
  set tdd_sync_i [ create_bd_port -dir I tdd_sync_i ]
  set tdd_sync_o [ create_bd_port -dir O tdd_sync_o ]
  set tdd_sync_t [ create_bd_port -dir O tdd_sync_t ]
  set tx_clk_out_n [ create_bd_port -dir O tx_clk_out_n ]
  set tx_clk_out_p [ create_bd_port -dir O tx_clk_out_p ]
  set tx_data_out_n [ create_bd_port -dir O -from 5 -to 0 tx_data_out_n ]
  set tx_data_out_p [ create_bd_port -dir O -from 5 -to 0 tx_data_out_p ]
  set tx_frame_out_n [ create_bd_port -dir O tx_frame_out_n ]
  set tx_frame_out_p [ create_bd_port -dir O tx_frame_out_p ]
  set txnrx [ create_bd_port -dir O txnrx ]
  set up_enable [ create_bd_port -dir I up_enable ]
  set up_txnrx [ create_bd_port -dir I up_txnrx ]

  # Create instance: GND_1, and set properties
  set GND_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 GND_1 ]
  set_property -dict [list \
    CONFIG.CONST_VAL {0} \
    CONFIG.CONST_WIDTH {1} \
  ] $GND_1


  # Create instance: axi_ad9361, and set properties
  set axi_ad9361 [ create_bd_cell -type ip -vlnv analog.com:user:axi_ad9361:1.0 axi_ad9361 ]
  set_property -dict [list \
    CONFIG.ADC_INIT_DELAY {20} \
    CONFIG.DAC_DDS_CORDIC_DW {14} \
    CONFIG.DAC_DDS_DISABLE {1} \
    CONFIG.DAC_DDS_TYPE {1} \
    CONFIG.ID {0} \
    CONFIG.MIMO_ENABLE {1} \
    CONFIG.TDD_DISABLE {1} \
  ] $axi_ad9361


  # Create instance: axi_ad9361_dac_fifo, and set properties
  set axi_ad9361_dac_fifo [ create_bd_cell -type ip -vlnv analog.com:user:util_rfifo:1.0 axi_ad9361_dac_fifo ]
  set_property -dict [list \
    CONFIG.DIN_ADDRESS_WIDTH {4} \
    CONFIG.DIN_DATA_WIDTH {16} \
    CONFIG.DOUT_DATA_WIDTH {16} \
  ] $axi_ad9361_dac_fifo


  # Create instance: axi_cpu_interconnect, and set properties
  set axi_cpu_interconnect [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_cpu_interconnect ]
  set_property CONFIG.NUM_MI {2} $axi_cpu_interconnect


  # Create instance: axi_iic_main, and set properties
  set axi_iic_main [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_iic:2.1 axi_iic_main ]
  set_property -dict [list \
    CONFIG.IIC_BOARD_INTERFACE {Custom} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $axi_iic_main


  # Create instance: clk_wiz_0, and set properties
  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
  set_property -dict [list \
    CONFIG.CLKIN1_JITTER_PS {250.0} \
    CONFIG.CLKOUT1_DRIVES {BUFG} \
    CONFIG.CLKOUT1_JITTER {180.876} \
    CONFIG.CLKOUT1_PHASE_ERROR {191.950} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT2_DRIVES {BUFG} \
    CONFIG.CLKOUT3_DRIVES {BUFG} \
    CONFIG.CLKOUT4_DRIVES {BUFG} \
    CONFIG.CLKOUT5_DRIVES {BUFG} \
    CONFIG.CLKOUT6_DRIVES {BUFG} \
    CONFIG.CLKOUT7_DRIVES {BUFG} \
    CONFIG.JITTER_SEL {No_Jitter} \
    CONFIG.MMCM_BANDWIDTH {OPTIMIZED} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {25.000} \
    CONFIG.MMCM_CLKIN1_PERIOD {25.000} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.0} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {10.000} \
    CONFIG.MMCM_DIVCLK_DIVIDE {1} \
    CONFIG.PRIM_IN_FREQ {40.000} \
    CONFIG.SECONDARY_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.USE_PHASE_ALIGNMENT {false} \
  ] $clk_wiz_0


  # Create instance: openwifi_ip
  create_hier_cell_openwifi_ip [current_bd_instance .] openwifi_ip

  # Create instance: sys_concat_intc, and set properties
  set sys_concat_intc [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 sys_concat_intc ]
  set_property CONFIG.NUM_PORTS {16} $sys_concat_intc


  # Create instance: sys_ps7, and set properties
  set sys_ps7 [ create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 sys_ps7 ]
  set_property -dict [list \
    CONFIG.PCW_ACT_APU_PERIPHERAL_FREQMHZ {666.666687} \
    CONFIG.PCW_ACT_CAN0_PERIPHERAL_FREQMHZ {23.8095} \
    CONFIG.PCW_ACT_CAN1_PERIPHERAL_FREQMHZ {23.8095} \
    CONFIG.PCW_ACT_CAN_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_DCI_PERIPHERAL_FREQMHZ {10.158730} \
    CONFIG.PCW_ACT_ENET0_PERIPHERAL_FREQMHZ {125.000000} \
    CONFIG.PCW_ACT_ENET1_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_FPGA0_PERIPHERAL_FREQMHZ {100.000000} \
    CONFIG.PCW_ACT_FPGA1_PERIPHERAL_FREQMHZ {200.000000} \
    CONFIG.PCW_ACT_FPGA2_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_FPGA3_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_I2C_PERIPHERAL_FREQMHZ {50} \
    CONFIG.PCW_ACT_PCAP_PERIPHERAL_FREQMHZ {200.000000} \
    CONFIG.PCW_ACT_QSPI_PERIPHERAL_FREQMHZ {200.000000} \
    CONFIG.PCW_ACT_SDIO_PERIPHERAL_FREQMHZ {50.000000} \
    CONFIG.PCW_ACT_SMC_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_SPI_PERIPHERAL_FREQMHZ {166.666672} \
    CONFIG.PCW_ACT_TPIU_PERIPHERAL_FREQMHZ {200.000000} \
    CONFIG.PCW_ACT_TTC0_CLK0_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC0_CLK1_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC0_CLK2_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC1_CLK0_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC1_CLK1_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC1_CLK2_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC_PERIPHERAL_FREQMHZ {50} \
    CONFIG.PCW_ACT_UART_PERIPHERAL_FREQMHZ {50.000000} \
    CONFIG.PCW_ACT_USB0_PERIPHERAL_FREQMHZ {60} \
    CONFIG.PCW_ACT_USB1_PERIPHERAL_FREQMHZ {60} \
    CONFIG.PCW_ACT_WDT_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_APU_CLK_RATIO_ENABLE {6:2:1} \
    CONFIG.PCW_APU_PERIPHERAL_FREQMHZ {667.000000} \
    CONFIG.PCW_CAN0_PERIPHERAL_CLKSRC {External} \
    CONFIG.PCW_CAN0_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_CAN1_PERIPHERAL_CLKSRC {External} \
    CONFIG.PCW_CAN1_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_CAN_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_CAN_PERIPHERAL_VALID {0} \
    CONFIG.PCW_CLK0_FREQ {100000000} \
    CONFIG.PCW_CLK1_FREQ {200000000} \
    CONFIG.PCW_CLK2_FREQ {10000000} \
    CONFIG.PCW_CLK3_FREQ {10000000} \
    CONFIG.PCW_CORE0_FIQ_INTR {0} \
    CONFIG.PCW_CORE0_IRQ_INTR {0} \
    CONFIG.PCW_CORE1_FIQ_INTR {0} \
    CONFIG.PCW_CORE1_IRQ_INTR {0} \
    CONFIG.PCW_CPU_CPU_6X4X_MAX_RANGE {667} \
    CONFIG.PCW_CPU_PERIPHERAL_CLKSRC {ARM PLL} \
    CONFIG.PCW_CRYSTAL_PERIPHERAL_FREQMHZ {33.333333} \
    CONFIG.PCW_DCI_PERIPHERAL_CLKSRC {DDR PLL} \
    CONFIG.PCW_DCI_PERIPHERAL_FREQMHZ {10.159} \
    CONFIG.PCW_DDR_PERIPHERAL_CLKSRC {DDR PLL} \
    CONFIG.PCW_DDR_RAM_BASEADDR {0x00100000} \
    CONFIG.PCW_DDR_RAM_HIGHADDR {0x3FFFFFFF} \
    CONFIG.PCW_DM_WIDTH {4} \
    CONFIG.PCW_DQS_WIDTH {4} \
    CONFIG.PCW_DQ_WIDTH {32} \
    CONFIG.PCW_DUAL_PARALLEL_QSPI_DATA_MODE {x8} \
    CONFIG.PCW_ENET0_BASEADDR {0xE000B000} \
    CONFIG.PCW_ENET0_ENET0_IO {MIO 16 .. 27} \
    CONFIG.PCW_ENET0_GRP_MDIO_ENABLE {1} \
    CONFIG.PCW_ENET0_GRP_MDIO_IO {MIO 52 .. 53} \
    CONFIG.PCW_ENET0_HIGHADDR {0xE000BFFF} \
    CONFIG.PCW_ENET0_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_ENET0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_ENET0_PERIPHERAL_FREQMHZ {1000 Mbps} \
    CONFIG.PCW_ENET1_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_ENET1_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_ENET_RESET_ENABLE {0} \
    CONFIG.PCW_ENET_RESET_POLARITY {Active Low} \
    CONFIG.PCW_EN_4K_TIMER {0} \
    CONFIG.PCW_EN_CAN0 {0} \
    CONFIG.PCW_EN_CAN1 {0} \
    CONFIG.PCW_EN_CLK0_PORT {1} \
    CONFIG.PCW_EN_CLK1_PORT {1} \
    CONFIG.PCW_EN_CLK2_PORT {0} \
    CONFIG.PCW_EN_CLK3_PORT {0} \
    CONFIG.PCW_EN_CLKTRIG0_PORT {0} \
    CONFIG.PCW_EN_CLKTRIG1_PORT {0} \
    CONFIG.PCW_EN_CLKTRIG2_PORT {0} \
    CONFIG.PCW_EN_CLKTRIG3_PORT {0} \
    CONFIG.PCW_EN_DDR {1} \
    CONFIG.PCW_EN_EMIO_CAN0 {0} \
    CONFIG.PCW_EN_EMIO_CAN1 {0} \
    CONFIG.PCW_EN_EMIO_CD_SDIO0 {0} \
    CONFIG.PCW_EN_EMIO_CD_SDIO1 {0} \
    CONFIG.PCW_EN_EMIO_ENET0 {0} \
    CONFIG.PCW_EN_EMIO_ENET1 {0} \
    CONFIG.PCW_EN_EMIO_GPIO {1} \
    CONFIG.PCW_EN_EMIO_I2C0 {0} \
    CONFIG.PCW_EN_EMIO_I2C1 {0} \
    CONFIG.PCW_EN_EMIO_MODEM_UART0 {0} \
    CONFIG.PCW_EN_EMIO_MODEM_UART1 {0} \
    CONFIG.PCW_EN_EMIO_PJTAG {0} \
    CONFIG.PCW_EN_EMIO_SDIO0 {0} \
    CONFIG.PCW_EN_EMIO_SDIO1 {0} \
    CONFIG.PCW_EN_EMIO_SPI0 {1} \
    CONFIG.PCW_EN_EMIO_SPI1 {0} \
    CONFIG.PCW_EN_EMIO_SRAM_INT {0} \
    CONFIG.PCW_EN_EMIO_TRACE {0} \
    CONFIG.PCW_EN_EMIO_TTC0 {0} \
    CONFIG.PCW_EN_EMIO_TTC1 {0} \
    CONFIG.PCW_EN_EMIO_UART0 {0} \
    CONFIG.PCW_EN_EMIO_UART1 {0} \
    CONFIG.PCW_EN_EMIO_WDT {0} \
    CONFIG.PCW_EN_EMIO_WP_SDIO0 {0} \
    CONFIG.PCW_EN_EMIO_WP_SDIO1 {0} \
    CONFIG.PCW_EN_ENET0 {1} \
    CONFIG.PCW_EN_ENET1 {0} \
    CONFIG.PCW_EN_GPIO {1} \
    CONFIG.PCW_EN_I2C0 {0} \
    CONFIG.PCW_EN_I2C1 {0} \
    CONFIG.PCW_EN_MODEM_UART0 {0} \
    CONFIG.PCW_EN_MODEM_UART1 {0} \
    CONFIG.PCW_EN_PJTAG {0} \
    CONFIG.PCW_EN_PTP_ENET0 {0} \
    CONFIG.PCW_EN_PTP_ENET1 {0} \
    CONFIG.PCW_EN_QSPI {1} \
    CONFIG.PCW_EN_RST0_PORT {1} \
    CONFIG.PCW_EN_RST1_PORT {1} \
    CONFIG.PCW_EN_RST2_PORT {1} \
    CONFIG.PCW_EN_RST3_PORT {0} \
    CONFIG.PCW_EN_SDIO0 {1} \
    CONFIG.PCW_EN_SDIO1 {0} \
    CONFIG.PCW_EN_SMC {0} \
    CONFIG.PCW_EN_SPI0 {1} \
    CONFIG.PCW_EN_SPI1 {0} \
    CONFIG.PCW_EN_TRACE {0} \
    CONFIG.PCW_EN_TTC0 {0} \
    CONFIG.PCW_EN_TTC1 {0} \
    CONFIG.PCW_EN_UART0 {0} \
    CONFIG.PCW_EN_UART1 {1} \
    CONFIG.PCW_EN_USB0 {0} \
    CONFIG.PCW_EN_USB1 {0} \
    CONFIG.PCW_EN_WDT {0} \
    CONFIG.PCW_FCLK0_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_FCLK1_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_FCLK2_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_FCLK3_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_FCLK_CLK0_BUF {TRUE} \
    CONFIG.PCW_FCLK_CLK1_BUF {TRUE} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100.0} \
    CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {200.0} \
    CONFIG.PCW_FPGA2_PERIPHERAL_FREQMHZ {200} \
    CONFIG.PCW_FPGA3_PERIPHERAL_FREQMHZ {50} \
    CONFIG.PCW_FPGA_FCLK0_ENABLE {1} \
    CONFIG.PCW_FPGA_FCLK1_ENABLE {1} \
    CONFIG.PCW_GP0_EN_MODIFIABLE_TXN {1} \
    CONFIG.PCW_GP0_NUM_READ_THREADS {4} \
    CONFIG.PCW_GP0_NUM_WRITE_THREADS {4} \
    CONFIG.PCW_GP1_EN_MODIFIABLE_TXN {1} \
    CONFIG.PCW_GP1_NUM_READ_THREADS {4} \
    CONFIG.PCW_GP1_NUM_WRITE_THREADS {4} \
    CONFIG.PCW_GPIO_BASEADDR {0xE000A000} \
    CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE {1} \
    CONFIG.PCW_GPIO_EMIO_GPIO_IO {64} \
    CONFIG.PCW_GPIO_EMIO_GPIO_WIDTH {64} \
    CONFIG.PCW_GPIO_HIGHADDR {0xE000AFFF} \
    CONFIG.PCW_GPIO_MIO_GPIO_ENABLE {1} \
    CONFIG.PCW_GPIO_MIO_GPIO_IO {MIO} \
    CONFIG.PCW_GPIO_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_I2C0_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_I2C1_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_I2C_RESET_ENABLE {1} \
    CONFIG.PCW_I2C_RESET_POLARITY {Active Low} \
    CONFIG.PCW_IMPORT_BOARD_PRESET {None} \
    CONFIG.PCW_INCLUDE_ACP_TRANS_CHECK {0} \
    CONFIG.PCW_IRQ_F2P_INTR {1} \
    CONFIG.PCW_IRQ_F2P_MODE {REVERSE} \
    CONFIG.PCW_MIO_0_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_0_PULLUP {enabled} \
    CONFIG.PCW_MIO_0_SLEW {slow} \
    CONFIG.PCW_MIO_10_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_10_PULLUP {enabled} \
    CONFIG.PCW_MIO_10_SLEW {slow} \
    CONFIG.PCW_MIO_11_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_11_PULLUP {enabled} \
    CONFIG.PCW_MIO_11_SLEW {slow} \
    CONFIG.PCW_MIO_12_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_12_PULLUP {enabled} \
    CONFIG.PCW_MIO_12_SLEW {slow} \
    CONFIG.PCW_MIO_13_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_13_PULLUP {enabled} \
    CONFIG.PCW_MIO_13_SLEW {slow} \
    CONFIG.PCW_MIO_14_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_14_PULLUP {enabled} \
    CONFIG.PCW_MIO_14_SLEW {slow} \
    CONFIG.PCW_MIO_15_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_15_PULLUP {enabled} \
    CONFIG.PCW_MIO_15_SLEW {slow} \
    CONFIG.PCW_MIO_16_IOTYPE {HSTL 1.8V} \
    CONFIG.PCW_MIO_16_PULLUP {disabled} \
    CONFIG.PCW_MIO_16_SLEW {slow} \
    CONFIG.PCW_MIO_17_IOTYPE {HSTL 1.8V} \
    CONFIG.PCW_MIO_17_PULLUP {disabled} \
    CONFIG.PCW_MIO_17_SLEW {slow} \
    CONFIG.PCW_MIO_18_IOTYPE {HSTL 1.8V} \
    CONFIG.PCW_MIO_18_PULLUP {disabled} \
    CONFIG.PCW_MIO_18_SLEW {slow} \
    CONFIG.PCW_MIO_19_IOTYPE {HSTL 1.8V} \
    CONFIG.PCW_MIO_19_PULLUP {disabled} \
    CONFIG.PCW_MIO_19_SLEW {slow} \
    CONFIG.PCW_MIO_1_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_1_PULLUP {enabled} \
    CONFIG.PCW_MIO_1_SLEW {slow} \
    CONFIG.PCW_MIO_20_IOTYPE {HSTL 1.8V} \
    CONFIG.PCW_MIO_20_PULLUP {disabled} \
    CONFIG.PCW_MIO_20_SLEW {slow} \
    CONFIG.PCW_MIO_21_IOTYPE {HSTL 1.8V} \
    CONFIG.PCW_MIO_21_PULLUP {disabled} \
    CONFIG.PCW_MIO_21_SLEW {slow} \
    CONFIG.PCW_MIO_22_IOTYPE {HSTL 1.8V} \
    CONFIG.PCW_MIO_22_PULLUP {disabled} \
    CONFIG.PCW_MIO_22_SLEW {slow} \
    CONFIG.PCW_MIO_23_IOTYPE {HSTL 1.8V} \
    CONFIG.PCW_MIO_23_PULLUP {disabled} \
    CONFIG.PCW_MIO_23_SLEW {slow} \
    CONFIG.PCW_MIO_24_IOTYPE {HSTL 1.8V} \
    CONFIG.PCW_MIO_24_PULLUP {disabled} \
    CONFIG.PCW_MIO_24_SLEW {slow} \
    CONFIG.PCW_MIO_25_IOTYPE {HSTL 1.8V} \
    CONFIG.PCW_MIO_25_PULLUP {disabled} \
    CONFIG.PCW_MIO_25_SLEW {slow} \
    CONFIG.PCW_MIO_26_IOTYPE {HSTL 1.8V} \
    CONFIG.PCW_MIO_26_PULLUP {disabled} \
    CONFIG.PCW_MIO_26_SLEW {slow} \
    CONFIG.PCW_MIO_27_IOTYPE {HSTL 1.8V} \
    CONFIG.PCW_MIO_27_PULLUP {disabled} \
    CONFIG.PCW_MIO_27_SLEW {slow} \
    CONFIG.PCW_MIO_28_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_28_PULLUP {disabled} \
    CONFIG.PCW_MIO_28_SLEW {slow} \
    CONFIG.PCW_MIO_29_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_29_PULLUP {disabled} \
    CONFIG.PCW_MIO_29_SLEW {slow} \
    CONFIG.PCW_MIO_2_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_2_SLEW {slow} \
    CONFIG.PCW_MIO_30_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_30_PULLUP {disabled} \
    CONFIG.PCW_MIO_30_SLEW {slow} \
    CONFIG.PCW_MIO_31_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_31_PULLUP {disabled} \
    CONFIG.PCW_MIO_31_SLEW {slow} \
    CONFIG.PCW_MIO_32_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_32_PULLUP {disabled} \
    CONFIG.PCW_MIO_32_SLEW {slow} \
    CONFIG.PCW_MIO_33_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_33_PULLUP {disabled} \
    CONFIG.PCW_MIO_33_SLEW {slow} \
    CONFIG.PCW_MIO_34_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_34_PULLUP {disabled} \
    CONFIG.PCW_MIO_34_SLEW {slow} \
    CONFIG.PCW_MIO_35_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_35_PULLUP {disabled} \
    CONFIG.PCW_MIO_35_SLEW {slow} \
    CONFIG.PCW_MIO_36_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_36_PULLUP {disabled} \
    CONFIG.PCW_MIO_36_SLEW {slow} \
    CONFIG.PCW_MIO_37_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_37_PULLUP {disabled} \
    CONFIG.PCW_MIO_37_SLEW {slow} \
    CONFIG.PCW_MIO_38_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_38_PULLUP {disabled} \
    CONFIG.PCW_MIO_38_SLEW {slow} \
    CONFIG.PCW_MIO_39_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_39_PULLUP {disabled} \
    CONFIG.PCW_MIO_39_SLEW {slow} \
    CONFIG.PCW_MIO_3_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_3_SLEW {slow} \
    CONFIG.PCW_MIO_40_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_40_PULLUP {disabled} \
    CONFIG.PCW_MIO_40_SLEW {slow} \
    CONFIG.PCW_MIO_41_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_41_PULLUP {disabled} \
    CONFIG.PCW_MIO_41_SLEW {slow} \
    CONFIG.PCW_MIO_42_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_42_PULLUP {disabled} \
    CONFIG.PCW_MIO_42_SLEW {slow} \
    CONFIG.PCW_MIO_43_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_43_PULLUP {disabled} \
    CONFIG.PCW_MIO_43_SLEW {slow} \
    CONFIG.PCW_MIO_44_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_44_PULLUP {disabled} \
    CONFIG.PCW_MIO_44_SLEW {slow} \
    CONFIG.PCW_MIO_45_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_45_PULLUP {disabled} \
    CONFIG.PCW_MIO_45_SLEW {slow} \
    CONFIG.PCW_MIO_46_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_46_PULLUP {enabled} \
    CONFIG.PCW_MIO_46_SLEW {slow} \
    CONFIG.PCW_MIO_47_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_47_PULLUP {enabled} \
    CONFIG.PCW_MIO_47_SLEW {slow} \
    CONFIG.PCW_MIO_48_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_48_PULLUP {disabled} \
    CONFIG.PCW_MIO_48_SLEW {slow} \
    CONFIG.PCW_MIO_49_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_49_PULLUP {disabled} \
    CONFIG.PCW_MIO_49_SLEW {slow} \
    CONFIG.PCW_MIO_4_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_4_SLEW {slow} \
    CONFIG.PCW_MIO_50_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_50_PULLUP {enabled} \
    CONFIG.PCW_MIO_50_SLEW {slow} \
    CONFIG.PCW_MIO_51_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_51_PULLUP {enabled} \
    CONFIG.PCW_MIO_51_SLEW {slow} \
    CONFIG.PCW_MIO_52_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_52_PULLUP {disabled} \
    CONFIG.PCW_MIO_52_SLEW {slow} \
    CONFIG.PCW_MIO_53_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_53_PULLUP {disabled} \
    CONFIG.PCW_MIO_53_SLEW {slow} \
    CONFIG.PCW_MIO_5_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_5_SLEW {slow} \
    CONFIG.PCW_MIO_6_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_6_SLEW {slow} \
    CONFIG.PCW_MIO_7_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_7_SLEW {slow} \
    CONFIG.PCW_MIO_8_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_8_SLEW {slow} \
    CONFIG.PCW_MIO_9_IOTYPE {LVCMOS 1.8V} \
    CONFIG.PCW_MIO_9_PULLUP {enabled} \
    CONFIG.PCW_MIO_9_SLEW {slow} \
    CONFIG.PCW_MIO_PRIMITIVE {54} \
    CONFIG.PCW_MIO_TREE_PERIPHERALS {Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#GPIO#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI\
Flash#Quad SPI Flash#Quad SPI Flash#GPIO#GPIO#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#SD 0#SD 0#SD\
0#SD 0#SD 0#SD 0#GPIO#GPIO#UART 1#UART 1#GPIO#GPIO#Enet 0#Enet 0} \
    CONFIG.PCW_MIO_TREE_SIGNALS {qspi1_ss_b#qspi0_ss_b#qspi0_io[0]#qspi0_io[1]#qspi0_io[2]#qspi0_io[3]/HOLD_B#qspi0_sclk#gpio[7]#qspi_fbclk#qspi1_sclk#qspi1_io[0]#qspi1_io[1]#qspi1_io[2]#qspi1_io[3]#gpio[14]#gpio[15]#tx_clk#txd[0]#txd[1]#txd[2]#txd[3]#tx_ctl#rx_clk#rxd[0]#rxd[1]#rxd[2]#rxd[3]#rx_ctl#gpio[28]#gpio[29]#gpio[30]#gpio[31]#gpio[32]#gpio[33]#gpio[34]#gpio[35]#gpio[36]#gpio[37]#gpio[38]#gpio[39]#clk#cmd#data[0]#data[1]#data[2]#data[3]#gpio[46]#gpio[47]#tx#rx#gpio[50]#gpio[51]#mdc#mdio}\
\
    CONFIG.PCW_M_AXI_GP0_ENABLE_STATIC_REMAP {0} \
    CONFIG.PCW_M_AXI_GP0_ID_WIDTH {12} \
    CONFIG.PCW_M_AXI_GP0_SUPPORT_NARROW_BURST {0} \
    CONFIG.PCW_M_AXI_GP0_THREAD_ID_WIDTH {12} \
    CONFIG.PCW_M_AXI_GP1_ENABLE_STATIC_REMAP {0} \
    CONFIG.PCW_M_AXI_GP1_ID_WIDTH {12} \
    CONFIG.PCW_M_AXI_GP1_SUPPORT_NARROW_BURST {0} \
    CONFIG.PCW_M_AXI_GP1_THREAD_ID_WIDTH {12} \
    CONFIG.PCW_NAND_CYCLES_T_AR {1} \
    CONFIG.PCW_NAND_CYCLES_T_CLR {1} \
    CONFIG.PCW_NAND_CYCLES_T_RC {11} \
    CONFIG.PCW_NAND_CYCLES_T_REA {1} \
    CONFIG.PCW_NAND_CYCLES_T_RR {1} \
    CONFIG.PCW_NAND_CYCLES_T_WC {11} \
    CONFIG.PCW_NAND_CYCLES_T_WP {1} \
    CONFIG.PCW_NOR_CS0_T_CEOE {1} \
    CONFIG.PCW_NOR_CS0_T_PC {1} \
    CONFIG.PCW_NOR_CS0_T_RC {11} \
    CONFIG.PCW_NOR_CS0_T_TR {1} \
    CONFIG.PCW_NOR_CS0_T_WC {11} \
    CONFIG.PCW_NOR_CS0_T_WP {1} \
    CONFIG.PCW_NOR_CS0_WE_TIME {0} \
    CONFIG.PCW_NOR_CS1_T_CEOE {1} \
    CONFIG.PCW_NOR_CS1_T_PC {1} \
    CONFIG.PCW_NOR_CS1_T_RC {11} \
    CONFIG.PCW_NOR_CS1_T_TR {1} \
    CONFIG.PCW_NOR_CS1_T_WC {11} \
    CONFIG.PCW_NOR_CS1_T_WP {1} \
    CONFIG.PCW_NOR_CS1_WE_TIME {0} \
    CONFIG.PCW_NOR_SRAM_CS0_T_CEOE {1} \
    CONFIG.PCW_NOR_SRAM_CS0_T_PC {1} \
    CONFIG.PCW_NOR_SRAM_CS0_T_RC {11} \
    CONFIG.PCW_NOR_SRAM_CS0_T_TR {1} \
    CONFIG.PCW_NOR_SRAM_CS0_T_WC {11} \
    CONFIG.PCW_NOR_SRAM_CS0_T_WP {1} \
    CONFIG.PCW_NOR_SRAM_CS0_WE_TIME {0} \
    CONFIG.PCW_NOR_SRAM_CS1_T_CEOE {1} \
    CONFIG.PCW_NOR_SRAM_CS1_T_PC {1} \
    CONFIG.PCW_NOR_SRAM_CS1_T_RC {11} \
    CONFIG.PCW_NOR_SRAM_CS1_T_TR {1} \
    CONFIG.PCW_NOR_SRAM_CS1_T_WC {11} \
    CONFIG.PCW_NOR_SRAM_CS1_T_WP {1} \
    CONFIG.PCW_NOR_SRAM_CS1_WE_TIME {0} \
    CONFIG.PCW_OVERRIDE_BASIC_CLOCK {0} \
    CONFIG.PCW_P2F_DMAC0_INTR {0} \
    CONFIG.PCW_P2F_DMAC1_INTR {0} \
    CONFIG.PCW_P2F_DMAC2_INTR {0} \
    CONFIG.PCW_P2F_DMAC3_INTR {0} \
    CONFIG.PCW_P2F_DMAC4_INTR {0} \
    CONFIG.PCW_P2F_DMAC5_INTR {0} \
    CONFIG.PCW_P2F_DMAC6_INTR {0} \
    CONFIG.PCW_P2F_DMAC7_INTR {0} \
    CONFIG.PCW_P2F_DMAC_ABORT_INTR {0} \
    CONFIG.PCW_P2F_ENET0_INTR {0} \
    CONFIG.PCW_P2F_GPIO_INTR {0} \
    CONFIG.PCW_P2F_QSPI_INTR {0} \
    CONFIG.PCW_P2F_SDIO0_INTR {0} \
    CONFIG.PCW_P2F_SPI0_INTR {0} \
    CONFIG.PCW_P2F_UART1_INTR {0} \
    CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY0 {0.100} \
    CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY1 {0.113} \
    CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY2 {0.111} \
    CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY3 {0.100} \
    CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_0 {-0.017} \
    CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_1 {-0.039} \
    CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_2 {-0.040} \
    CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_3 {-0.016} \
    CONFIG.PCW_PACKAGE_NAME {fbg676} \
    CONFIG.PCW_PCAP_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_PCAP_PERIPHERAL_FREQMHZ {200} \
    CONFIG.PCW_PERIPHERAL_BOARD_PRESET {part0} \
    CONFIG.PCW_PJTAG_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_PLL_BYPASSMODE_ENABLE {0} \
    CONFIG.PCW_PRESET_BANK0_VOLTAGE {LVCMOS 1.8V} \
    CONFIG.PCW_PRESET_BANK1_VOLTAGE {LVCMOS 1.8V} \
    CONFIG.PCW_PS7_SI_REV {PRODUCTION} \
    CONFIG.PCW_QSPI_GRP_FBCLK_ENABLE {1} \
    CONFIG.PCW_QSPI_GRP_FBCLK_IO {MIO 8} \
    CONFIG.PCW_QSPI_GRP_IO1_ENABLE {1} \
    CONFIG.PCW_QSPI_GRP_IO1_IO {MIO 0 9 .. 13} \
    CONFIG.PCW_QSPI_GRP_SINGLE_SS_ENABLE {0} \
    CONFIG.PCW_QSPI_GRP_SS1_ENABLE {0} \
    CONFIG.PCW_QSPI_INTERNAL_HIGHADDRESS {0xFDFFFFFF} \
    CONFIG.PCW_QSPI_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_QSPI_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_QSPI_PERIPHERAL_FREQMHZ {200} \
    CONFIG.PCW_QSPI_QSPI_IO {MIO 1 .. 6} \
    CONFIG.PCW_SD0_GRP_CD_ENABLE {0} \
    CONFIG.PCW_SD0_GRP_POW_ENABLE {0} \
    CONFIG.PCW_SD0_GRP_WP_ENABLE {0} \
    CONFIG.PCW_SD0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_SD0_SD0_IO {MIO 40 .. 45} \
    CONFIG.PCW_SD1_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_SDIO0_BASEADDR {0xE0100000} \
    CONFIG.PCW_SDIO0_HIGHADDR {0xE0100FFF} \
    CONFIG.PCW_SDIO_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_SDIO_PERIPHERAL_FREQMHZ {50} \
    CONFIG.PCW_SDIO_PERIPHERAL_VALID {1} \
    CONFIG.PCW_SMC_CYCLE_T0 {NA} \
    CONFIG.PCW_SMC_CYCLE_T1 {NA} \
    CONFIG.PCW_SMC_CYCLE_T2 {NA} \
    CONFIG.PCW_SMC_CYCLE_T3 {NA} \
    CONFIG.PCW_SMC_CYCLE_T4 {NA} \
    CONFIG.PCW_SMC_CYCLE_T5 {NA} \
    CONFIG.PCW_SMC_CYCLE_T6 {NA} \
    CONFIG.PCW_SMC_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_SMC_PERIPHERAL_VALID {0} \
    CONFIG.PCW_SPI0_BASEADDR {0xE0006000} \
    CONFIG.PCW_SPI0_HIGHADDR {0xE0006FFF} \
    CONFIG.PCW_SPI0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_SPI0_SPI0_IO {EMIO} \
    CONFIG.PCW_SPI1_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_SPI_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_SPI_PERIPHERAL_FREQMHZ {166.666666} \
    CONFIG.PCW_SPI_PERIPHERAL_VALID {1} \
    CONFIG.PCW_S_AXI_ACP_ARUSER_VAL {31} \
    CONFIG.PCW_S_AXI_ACP_AWUSER_VAL {31} \
    CONFIG.PCW_S_AXI_ACP_ID_WIDTH {3} \
    CONFIG.PCW_S_AXI_HP3_DATA_WIDTH {64} \
    CONFIG.PCW_S_AXI_HP3_ID_WIDTH {6} \
    CONFIG.PCW_TPIU_PERIPHERAL_CLKSRC {External} \
    CONFIG.PCW_TRACE_INTERNAL_WIDTH {2} \
    CONFIG.PCW_TRACE_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_TTC0_CLK0_PERIPHERAL_CLKSRC {CPU_1X} \
    CONFIG.PCW_TTC0_CLK0_PERIPHERAL_DIVISOR0 {1} \
    CONFIG.PCW_TTC0_CLK1_PERIPHERAL_CLKSRC {CPU_1X} \
    CONFIG.PCW_TTC0_CLK1_PERIPHERAL_DIVISOR0 {1} \
    CONFIG.PCW_TTC0_CLK2_PERIPHERAL_CLKSRC {CPU_1X} \
    CONFIG.PCW_TTC0_CLK2_PERIPHERAL_DIVISOR0 {1} \
    CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_TTC1_CLK0_PERIPHERAL_CLKSRC {CPU_1X} \
    CONFIG.PCW_TTC1_CLK0_PERIPHERAL_DIVISOR0 {1} \
    CONFIG.PCW_TTC1_CLK1_PERIPHERAL_CLKSRC {CPU_1X} \
    CONFIG.PCW_TTC1_CLK1_PERIPHERAL_DIVISOR0 {1} \
    CONFIG.PCW_TTC1_CLK2_PERIPHERAL_CLKSRC {CPU_1X} \
    CONFIG.PCW_TTC1_CLK2_PERIPHERAL_DIVISOR0 {1} \
    CONFIG.PCW_TTC1_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_UART0_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_UART1_BASEADDR {0xE0001000} \
    CONFIG.PCW_UART1_BAUD_RATE {115200} \
    CONFIG.PCW_UART1_GRP_FULL_ENABLE {0} \
    CONFIG.PCW_UART1_HIGHADDR {0xE0001FFF} \
    CONFIG.PCW_UART1_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_UART1_UART1_IO {MIO 48 .. 49} \
    CONFIG.PCW_UART_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_UART_PERIPHERAL_FREQMHZ {50} \
    CONFIG.PCW_UART_PERIPHERAL_VALID {1} \
    CONFIG.PCW_UIPARAM_ACT_DDR_FREQ_MHZ {533.333374} \
    CONFIG.PCW_UIPARAM_DDR_ADV_ENABLE {0} \
    CONFIG.PCW_UIPARAM_DDR_AL {0} \
    CONFIG.PCW_UIPARAM_DDR_BL {8} \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY0 {0.25} \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY1 {0.25} \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY2 {0.25} \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY3 {0.25} \
    CONFIG.PCW_UIPARAM_DDR_BUS_WIDTH {32 Bit} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_0_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_0_PACKAGE_LENGTH {92.3275} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_0_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_1_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_1_PACKAGE_LENGTH {92.3275} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_1_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_2_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_2_PACKAGE_LENGTH {92.3275} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_2_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_3_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_3_PACKAGE_LENGTH {92.3275} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_3_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_STOP_EN {0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_0_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_0_PACKAGE_LENGTH {108.9255} \
    CONFIG.PCW_UIPARAM_DDR_DQS_0_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_DQS_1_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_1_PACKAGE_LENGTH {131.286} \
    CONFIG.PCW_UIPARAM_DDR_DQS_1_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_DQS_2_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_2_PACKAGE_LENGTH {131.83} \
    CONFIG.PCW_UIPARAM_DDR_DQS_2_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_DQS_3_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_3_PACKAGE_LENGTH {108.5285} \
    CONFIG.PCW_UIPARAM_DDR_DQS_3_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_0 {0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_1 {0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_2 {0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_3 {0} \
    CONFIG.PCW_UIPARAM_DDR_DQ_0_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQ_0_PACKAGE_LENGTH {107.643} \
    CONFIG.PCW_UIPARAM_DDR_DQ_0_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_DQ_1_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQ_1_PACKAGE_LENGTH {132.917} \
    CONFIG.PCW_UIPARAM_DDR_DQ_1_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_DQ_2_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQ_2_PACKAGE_LENGTH {129.6135} \
    CONFIG.PCW_UIPARAM_DDR_DQ_2_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_DQ_3_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQ_3_PACKAGE_LENGTH {108.6395} \
    CONFIG.PCW_UIPARAM_DDR_DQ_3_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_ENABLE {1} \
    CONFIG.PCW_UIPARAM_DDR_FREQ_MHZ {533.333333} \
    CONFIG.PCW_UIPARAM_DDR_HIGH_TEMP {Normal (0-85)} \
    CONFIG.PCW_UIPARAM_DDR_MEMORY_TYPE {DDR 3} \
    CONFIG.PCW_UIPARAM_DDR_PARTNO {MT41K256M16 RE-125} \
    CONFIG.PCW_UIPARAM_DDR_TRAIN_DATA_EYE {1} \
    CONFIG.PCW_UIPARAM_DDR_TRAIN_READ_GATE {1} \
    CONFIG.PCW_UIPARAM_DDR_TRAIN_WRITE_LEVEL {1} \
    CONFIG.PCW_UIPARAM_DDR_USE_INTERNAL_VREF {0} \
    CONFIG.PCW_UIPARAM_GENERATE_SUMMARY {NA} \
    CONFIG.PCW_USB0_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_USB1_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_USB_RESET_ENABLE {1} \
    CONFIG.PCW_USB_RESET_POLARITY {Active Low} \
    CONFIG.PCW_USE_AXI_FABRIC_IDLE {0} \
    CONFIG.PCW_USE_AXI_NONSECURE {0} \
    CONFIG.PCW_USE_CORESIGHT {0} \
    CONFIG.PCW_USE_CROSS_TRIGGER {0} \
    CONFIG.PCW_USE_CR_FABRIC {1} \
    CONFIG.PCW_USE_DDR_BYPASS {0} \
    CONFIG.PCW_USE_DEBUG {0} \
    CONFIG.PCW_USE_DEFAULT_ACP_USER_VAL {1} \
    CONFIG.PCW_USE_DMA0 {1} \
    CONFIG.PCW_USE_DMA1 {0} \
    CONFIG.PCW_USE_DMA2 {0} \
    CONFIG.PCW_USE_DMA3 {0} \
    CONFIG.PCW_USE_EXPANDED_IOP {0} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
    CONFIG.PCW_USE_HIGH_OCM {0} \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_USE_M_AXI_GP1 {1} \
    CONFIG.PCW_USE_PROC_EVENT_BUS {0} \
    CONFIG.PCW_USE_PS_SLCR_REGISTERS {0} \
    CONFIG.PCW_USE_S_AXI_ACP {1} \
    CONFIG.PCW_USE_S_AXI_GP0 {0} \
    CONFIG.PCW_USE_S_AXI_GP1 {0} \
    CONFIG.PCW_USE_S_AXI_HP0 {0} \
    CONFIG.PCW_USE_S_AXI_HP1 {0} \
    CONFIG.PCW_USE_S_AXI_HP2 {0} \
    CONFIG.PCW_USE_S_AXI_HP3 {1} \
    CONFIG.PCW_USE_TRACE {0} \
    CONFIG.PCW_VALUE_SILVERSION {3} \
    CONFIG.PCW_WDT_PERIPHERAL_CLKSRC {CPU_1X} \
    CONFIG.PCW_WDT_PERIPHERAL_DIVISOR0 {1} \
    CONFIG.PCW_WDT_PERIPHERAL_ENABLE {0} \
    CONFIG.preset {ZC706} \
  ] $sys_ps7


  # Create instance: sys_rstgen, and set properties
  set sys_rstgen [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 sys_rstgen ]
  set_property CONFIG.C_EXT_RST_WIDTH {1} $sys_rstgen


  # Create instance: util_ad9361_adc_fifo, and set properties
  set util_ad9361_adc_fifo [ create_bd_cell -type ip -vlnv analog.com:user:util_wfifo:1.0 util_ad9361_adc_fifo ]
  set_property -dict [list \
    CONFIG.DIN_ADDRESS_WIDTH {4} \
    CONFIG.DIN_DATA_WIDTH {16} \
    CONFIG.DOUT_DATA_WIDTH {16} \
    CONFIG.NUM_OF_CHANNELS {4} \
  ] $util_ad9361_adc_fifo


  # Create instance: util_ad9361_adc_pack, and set properties
  set util_ad9361_adc_pack [ create_bd_cell -type ip -vlnv analog.com:user:util_cpack2:1.0 util_ad9361_adc_pack ]
  set_property -dict [list \
    CONFIG.NUM_OF_CHANNELS {4} \
    CONFIG.SAMPLE_DATA_WIDTH {16} \
  ] $util_ad9361_adc_pack


  # Create instance: util_ad9361_dac_upack, and set properties
  set util_ad9361_dac_upack [ create_bd_cell -type ip -vlnv analog.com:user:util_upack2:1.0 util_ad9361_dac_upack ]
  set_property -dict [list \
    CONFIG.NUM_OF_CHANNELS {4} \
    CONFIG.SAMPLE_DATA_WIDTH {16} \
  ] $util_ad9361_dac_upack


  # Create instance: util_ad9361_divclk, and set properties
  set util_ad9361_divclk [ create_bd_cell -type ip -vlnv analog.com:user:util_clkdiv:1.0 util_ad9361_divclk ]

  set_property -dict [ list \
   CONFIG.FREQ_HZ {40000000} \
 ] [get_bd_pins /util_ad9361_divclk/clk_out]

  # Create instance: util_ad9361_divclk_reset, and set properties
  set util_ad9361_divclk_reset [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 util_ad9361_divclk_reset ]

  # Create instance: util_ad9361_divclk_sel, and set properties
  set util_ad9361_divclk_sel [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_reduced_logic:2.0 util_ad9361_divclk_sel ]
  set_property CONFIG.C_SIZE {2} $util_ad9361_divclk_sel


  # Create instance: util_ad9361_divclk_sel_concat, and set properties
  set util_ad9361_divclk_sel_concat [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 util_ad9361_divclk_sel_concat ]
  set_property CONFIG.NUM_PORTS {2} $util_ad9361_divclk_sel_concat


  # Create instance: util_ad9361_tdd_sync, and set properties
  set util_ad9361_tdd_sync [ create_bd_cell -type ip -vlnv analog.com:user:util_tdd_sync:1.0 util_ad9361_tdd_sync ]
  set_property CONFIG.TDD_SYNC_PERIOD {10000000} $util_ad9361_tdd_sync


  # Create interface connections
  connect_bd_intf_net -intf_net S00_AXI_1 [get_bd_intf_pins axi_cpu_interconnect/S00_AXI] [get_bd_intf_pins sys_ps7/M_AXI_GP0]
  connect_bd_intf_net -intf_net axi_cpu_interconnect_M00_AXI [get_bd_intf_pins axi_cpu_interconnect/M00_AXI] [get_bd_intf_pins axi_iic_main/S_AXI]
  connect_bd_intf_net -intf_net axi_cpu_interconnect_M01_AXI [get_bd_intf_pins axi_ad9361/s_axi] [get_bd_intf_pins axi_cpu_interconnect/M01_AXI]
  connect_bd_intf_net -intf_net openwifi_ip_M00_AXI [get_bd_intf_pins openwifi_ip/M00_AXI] [get_bd_intf_pins sys_ps7/S_AXI_ACP]
  connect_bd_intf_net -intf_net openwifi_ip_M00_AXI1 [get_bd_intf_pins openwifi_ip/M00_AXI1] [get_bd_intf_pins sys_ps7/S_AXI_HP3]
  connect_bd_intf_net -intf_net sys_ps7_DDR [get_bd_intf_ports ddr] [get_bd_intf_pins sys_ps7/DDR]
  connect_bd_intf_net -intf_net sys_ps7_FIXED_IO [get_bd_intf_ports fixed_io] [get_bd_intf_pins sys_ps7/FIXED_IO]
  connect_bd_intf_net -intf_net sys_ps7_M_AXI_GP1 [get_bd_intf_pins openwifi_ip/S00_AXI] [get_bd_intf_pins sys_ps7/M_AXI_GP1]

  # Create port connections
  connect_bd_net -net GND_1_dout [get_bd_pins GND_1/dout] [get_bd_pins sys_concat_intc/In0] [get_bd_pins sys_concat_intc/In8] [get_bd_pins sys_concat_intc/In9] [get_bd_pins sys_concat_intc/In10] [get_bd_pins sys_concat_intc/In11]
  connect_bd_net -net axi_ad9361_adc_data_i0 [get_bd_pins axi_ad9361/adc_data_i0] [get_bd_pins util_ad9361_adc_fifo/din_data_0]
  connect_bd_net -net axi_ad9361_adc_data_i1 [get_bd_pins axi_ad9361/adc_data_i1] [get_bd_pins util_ad9361_adc_fifo/din_data_2]
  connect_bd_net -net axi_ad9361_adc_data_q0 [get_bd_pins axi_ad9361/adc_data_q0] [get_bd_pins util_ad9361_adc_fifo/din_data_1]
  connect_bd_net -net axi_ad9361_adc_data_q1 [get_bd_pins axi_ad9361/adc_data_q1] [get_bd_pins util_ad9361_adc_fifo/din_data_3]
  connect_bd_net -net axi_ad9361_adc_enable_i0 [get_bd_pins axi_ad9361/adc_enable_i0] [get_bd_pins util_ad9361_adc_fifo/din_enable_0]
  connect_bd_net -net axi_ad9361_adc_enable_i1 [get_bd_pins axi_ad9361/adc_enable_i1] [get_bd_pins util_ad9361_adc_fifo/din_enable_2]
  connect_bd_net -net axi_ad9361_adc_enable_q0 [get_bd_pins axi_ad9361/adc_enable_q0] [get_bd_pins util_ad9361_adc_fifo/din_enable_1]
  connect_bd_net -net axi_ad9361_adc_enable_q1 [get_bd_pins axi_ad9361/adc_enable_q1] [get_bd_pins util_ad9361_adc_fifo/din_enable_3]
  connect_bd_net -net axi_ad9361_adc_r1_mode [get_bd_pins axi_ad9361/adc_r1_mode] [get_bd_pins util_ad9361_divclk_sel_concat/In0]
  connect_bd_net -net axi_ad9361_adc_valid_i0 [get_bd_pins axi_ad9361/adc_valid_i0] [get_bd_pins util_ad9361_adc_fifo/din_valid_0]
  connect_bd_net -net axi_ad9361_adc_valid_i1 [get_bd_pins axi_ad9361/adc_valid_i1] [get_bd_pins util_ad9361_adc_fifo/din_valid_2]
  connect_bd_net -net axi_ad9361_adc_valid_q0 [get_bd_pins axi_ad9361/adc_valid_q0] [get_bd_pins util_ad9361_adc_fifo/din_valid_1]
  connect_bd_net -net axi_ad9361_adc_valid_q1 [get_bd_pins axi_ad9361/adc_valid_q1] [get_bd_pins util_ad9361_adc_fifo/din_valid_3]
  connect_bd_net -net axi_ad9361_dac_enable_i0 [get_bd_pins axi_ad9361/dac_enable_i0] [get_bd_pins axi_ad9361_dac_fifo/dout_enable_0]
  connect_bd_net -net axi_ad9361_dac_enable_i1 [get_bd_pins axi_ad9361/dac_enable_i1] [get_bd_pins axi_ad9361_dac_fifo/dout_enable_2]
  connect_bd_net -net axi_ad9361_dac_enable_q0 [get_bd_pins axi_ad9361/dac_enable_q0] [get_bd_pins axi_ad9361_dac_fifo/dout_enable_1]
  connect_bd_net -net axi_ad9361_dac_enable_q1 [get_bd_pins axi_ad9361/dac_enable_q1] [get_bd_pins axi_ad9361_dac_fifo/dout_enable_3]
  connect_bd_net -net axi_ad9361_dac_fifo_din_enable_0 [get_bd_pins axi_ad9361_dac_fifo/din_enable_0] [get_bd_pins util_ad9361_dac_upack/enable_0]
  connect_bd_net -net axi_ad9361_dac_fifo_din_enable_1 [get_bd_pins axi_ad9361_dac_fifo/din_enable_1] [get_bd_pins util_ad9361_dac_upack/enable_1]
  connect_bd_net -net axi_ad9361_dac_fifo_din_enable_2 [get_bd_pins axi_ad9361_dac_fifo/din_enable_2] [get_bd_pins util_ad9361_dac_upack/enable_2]
  connect_bd_net -net axi_ad9361_dac_fifo_din_enable_3 [get_bd_pins axi_ad9361_dac_fifo/din_enable_3] [get_bd_pins util_ad9361_dac_upack/enable_3]
  connect_bd_net -net axi_ad9361_dac_fifo_din_valid_0 [get_bd_pins axi_ad9361_dac_fifo/din_valid_0] [get_bd_pins util_ad9361_dac_upack/fifo_rd_en]
  connect_bd_net -net axi_ad9361_dac_fifo_dout_data_0 [get_bd_pins axi_ad9361/dac_data_i0] [get_bd_pins axi_ad9361_dac_fifo/dout_data_0]
  connect_bd_net -net axi_ad9361_dac_fifo_dout_data_1 [get_bd_pins axi_ad9361/dac_data_q0] [get_bd_pins axi_ad9361_dac_fifo/dout_data_1]
  connect_bd_net -net axi_ad9361_dac_fifo_dout_data_2 [get_bd_pins axi_ad9361/dac_data_i1] [get_bd_pins axi_ad9361_dac_fifo/dout_data_2]
  connect_bd_net -net axi_ad9361_dac_fifo_dout_data_3 [get_bd_pins axi_ad9361/dac_data_q1] [get_bd_pins axi_ad9361_dac_fifo/dout_data_3]
  connect_bd_net -net axi_ad9361_dac_fifo_dout_unf [get_bd_pins axi_ad9361/dac_dunf] [get_bd_pins axi_ad9361_dac_fifo/dout_unf]
  connect_bd_net -net axi_ad9361_dac_r1_mode [get_bd_pins axi_ad9361/dac_r1_mode] [get_bd_pins util_ad9361_divclk_sel_concat/In1]
  connect_bd_net -net axi_ad9361_dac_valid_i0 [get_bd_pins axi_ad9361/dac_valid_i0] [get_bd_pins axi_ad9361_dac_fifo/dout_valid_0]
  connect_bd_net -net axi_ad9361_dac_valid_i1 [get_bd_pins axi_ad9361/dac_valid_i1] [get_bd_pins axi_ad9361_dac_fifo/dout_valid_2]
  connect_bd_net -net axi_ad9361_dac_valid_q0 [get_bd_pins axi_ad9361/dac_valid_q0] [get_bd_pins axi_ad9361_dac_fifo/dout_valid_1]
  connect_bd_net -net axi_ad9361_dac_valid_q1 [get_bd_pins axi_ad9361/dac_valid_q1] [get_bd_pins axi_ad9361_dac_fifo/dout_valid_3]
  connect_bd_net -net axi_ad9361_enable [get_bd_ports enable] [get_bd_pins axi_ad9361/enable]
  connect_bd_net -net axi_ad9361_l_clk [get_bd_pins axi_ad9361/clk] [get_bd_pins axi_ad9361/l_clk] [get_bd_pins axi_ad9361_dac_fifo/dout_clk] [get_bd_pins util_ad9361_adc_fifo/din_clk] [get_bd_pins util_ad9361_divclk/clk]
  connect_bd_net -net axi_ad9361_rst [get_bd_pins axi_ad9361/rst] [get_bd_pins axi_ad9361_dac_fifo/dout_rst] [get_bd_pins util_ad9361_adc_fifo/din_rst]
  connect_bd_net -net axi_ad9361_tdd_sync_cntr [get_bd_ports tdd_sync_t] [get_bd_pins axi_ad9361/tdd_sync_cntr] [get_bd_pins util_ad9361_tdd_sync/sync_mode]
  connect_bd_net -net axi_ad9361_tx_clk_out_n [get_bd_ports tx_clk_out_n] [get_bd_pins axi_ad9361/tx_clk_out_n]
  connect_bd_net -net axi_ad9361_tx_clk_out_p [get_bd_ports tx_clk_out_p] [get_bd_pins axi_ad9361/tx_clk_out_p]
  connect_bd_net -net axi_ad9361_tx_data_out_n [get_bd_ports tx_data_out_n] [get_bd_pins axi_ad9361/tx_data_out_n]
  connect_bd_net -net axi_ad9361_tx_data_out_p [get_bd_ports tx_data_out_p] [get_bd_pins axi_ad9361/tx_data_out_p]
  connect_bd_net -net axi_ad9361_tx_frame_out_n [get_bd_ports tx_frame_out_n] [get_bd_pins axi_ad9361/tx_frame_out_n]
  connect_bd_net -net axi_ad9361_tx_frame_out_p [get_bd_ports tx_frame_out_p] [get_bd_pins axi_ad9361/tx_frame_out_p]
  connect_bd_net -net axi_ad9361_txnrx [get_bd_ports txnrx] [get_bd_pins axi_ad9361/txnrx]
  connect_bd_net -net axi_iic_main_iic2intc_irpt [get_bd_pins axi_iic_main/iic2intc_irpt] [get_bd_pins sys_concat_intc/In14]
  connect_bd_net -net dac_ready_1 [get_bd_pins openwifi_ip/dac_ready] [get_bd_pins util_ad9361_dac_upack/s_axis_ready]
  connect_bd_net -net gpio_i_1 [get_bd_ports gpio_i] [get_bd_pins sys_ps7/GPIO_I]
  connect_bd_net -net gpio_status_1 [get_bd_ports gpio_status] [get_bd_pins openwifi_ip/gpio_status]
  connect_bd_net -net openwifi_ip_dac_data [get_bd_pins openwifi_ip/dac_data] [get_bd_pins util_ad9361_dac_upack/s_axis_data]
  connect_bd_net -net openwifi_ip_dac_valid [get_bd_pins openwifi_ip/dac_valid] [get_bd_pins util_ad9361_dac_upack/s_axis_valid]
  connect_bd_net -net openwifi_ip_mm2s_introut [get_bd_pins openwifi_ip/mm2s_introut] [get_bd_pins sys_concat_intc/In6]
  connect_bd_net -net openwifi_ip_mm2s_introut1 [get_bd_pins openwifi_ip/mm2s_introut1] [get_bd_pins sys_concat_intc/In2]
  connect_bd_net -net openwifi_ip_rx_pkt_intr [get_bd_pins openwifi_ip/rx_pkt_intr] [get_bd_pins sys_concat_intc/In1]
  connect_bd_net -net openwifi_ip_s2mm_introut [get_bd_pins openwifi_ip/s2mm_introut] [get_bd_pins sys_concat_intc/In3]
  connect_bd_net -net openwifi_ip_s2mm_introut1 [get_bd_pins openwifi_ip/s2mm_introut1] [get_bd_pins sys_concat_intc/In7]
  connect_bd_net -net openwifi_ip_spi0_clk_o [get_bd_ports spi0_clk_o] [get_bd_pins openwifi_ip/spi0_clk_o]
  connect_bd_net -net openwifi_ip_spi0_csn_0_o [get_bd_ports spi0_csn_0_o] [get_bd_pins openwifi_ip/spi0_csn_0_o]
  connect_bd_net -net openwifi_ip_spi0_sdo_o [get_bd_ports spi0_sdo_o] [get_bd_pins openwifi_ip/spi0_sdo_o]
  connect_bd_net -net openwifi_ip_tx_itrpt [get_bd_pins openwifi_ip/tx_itrpt] [get_bd_pins sys_concat_intc/In5]
  connect_bd_net -net rx_clk_in_n_1 [get_bd_ports rx_clk_in_n] [get_bd_pins axi_ad9361/rx_clk_in_n]
  connect_bd_net -net rx_clk_in_p_1 [get_bd_ports rx_clk_in_p] [get_bd_pins axi_ad9361/rx_clk_in_p]
  connect_bd_net -net rx_data_in_n_1 [get_bd_ports rx_data_in_n] [get_bd_pins axi_ad9361/rx_data_in_n]
  connect_bd_net -net rx_data_in_p_1 [get_bd_ports rx_data_in_p] [get_bd_pins axi_ad9361/rx_data_in_p]
  connect_bd_net -net rx_frame_in_n_1 [get_bd_ports rx_frame_in_n] [get_bd_pins axi_ad9361/rx_frame_in_n]
  connect_bd_net -net rx_frame_in_p_1 [get_bd_ports rx_frame_in_p] [get_bd_pins axi_ad9361/rx_frame_in_p]
  connect_bd_net -net spi0_clk_i_1 [get_bd_ports spi0_clk_i] [get_bd_pins sys_ps7/SPI0_SCLK_I]
  connect_bd_net -net spi0_csn_i_1 [get_bd_ports spi0_csn_i] [get_bd_pins sys_ps7/SPI0_SS_I]
  connect_bd_net -net spi0_sdi_i_1 [get_bd_ports spi0_sdi_i] [get_bd_pins sys_ps7/SPI0_MISO_I]
  connect_bd_net -net spi0_sdo_i_1 [get_bd_ports spi0_sdo_i] [get_bd_pins sys_ps7/SPI0_MOSI_I]
  connect_bd_net -net spi1_clk_i_1 [get_bd_ports spi1_clk_i]
  connect_bd_net -net spi1_csn_i_1 [get_bd_ports spi1_csn_i]
  connect_bd_net -net spi1_sdi_i_1 [get_bd_ports spi1_sdi_i]
  connect_bd_net -net spi1_sdo_i_1 [get_bd_ports spi1_sdo_i]
  connect_bd_net -net sys_200m_clk [get_bd_pins axi_ad9361/delay_clk] [get_bd_pins sys_ps7/FCLK_CLK1]
  connect_bd_net -net sys_concat_intc_dout [get_bd_pins sys_concat_intc/dout] [get_bd_pins sys_ps7/IRQ_F2P]
  connect_bd_net -net sys_cpu_clk [get_bd_pins axi_ad9361/s_axi_aclk] [get_bd_pins axi_cpu_interconnect/ACLK] [get_bd_pins axi_cpu_interconnect/M00_ACLK] [get_bd_pins axi_cpu_interconnect/M01_ACLK] [get_bd_pins axi_cpu_interconnect/S00_ACLK] [get_bd_pins axi_iic_main/s_axi_aclk] [get_bd_pins openwifi_ip/ps_clk] [get_bd_pins sys_ps7/DMA0_ACLK] [get_bd_pins sys_ps7/FCLK_CLK0] [get_bd_pins sys_ps7/M_AXI_GP0_ACLK] [get_bd_pins sys_rstgen/slowest_sync_clk] [get_bd_pins util_ad9361_tdd_sync/clk]
  connect_bd_net -net sys_cpu_reset [get_bd_pins sys_rstgen/peripheral_reset]
  connect_bd_net -net sys_cpu_resetn [get_bd_pins axi_ad9361/s_axi_aresetn] [get_bd_pins axi_cpu_interconnect/ARESETN] [get_bd_pins axi_cpu_interconnect/M00_ARESETN] [get_bd_pins axi_cpu_interconnect/M01_ARESETN] [get_bd_pins axi_cpu_interconnect/S00_ARESETN] [get_bd_pins axi_iic_main/s_axi_aresetn] [get_bd_pins sys_rstgen/peripheral_aresetn] [get_bd_pins util_ad9361_divclk_reset/ext_reset_in] [get_bd_pins util_ad9361_tdd_sync/rstn]
  connect_bd_net -net sys_ps7_FCLK_CLK2 [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins openwifi_ip/m_axi_mm2s_aclk] [get_bd_pins sys_ps7/M_AXI_GP1_ACLK] [get_bd_pins sys_ps7/S_AXI_ACP_ACLK] [get_bd_pins sys_ps7/S_AXI_HP3_ACLK]
  connect_bd_net -net sys_ps7_FCLK_RESET0_N [get_bd_pins sys_ps7/FCLK_RESET0_N] [get_bd_pins sys_rstgen/ext_reset_in]
  connect_bd_net -net sys_ps7_FCLK_RESET2_N [get_bd_pins openwifi_ip/ext_reset_in] [get_bd_pins sys_ps7/FCLK_RESET2_N]
  connect_bd_net -net sys_ps7_GPIO_O [get_bd_ports gpio_o] [get_bd_pins sys_ps7/GPIO_O]
  connect_bd_net -net sys_ps7_GPIO_T [get_bd_ports gpio_t] [get_bd_pins sys_ps7/GPIO_T]
  connect_bd_net -net sys_ps7_SPI0_MOSI_O [get_bd_pins openwifi_ip/spi0_mosi] [get_bd_pins sys_ps7/SPI0_MOSI_O]
  connect_bd_net -net sys_ps7_SPI0_SCLK_O [get_bd_pins openwifi_ip/spi0_sclk] [get_bd_pins sys_ps7/SPI0_SCLK_O]
  connect_bd_net -net sys_ps7_SPI0_SS1_O [get_bd_ports spi0_csn_1_o] [get_bd_pins sys_ps7/SPI0_SS1_O]
  connect_bd_net -net sys_ps7_SPI0_SS2_O [get_bd_ports spi0_csn_2_o] [get_bd_pins sys_ps7/SPI0_SS2_O]
  connect_bd_net -net sys_ps7_SPI0_SS_O [get_bd_pins openwifi_ip/spi0_csn] [get_bd_pins sys_ps7/SPI0_SS_O]
  connect_bd_net -net sys_ps7_SPI1_MOSI_O [get_bd_ports spi1_sdo_o]
  connect_bd_net -net sys_ps7_SPI1_SCLK_O [get_bd_ports spi1_clk_o]
  connect_bd_net -net sys_ps7_SPI1_SS1_O [get_bd_ports spi1_csn_1_o]
  connect_bd_net -net sys_ps7_SPI1_SS2_O [get_bd_ports spi1_csn_2_o]
  connect_bd_net -net sys_ps7_SPI1_SS_O [get_bd_ports spi1_csn_0_o]
  connect_bd_net -net tdd_sync_i_1 [get_bd_ports tdd_sync_i] [get_bd_pins util_ad9361_tdd_sync/sync_in]
  connect_bd_net -net up_enable_1 [get_bd_ports up_enable] [get_bd_pins axi_ad9361/up_enable]
  connect_bd_net -net up_txnrx_1 [get_bd_ports up_txnrx] [get_bd_pins axi_ad9361/up_txnrx]
  connect_bd_net -net util_ad9361_adc_fifo_din_ovf [get_bd_pins axi_ad9361/adc_dovf] [get_bd_pins util_ad9361_adc_fifo/din_ovf]
  connect_bd_net -net util_ad9361_adc_fifo_dout_data_0 [get_bd_pins util_ad9361_adc_fifo/dout_data_0] [get_bd_pins util_ad9361_adc_pack/fifo_wr_data_0]
  connect_bd_net -net util_ad9361_adc_fifo_dout_data_1 [get_bd_pins util_ad9361_adc_fifo/dout_data_1] [get_bd_pins util_ad9361_adc_pack/fifo_wr_data_1]
  connect_bd_net -net util_ad9361_adc_fifo_dout_data_2 [get_bd_pins util_ad9361_adc_fifo/dout_data_2] [get_bd_pins util_ad9361_adc_pack/fifo_wr_data_2]
  connect_bd_net -net util_ad9361_adc_fifo_dout_data_3 [get_bd_pins util_ad9361_adc_fifo/dout_data_3] [get_bd_pins util_ad9361_adc_pack/fifo_wr_data_3]
  connect_bd_net -net util_ad9361_adc_fifo_dout_enable_0 [get_bd_pins util_ad9361_adc_fifo/dout_enable_0] [get_bd_pins util_ad9361_adc_pack/enable_0]
  connect_bd_net -net util_ad9361_adc_fifo_dout_enable_1 [get_bd_pins util_ad9361_adc_fifo/dout_enable_1] [get_bd_pins util_ad9361_adc_pack/enable_1]
  connect_bd_net -net util_ad9361_adc_fifo_dout_enable_2 [get_bd_pins util_ad9361_adc_fifo/dout_enable_2] [get_bd_pins util_ad9361_adc_pack/enable_2]
  connect_bd_net -net util_ad9361_adc_fifo_dout_enable_3 [get_bd_pins util_ad9361_adc_fifo/dout_enable_3] [get_bd_pins util_ad9361_adc_pack/enable_3]
  connect_bd_net -net util_ad9361_adc_fifo_dout_valid_0 [get_bd_pins util_ad9361_adc_fifo/dout_valid_0] [get_bd_pins util_ad9361_adc_pack/fifo_wr_en]
  connect_bd_net -net util_ad9361_adc_pack_fifo_wr_overflow [get_bd_pins util_ad9361_adc_fifo/dout_ovf] [get_bd_pins util_ad9361_adc_pack/fifo_wr_overflow]
  connect_bd_net -net util_ad9361_adc_pack_packed_fifo_wr_data [get_bd_pins openwifi_ip/adc_data] [get_bd_pins util_ad9361_adc_pack/packed_fifo_wr_data]
  connect_bd_net -net util_ad9361_adc_pack_packed_fifo_wr_en [get_bd_pins openwifi_ip/adc_valid] [get_bd_pins util_ad9361_adc_pack/packed_fifo_wr_en]
  connect_bd_net -net util_ad9361_dac_upack_fifo_rd_data_0 [get_bd_pins axi_ad9361_dac_fifo/din_data_0] [get_bd_pins util_ad9361_dac_upack/fifo_rd_data_0]
  connect_bd_net -net util_ad9361_dac_upack_fifo_rd_data_1 [get_bd_pins axi_ad9361_dac_fifo/din_data_1] [get_bd_pins util_ad9361_dac_upack/fifo_rd_data_1]
  connect_bd_net -net util_ad9361_dac_upack_fifo_rd_data_2 [get_bd_pins axi_ad9361_dac_fifo/din_data_2] [get_bd_pins util_ad9361_dac_upack/fifo_rd_data_2]
  connect_bd_net -net util_ad9361_dac_upack_fifo_rd_data_3 [get_bd_pins axi_ad9361_dac_fifo/din_data_3] [get_bd_pins util_ad9361_dac_upack/fifo_rd_data_3]
  connect_bd_net -net util_ad9361_dac_upack_fifo_rd_underflow [get_bd_pins axi_ad9361_dac_fifo/din_unf] [get_bd_pins util_ad9361_dac_upack/fifo_rd_underflow]
  connect_bd_net -net util_ad9361_dac_upack_fifo_rd_valid [get_bd_pins axi_ad9361_dac_fifo/din_valid_in_0] [get_bd_pins axi_ad9361_dac_fifo/din_valid_in_1] [get_bd_pins axi_ad9361_dac_fifo/din_valid_in_2] [get_bd_pins axi_ad9361_dac_fifo/din_valid_in_3] [get_bd_pins util_ad9361_dac_upack/fifo_rd_valid]
  connect_bd_net -net util_ad9361_divclk_clk_out [get_bd_pins axi_ad9361_dac_fifo/din_clk] [get_bd_pins clk_wiz_0/clk_in1] [get_bd_pins openwifi_ip/adc_clk] [get_bd_pins util_ad9361_adc_fifo/dout_clk] [get_bd_pins util_ad9361_adc_pack/clk] [get_bd_pins util_ad9361_dac_upack/clk] [get_bd_pins util_ad9361_divclk/clk_out] [get_bd_pins util_ad9361_divclk_reset/slowest_sync_clk]
  connect_bd_net -net util_ad9361_divclk_reset_peripheral_aresetn [get_bd_pins axi_ad9361_dac_fifo/din_rstn] [get_bd_pins util_ad9361_adc_fifo/dout_rstn] [get_bd_pins util_ad9361_divclk_reset/peripheral_aresetn]
  connect_bd_net -net util_ad9361_divclk_reset_peripheral_reset [get_bd_pins clk_wiz_0/reset] [get_bd_pins openwifi_ip/adc_rst] [get_bd_pins util_ad9361_adc_pack/reset] [get_bd_pins util_ad9361_dac_upack/reset] [get_bd_pins util_ad9361_divclk_reset/peripheral_reset]
  connect_bd_net -net util_ad9361_divclk_sel_Res [get_bd_pins util_ad9361_divclk/clk_sel] [get_bd_pins util_ad9361_divclk_sel/Res]
  connect_bd_net -net util_ad9361_divclk_sel_concat_dout [get_bd_pins util_ad9361_divclk_sel/Op1] [get_bd_pins util_ad9361_divclk_sel_concat/dout]
  connect_bd_net -net util_ad9361_tdd_sync_sync_out [get_bd_ports tdd_sync_o] [get_bd_pins axi_ad9361/tdd_sync] [get_bd_pins util_ad9361_tdd_sync/sync_out]

  # Create address segments
  assign_bd_address -offset 0x80400000 -range 0x00010000 -target_address_space [get_bd_addr_spaces sys_ps7/Data] [get_bd_addr_segs openwifi_ip/axi_dma_0/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x80410000 -range 0x00010000 -target_address_space [get_bd_addr_spaces sys_ps7/Data] [get_bd_addr_segs openwifi_ip/axi_dma_1/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x79020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces sys_ps7/Data] [get_bd_addr_segs axi_ad9361/s_axi/axi_lite] -force
  assign_bd_address -offset 0x41600000 -range 0x00001000 -target_address_space [get_bd_addr_spaces sys_ps7/Data] [get_bd_addr_segs axi_iic_main/S_AXI/Reg] -force
  assign_bd_address -offset 0x83C30000 -range 0x00010000 -target_address_space [get_bd_addr_spaces sys_ps7/Data] [get_bd_addr_segs openwifi_ip/openofdm_rx_0/s00_axi/reg0] -force
  assign_bd_address -offset 0x83C10000 -range 0x00010000 -target_address_space [get_bd_addr_spaces sys_ps7/Data] [get_bd_addr_segs openwifi_ip/openofdm_tx_0/s00_axi/reg0] -force
  assign_bd_address -offset 0x83C20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces sys_ps7/Data] [get_bd_addr_segs openwifi_ip/rx_intf_0/s00_axi/reg0] -force
  assign_bd_address -offset 0x83C50000 -range 0x00010000 -target_address_space [get_bd_addr_spaces sys_ps7/Data] [get_bd_addr_segs openwifi_ip/side_ch_0/s00_axi/reg0] -force
  assign_bd_address -offset 0x83C00000 -range 0x00010000 -target_address_space [get_bd_addr_spaces sys_ps7/Data] [get_bd_addr_segs openwifi_ip/tx_intf_0/s00_axi/reg0] -force
  assign_bd_address -offset 0x83C40000 -range 0x00010000 -target_address_space [get_bd_addr_spaces sys_ps7/Data] [get_bd_addr_segs openwifi_ip/xpu_0/s00_axi/reg0] -force
  assign_bd_address -offset 0x00000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_0/Data_MM2S] [get_bd_addr_segs sys_ps7/S_AXI_HP3/HP3_DDR_LOWOCM] -force
  assign_bd_address -offset 0x00000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_0/Data_S2MM] [get_bd_addr_segs sys_ps7/S_AXI_HP3/HP3_DDR_LOWOCM] -force
  assign_bd_address -offset 0x00000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_0/Data_SG] [get_bd_addr_segs sys_ps7/S_AXI_HP3/HP3_DDR_LOWOCM] -force
  assign_bd_address -offset 0x00000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_1/Data_MM2S] [get_bd_addr_segs sys_ps7/S_AXI_ACP/ACP_DDR_LOWOCM] -force
  assign_bd_address -offset 0xFC000000 -range 0x02000000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_1/Data_MM2S] [get_bd_addr_segs sys_ps7/S_AXI_ACP/ACP_QSPI_LINEAR] -force
  assign_bd_address -offset 0x00000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_1/Data_S2MM] [get_bd_addr_segs sys_ps7/S_AXI_ACP/ACP_DDR_LOWOCM] -force
  assign_bd_address -offset 0xFC000000 -range 0x02000000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_1/Data_S2MM] [get_bd_addr_segs sys_ps7/S_AXI_ACP/ACP_QSPI_LINEAR] -force
  assign_bd_address -offset 0x00000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_1/Data_SG] [get_bd_addr_segs sys_ps7/S_AXI_ACP/ACP_DDR_LOWOCM] -force
  assign_bd_address -offset 0xFC000000 -range 0x02000000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_1/Data_SG] [get_bd_addr_segs sys_ps7/S_AXI_ACP/ACP_QSPI_LINEAR] -force

  # Exclude Address Segments
  exclude_bd_addr_seg -offset 0xE0000000 -range 0x00400000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_1/Data_MM2S] [get_bd_addr_segs sys_ps7/S_AXI_ACP/ACP_IOP]
  exclude_bd_addr_seg -offset 0x40000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_1/Data_MM2S] [get_bd_addr_segs sys_ps7/S_AXI_ACP/ACP_M_AXI_GP0]
  exclude_bd_addr_seg -offset 0x80000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_1/Data_MM2S] [get_bd_addr_segs sys_ps7/S_AXI_ACP/ACP_M_AXI_GP1]
  exclude_bd_addr_seg -offset 0xE0000000 -range 0x00400000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_1/Data_S2MM] [get_bd_addr_segs sys_ps7/S_AXI_ACP/ACP_IOP]
  exclude_bd_addr_seg -offset 0x40000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_1/Data_S2MM] [get_bd_addr_segs sys_ps7/S_AXI_ACP/ACP_M_AXI_GP0]
  exclude_bd_addr_seg -offset 0x80000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_1/Data_S2MM] [get_bd_addr_segs sys_ps7/S_AXI_ACP/ACP_M_AXI_GP1]
  exclude_bd_addr_seg -offset 0xE0000000 -range 0x00400000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_1/Data_SG] [get_bd_addr_segs sys_ps7/S_AXI_ACP/ACP_IOP]
  exclude_bd_addr_seg -offset 0x40000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_1/Data_SG] [get_bd_addr_segs sys_ps7/S_AXI_ACP/ACP_M_AXI_GP0]
  exclude_bd_addr_seg -offset 0x80000000 -range 0x40000000 -target_address_space [get_bd_addr_spaces openwifi_ip/axi_dma_1/Data_SG] [get_bd_addr_segs sys_ps7/S_AXI_ACP/ACP_M_AXI_GP1]


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


