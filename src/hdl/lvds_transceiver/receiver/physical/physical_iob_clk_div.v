/*
    Module  : PHYSICAL_IOB_CLK_DIV
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024
    
*/


`ifndef _PHYSICAL_IOB_CLK_DIV_V_
`define _PHYSICAL_IOB_CLK_DIV_V_

module physical_iob_clk_div (
    input wire i_clk_600_p, i_clk_600_n,
    output wire o_clk_120,
    output wire o_clk_200,
    output wire o_clk_600

);

    ////////////////////////////////////////////////////////////////////////
    // INPUT DIFF - BUFFER
    wire ibufds_clk_600_o;

    IBUFDS #(
	    .IBUF_LOW_PWR   ("FALSE"),
        .DIFF_TERM      ("TRUE")
    ) inst_ibufds_phys_clk (
	    .I    (i_clk_600_p),
	    .IB   (i_clk_600_n),
	    .O    (ibufds_clk_600_o)
    );

    ////////////////////////////////////////////////////////////////////////
    // CLK 600 MHZ 
    BUFIO inst_bufio (
        .I (ibufds_clk_600_o),
        .O (o_clk_600)
    );

    ////////////////////////////////////////////////////////////////////////    
    // CLK 200 MHZ 
    BUFR #(
        .BUFR_DIVIDE    ("3"),   
        .SIM_DEVICE     ("7SERIES") 
    ) inst_bufr_300 (
        .I      (ibufds_clk_600_o),
        .CE     (1'b1),   
        .CLR    (1'b0), 
        .O      (o_clk_200)   
    );

    ///////////////////////////////////////////////////////////////////////    
    // CLK 120 MHZ
    BUFR #(
        .BUFR_DIVIDE    ("5"),   
        .SIM_DEVICE     ("7SERIES") 
    ) inst_bufr_120 (
        .I      (ibufds_clk_600_o),
        .CE     (1'b1),   
        .CLR    (1'b0),
        .O      (o_clk_120)     
    );
    
    
endmodule

`endif /* PHYSICAL_IOB_CLK_DIV */