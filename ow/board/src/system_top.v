// Board adapter for XC7Z045-FBG676 + AD9361. Schematic pages 04,09,10,11,12.
// Openwifi processing remains in the upstream system BD; this file maps board IO.
`timescale 1ns/1ps
module system_top (
    inout [14:0] ddr_addr, inout [2:0] ddr_ba,
    inout ddr_cas_n, ddr_ck_n, ddr_ck_p, ddr_cke, ddr_cs_n,
    inout [3:0] ddr_dm, inout [31:0] ddr_dq,
    inout [3:0] ddr_dqs_n, ddr_dqs_p,
    inout ddr_odt, ddr_ras_n, ddr_reset_n, ddr_we_n,
    inout fixed_io_ddr_vrn, fixed_io_ddr_vrp,
    inout [53:0] fixed_io_mio,
    inout fixed_io_ps_clk, fixed_io_ps_porb, fixed_io_ps_srstb,
    input rx_clk_in_p, rx_clk_in_n, rx_frame_in_p, rx_frame_in_n,
    input [5:0] rx_data_in_p, rx_data_in_n,
    output tx_clk_out_p, tx_clk_out_n, tx_frame_out_p, tx_frame_out_n,
    output [5:0] tx_data_out_p, tx_data_out_n,
    output enable, txnrx,
    inout resetb, sync_in, en_agc, gpio_clksel,
    inout [3:0] ctrl_in,
    input [7:0] gpio_status,
    output spi_csn, spi_clk, spi_mosi, input spi_miso,
    output gpio_R1_LNA_EN, gpio_R2_LNA_EN,
    output gpio_T1_PA_EN, gpio_T2_PA_EN
);
    wire [63:0] gpio_i, gpio_o, gpio_t;
    // Preserve upstream GPIO numbers: Linux Zynq GPIO index = EMIO bit + 54.
    // Reset 100, sync 99, en_agc 98, ctl 94..97, enable 101, txnrx 102.
    assign gpio_i = {gpio_o[63:40], gpio_status, gpio_o[31:0]};
    IOBUF u_reset (.I(gpio_o[46]), .T(gpio_t[46]), .O(), .IO(resetb));
    IOBUF u_sync  (.I(gpio_o[45]), .T(gpio_t[45]), .O(), .IO(sync_in));
    IOBUF u_agc   (.I(gpio_o[44]), .T(gpio_t[44]), .O(), .IO(en_agc));
    IOBUF u_clksel(.I(gpio_o[51]), .T(gpio_t[51]), .O(), .IO(gpio_clksel));
    genvar i;
    generate for (i=0; i<4; i=i+1) begin: g_ctl
        IOBUF u_ctl (.I(gpio_o[40+i]), .T(gpio_t[40+i]), .O(), .IO(ctrl_in[i]));
    end endgenerate
    // Schematic: these enables switch the RF regulators. Receive-only first build.
    assign gpio_R1_LNA_EN = 1'b1;
    assign gpio_R2_LNA_EN = 1'b1;
    assign gpio_T1_PA_EN = 1'b0;
    assign gpio_T2_PA_EN = 1'b0;
    system_wrapper i_system_wrapper (
        .ddr_addr(ddr_addr), .ddr_ba(ddr_ba), .ddr_cas_n(ddr_cas_n),
        .ddr_ck_n(ddr_ck_n), .ddr_ck_p(ddr_ck_p), .ddr_cke(ddr_cke),
        .ddr_cs_n(ddr_cs_n), .ddr_dm(ddr_dm), .ddr_dq(ddr_dq),
        .ddr_dqs_n(ddr_dqs_n), .ddr_dqs_p(ddr_dqs_p), .ddr_odt(ddr_odt),
        .ddr_ras_n(ddr_ras_n), .ddr_reset_n(ddr_reset_n), .ddr_we_n(ddr_we_n),
        .fixed_io_ddr_vrn(fixed_io_ddr_vrn), .fixed_io_ddr_vrp(fixed_io_ddr_vrp),
        .fixed_io_mio(fixed_io_mio), .fixed_io_ps_clk(fixed_io_ps_clk),
        .fixed_io_ps_porb(fixed_io_ps_porb), .fixed_io_ps_srstb(fixed_io_ps_srstb),
        .gpio_i(gpio_i), .gpio_o(gpio_o), .gpio_t(gpio_t), .gpio_status(gpio_status),
        .rx_clk_in_p(rx_clk_in_p), .rx_clk_in_n(rx_clk_in_n),
        .rx_frame_in_p(rx_frame_in_p), .rx_frame_in_n(rx_frame_in_n),
        .rx_data_in_p(rx_data_in_p), .rx_data_in_n(rx_data_in_n),
        .tx_clk_out_p(tx_clk_out_p), .tx_clk_out_n(tx_clk_out_n),
        .tx_frame_out_p(tx_frame_out_p), .tx_frame_out_n(tx_frame_out_n),
        .tx_data_out_p(tx_data_out_p), .tx_data_out_n(tx_data_out_n),
        .enable(enable), .txnrx(txnrx), .up_enable(gpio_o[47]), .up_txnrx(gpio_o[48]),
        .spi0_clk_i(1'b0), .spi0_clk_o(spi_clk), .spi0_csn_i(1'b1),
        .spi0_csn_0_o(spi_csn), .spi0_csn_1_o(), .spi0_csn_2_o(),
        .spi0_sdi_i(spi_miso), .spi0_sdo_i(1'b0), .spi0_sdo_o(spi_mosi),
        .spi1_clk_i(1'b0), .spi1_clk_o(), .spi1_csn_i(1'b1),
        .spi1_csn_0_o(), .spi1_csn_1_o(), .spi1_csn_2_o(),
        .spi1_sdi_i(1'b0), .spi1_sdo_i(1'b0), .spi1_sdo_o(),
        .tdd_sync_i(1'b0), .tdd_sync_o(), .tdd_sync_t()
    );
endmodule
