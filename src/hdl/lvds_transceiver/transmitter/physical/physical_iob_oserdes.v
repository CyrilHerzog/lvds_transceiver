/*
    Module  : PHYSICAL_IOB_OSERDES
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _PHYSICAL_IOB_OSERDES_V_
`define _PHYSICAL_IOB_OSERDES_V_


`include "src/hdl/cdc/async_reset.v"

module physical_iob_oserdes #(
   parameter ENABLE_OSERDESE1 = 0 // for icarus verilog
)(
   // CLK_120
   input wire i_clk_120, i_clk_120_arst_n,
   input wire [9:0]i_data,
   // CLK_600 
   input wire i_clk_600, 
   output wire o_tx_p, o_tx_n  
);


   //////////////////////////////////////////////////////////////////////////////////////
   // LOCAL RESET
   wire local_reset_120;

   async_reset #(
      .STAGES   (2),
      .INIT     (1'b1),
      .RST_VAL  (1'b1)
   ) inst_local_reset_120 (
      .i_clk    (i_clk_120), 
      .i_rst_n  (i_clk_120_arst_n),
      .o_rst    (local_reset_120)
   );
          

   ///////////////////////////////////////////////////////////////////////////////////////
   // OSERDES

   wire[1:0] oserdese_slave_shift_out_o;
   wire oserdese_master_o;


   generate
      if (ENABLE_OSERDESE1 == 0) begin       
           
            OSERDESE2 #(
               .DATA_RATE_OQ    ("DDR"),  
               .DATA_RATE_TQ    ("SDR"),
               .DATA_WIDTH      (10),   
               .INIT_OQ         (1'b0),
               .INIT_TQ         (1'b0),      
               .SERDES_MODE     ("MASTER"),            
               .SRVAL_OQ        (1'b0),
               .SRVAL_TQ        (1'b0),
               .TBYTE_CTL       ("FALSE"),
               .TBYTE_SRC       ("FALSE"),
               .TRISTATE_WIDTH  (1)      
            ) inst_oserdese2_master (
               .OFB             (),                  
               .OQ              (oserdese_master_o),           
               .SHIFTOUT1       (),
               .SHIFTOUT2       (),
               .TBYTEOUT        (),
               .TFB             (),            
               .TQ              (),            
               .CLK             (i_clk_600),     
               .CLKDIV          (i_clk_120),       
               .D1              (i_data[0]),
               .D2              (i_data[1]),
               .D3              (i_data[2]),
               .D4              (i_data[3]),
               .D5              (i_data[4]),
               .D6              (i_data[5]),
               .D7              (i_data[6]),
               .D8              (i_data[7]),
               .OCE             (1'b1),           
               .RST             (local_reset_120), // asynchronous reset (posedge)        
               .SHIFTIN1        (oserdese_slave_shift_out_o[0]),
               .SHIFTIN2        (oserdese_slave_shift_out_o[1]),
               .T1              (1'b0),
               .T2              (1'b0),
               .T3              (1'b0),
               .T4              (1'b0),
               .TBYTEIN         (1'b0),
               .TCE             (1'b0)
      );

         OSERDESE2 #(
            .DATA_RATE_OQ    ("DDR"),  
            .DATA_RATE_TQ    ("SDR"),   
            .DATA_WIDTH      (10),
            .INIT_OQ         (1'b0),
            .INIT_TQ         (1'b0),      
            .SERDES_MODE     ("SLAVE"),       
            .SRVAL_OQ        (1'b0),
            .SRVAL_TQ        (1'b0),
            .TBYTE_CTL       ("FALSE"),
            .TBYTE_SRC       ("FALSE"),
            .TRISTATE_WIDTH  (1)      
         ) inst_oserdese2_slave (
            .OFB             (),          
            .OQ              (),              
            .SHIFTOUT1       (oserdese_slave_shift_out_o[0]),
            .SHIFTOUT2       (oserdese_slave_shift_out_o[1]),
            .TBYTEOUT        (),
            .TFB             (),             
            .TQ              (),               
            .CLK             (i_clk_600),       
            .CLKDIV          (i_clk_120),  
            .D1              (1'b0),
            .D2              (1'b0),
            .D3              (i_data[8]),
            .D4              (i_data[9]),
            .D5              (1'b0),
            .D6              (1'b0),
            .D7              (1'b0),
            .D8              (1'b0),
            .OCE             (1'b1),           
            .RST             (local_reset_120), // asynchronous reset (posedge)          
            .SHIFTIN1        (1'b0),
            .SHIFTIN2        (1'b0),
            .T1              (1'b0),
            .T2              (1'b0),
            .T3              (1'b0),
            .T4              (1'b0),
            .TBYTEIN         (1'b0),        
            .TCE             (1'b0)
         );

   end else begin
      // use oserdese1 for simulation with icarus verilog
        OSERDESE1 #(
            .DATA_RATE_OQ   ("DDR"),  
            .DATA_RATE_TQ   ("SDR"),  
            .DDR3_DATA      (0),
            .INIT_TQ        (1'b0),
            .INIT_OQ        (1'b0),
            .DATA_WIDTH     (10),       
            .SERDES_MODE    ("MASTER"), 
            .ODELAY_USED    (0),      
            .INTERFACE_TYPE ("DEFAULT"),       
            .SRVAL_OQ       (1'b0),
            .SRVAL_TQ       (1'b0),
            .TRISTATE_WIDTH (1)      
        ) inst_oserdese1_master (
            .OFB(),                  
            .OQ             (oserdese_master_o),           
            .SHIFTOUT1      (),
            .SHIFTOUT2      (),
            .TFB            (),            
            .TQ             (),            
            .CLK            (i_clk_600),     
            .CLKDIV         (i_clk_120),       
            .CLKPERF        (1'b0),
            .CLKPERFDELAY   (1'b0),
            .D1             (i_data[0]),
            .D2             (i_data[1]),
            .D3             (i_data[2]),
            .D4             (i_data[3]),
            .D5             (i_data[4]),
            .D6             (i_data[5]),
            .OCE            (1'b1),           
            .ODV            (1'b0),
            .RST            (local_reset_120), // asynchronous reset (posedge)        
            .SHIFTIN1       (oserdese_slave_shift_out_o[0]),
            .SHIFTIN2       (oserdese_slave_shift_out_o[1]),
            .T1             (1'b0),
            .T2             (1'b0),
            .T3             (1'b0),
            .T4             (1'b0),
            .TCE            (1'b0),        
            .WC             (1'b0)
      );
         
         OSERDESE1 #(
            .DATA_RATE_OQ   ("DDR"),  
            .DATA_RATE_TQ   ("SDR"),   
            .DDR3_DATA      (0),
            .INIT_TQ        (1'b0),
            .INIT_OQ        (1'b0),
            .DATA_WIDTH     (10),        
            .SERDES_MODE    ("SLAVE"), 
            .ODELAY_USED    (0),      
            .INTERFACE_TYPE ("DEFAULT"),      
            .SRVAL_OQ       (1'b0),
            .SRVAL_TQ       (1'b0),
            .TRISTATE_WIDTH (1)      
         ) inst_oserdese1_slave (
            .OFB            (),          
            .OQ             (),              
            .SHIFTOUT1      (oserdese_slave_shift_out_o[0]),
            .SHIFTOUT2      (oserdese_slave_shift_out_o[1]),
            .TFB            (),             
            .TQ             (),               
            .CLK            (i_clk_600),       
            .CLKDIV         (i_clk_120),  
            .CLKPERF        (1'b0),
            .CLKPERFDELAY   (1'b0),
            .D1             (1'b0),
            .D2             (1'b0),
            .D3             (i_data[6]),
            .D4             (i_data[7]),
            .D5             (i_data[8]),
            .D6             (i_data[9]),
            .OCE            (1'b1),           
            .ODV            (1'b0), 
            .RST            (local_reset_120), // asynchronous reset (posedge)          
            .SHIFTIN1       (1'b0),
            .SHIFTIN2       (1'b0),
            .T1             (1'b0),
            .T2             (1'b0),
            .T3             (1'b0),
            .T4             (1'b0),
            .TCE            (1'b0),        
            .WC             (1'b0)
         );

         
   end

endgenerate

//////////////////////////////////////////////////////////////////////////////////////
// OUTPUT BUFFER

      OBUFDS #(
         .IOSTANDARD    ("LVDS_25"), 
         .SLEW          ("SLOW")           
      ) inst_tx_obufds (
         .O     (o_tx_p),             
         .OB    (o_tx_n),         
         .I     (oserdese_master_o)         
      );

  
endmodule

`endif /* PHYSICAL_IOB_OSERDES */