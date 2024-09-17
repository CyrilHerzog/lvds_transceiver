/*
    Module  : PHYSICAL_IOB_ISERDES
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024
    
*/


`ifndef _PHYSICAL_IOB_ISERDES_V_
`define _PHYSICAL_IOB_ISERDES_V_

`include "src/hdl/cdc/async_reset.v"

module physical_iob_iserdes #(
    parameter ENABLE_ISERDESE1  = 0,  // for icarus verilog
    parameter ENABLE_TEST_DELAY = 1,
    parameter IDELAYE_REF_FREQ  = 200
)(
	input wire i_clk_200, i_clk_200_arst_n,
    // clk_200
    input wire[4:0] i_delay_val,
    input wire[4:0] i_test_delay_val, 
	output wire [5:0] o_data,
    // 
    input wire i_clk_600,
    // clk_600 
    input wire i_rx
);


   //////////////////////////////////////////////////////////////////////////////////////
   // LOCAL RESET
   wire local_reset_200;

   async_reset #(
      .STAGES   (2),
      .INIT     (1'b1),
      .RST_VAL  (1'b1)
    ) inst_local_reset_200 (
      .i_clk    (i_clk_200), 
      .i_rst_n  (i_clk_200_arst_n),
      .o_rst    (local_reset_200)
    );

    /////////////////////////////////////////////////////////////////////////////////////
    // IDELAYE

    wire[1:0] rx_delay_o;

    IDELAYE2 #(
        .CINVCTRL_SEL           ("FALSE"),          // Enable dynamic clock inversion (FALSE, TRUE)
        .DELAY_SRC              ("IDATAIN"),        // Delay input (IDATAIN, DATAIN)
        .HIGH_PERFORMANCE_MODE  ("TRUE"),           // Reduced jitter ("TRUE"), Reduced power ("FALSE")
        .IDELAY_TYPE            ("VAR_LOAD"),       // FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
        .IDELAY_VALUE           (0),                // Input delay tap setting (0-31)
        .PIPE_SEL               ("FALSE"),          // Select pipelined mode, FALSE, TRUE
        .REFCLK_FREQUENCY       (IDELAYE_REF_FREQ), // IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
        .SIGNAL_PATTERN         ("DATA")            // DATA, CLOCK input signal
    ) inst_idelaye2 (
        .CNTVALUEOUT            (),                 // 5-bit output: Counter value output
        .DATAOUT                (rx_delay_o[0]),    // 1-bit output: Delayed data output
        .C                      (i_clk_200),        // 1-bit input: Clock input
        .CE                     (1'b0),             // 1-bit input: Active high enable increment/decrement input
        .CINVCTRL               (1'b0),             // 1-bit input: Dynamic clock inversion input
        .CNTVALUEIN             (i_delay_val),      // 5-bit input: Counter value input
        .DATAIN                 (1'b0),             // 1-bit input: Internal delay data input
        .IDATAIN                (i_rx),             // 1-bit input: Data input from the I/O
        .INC                    (1'b0),             // 1-bit input: Increment / Decrement tap delay input
        .LD                     (1'b1),             // 1-bit input: Load IDELAY_VALUE input
        .LDPIPEEN               (1'b0),             // 1-bit input: Enable PIPELINE register to load data input
        .REGRST                 (1'b0)              // 1-bit input: Active-high reset tap-delay input
    );


    generate
        if (ENABLE_TEST_DELAY == 1) begin
            //
            IDELAYE2 #(
                .CINVCTRL_SEL           ("FALSE"),         
                .DELAY_SRC              ("DATAIN"),      
                .HIGH_PERFORMANCE_MODE  ("TRUE"),           
                .IDELAY_TYPE            ("VAR_LOAD"),       
                .IDELAY_VALUE           (0),               
                .PIPE_SEL               ("FALSE"),          
                .REFCLK_FREQUENCY       (IDELAYE_REF_FREQ), 
                .SIGNAL_PATTERN         ("DATA")            
            ) inst_idelaye2_test (
                .CNTVALUEOUT            (),                
                .DATAOUT                (rx_delay_o[1]),   
                .C                      (i_clk_200),        
                .CE                     (1'b0),            
                .CINVCTRL               (1'b0),             
                .CNTVALUEIN             (i_test_delay_val),        
                .DATAIN                 (rx_delay_o[0]),    
                .IDATAIN                (1'b0),             
                .INC                    (1'b0),             
                .LD                     (1'b1),             
                .LDPIPEEN               (1'b0),             
                .REGRST                 (1'b0)              
            );

        end else begin
            //
            assign rx_delay_o[1] = rx_delay_o[0];
        end

    endgenerate


    ///////////////////////////////////////////////////////////////////////////////////////
    // ISERDES

    generate
        if (ENABLE_ISERDESE1 == 0) begin

            ISERDESE2 #(			
		        .DATA_RATE      	("DDR"), 
		        .DATA_WIDTH     	(6), 
		        .DYN_CLKDIV_INV_EN  ("FALSE"),
		        .DYN_CLK_INV_EN     ("FALSE"),
		        .INIT_Q1            (1'b0),
                .INIT_Q2            (1'b0),
                .INIT_Q3            (1'b0),
                .INIT_Q4            (1'b0),	
                .INTERFACE_TYPE 	("NETWORKING"),	 	
		        .IOBDELAY           ("IFD"), 		
		        .NUM_CE				(2),
		        .OFB_USED           ("FALSE"),
		        .SERDES_MODE    	("MASTER"),
		        .SRVAL_Q1           (1'b0),
                .SRVAL_Q2           (1'b0),
                .SRVAL_Q3           (1'b0),
                .SRVAL_Q4           (1'b0)
	        ) inst_iserdese2 (
		        .O                  (),                      
                .Q1                 (o_data[5]),
                .Q2                 (o_data[4]),
                .Q3                 (o_data[3]),
                .Q4                 (o_data[2]),
                .Q5                 (o_data[1]),
                .Q6                 (o_data[0]),
                .Q7                 (),
                .Q8                 (),
                .SHIFTOUT1          (),
                .SHIFTOUT2          (),
                .BITSLIP            (1'b0),           
                .CE1                (1'b1),
                .CE2                (1'b1),
                .CLKDIVP            (1'b0),           
                .CLK                (i_clk_600),                  
                .CLKB               (~i_clk_600),              
                .CLKDIV             (i_clk_200),            
                .OCLK               (1'b0),                
                .DYNCLKDIVSEL       (1'b0), 
                .DYNCLKSEL          (1'b0),       
                .D                  (1'b0),                      
                .DDLY               (rx_delay_o[1]),               
                .OFB                (),                
                .OCLKB              (1'b0),              
                .RST                (local_reset_200), // async reset on pos-edge                
                .SHIFTIN1           (1'b0),
                .SHIFTIN2           (1'b0)
            );
        end else begin

            ISERDESE1 #(
	            .DATA_WIDTH     	(6), 			
	            .DATA_RATE      	("DDR"), 		
	            .SERDES_MODE    	("MASTER"), 		
	            .IOBDELAY	        ("IFD"), 		
	            .INTERFACE_TYPE     ("NETWORKING"),
	            .NUM_CE			    (2) 	
            ) inst_iserdese1 (
	            .D       		    (1'b0),
	            .DDLY     		    (rx_delay_o[1]),
	            .CE1     		    (1'b1),
	            .CE2     		    (1'b1),
	            .CLK	   		    (i_clk_600),
	            .CLKB    		    (~i_clk_600),
	            .RST     		    (local_reset_200), // async-reset on pos-edge
	            .CLKDIV  		    (i_clk_200),
	            .OCLK    		    (1'b0),
	            .DYNCLKSEL    	    (1'b0),
	            .DYNCLKDIVSEL     	(1'b0),
	            .SHIFTIN1 	     	(1'b0),
	            .SHIFTIN2 		    (1'b0),
	            .BITSLIP 	     	(1'b0),
	            .O	 	          	(),
	            .Q6  			    (o_data[0]),
	            .Q5  			    (o_data[1]),
	            .Q4  		    	(o_data[2]),
	            .Q3  		    	(o_data[3]),
	            .Q2  		    	(o_data[4]),
	            .Q1  		    	(o_data[5]),
	            .OFB 		    	(),
	            .SHIFTOUT1	    	(),
	            .SHIFTOUT2 	    	()
	        );

        end
    endgenerate

endmodule

`endif