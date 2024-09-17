

/*
    Module  : LVDS_TRANSCEIVER_TOP
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _LVDS_TRANSCEIVER_TOP_V_
`define _LVDS_TRANSCEIVER_TOP_V_


`include "src/hdl/lvds_transceiver/include/lvds_transceiver_defines.vh"
//
`include "src/hdl/lvds_transceiver/transceiver_link_layer_top.v"
`include "src/hdl/lvds_transceiver/transceiver_physical_layer_top.v"
`include "src/hdl/lvds_transceiver/transceiver_elastic_buffer.v"
//
`include "src/hdl/cdc/async_reset.v"
`include "src/hdl/cdc/synchronizer.v"
`include "src/hdl/cdc/handshake_synchronizer.v"


module lvds_transceiver_top #(
    parameter SIMULATION_ENABLE     = 1,
    parameter PHYS_CTRL_MON_ENABLE  = 1,
    parameter IDELAYE_REF_FREQ      = 200,
    //
    parameter CONNECTION_TYPE       = `DEFAULT_CONNECTION_TYPE,
    parameter TLP_TX_WIDTH          = `DEFAULT_TLP_WIDTH,
    parameter TLP_RX_WIDTH          = `DEFAULT_TLP_WIDTH,
    parameter TLP_ID_WIDTH          = `CONFIG_TLP_ID_WIDTH,
    parameter TLP_BUFFER_TYPE       = `DEFAULT_TLP_BUFFER_TYPE,
    parameter TLP_BUFFER_ADDR_WIDTH = `DEFAULT_TLP_BUFFER_ADDR_WIDTH,
    parameter CRC_POLY              = `DEFAULT_CRC_POLY,             
    parameter CRC_INIT              = `DEFAULT_CRC_INIT
)(
    input wire i_sys_clk_120, i_sys_arst_n,
    //
    // TLP - INTERFACE
    input wire i_tlp_wr_clk, i_tlp_rd_clk,
    input wire i_tlp_wr, i_tlp_rd,
    input wire[TLP_TX_WIDTH-1:0] i_tlp,
    output wire[TLP_RX_WIDTH-1:0] o_tlp,
    output wire o_tlp_rdy, o_tlp_valid,
    //
    // PHYSICAL - INTERFACE
    input wire i_phys_clk_600_p, i_phys_clk_600_n,
    input wire i_phys_clk_200, i_phys_clk_120,
    input wire i_phys_rx_p, i_phys_rx_n,
    output wire o_phys_clk_600_p, o_phys_clk_600_n,
    output wire o_phys_tx_p, o_phys_tx_n,
    // CONTROL & MONITOR
    input wire i_ctrl_mon_clk,
    input wire i_ctrl_mon_arst_n,
    input wire i_ctrl_tab_delay_wr,
    input wire[4:0] i_ctrl_tab_delay,
    output wire[4:0] o_mon_edge_tabs,
    output wire[4:0] o_mon_delay_tabs 
);

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOCAL_MASTER_RESET
    wire local_master_reset;

    async_reset #(
        .STAGES   (4),
        .INIT     (1'b0),
        .RST_VAL  (1'b0)
    ) inst_master_reset (
        .i_clk    (i_sys_clk_120), 
        .i_rst_n  (i_sys_arst_n),
        .o_rst    (local_master_reset)
    );


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LINK_LAYER

    transceiver_link_layer_top #(
        .TLP_TX_WIDTH          (TLP_TX_WIDTH),
        .TLP_RX_WIDTH          (TLP_RX_WIDTH),
        .TLP_BUFFER_TYPE       (TLP_BUFFER_TYPE),
        .TLP_BUFFER_ADDR_WIDTH (TLP_BUFFER_ADDR_WIDTH),
        .CRC_INIT              (CRC_INIT),
        .CRC_POLY              (CRC_POLY)
    ) inst_link_layer_top (
        .i_sys_clk_120         (i_sys_clk_120),
        .i_sys_arst_n          (local_master_reset),
        // TLP - INTERFACE
        .i_tlp_wr_clk          (i_tlp_wr_clk), 
        .i_tlp_rd_clk          (i_tlp_rd_clk), 
        .i_tlp_wr              (i_tlp_wr), 
        .i_tlp_rd              (i_tlp_rd), 
        .i_tlp                 (i_tlp), 
        .o_tlp                 (o_tlp),
        .o_tlp_rdy             (o_tlp_rdy),
        .o_tlp_valid           (o_tlp_valid),
        //
        // PHYSICAL - INTERFACE
        .i_phys_cal_done       (inst_sync_link_cal_done.o_sync),
        .i_phys_cal_fail       (inst_sync_link_cal_fail.o_sync),
        .o_phys_cal_start      (),
        //
        .i_phys_packet_k_en    (inst_rx_packet_buffer.o_data[8]),
        .i_phys_packet_byte    (inst_rx_packet_buffer.o_data[7:0]), 
        .o_phys_packet_k_en    (), 
        .o_phys_packet_byte    () 
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // CDC => SYS_CLK_120 <=> PHYS_CLK_120

    // CAL START    : LINK_LAYER => PHYSICAL_LAYER 
    synchronizer #(
        .STAGES   (2),
        .INIT     (1'b0)
    ) inst_sync_phys_cal_start (
        .i_clk    (inst_physical_layer_top.o_clk_120),
        .i_arst_n (local_master_reset),
        .i_async  (inst_link_layer_top.o_phys_cal_start), 
        .o_sync   () 
    );

    // CAL DONE     : PHYSICAL_LAYER => LINK_LAYER
    synchronizer #(
        .STAGES   (2),
        .INIT     (1'b0)
    ) inst_sync_link_cal_done (
        .i_clk    (i_sys_clk_120),
        .i_arst_n (local_master_reset),
        .i_async  (inst_physical_layer_top.o_cal_done), 
        .o_sync   () 
    );

    // CAL FAIL     : PHYSICAL_LAYER => LINK_LAYER
    synchronizer #(
        .STAGES   (2),
        .INIT     (1'b0)
    ) inst_sync_link_cal_fail (
        .i_clk    (i_sys_clk_120),
        .i_arst_n (local_master_reset),
        .i_async  (inst_physical_layer_top.o_cal_fail), 
        .o_sync   () 
    );

    //
    transceiver_elastic_buffer #(
        .DATA_WIDTH     (9),
        .ADDR_WIDTH     (6)
    ) inst_tx_packet_buffer (
        .i_wr_clk       (i_sys_clk_120),
        .i_wr_arst_n    (local_master_reset),
        .i_rd_clk       (inst_physical_layer_top.o_clk_120),
        .i_rd_arst_n    (local_master_reset),
        .i_data         ({inst_link_layer_top.o_phys_packet_k_en, inst_link_layer_top.o_phys_packet_byte}),
        .o_data         ()
    );

    //
    transceiver_elastic_buffer #(
        .DATA_WIDTH     (9),
        .ADDR_WIDTH     (6)
    ) inst_rx_packet_buffer (
        .i_wr_clk       (inst_physical_layer_top.o_clk_120),
        .i_wr_arst_n    (local_master_reset),
        .i_rd_clk       (i_sys_clk_120),
        .i_rd_arst_n    (local_master_reset),
        .i_data         ({inst_physical_layer_top.o_packet_k_en, inst_physical_layer_top.o_packet_byte}),
        .o_data         ()
    );



    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // PHYSICAL_LAYER

    transceiver_physical_layer_top #(   
        .CONNECTION_TYPE       (CONNECTION_TYPE),
        .SIMULATION_ENABLE     (SIMULATION_ENABLE),
        .CTRL_DELAY_ENABLE     (0), // not work with idelaye cascade 
        .IDELAYE_REF_FREQ      (IDELAYE_REF_FREQ)
    ) inst_physical_layer_top (
        // CLK_120
        .i_clk_120             (i_phys_clk_120), 
        .i_clk_120_arst_n      (local_master_reset),
        .o_clk_120             (),
        //
        // CAL - CONTROL
        .i_cal_start           (inst_sync_phys_cal_start.o_sync),
        .o_cal_done            (),
        .o_cal_fail            (),
        //
        // DATA TRANSMISSION
        .i_packet_k_en         (inst_tx_packet_buffer.o_data[8]),        
        .i_packet_byte         (inst_tx_packet_buffer.o_data[7:0]),
        .o_packet_k_en         (),
        .o_packet_byte         (),
        // 
        // CLK_200
        .i_clk_200             (i_phys_clk_200),
        .i_clk_200_arst_n      (local_master_reset),
        .o_clk_200             (),
        //
        .i_ctrl_delay_tabs     (5'b00000), // not used
        .o_mon_edge_tabs       (),
        .o_mon_delay_tabs      (),
        .o_mon_delay_tabs_wr   (),
        //
        // CLK_600
        .i_clk_600_p           (i_phys_clk_600_p),
        .i_clk_600_n           (i_phys_clk_600_n),
        .o_clk_600_p           (o_phys_clk_600_p), 
        .o_clk_600_n           (o_phys_clk_600_n),
        //
        .i_rx_p                (i_phys_rx_p),
        .i_rx_n                (i_phys_rx_n),
        .o_tx_p                (o_phys_tx_p),
        .o_tx_n                (o_phys_tx_n)
    );


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // PHYSICAL CONTROL & MONITOR

    wire[4:0] internal_ctrl_delay_tabs;

    generate
        if (PHYS_CTRL_MON_ENABLE == 1) begin
            //
            handshake_synchronizer #(
                .SYNC_STAGES    (2),
                .DATA_WIDTH     (5)
            ) inst_cdc_mon_edge_tabs (
                .i_in_clk       (inst_physical_layer_top.o_clk_200),
                .i_in_arst_n    (local_master_reset),
                .i_out_clk      (i_ctrl_mon_clk),
                .i_out_arst_n   (i_ctrl_mon_arst_n),
                .i_in_wr        (inst_physical_layer_top.o_cal_done),
                .o_in_rdy       (),
                .o_in_ack       (),
                .o_out_valid    (),
                .i_in_data      (inst_physical_layer_top.o_mon_edge_tabs),
                .o_out_data     (o_mon_edge_tabs)
            );

            handshake_synchronizer #(
                .SYNC_STAGES    (2),
                .DATA_WIDTH     (5)
            ) inst_cdc_mon_delay_tabs (
                .i_in_clk       (inst_physical_layer_top.o_clk_200),
                .i_in_arst_n    (local_master_reset),
                .i_out_clk      (i_ctrl_mon_clk),
                .i_out_arst_n   (i_ctrl_mon_arst_n),
                .i_in_wr        (inst_physical_layer_top.o_mon_delay_tabs_wr),
                .o_in_rdy       (),
                .o_in_ack       (),
                .o_out_valid    (),
                .i_in_data      (inst_physical_layer_top.o_mon_delay_tabs),
                .o_out_data     (o_mon_delay_tabs)
            );

            /*
            handshake_synchronizer #(
                .SYNC_STAGES    (2),
                .DATA_WIDTH     (5)
            ) inst_cdc_ctrl_delay_tabs (
                .i_in_clk       (i_ctrl_mon_clk),
                .i_in_arst_n    (i_ctrl_mon_arst_n),
                .i_out_clk      (inst_physical_layer_top.o_clk_200),
                .i_out_arst_n   (local_master_reset),
                .i_in_wr        (i_ctrl_tab_delay_wr),
                .o_in_rdy       (),
                .o_in_ack       (),
                .o_out_valid    (),
                .i_in_data      (i_ctrl_delay_tabs),
                .o_out_data     (internal_ctrl_delay_tabs)
            );

            */
        end else begin
            //
            assign o_mon_edge_tabs  = 5'b00000;
            assign o_mon_delay_tabs = 5'b00000;
            //
            //assign internal_ctrl_delay_tabs = 5'b00000;
        end

    endgenerate




endmodule

`endif /* LVDS_TRANSCEIVER_TOP */