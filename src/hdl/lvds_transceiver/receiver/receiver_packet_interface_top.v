
/*
    Module  : RECEIVER_PACKET_INTERFACE_TOP
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _RECEIVER_PACKET_INTERFACE_TOP_V_
`define _RECEIVER_PACKET_INTERFACE_TOP_V_



`include "src/hdl/lvds_transceiver/include/lvds_transceiver_defines.vh"


`include "src/hdl/lvds_transceiver/receiver/packet_checker/receiver_packet_checker_top.v"
`include "src/hdl/divers/sync_fifo.v"
//
`include "src/hdl/cdc/async_fifo.v"
`include "src/hdl/cdc/async_reset.v"




module receiver_packet_interface_top #(
    parameter TLP_WIDTH              = `DEFAULT_TLP_WIDTH,
    parameter TLP_ID_WIDTH           = `CONFIG_TLP_ID_WIDTH,
    parameter TLP_BUFFER_TYPE        = `DEFAULT_TLP_BUFFER_TYPE,
    parameter TLP_BUFFER_ADDR_WIDTH  = `DEFAULT_TLP_BUFFER_ADDR_WIDTH,       
    parameter DLLP_WIDTH             = `CONFIG_DLLP_WIDTH,
    parameter DLLP_BUFFER_ADDR_WIDTH = `CONFIG_DLLP_BUFFER_ADDR_WIDTH,
    parameter CRC_INIT               = `DEFAULT_CRC_INIT,
    parameter CRC_POLY               = `DEFAULT_CRC_POLY
)(
    input wire i_sys_clk_120, i_sys_arst_n,
    // tlp interface => connect to higher layer 
    input wire i_tlp_rd_clk,
    input wire i_tlp_rd,
    output wire[TLP_WIDTH-1:0] o_tlp,
    output wire o_tlp_valid,
    output wire o_tlp_rdy,
    // link - manager
    input wire i_dllp_rd,
    output wire[DLLP_WIDTH-1:0] o_dllp,
    output wire o_dllp_valid,
    //
    input wire i_status_id_rd,
    output wire[TLP_ID_WIDTH:0] o_status_id,
    output wire o_status_id_valid,
    //
    input wire i_phys_packet_k_en,
    input wire[7:0] i_phys_packet_byte
);


    ////////////////////////////////////////////////////////////////////////////////////////
    // LOCAL RESET
    async_reset #(
        .STAGES   (2),
        .INIT     (1'b0),
        .RST_VAL  (1'b0)
    ) inst_sys_reset_120 (
        .i_clk    (i_sys_clk_120), 
        .i_rst_n  (i_sys_arst_n),
        .o_rst    ()
    );

    async_reset #(
        .STAGES   (2),
        .INIT     (1'b0),
        .RST_VAL  (1'b0)
    ) inst_tlp_reset (
        .i_clk    (i_tlp_rd_clk), 
        .i_rst_n  (i_sys_arst_n), // reset by system
        .o_rst    ()
    );

    ///////////////////////////////////////////////////////////////////////////////////
    // INTERFACE TO TRANSACTION - LAYER (BUFFERING)
    wire internal_fifo_tlp_rdy_o;
    
    generate
        if (TLP_BUFFER_TYPE == 0) begin
            sync_fifo #(
                .DATA_WIDTH     (TLP_WIDTH),
                .ADDR_WIDTH     (TLP_BUFFER_ADDR_WIDTH)
            ) inst_sync_fifo_tlp (
                .i_clk          (i_sys_clk_120),
                .i_arst_n       (inst_sys_reset_120.o_rst),
                .i_wr           (inst_packet_checker.o_tlp_valid),
                .i_rd           (i_tlp_rd),
                .i_data         (inst_packet_checker.o_tlp),
                .o_data         (o_tlp),
                .o_full         (),
                .o_empty        ()
            );

            assign o_tlp_valid             = ~inst_sync_fifo_tlp.o_empty;
            assign internal_fifo_tlp_rdy_o = ~inst_sync_fifo_tlp.o_full;

           
        end else begin 
            async_fifo #(
                .DATA_WIDTH     (TLP_WIDTH),
                .ADDR_WIDTH     (TLP_BUFFER_ADDR_WIDTH)
            ) inst_async_fifo_tlp (
                .i_wr_clk       (i_sys_clk_120),
                .i_wr_arst_n    (inst_sys_reset_120.o_rst),
                .i_rd_clk       (i_tlp_rd_clk),
                .i_rd_arst_n    (inst_tlp_reset.o_rst),
                .i_wr           (inst_packet_checker.o_tlp_valid),
                .i_rd           (i_tlp_rd),
                .i_data         (inst_packet_checker.o_tlp),
                .o_data         (o_tlp),
                .o_full         (),
                .o_empty        ()
            );

            assign o_tlp_valid             = ~inst_async_fifo_tlp.o_empty;
            assign internal_fifo_tlp_rdy_o = ~inst_async_fifo_tlp.o_full;
        end
    endgenerate

    assign o_tlp_rdy = internal_fifo_tlp_rdy_o;

    ////////////////////////////////////////////////////////////////////////////////////
    // INTERFACE LINK CONTROL

    sync_fifo #(
        .DATA_WIDTH     (DLLP_WIDTH),
        .ADDR_WIDTH     (DLLP_BUFFER_ADDR_WIDTH)
    ) inst_sync_fifo_dllp (
        .i_clk          (i_sys_clk_120),
        .i_arst_n       (inst_sys_reset_120.o_rst),
        .i_wr           (inst_packet_checker.o_dllp_valid),
        .i_rd           (i_dllp_rd),
        .i_data         (inst_packet_checker.o_dllp),
        .o_data         (o_dllp),
        .o_full         (),
        .o_empty        ()
    );

    assign o_dllp_valid = ~inst_sync_fifo_dllp.o_empty; 


    //////////////////////////////////////////////////////////////////////////////////
    // PACKET CHECKER

    receiver_packet_checker_top #(
        .TLP_WIDTH          (TLP_WIDTH),
        .DLLP_WIDTH         (DLLP_WIDTH),
        .TLP_ID_WIDTH       (TLP_ID_WIDTH),
        .CRC_POLY           (CRC_POLY),
        .CRC_INIT           (CRC_INIT)
    ) inst_packet_checker (
        .i_clk              (i_sys_clk_120),
        .i_arst_n           (inst_sys_reset_120.o_rst),
    // TLP - INTERFACE
        .i_tlp_rdy          (internal_fifo_tlp_rdy_o),
        .o_tlp              (),
        .o_tlp_valid        (),
    // DLLP - INTERFACE
        .i_dllp_rdy         (~inst_sync_fifo_dllp.o_full),
        .o_dllp             (),
        .o_dllp_valid       (),
    // LINK - CONTROL - INTERFACE
        .i_status_id_ack    (i_status_id_rd),
        .o_status_id        (o_status_id),
        .o_status_id_valid  (o_status_id_valid),
    // PHYSICAL - INTERFACE
        .i_phys_k_en        (i_phys_packet_k_en),
        .i_phys_byte        (i_phys_packet_byte)
);


endmodule

`endif /* RECEIVER_PACKET_INTERFACE_TOP */