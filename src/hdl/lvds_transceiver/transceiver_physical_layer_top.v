

/*
    Module  : TRANSCEIVER_PHYSICAL_LAYER_TOP
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024
*/

`ifndef _TRANSCEIVER_PHYSICAL_LAYER_TOP_V_
`define _TRANSCEIVER_PHYSICAL_LAYER_TOP_V_


`include "src/hdl/lvds_transceiver/include/lvds_transceiver_defines.vh"

//
`include "src/hdl/lvds_transceiver/receiver/physical/physical_iob_clk_div.v"
`include "src/hdl/lvds_transceiver/receiver/physical/receiver_physical_iob_top.v"
//
`include "src/hdl/lvds_transceiver/transmitter/physical/physical_iob_clk_gen.v"
`include "src/hdl/lvds_transceiver/transmitter/physical/transmitter_physical_iob_top.v"
//
`include "src/hdl/cdc/async_reset.v"

module transceiver_physical_layer_top #(   
    parameter CONNECTION_TYPE   = `DEFAULT_CONNECTION_TYPE,
    parameter SIMULATION_ENABLE = 0,
    parameter CTRL_DELAY_ENABLE = 0,
    parameter IDELAYE_REF_FREQ  = 200
) (
    // CLK_120
    input wire i_clk_120, i_clk_120_arst_n,
    output wire o_clk_120,
    //
    // cal - control
    input wire i_cal_start,
    output wire o_cal_done,
    output wire o_cal_fail,
    //
    // data transmission
    input wire i_packet_k_en,
    input wire[7:0] i_packet_byte,
    output wire o_packet_k_en,
    output wire[7:0] o_packet_byte,
    // 
    // CLK_200
    input wire i_clk_200, i_clk_200_arst_n,
    output wire o_clk_200,
    //
    input wire[4:0] i_ctrl_delay_tabs,
    output wire[4:0] o_mon_edge_tabs,
    output wire[4:0] o_mon_delay_tabs,
    output wire o_mon_delay_tabs_wr,
    //
    // CLK_600
    input wire i_clk_600_p, i_clk_600_n,
    output wire o_clk_600_p, o_clk_600_n,
    //
    input wire i_rx_p,
    input wire i_rx_n,
    output wire o_tx_p,
    output wire o_tx_n
    //
);

    

    ///////////////////////////////////////////////////////////////////////////////////////////
    wire internal_clk_120;
    wire internal_clk_200;
    wire internal_clk_600;

    generate
        if (CONNECTION_TYPE == 1) begin 

            physical_iob_clk_div inst_physical_iob_clk_div (
                .i_clk_600_p    (i_clk_600_p), 
                .i_clk_600_n    (i_clk_600_n),
                .o_clk_120      (internal_clk_120),
                .o_clk_200      (internal_clk_200),
                .o_clk_600      (internal_clk_600)
            );

            assign o_clk_600_p = 1'b0;
            assign o_clk_600_n = 1'b0;

        end else begin

            physical_iob_clk_gen inst_physical_iob_clk_gen (
                .i_clk_600     (i_clk_600_p),
                .o_clk_600_p   (o_clk_600_p),
                .o_clk_600_n   (o_clk_600_n)
            );

            assign internal_clk_120 = i_clk_120;
            assign internal_clk_200 = i_clk_200;
            assign internal_clk_600 = i_clk_600_p;

        end

    endgenerate

    assign o_clk_120 = internal_clk_120;
    assign o_clk_200 = internal_clk_200;
    
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // RESET

    async_reset #(
        .STAGES   (2),
        .INIT     (1'b0),
        .RST_VAL  (1'b0)
    ) inst_clk_120_reset (
        .i_clk    (internal_clk_120), 
        .i_rst_n  (i_clk_120_arst_n),
        .o_rst    ()
    );

    async_reset #(
        .STAGES   (2),
        .INIT     (1'b0),
        .RST_VAL  (1'b0)
    ) inst_clk_200_reset (
        .i_clk    (internal_clk_200), 
        .i_rst_n  (i_clk_200_arst_n),
        .o_rst    ()
    );


    /////////////////////////////////////////////////////////////////////////////////////////////
    transmitter_physical_iob_top #(
        .ENABLE_OSERDESE1 (SIMULATION_ENABLE)
    ) inst_physical_iob_tx (
        // CLK_120
        .i_clk_120_arst_n (inst_clk_120_reset.o_rst), 
        .i_clk_120        (internal_clk_120),
        .i_packet_k_en    (i_packet_k_en),
        .i_packet_byte    (i_packet_byte),
        // CLK_600
        .i_clk_600        (internal_clk_600),
        .o_tx_p           (o_tx_p),
        .o_tx_n           (o_tx_n)
    );


    //////////////////////////////////////////////////////////////////////////////////////////////
    receiver_physical_iob_top #(
        .ENABLE_ISERDESE1     (SIMULATION_ENABLE),
        .ENABLE_TEST_DELAY    (CTRL_DELAY_ENABLE),
        .IDELAYE_REF_FREQ     (IDELAYE_REF_FREQ)
    ) inst_physical_iob_rx (
        // CLK_120
        .i_clk_120_arst_n     (inst_clk_120_reset.o_rst), 
        .i_clk_120            (internal_clk_120),
        .i_cal_start          (i_cal_start),
        .o_cal_done           (o_cal_done),
        .o_cal_fail           (o_cal_fail),
        .o_packet_k_en        (o_packet_k_en),
        .o_packet_byte        (o_packet_byte),
        // CLK_200
        .i_clk_200_arst_n     (inst_clk_200_reset.o_rst),
        .i_clk_200            (internal_clk_200),
        .i_ctrl_delay_tabs    (i_ctrl_delay_tabs),
        .o_mon_edge_tabs      (o_mon_edge_tabs),
        .o_mon_delay_tabs     (o_mon_delay_tabs),
        .o_mon_delay_tabs_wr  (o_mon_delay_tabs_wr),
        // CLK_600
        .i_clk_600            (internal_clk_600),
        .i_rx_p               (i_rx_p),
        .i_rx_n               (i_rx_n)
    );

    


endmodule

`endif /* TRANSCEIVER_PHYSICAL_LAYER_TOP */