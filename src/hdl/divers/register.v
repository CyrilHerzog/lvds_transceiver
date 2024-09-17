/*
    Module  : REGISTER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`ifndef _REGISTER_V_
`define _REGISTER_V_

module register #(
    parameter DATA_WIDTH = 8
)( 
    input wire i_clk, i_arst_n,
    input wire i_wr, i_clr, // synchronous
    input wire[DATA_WIDTH-1:0] i_data,
    output wire[DATA_WIDTH-1:0] o_data
);

    reg[DATA_WIDTH-1:0] r_data;
    wire[DATA_WIDTH-1:0] ri_data;

    always@(posedge i_clk , negedge i_arst_n)
        if (~i_arst_n)
            r_data <= {DATA_WIDTH{1'b0}};
        else
            r_data <= ri_data;
        
    
    assign ri_data = i_clr ? {DATA_WIDTH{1'b0}} : (i_wr ? i_data : r_data);

    assign o_data = r_data;

endmodule

`endif /* REGISTER */