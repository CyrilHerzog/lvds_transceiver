/*
    Module  : ASYNC_RESET
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024
    
*/


`ifndef _ASYNC_RESET_V_
`define _ASYNC_RESET_V_


module async_reset #(
    parameter STAGES  = 2,
    parameter INIT    = 1'b0,
    parameter RST_VAL = 1'b0      // 1'b0 => FDCE, 1'b1 => FDPE
) (
    input wire i_clk, 
    input wire i_rst_n,
    output wire o_rst
);
    // valid stages >= 2
    localparam VSTAGES = (STAGES < 2) ? 2 : STAGES;

    (* shreg_extract = "no", ASYNC_REG = "TRUE" *)
    reg [VSTAGES-1:0] r_rst = {VSTAGES{INIT}};
    wire [VSTAGES-1:0] ri_rst;

    always @(posedge i_clk, negedge i_rst_n)
        if (~i_rst_n) 
            r_rst <= {STAGES{RST_VAL}}; 
        else
            r_rst <= ri_rst;
                
        
    assign ri_rst = {r_rst[VSTAGES-2:0], ~RST_VAL}; 

    // Synchronized Output
    assign o_rst = r_rst[VSTAGES-1];

endmodule

`endif /* ASYNC_RESET */