/*
    Module  : TRANSMITTER_PACKET_GENERATOR_TOP
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`ifndef _TRANSMITTER_PACKET_GENERATOR_TOP_V_
`define _TRANSMITTER_PACKET_GENERATOR_TOP_V_

`include "src/hdl/global_functions.vh"
`include "src/hdl/lvds_transceiver/include/lvds_transceiver_defines.vh"

`include "src/hdl/crc/crc_8.v"
`include "src/hdl/lvds_transceiver/transmitter/packet_generator/packet_generator_controller.v"
`include "src/hdl/lvds_transceiver/transmitter/packet_generator/packet_generator_shift_out.v"
`include "src/hdl/lvds_transceiver/transmitter/packet_generator/packet_generator_replay_buffer.v"
//
`include "src/hdl/cdc/async_reset.v"

module transmitter_packet_generator_top #(
    parameter TLP_WIDTH    = `DEFAULT_TLP_WIDTH,
    parameter DLLP_WIDTH   = `CONFIG_DLLP_WIDTH,
    parameter TLP_ID_WIDTH = `CONFIG_TLP_ID_WIDTH,
    parameter CRC_POLY     = `DEFAULT_CRC_POLY,
    parameter CRC_INIT     = `DEFAULT_CRC_INIT
)(
    input wire i_clk, i_arst_n,
    // TLP - INTERFACE
    input wire i_tlp_valid,      
    input wire [TLP_WIDTH-1:0] i_tlp,
    output wire o_tlp_ack,
    // DLLP - INTERFACE
    input wire i_dllp_valid,
    input wire [DLLP_WIDTH-1:0] i_dllp,
    output wire o_dllp_ack,
    // CONTROL - INTERFACE
    input wire i_tlp_start,
    input wire i_tlp_stop,
    input wire i_tlp_rply_start,
    input wire i_tlp_id_ack,  
    output wire o_tlp_rply_act,
    output wire o_tlp_id_all_ack,
    output wire o_tlp_id_wait_ack,
    output wire [TLP_ID_WIDTH-1:0] o_tlp_id_nack,
    output wire [TLP_ID_WIDTH-1:0] o_tlp_id_ack,
    // PHYSICAL - INTERFACE
    output wire o_phys_k_en,
    output wire [7:0] o_phys_byte 
);

    /////////////////////////////////////////////////////////////////////////////////////////
    // CONSTANT'S

    localparam TLP_HEADER_BYTES = `fun_sizeof_byte((TLP_ID_WIDTH + 1) << 1);
    localparam TLP_BYTES        = `fun_sizeof_byte(TLP_WIDTH) + TLP_HEADER_BYTES;  
    localparam DLLP_BYTES       = `fun_sizeof_byte(DLLP_WIDTH);

    localparam DLLP_FRAME_WIDTH = (DLLP_BYTES << 3); 
    localparam TLP_FRAME_WIDTH  = (TLP_BYTES  << 3);  
    localparam TLP_HEADER_WIDTH = (TLP_HEADER_BYTES << 3);

    localparam TLP_HEADER_PADDING = `fun_padding_bits((TLP_ID_WIDTH + 1) << 1);
    localparam TLP_FRAME_PADDING  = `fun_padding_bits(TLP_WIDTH);
    localparam DLLP_FRAME_PADDING = `fun_padding_bits(DLLP_WIDTH);


    ////////////////////////////////////////////////////////////////////////////////////////
    // LOCAL RESET
    wire local_reset_n;

    async_reset #(
        .STAGES   (2),
        .INIT     (1'b0),
        .RST_VAL  (1'b0)
    ) inst_local_reset (
        .i_clk    (i_clk), 
        .i_rst_n  (i_arst_n),
        .o_rst    (local_reset_n)
    );
    
    ///////////////////////////////////////////////////////////////////////////////////////
    // CONTROLLER

    packet_generator_controller #(
        .TLP_ID_WIDTH            (TLP_ID_WIDTH),
        .NUM_TLP_HEADER_BYTES    (TLP_HEADER_BYTES),
        .NUM_TLP_BYTES           (TLP_BYTES),
        .NUM_DLLP_BYTES          (DLLP_BYTES)
    ) inst_controller (
        .i_clk                   (i_clk),
        .i_arst_n                (local_reset_n),
        .i_tlp_valid             (i_tlp_valid), 
        .i_dllp_valid            (i_dllp_valid),
        .o_tlp_ack               (o_tlp_ack),
        .o_dllp_ack              (o_dllp_ack),
        // link manager
        .i_tlp_start             (i_tlp_start),
        .i_tlp_stop              (i_tlp_stop),
        .i_tlp_rply_start        (i_tlp_rply_start),
        .i_tlp_id_ack            (i_tlp_id_ack),
        .o_tlp_rply_act          (o_tlp_rply_act),
        .o_tlp_id_all_ack        (o_tlp_id_all_ack),
        .o_tlp_id_wait_ack       (o_tlp_id_wait_ack),
        //
        .o_crc_init              (),
        .o_crc_calc              (),
        .o_sel_rply              (),
        .o_rply_id_set           (),
        .o_rply_wr               (),
        .o_rply_rd               (),
        .o_frame_load            (),
        .o_sel_dllp              (),
        .o_packet_run            (),
        .o_packet_stop           (),
        //
        .o_rply_id               (),
        .o_tlp_header            (),
        .o_tlp_id_nack           (o_tlp_id_nack),
        .o_tlp_id_ack            (o_tlp_id_ack)
    );


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // SHIFT REGISTER

    wire[TLP_FRAME_WIDTH-1:0] tlp_frame;
    wire [DLLP_FRAME_WIDTH-1:0] dllp_frame;
    
    assign dllp_frame = {{DLLP_FRAME_PADDING{1'b0}}, i_dllp};
    assign tlp_frame  = {{TLP_FRAME_PADDING{1'b0}}, i_tlp, {TLP_HEADER_PADDING{1'b0}}, inst_controller.o_tlp_header};


    packet_generator_shift_out #(
        .DLLP_FRAME_WIDTH (DLLP_FRAME_WIDTH),
        .TLP_FRAME_WIDTH  (TLP_FRAME_WIDTH)
    ) inst_fifo_data (
        .i_clk            (i_clk),
        .i_dllp_frame     (dllp_frame),
        .i_tlp_frame      (tlp_frame),
        .load_frame       (inst_controller.o_frame_load),
        .sel_dllp         (inst_controller.o_sel_dllp),
        .o_byte           ()
    );

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // REPLAY - BUFFER
    packet_generator_replay_buffer #(
        .FRAME_WIDTH    (TLP_WIDTH), // save tlp data only (without id, crc)
        .ID_WIDTH       (TLP_ID_WIDTH)
    ) inst_replay_data (
        .i_clk          (i_clk),
        .i_arst_n       (local_reset_n),
        .i_set_id       (inst_controller.o_rply_id_set),
        .i_wr           (inst_controller.o_rply_wr),
        .i_rd           (inst_controller.o_rply_rd),
        .i_byte         (inst_fifo_data.o_byte),
        .i_id           (inst_controller.o_rply_id), 
        .o_byte         ()
    );
   
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // CRC
    wire[7:0] crc_data_i;

    // MUX 2x1
    assign crc_data_i = (inst_controller.o_sel_rply) ? inst_replay_data.o_byte : inst_fifo_data.o_byte;

    crc_8 #(
        .POLY  (CRC_POLY), 
        .INIT  (CRC_INIT)  
    ) inst_crc_8 (
        .i_clk    (i_clk),
        .i_arst_n (local_reset_n),
        .i_init   (inst_controller.o_crc_init),
        .i_calc   (inst_controller.o_crc_calc),
        .i_data   (crc_data_i),
        .o_crc    ()
    );


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // OUTPUT MUX - STAGE

    wire[8:0] k_mux, d_mux;
    reg[8:0] r_kd, r_phys;
    wire[8:0] ri_kd, ri_phys;
    
    always@ (posedge i_clk, negedge local_reset_n)
        if (~local_reset_n) begin
            r_kd   <= {1'b0,`K_CODE_SKP};
            r_phys <= {1'b0,`K_CODE_SKP};
        end else begin
            r_kd   <= ri_kd;
            r_phys <= ri_phys;
        end


    // 4 * 9 mux => sel k_code
    assign k_mux = inst_controller.o_frame_load ? ((inst_controller.o_sel_dllp || inst_controller.o_packet_stop) ? {1'b1,`K_CODE_START_DLLP} : {1'b1, `K_CODE_START_TLP}) : 
                              ((inst_controller.o_sel_dllp || inst_controller.o_packet_stop) ? {1'b1, `K_CODE_STOP} : {1'b1, `K_CODE_SKP});

    assign d_mux = inst_controller.o_sel_rply ? {1'b0, inst_replay_data.o_byte} : {1'b0, inst_fifo_data.o_byte};
    assign ri_kd = inst_controller.o_packet_run ? d_mux : k_mux;
    // 2 * 9 mux => sel k/data/crc
    assign ri_phys = inst_controller.o_packet_stop ? {1'b0, inst_crc_8.o_crc} : r_kd;

    // assign output to physical layer
    assign o_phys_byte = r_phys[7:0];
    assign o_phys_k_en = r_phys[8];

endmodule

`endif /* TRANSMITTER_PACKET_GENERATOR_TOP */