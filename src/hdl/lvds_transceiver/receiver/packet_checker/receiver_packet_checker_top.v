/*
    Module  : RECEIVER_PACKET_CHECKER_TOP
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _LVDS_RECEIVER_PACKET_CHECKER_TOP_V_
`define _LVDS_RECEIVER_PACKET_CHECKER_TOP_V_


`include "src/hdl/global_functions.vh"
`include "src/hdl/lvds_transceiver/include/lvds_transceiver_defines.vh"

`include "src/hdl/lvds_transceiver/receiver/packet_checker/packet_checker_controller.v"
`include "src/hdl/lvds_transceiver/receiver/packet_checker/packet_checker_input_shift.v"

`include "src/hdl/divers/sync_fifo.v"
`include "src/hdl/crc/crc_8.v"
//
`include "src/hdl/cdc/async_reset.v"


module receiver_packet_checker_top #(
    parameter TLP_WIDTH    = `DEFAULT_TLP_WIDTH,
    parameter DLLP_WIDTH   = `CONFIG_DLLP_WIDTH,
    parameter TLP_ID_WIDTH = `CONFIG_TLP_ID_WIDTH,
    parameter CRC_POLY     = `DEFAULT_CRC_POLY,
    parameter CRC_INIT     = `DEFAULT_CRC_INIT
)(
    input wire i_clk, i_arst_n,
    // TLP - INTERFACE
    input wire i_tlp_rdy,      
    output wire [TLP_WIDTH-1:0] o_tlp,
    output wire o_tlp_valid,
    // DLLP - INTERFACE
    input wire i_dllp_rdy,
    output wire [DLLP_WIDTH-1:0] o_dllp,
    output wire o_dllp_valid,
    // LINK - CONTROL - INTERFACE
    input wire i_status_id_ack,
    output wire [TLP_ID_WIDTH:0] o_status_id,
    output wire o_status_id_valid,
    // PHYSICAL - INTERFACE
    input wire i_phys_k_en,
    input wire [7:0] i_phys_byte 
);

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // INTERNAL CONSTANT'S

    localparam TLP_HEADER_BYTES = `fun_sizeof_byte((TLP_ID_WIDTH + 1) << 1);
    localparam TLP_BYTES        = `fun_sizeof_byte(TLP_WIDTH) + TLP_HEADER_BYTES;  
    localparam DLLP_BYTES       = `fun_sizeof_byte(DLLP_WIDTH);

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // K - CODE & INPUT STAGE

    reg[8:0] r_phys_a, r_phys_b, r_phys_c;
    wire[8:0] ri_phys_a, ri_phys_b, ri_phys_c;
    reg r_k_start_dllp, r_k_start_tlp, r_k_stop, r_k_skp_n;
    wire ri_k_start_dllp, ri_k_start_tlp, ri_k_stop, ri_k_skp_n;

    always@(posedge i_clk, negedge local_reset_n)
        if (~local_reset_n) begin
            r_phys_a       <= 8'h00;
            r_phys_b       <= 8'h00;
            r_phys_c       <= 8'h00;
            //
            r_k_start_dllp <= 1'b0;
            r_k_start_tlp  <= 1'b0;
            r_k_stop       <= 1'b0;
            r_k_skp_n      <= 1'b1;
        end else begin
            r_phys_a       <= ri_phys_a;
            r_phys_b       <= ri_phys_b;
            r_phys_c       <= ri_phys_c;
            //
            r_k_start_dllp <= ri_k_start_dllp;
            r_k_start_tlp  <= ri_k_start_tlp;
            r_k_stop       <= ri_k_stop;
            r_k_skp_n      <= ri_k_skp_n;
        end

    assign ri_phys_a = {i_phys_k_en, i_phys_byte};
    assign ri_phys_b = r_phys_a;
    assign ri_phys_c = r_phys_b;
    //
    assign ri_k_start_dllp = (r_phys_b == {1'b1, `K_CODE_START_DLLP});
    assign ri_k_start_tlp  = (r_phys_b == {1'b1, `K_CODE_START_TLP});
    assign ri_k_stop       = (r_phys_a == {1'b1, `K_CODE_STOP}); // check stop and crc result at the same time 
    assign ri_k_skp_n      = ~(r_phys_b == {1'b1, `K_CODE_SKP});
    

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // SHIFT REGISTER

    packet_checker_input_shift #(
        .STAGES ((`fun_max(DLLP_BYTES, TLP_BYTES)) + 2) // add two extra stages
    ) inst_frame_shift_in (
        .i_clk     (i_clk),
        .i_enable  (r_k_skp_n),
        .i_byte    (r_phys_c[7:0]),
        .o_frame   ()
    );

    assign o_dllp = inst_frame_shift_in.o_frame[((DLLP_WIDTH + 8) - 1):8];

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // CRC

    wire crc_ok;

    crc_8 #(
        .POLY     (CRC_POLY), 
        .INIT     (CRC_INIT)  
    ) inst_crc_8(
        .i_clk    (i_clk),
        .i_arst_n (local_reset_n),
        .i_init   (inst_controller.o_crc_init),
        .i_calc   (r_k_skp_n),
        .i_data   (r_phys_c[7:0]),
        .o_crc    ()
    );

    assign crc_ok = (inst_crc_8.o_crc == r_phys_c[7:0]); // check calc crc == crc_header 

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // CONTROLLER

    packet_checker_controller #(
        .TLP_ID_WIDTH         (TLP_ID_WIDTH),
        .NUM_TLP_HEADER_BYTES (TLP_HEADER_BYTES),
        .NUM_TLP_BYTES        (TLP_BYTES),
        .NUM_DLLP_BYTES       (DLLP_BYTES)
    ) inst_controller (
        .i_clk                (i_clk),
        .i_arst_n             (local_reset_n),
        //
        .i_tlp_rdy            (i_tlp_rdy),
        .o_tlp_wr             (o_tlp_valid),
        //
        .i_dllp_rdy           (i_dllp_rdy),
        .o_dllp_wr            (o_dllp_valid),
        //
        .i_k_start_tlp        (r_k_start_tlp),
        .i_k_start_dllp       (r_k_start_dllp),
        .i_k_stop             (r_k_stop),
        .i_k_skp_n            (r_k_skp_n),
        .i_crc_ok             (crc_ok),
        .o_crc_init           (),
        //
        .o_tlp_temp_wr        (),
        .o_tlp_temp_wr_addr   (),
        .o_tlp_temp_rd_addr   (),
        //
        .i_tr_result_valid    (~inst_tr_result_buffer.o_empty),
        .i_tr_result          (inst_tr_result_buffer.o_data), // {(crc_ok & i_k_stop), tr_frame_num} 
        .o_tr_result          (),
        .o_tr_result_wr       (),
        .o_tr_result_rd       (),
        //
        .o_id_result          (),
        .o_id_result_wr       ()
    );
 

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // TLP TEMPORARY STORAGE
    
    // transfer information for eval the temporary tlp data
    sync_fifo #(
        .DATA_WIDTH (3 * (TLP_ID_WIDTH + 1)), // {{crc_ok & frame_ok}, tr_frame_num, tlp_header} => tlp_header = {frame_num, frame_id}
        .ADDR_WIDTH (TLP_ID_WIDTH)
    ) inst_tr_result_buffer (
        .i_clk      (i_clk),
        .i_arst_n   (local_reset_n),
        .i_wr       (inst_controller.o_tr_result_wr),
        .i_rd       (inst_controller.o_tr_result_rd),
        .i_data     ({inst_controller.o_tr_result, inst_frame_shift_in.o_frame[(8 + ((TLP_ID_WIDTH + 1) << 1))-1:8]}),
        .o_data     (), 
        .o_full     (), // not used
        .o_empty    () 
    );


    // single port ram
    reg [TLP_WIDTH-1:0] r_ram [(2**TLP_ID_WIDTH)-1:0];

    always@(posedge i_clk)
        if (inst_controller.o_tlp_temp_wr)
            r_ram[inst_controller.o_tlp_temp_wr_addr] <= inst_frame_shift_in.o_frame[(TLP_WIDTH + (TLP_HEADER_BYTES << 3)) - 1:(TLP_HEADER_BYTES << 3)];

    assign o_tlp = r_ram[inst_controller.o_tlp_temp_rd_addr];


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // final result for ack/nack - dllp protocol  
    sync_fifo #(
        .DATA_WIDTH (TLP_ID_WIDTH + 1), // {{ack,nack}, frame_id}  
        .ADDR_WIDTH (TLP_ID_WIDTH)
    ) inst_id_result_buffer (
        .i_clk      (i_clk),
        .i_arst_n   (local_reset_n),
        .i_wr       (inst_controller.o_id_result_wr),
        .i_rd       (i_status_id_ack),
        .i_data     (inst_controller.o_id_result),
        .o_data     (o_status_id), 
        .o_full     (), // not used
        .o_empty    () 
    );

    assign o_status_id_valid = ~inst_id_result_buffer.o_empty;

endmodule

`endif /* RECEIVER_PACKET_CHECKER_TOP */