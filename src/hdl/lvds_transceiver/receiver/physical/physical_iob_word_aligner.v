/*
    Module  : PHYSICAL_IOB_WORD_ALIGNER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _PHYSICAL_IOB_WORD_ALIGNER_V_
`define _PHYSICAL_IOB_WORD_ALIGNER_V_

`include "src/hdl/cdc/async_reset.v"

module physical_iob_word_aligner (
    input wire i_clk, i_arst_n,
    input wire i_start,
    input wire [9:0] i_data,
    output wire[3:0] o_slipbits,
    output wire o_run,
    output wire o_done,
    output wire o_fail
);

    localparam K_CODE_SKP_RD_N   = 10'h33c;
    localparam K_CODE_SKP_RD_P   = 10'h0c3; // !K_CODE_SKP_N 

    ///////////////////////////////////////////////////////////////////////////////
    // LOCAL RESET
    wire local_arst_n;

    async_reset #(
        .STAGES   (2),
        .INIT     (1'b0),
        .RST_VAL  (1'b0)
    ) inst_async_reset (
        .i_clk    (i_clk), 
        .i_rst_n  (i_arst_n),
        .o_rst    (local_arst_n)
    );
    
    
    /////////////////////////////////////////////////////////////////////////////////
    // INPUT
    
    reg r_start;
    wire start_flag;

    reg[9:0] r_data_i;
    
    always@ (posedge i_clk, negedge local_arst_n)
        if (~local_arst_n) begin
            r_start  <= 1'b0;
            r_data_i <= 10'b0000000000;
        end else begin
            r_start  <= i_start;
            r_data_i <= i_data; 
        end

    assign start_flag = i_start & ~r_start;

    //////////////////////////////////////////////////////////////////////////////////
    // CONTROL - LOGIC

    reg r_done, r_enable, r_fail;
    wire ri_done, ri_enable, ri_fail;
    
    wire aligning_done, aligning_fail;

    always@(posedge i_clk, negedge local_arst_n)
        if (~local_arst_n) begin
            r_enable <= 1'b0;
            r_done   <= 1'b0;
            r_fail   <= 1'b0;
        end else begin
            r_enable <= ri_enable;
            r_done   <= ri_done;
            r_fail   <= ri_fail;
        end

    // SR
    assign ri_enable = (start_flag | r_enable) & ~(r_done | r_fail);
    assign ri_done   = (aligning_done | r_done) & ~start_flag;
    assign ri_fail   = (aligning_fail | r_fail) & ~start_flag; 

    assign o_run  = r_enable;
    assign o_done = r_done;
    assign o_fail = r_fail;

    //////////////////////////////////////////////////////////////////////////////////
    // ALIGNING - OPERATION

    reg [5:0] r_bitslip_wait;
    wire [5:0] ri_bitslip_wait; 

    reg[3:0] r_slipbits;
    wire[3:0] ri_slipbits;

    reg[7:0] r_filter_shift;
    wire[7:0] ri_filter_shift;

    wire bitslip_puls, bitslip_max;
    wire match;

    always@(posedge i_clk, negedge local_arst_n)
        if(~local_arst_n) begin
            r_slipbits      <= 4'b0000;
            r_bitslip_wait  <= 5'b00000;
            r_filter_shift  <= 8'b00000000;
        end else begin
            r_slipbits     <= ri_slipbits;
            r_bitslip_wait <= ri_bitslip_wait;
            r_filter_shift <= ri_filter_shift;
        end
    
    //
    assign match = ((r_data_i == K_CODE_SKP_RD_N) || (r_data_i == K_CODE_SKP_RD_P)); // K_CODE_SKP_RD_N OR K_CODE_SKP_RD_P
    //
    assign ri_bitslip_wait = (r_enable) ? r_bitslip_wait + 5'b00001 : 5'b00000;
    assign bitslip_puls    = &r_bitslip_wait;
    //
    assign ri_slipbits = (start_flag) ? 4'b0000 : (bitslip_puls ? r_slipbits + 4'b0001 : r_slipbits);
    assign bitslip_max = (r_slipbits == 4'b1001);
    //
    assign ri_filter_shift = {r_filter_shift[6:0], (match & r_enable)};
    assign aligning_done   = &r_filter_shift;
    assign aligning_fail   = (bitslip_max & bitslip_puls);
    
    //
    assign o_slipbits = r_slipbits;

endmodule

`endif /* PHYSICAL_IOB_WORD_ALIGNER */