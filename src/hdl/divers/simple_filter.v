/*
    Module  : SIMPLE_FILTER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024
    
*/


`ifndef _SIMPLE_FILTER_V_
`define _SIMPLE_FILTER_V_

module simple_filter #(
    parameter FILTER_WIDTH = 8,
    parameter INIT_VAL     = 0
) (
    input wire i_clk, i_arst_n,
    input wire i_raw,
    output wire o_filter
);

    reg[FILTER_WIDTH-1:0] r_filter_shift;
    wire[FILTER_WIDTH-1:0] ri_filter_shift;

    reg r_filter_o;
    wire ri_filter_o;

    always@(posedge i_clk, negedge i_arst_n)
        if (~i_arst_n) begin
            r_filter_shift <= {FILTER_WIDTH{INIT_VAL}};
            r_filter_o     <= INIT_VAL;
        end else begin
            r_filter_shift <= ri_filter_shift;
            r_filter_o     <= ri_filter_o;
        end

    assign ri_filter_shift = {r_filter_shift[FILTER_WIDTH-2:0], i_raw};
    assign ri_filter_o     = &r_filter_shift;

    // filtered output
    assign o_filter = r_filter_o;


endmodule

`endif /* SIMPLE_FILTER */