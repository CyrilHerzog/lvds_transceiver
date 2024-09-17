
/*
    Module  : SYNCHRONIZER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024
    
*/


`ifndef _SYNCHRONIZER_V_
`define _SYNCHRONIZER_V_


module synchronizer #(
    parameter STAGES = 2,
    parameter INIT   = 1'b0
) (
    input wire i_clk, i_arst_n,
    input wire i_async,
    output wire o_sync
);
    // valid stages >= 2
    localparam VSTAGES = (STAGES < 2) ? 2 : STAGES;

    (* shreg_extract = "no", ASYNC_REG = "TRUE" *)
    reg [VSTAGES-1:0] r_sync = {VSTAGES{INIT}};
    wire [VSTAGES-1:0] ri_sync;

    always @(posedge i_clk, negedge i_arst_n)
        if (~i_arst_n) 
            r_sync <= {VSTAGES{INIT}};
        else
            r_sync <= ri_sync;
                   
        
    assign ri_sync = {r_sync [VSTAGES-2:0], i_async};

    // Synchronized Output
    assign o_sync = r_sync[VSTAGES-1];

endmodule

`endif /* SYNCHRONIZER */