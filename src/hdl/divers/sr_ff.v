/*
    Module  : SR_FF
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`ifndef _SR_FF_V_
`define _SR_FF_V_

module sr_ff ( 
    input wire i_clk, i_arst_n,
    input wire i_s, i_r,
    output wire o_q, o_qn
);

    reg r_q;
    wire ri_q;

    always@(posedge i_clk , negedge i_arst_n)
        if (~i_arst_n)
            r_q <= 1'b0;
        else
            r_q <= ri_q;
        
    
    assign ri_q = (i_s || r_q) && ~i_r;

    assign o_q = r_q;
    assign o_qn = ~r_q;

endmodule

`endif /* SR_FF */
