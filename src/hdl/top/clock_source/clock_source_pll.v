 /*
    Module  : CLOCK_SOURCE_PLL
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _CLOCK_SOURCE_PLL_V_
`define _CLOCK_SOURCE_PLL_V_

module clock_source_pll
( 
    // ONBOARD CLOCK
    input wire i_gclk, 
    // PS (TESTCORE) CLOCK 
    output wire o_bufg_clk_166,  // 166.666667 MHZ
    // TRX FMC CLOCK
    output wire o_fmc_clk_50_p,
    output wire o_fmc_clk_50_n,
    //
    output wire o_locked 
 );

   
    wire ibuf_gclk_o;
    
    wire pll_clk_50_o;
    wire pll_clk_166_o;
    wire pll_clk_fb_o;
    wire pll_clk_fb_i;
    //
    wire bufg_clk_50_o;
  
    
    

    // buffer single clock - input (Y9)    
    IBUF inst_ibuf_clk_in (
        .I (i_gclk),
        .O (ibuf_gclk_o)    
    );
    
    PLLE2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),  
        .CLKFBOUT_MULT      (10),        
        .CLKFBOUT_PHASE     (0.0),     
        .CLKIN1_PERIOD      (10.0),   
        .CLKOUT0_DIVIDE     (20),
        .CLKOUT1_DIVIDE     (6),
        .CLKOUT2_DIVIDE     (1),
        .CLKOUT3_DIVIDE     (1),
        .CLKOUT4_DIVIDE     (1),
        .CLKOUT5_DIVIDE     (1),
        .CLKOUT0_DUTY_CYCLE (0.5),
        .CLKOUT1_DUTY_CYCLE (0.5),
        .CLKOUT2_DUTY_CYCLE (0.5),
        .CLKOUT3_DUTY_CYCLE (0.5),
        .CLKOUT4_DUTY_CYCLE (0.5),
        .CLKOUT5_DUTY_CYCLE (0.5),
        .CLKOUT0_PHASE      (0.0),
        .CLKOUT1_PHASE      (0.0),
        .CLKOUT2_PHASE      (0.0),
        .CLKOUT3_PHASE      (0.0),
        .CLKOUT4_PHASE      (0.0),
        .CLKOUT5_PHASE      (0.0),
        .DIVCLK_DIVIDE      (1),       
        .REF_JITTER1        (0.0),       
        .STARTUP_WAIT       ("FALSE")    
    ) inst_plle2_base (
        .CLKOUT0            (pll_clk_50_o),   
        .CLKOUT1            (pll_clk_166_o),   
        .CLKOUT2            (),  
        .CLKOUT3            (),  
        .CLKOUT4            (),  
        .CLKOUT5            (),   
        .CLKFBOUT           (pll_clk_fb_o),  
        .LOCKED             (o_locked),     
        .CLKIN1             (ibuf_gclk_o),    
        .PWRDWN             (1'b0),   
        .RST                (1'b0),   
        .CLKFBIN            (pll_clk_fb_i)   
    );

    // internal loop => no phase alligning
    assign pll_clk_fb_i = pll_clk_fb_o;
    
    
    ///////////////////////////////////////////////////////////////////////////////
    // PS - CLOCK (Testcore)

    BUFG inst_bufg_clk1 (
        .I  (pll_clk_166_o),
        .O  (o_bufg_clk_166)
    );

    //////////////////////////////////////////////////////////////////////////////
    // GENERATE INPUT CLOCK FMC - PERIPHERIE 

    BUFG inst_bufg_clk0 (
        .I  (pll_clk_50_o),
        .O  (bufg_clk_50_o)
    );

    // ODDR
    wire oddr_o;

    ODDR #(
        .DDR_CLK_EDGE   ("OPPOSITE_EDGE"), 
        .INIT           (1'b0),    
        .SRTYPE         ("SYNC") 
    ) inst_oddr (                          
        .C              (bufg_clk_50_o),  
        .CE             (1'b1),                      
        .D1             (1'b1),                    
        .D2             (1'b0),                      
        .R              (1'b0),                       
        .S              (1'b0),
        .Q              (oddr_o)                      
    );


    // OUTPUT - DIFF BUFFER
    OBUFDS #(
        .IOSTANDARD ("LVDS_25"), 
        .SLEW       ("SLOW")          
    ) inst_obufds (
        .I          (oddr_o),
        .O          (o_fmc_clk_50_p),                     
        .OB         (o_fmc_clk_50_n)                   
    );
    

endmodule

`endif /* CLOCK_SOURCE_PLL */

