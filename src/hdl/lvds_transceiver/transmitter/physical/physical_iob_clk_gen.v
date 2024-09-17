
/*
    Module  : PHYSICAL_IOB_CLK_GEN
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024
    
*/


`ifndef _PHYSICAL_IOB_CLK_GEN_V_
`define _PHYSICAL_IOB_CLK_GEN_V_

module physical_iob_clk_gen (
    input wire i_clk_600,
    output wire o_clk_600_p, o_clk_600_n
);

    //////////////////////////////////////////////////////////////////////////////
    // ODDR

    wire oddr_o;

    ODDR #(
        .DDR_CLK_EDGE   ("OPPOSITE_EDGE"), 
        .INIT           (1'b0),    
        .SRTYPE         ("SYNC") 
    ) inst_oddr (                          
        .C              (i_clk_600),  
        .CE             (1'b1),                      
        .D1             (1'b1),                    
        .D2             (1'b0),                      
        .R              (1'b0),                       
        .S              (1'b0),
        .Q              (oddr_o)                      
    );

    /////////////////////////////////////////////////////////////////////////////
    // OUTPUT - DIFF BUFFER

    OBUFDS #(
        .IOSTANDARD ("LVDS_25"), 
        .SLEW       ("SLOW")          
    ) inst_obufds (
        .I          (oddr_o),
        .O          (o_clk_600_p),                     
        .OB         (o_clk_600_n)                   
    );

endmodule

`endif /* PHYSICAL_IOB_CLOCK_GEN */