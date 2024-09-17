/*
    Module  : BINARY_COUNTER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`ifndef _BINARY_COUNTER_V_
`define _BINARY_COUNTER_V_

module binary_counter #(
    parameter WIDTH = 8
)( 
    input wire i_clk, i_arst_n,
    input wire i_inc, i_dec, // increment / decrement
    input wire i_set, i_clr, // synchronous set (set_val) / clr (0)
    input wire[WIDTH-1:0] i_set_val,  
    output wire[WIDTH-1:0] o_count,
    output wire o_max,
    output wire o_zero
);

    reg[WIDTH-1:0] r_count;
    wire[WIDTH-1:0] ri_count;

    always@(posedge i_clk, negedge i_arst_n)
        if (~i_arst_n)
            r_count <= {WIDTH{1'b0}};
        else
            r_count <= ri_count;


    // MUX 2X1
    wire[WIDTH-1:0] next_count;   
    assign next_count = i_inc ? r_count + {{(WIDTH - 1){1'b0}}, 1'b1} : r_count - {{(WIDTH - 1){1'b0}}, 1'b1};

    // MUX 4X1
    wire sel[1:0];
    assign sel[0] = ((i_inc ^ i_dec) || i_clr);
    assign sel[1] = (i_set || i_clr);    
    assign ri_count = sel[1] ? (sel[0] ? {WIDTH{1'b0}} : i_set_val) : (sel[0] ? next_count : r_count);  

    // ASSIGN OUTPUT
    assign o_count = r_count;
    //
    assign o_max = &r_count;
    assign o_zero = ~|r_count;

endmodule

`endif /* BINARY_COUNTER */