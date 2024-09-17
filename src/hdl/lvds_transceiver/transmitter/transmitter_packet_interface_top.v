
/*
    Module  : TRANSMITTER_PACKET_INTERFACE_TOP
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _TRANSMITTER_PACKET_INTERFACE_TOP_V_
`define _TRANSMITTER_PACKET_INTERFACE_TOP_V_

`include "src/hdl/lvds_transceiver/include/lvds_transceiver_defines.vh"
`include "src/hdl/lvds_transceiver/transmitter/packet_generator/transmitter_packet_generator_top.v"

`include "src/hdl/divers/sync_fifo.v"
//
`include "src/hdl/cdc/async_fifo.v"
`include "src/hdl/cdc/async_reset.v"


module transmitter_packet_interface_top #(
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
    // TLP INTERFACE 
    input wire i_tlp_wr_clk,
    input wire i_tlp_wr,
    input wire[TLP_WIDTH-1:0] i_tlp,
    output wire o_tlp_rdy,
    // DLLP INTERFACE
    input wire i_dllp_wr,
    input wire[DLLP_WIDTH-1:0] i_dllp,
    output wire o_dllp_rdy,
    // LINK CONTROL
    input wire i_tlp_start,
    input wire i_tlp_stop,    
    input wire i_tlp_rply_start,       
    input wire i_tlp_id_ack,         
    output wire o_tlp_rply_act,          
    output wire o_tlp_id_all_ack,     
    output wire o_tlp_id_wait_ack, 
    output wire [TLP_ID_WIDTH-1:0] o_tlp_id_nack,
    output wire [TLP_ID_WIDTH-1:0] o_tlp_id_ack,
    // PHYSICAL INTERFACE
    output wire o_phys_packet_k_en,
    output wire[7:0] o_phys_packet_byte
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
        .i_clk    (i_tlp_wr_clk), 
        .i_rst_n  (i_sys_arst_n), // reset by system
        .o_rst    ()
    );


    //////////////////////////////////////////////////////////////////////////////////////////
    // INTERFACE TO TRANSACTION - LAYER (BUFFERING)

    wire fifo_tlp_valid_o;
    wire[TLP_WIDTH-1:0] fifo_tlp_data_o;
    wire test_almost_empty;

    generate
        if (TLP_BUFFER_TYPE == 0) begin
            sync_fifo #(
                .DATA_WIDTH     (TLP_WIDTH),
                .ADDR_WIDTH     (TLP_BUFFER_ADDR_WIDTH)
            ) inst_sync_fifo_tlp (
                .i_clk          (i_sys_clk_120),
                .i_arst_n       (inst_sys_reset_120.o_rst),
                .i_wr           (i_tlp_wr),
                .i_rd           (inst_packet_generator.o_tlp_ack),
                .i_data         (i_tlp),
                .o_data         (),
                .o_full         (),
                .o_empty        ()
            );

            // local signal's
            assign o_tlp_rdy        = ~inst_sync_fifo_tlp.o_full;
            assign fifo_tlp_valid_o = ~inst_sync_fifo_tlp.o_empty;
            assign fifo_tlp_data_o  = inst_sync_fifo_tlp.o_data;
        
        end else begin 
            async_fifo #(
                .DATA_WIDTH     (TLP_WIDTH),
                .ADDR_WIDTH     (TLP_BUFFER_ADDR_WIDTH)
            ) inst_async_fifo_tlp (
                .i_wr_clk       (i_tlp_wr_clk),
                .i_wr_arst_n    (inst_tlp_reset.o_rst),
                .i_rd_clk       (i_sys_clk_120),
                .i_rd_arst_n    (inst_sys_reset_120.o_rst),
                .i_wr           (i_tlp_wr),
                .i_rd           (inst_packet_generator.o_tlp_ack),
                .i_data         (i_tlp),
                .o_data         (),
                .o_full         (),
                .o_almost_full  (),
                .o_empty        (),
                .o_almost_empty ()
            );

            // local signal's
            assign o_tlp_rdy        = ~inst_async_fifo_tlp.o_full;
            assign fifo_tlp_valid_o = ~inst_async_fifo_tlp.o_empty;
            assign fifo_tlp_data_o  = inst_async_fifo_tlp.o_data;
        end
    endgenerate

    
    ///////////////////////////////////////////////////////////////////////////////////////
    // LINK - LAYER

    sync_fifo #(
        .DATA_WIDTH     (DLLP_WIDTH),
        .ADDR_WIDTH     (DLLP_BUFFER_ADDR_WIDTH)
    ) inst_sync_fifo_dllp (
        .i_clk          (i_sys_clk_120),
        .i_arst_n       (inst_sys_reset_120.o_rst),
        .i_wr           (i_dllp_wr),
        .i_rd           (inst_packet_generator.o_dllp_ack),
        .i_data         (i_dllp),
        .o_data         (),
        .o_full         (),
        .o_empty        ()
    );

    assign o_dllp_rdy = ~inst_sync_fifo_dllp.o_full; 


    //////////////////////////////////////////////////////////////////////////////////////////
    // PACKET GENERATOR

    transmitter_packet_generator_top #(
        .TLP_WIDTH         (TLP_WIDTH),
        .DLLP_WIDTH        (DLLP_WIDTH),
        .TLP_ID_WIDTH      (TLP_ID_WIDTH),
        .CRC_POLY          (CRC_POLY),
        .CRC_INIT          (CRC_INIT)
    ) inst_packet_generator (
        .i_clk             (i_sys_clk_120),
        .i_arst_n          (inst_sys_reset_120.o_rst),
        // TLP
        .i_tlp_valid       (fifo_tlp_valid_o),
        .i_tlp             (fifo_tlp_data_o),
        .o_tlp_ack         (),
        // DLLP
        .i_dllp_valid      (~inst_sync_fifo_dllp.o_empty),
        .i_dllp            (inst_sync_fifo_dllp.o_data),
        .o_dllp_ack        (),
        // CONTROL
        .i_tlp_start       (i_tlp_start),
        .i_tlp_stop        (i_tlp_stop),
        .i_tlp_rply_start  (i_tlp_rply_start),
        .i_tlp_id_ack      (i_tlp_id_ack),
        .o_tlp_rply_act    (o_tlp_rply_act),
        .o_tlp_id_all_ack  (o_tlp_id_all_ack),
        .o_tlp_id_wait_ack (o_tlp_id_wait_ack),
        .o_tlp_id_nack     (o_tlp_id_nack),
        .o_tlp_id_ack      (o_tlp_id_ack),
        // PHYSICAL
        .o_phys_k_en       (o_phys_packet_k_en),
        .o_phys_byte       (o_phys_packet_byte)
    );


endmodule

`endif /* TRANSMITTER_PACKET_INTERFACE_TOP */