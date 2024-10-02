 /*
    Module  : LOOP_INTERFACE_TOP
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _LOOP_INTERFACE_TOP_V_
`define _LOOP_INTERFACE_TOP_V_

`include "src/hdl/test_core/loop_interface/loop_interface_handler_trx_a.v"
`include "src/hdl/test_core/loop_interface/loop_interface_handler_trx_b.v"
//
`include "src/hdl/divers/binary_counter.v"
//
`include "src/hdl/cdc/async_reset.v"


module loop_interface_top (
    input wire i_clk, i_arst_n,
    // CONTROL & STATUS 
    input wire i_loop_enable, 
    output wire o_loop_run,
    output wire o_loop_done,
    output wire o_loop_timeout,
    output wire [15:0] o_loop_cycle,
    //
    input wire[2:0] i_pattern_num,
    output wire o_pattern_wr,
    output wire [2:0] o_pattern_addr,
    output wire [55:0] o_pattern,
    // TRANSCEIVER A
    input wire i_trx_a_rdy, i_trx_a_valid,
    input wire [33:0] i_trx_a,
    output wire o_trx_a_wr, o_trx_a_rd,
    // TRANSCEIVER B
    input wire i_trx_b_rdy, i_trx_b_valid,
    input wire [55:0] i_trx_b,
    output wire[33:0] o_trx_b,
    output wire o_trx_b_wr, o_trx_b_rd
);


    /////////////////////////////////////////////////////////////////////////////////////////////
    // LOCAL RESET
    async_reset #(
      .STAGES   (2),
      .INIT     (1'b0),
      .RST_VAL  (1'b0)
    ) inst_local_reset (
      .i_clk    (i_clk), 
      .i_rst_n  (i_arst_n),
      .o_rst    ()
    );

    ////////////////////////////////////////////////////////////////////////////////////////////
    // HANDLER TRANSCEIVER A
    loop_interface_handler_trx_a #(
        .TIMEOUT_WIDTH   (4) // timeout handling is implemented with the max-flag of loop-cycle-counter 
    ) inst_handler_a (
        .i_clk          (i_clk),
        .i_arst_n       (inst_local_reset.o_rst),
    // CONTROL & STATUS (PC)
        .i_loop_enable  (i_loop_enable),
        .i_pattern_num  (i_pattern_num),
        .o_loop_start   (),
        .o_loop_done    (o_loop_done),
        .o_running      (),
    // L / P - BANK CONTROL
        .o_bank_l       (o_pattern),
        .o_bank_addr    (o_pattern_addr),
        .o_bank_wr      (o_pattern_wr),
    // TRANSCEIVER INTERFACE
        .i_trx_valid    (i_trx_a_valid),
        .i_trx_rdy      (i_trx_a_rdy),
        .i_trx          (i_trx_a),
        .o_trx_wr       (o_trx_a_wr),
        .o_trx_rd       (o_trx_a_rd)
    );

    assign o_loop_run = inst_handler_a.o_running;

    /////////////////////////////////////////////////////////////////////////////////////////////
    // HANDLER TRANSCEIVER B
    loop_interface_handler_trx_b inst_handler_b (
        .i_clk          (i_clk),
        .i_arst_n       (inst_local_reset.o_rst),
    // TRANSCEIVER INTERFACE
        .i_trx_valid    (i_trx_b_valid), 
        .i_trx_rdy      (i_trx_b_rdy),
        .i_trx          (i_trx_b),
        .o_trx          (o_trx_b),
        .o_trx_wr       (o_trx_b_wr),
        .o_trx_rd       (o_trx_b_rd)
    );



    /////////////////////////////////////////////////////////////////////////////////////////////
    // LOOP CYCLE COUNTER
    binary_counter #(
        .WIDTH     (16)
    ) inst_loop_cycle_counter ( 
        .i_clk     (i_clk), 
        .i_arst_n  (inst_local_reset.o_rst),
        .i_clr     (inst_handler_a.o_loop_start),
        .i_set     (1'b0),
        .i_inc     (inst_handler_a.o_running),
        .i_dec     (1'b0),
        .i_set_val (16'b0),   
        .o_count   (o_loop_cycle),
        .o_max     (),
        .o_zero    ()
    );

    // LOOP TIMEOUT (disabled due to crc test's )
    sr_ff inst_sel_p_bank ( 
        .i_clk      (i_clk),
        .i_arst_n   (inst_local_reset.o_rst),
        .i_s        (inst_loop_cycle_counter.o_max),
        .i_r        (~inst_handler_a.o_running),
        .o_q        (), 
        .o_qn       ()
    );

    assign o_loop_timeout = 1'b0; // disabled


endmodule

`endif /* LOOP_INTERFACE_TOP */