 /*
    Module  : CLOCK_SOURCE_MMCM
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`ifndef _CLOCK_SOURCE_MMCM_V_
`define _CLOCK_SOURCE_MMCM_V_

module clock_source_mmcm (
    input wire i_fmc_clk_50_p, 
    input wire i_fmc_clk_50_n, 
    // TRX PHYSICAL LAYER CLOCK
    output wire o_bufio_clk_600,
    output wire o_bufr_clk_200,
    output wire o_bufr_clk_120,
    // TRX LINK LAYER CLOCK
    output wire o_bufg_clk_120,
    // IDLEAYE CNTRL CLOCK
    output wire o_bufg_clk_300,
    output wire o_bufg_clk_200,
    //
    output wire o_locked
  );  


  
    wire mmcm_clk_fb_o;
    wire mmcm_clk_fb_i;
    wire mmcm_clk_600_o;
    wire mmcm_clk_120_o;
    wire mmcm_clk_300_o;
    wire mmcm_clk_200_o;
    wire ibufgds_clk_o;
  
    IBUFDS #(
	   .IBUF_LOW_PWR		("FALSE"),
       .DIFF_TERM           ("TRUE")
    ) inst_ibufgds_clk0 (
	   .I    			(i_fmc_clk_50_p),
	   .IB       		(i_fmc_clk_50_n),
	   .O         		(ibufgds_clk_o)
    );

    MMCME2_ADV #(
        .BANDWIDTH            ("OPTIMIZED"),
        .CLKOUT4_CASCADE      ("FALSE"),
        .COMPENSATION         ("ZHOLD"),
        .STARTUP_WAIT         ("FALSE"),
        .DIVCLK_DIVIDE        (1),
        .CLKFBOUT_MULT_F      (24.0), 
        .CLKFBOUT_PHASE       (0.000),
        .CLKFBOUT_USE_FINE_PS ("FALSE"),
        .CLKOUT0_DIVIDE_F     (2.0),
        .CLKOUT0_PHASE        (0.000),
        .CLKOUT0_DUTY_CYCLE   (0.500),
        .CLKOUT0_USE_FINE_PS  ("FALSE"),
        .CLKOUT1_DIVIDE       (10.0),
        .CLKOUT1_PHASE        (0.000),
        .CLKOUT1_DUTY_CYCLE   (0.500),
        .CLKOUT1_USE_FINE_PS  ("FALSE"),
        .CLKOUT2_DIVIDE       (4),
        .CLKOUT2_PHASE        (0.000),
        .CLKOUT2_DUTY_CYCLE   (0.500),
        .CLKOUT2_USE_FINE_PS  ("FALSE"),
        .CLKOUT3_DIVIDE       (6),
        .CLKOUT3_PHASE        (0.000),
        .CLKOUT3_DUTY_CYCLE   (0.500),
        .CLKOUT3_USE_FINE_PS  ("FALSE"),
        .CLKIN1_PERIOD        (20.0) 
    ) inst_mmcm_adv (
        .CLKFBOUT            (mmcm_clk_fb_o),
        .CLKFBOUTB           (),
        .CLKOUT0             (mmcm_clk_600_o),
        .CLKOUT0B            (),
        .CLKOUT1             (mmcm_clk_120_o),
        .CLKOUT1B            (),
        .CLKOUT2             (mmcm_clk_300_o),
        .CLKOUT2B            (),
        .CLKOUT3             (mmcm_clk_200_o),
        .CLKOUT3B            (),
        .CLKOUT4             (),
        .CLKOUT5             (),
        .CLKOUT6             (),
        .CLKFBIN             (mmcm_clk_fb_i),
        .CLKIN1              (ibufgds_clk_o),
        .CLKIN2              (1'b0),
        .CLKINSEL            (1'b1),
        .DADDR               (7'h0),
        .DCLK                (1'b0),
        .DEN                 (1'b0),
        .DI                  (16'h0),
        .DO                  (),
        .DRDY                (),
        .DWE                 (1'b0),
        .PSCLK               (1'b0),
        .PSEN                (1'b0),
        .PSINCDEC            (1'b0),
        .PSDONE              (),
        .LOCKED              (o_locked),
        .CLKINSTOPPED        (),
        .CLKFBSTOPPED        (),
        .PWRDWN              (1'b0),
        .RST                 (1'b0)
        );
    
    // internal feedback
    assign mmcm_clk_fb_i = mmcm_clk_fb_o;

    ///////////////////////////////////////////////////////////////////////////////////////
    // TRANSCEIVER PHYSICAL - LAYER CLOCK

    // 600 MHZ 
    BUFIO inst_bufio_600 (
        .I (mmcm_clk_600_o),
        .O (o_bufio_clk_600)
    );
        
    // 200 MHZ 
    BUFR #(
        .BUFR_DIVIDE("3"),   
        .SIM_DEVICE("7SERIES") 
    ) inst_bufr_300 (
        .I(mmcm_clk_600_o),
        .CLR(1'b0),
        .CE(1'b1), 
        .O(o_bufr_clk_200)  
    );
        
    // 120 MHZ
    BUFR #(
        .BUFR_DIVIDE("5"),   
        .SIM_DEVICE("7SERIES") 
    ) inst_bufr_120 (
        .I(mmcm_clk_600_o),
        .CLR(1'b0),
        .CE(1'b1), 
        .O(o_bufr_clk_120)      
    );

    //////////////////////////////////////////////////////////////////////////////////////
    // TRANSCEIVER LINK - LAYER CLOCK

    // 120 MHZ
    BUFG inst_bufg_clk_120 (
        .I  (mmcm_clk_120_o),
        .O  (o_bufg_clk_120)
    );

    //////////////////////////////////////////////////////////////////////////////////////
    // IDELAYE - CONTROL CLOCK

    // 300 MHZ
    BUFG inst_bufg_clk_300 (
        .I  (mmcm_clk_300_o),
        .O  (o_bufg_clk_300)
    );

    // 200 MHZ
    BUFG inst_bufg_clk_200 (
        .I  (mmcm_clk_200_o),
        .O  (o_bufg_clk_200)
    );
    

endmodule

`endif /* CLOCK_SOURCE_MMCM */