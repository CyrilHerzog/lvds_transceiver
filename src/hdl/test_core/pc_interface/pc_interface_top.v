
/*
    Module  : PC_INTERFACE_TOP
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _PC_INTERFACE_TOP_V_
`define _PC_INTERFACE_TOP_V_

`include "src/hdl/uart/include/uart_defines.vh"
//
`include "src/hdl/test_core/pc_interface/pc_interface_handler.v"

//
`include "src/hdl/uart/uart_transceiver.v"
`include "src/hdl/divers/mux_8.v"
`include "src/hdl/divers/demux.v"
//
`include "src/hdl/cdc/async_reset.v"


module pc_interface_top #(
    parameter CLK_FREQUENCY           = 100_000_000,
    parameter UART_BAUDRATE           = 115200,
    parameter UART_STOP_BITS          = `STOP_BITS_ONE,
    parameter UART_PARITY             = `PARITY_EVEN,
    parameter UART_FIFO_TX_ADDR_WIDTH = 8,
    parameter UART_FIFO_RX_ADDR_WIDTH = 8,
    parameter TEST_PATTERN_WIDTH      = 56
) (
    input wire i_clk, i_arst_n,
    // UART
    input wire i_pc_rx,
    output wire o_pc_tx, 
    output wire o_pc_err,
    // P - BANK
    input wire[TEST_PATTERN_WIDTH-1:0] i_pattern, // from loop - bank
    output wire o_pattern_wr,
    output wire[TEST_PATTERN_WIDTH-1:0] o_pattern,
    output wire [2:0] o_pattern_addr,
    // C - BANK
    output wire[7:0] o_bank_c_wr, // write - bit for any register 0 - 7
    output wire [15:0] o_bank_c_data_0,
    output wire [15:0] o_bank_c_data_1,
    output wire [15:0] o_bank_c_data_2,
    output wire [15:0] o_bank_c_data_3,
    output wire [15:0] o_bank_c_data_4,
    output wire [15:0] o_bank_c_data_5,
    output wire [15:0] o_bank_c_data_6,
    output wire [15:0] o_bank_c_data_7,
    // S - BANK
    input wire [15:0] i_bank_s_data_0,
    input wire [15:0] i_bank_s_data_1,
    input wire [15:0] i_bank_s_data_2,
    input wire [15:0] i_bank_s_data_3,
    input wire [15:0] i_bank_s_data_4,
    input wire [15:0] i_bank_s_data_5,
    input wire [15:0] i_bank_s_data_6,
    input wire [15:0] i_bank_s_data_7
 );
    
    /////////////////////////////////////////////////////////////////////////////////////////////
    // LOCAL RESET
    async_reset #(
      .STAGES   (2),
      .INIT     (1'b0),
      .RST_VAL  (1'b0)
    ) inst_local_reset (
      .i_clk    (i_clk), 
      .i_rst_n  (i_arst_n),
      .o_rst    ()
    );
   

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // CALC TIMEOUT WIDTH
    localparam PARITY_BIT = (UART_PARITY != `PARITY_NONE) ? 1 : 0;
    localparam STOP_BITS  = (UART_STOP_BITS != `STOP_BITS_ONE) ? 2 : 1;
    localparam UART_BITS  = 9 + PARITY_BIT + STOP_BITS;

    localparam TIMEOUT_WIDTH = $clog2((CLK_FREQUENCY / UART_BAUDRATE) * UART_BITS) + 8; // take the next larger width 



    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // PC - INTERFACE (UART - TRANSCEIVER)

    uart_transceiver #(
        .F_CLK              (CLK_FREQUENCY), 
        .BAUDRATE           (UART_BAUDRATE), 
        .DATA_WIDTH         (8), 
        .STOP_BITS          (UART_STOP_BITS), 
        .PARITY             (UART_PARITY),
        .FIFO_TX_ADDR_WIDTH (UART_FIFO_TX_ADDR_WIDTH),
        .FIFO_RX_ADDR_WIDTH (UART_FIFO_RX_ADDR_WIDTH)
    ) inst_pc_interface (
        .i_clk              (i_clk),
        .i_arst_n           (inst_local_reset.o_rst),
        .i_rx               (i_pc_rx),
        .o_tx               (o_pc_tx),
        .i_rd               (inst_handler.o_pc_rd),
        .i_wr               (inst_handler.o_pc_wr),
        .i_data             (inst_handler.o_pc_data),
        .o_data             (),
        .o_rx_valid         (),
        .o_tx_rdy           (),
        .o_err_state        (),
        .o_err              (o_pc_err)
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    pc_interface_handler #(
        .TEST_PATTERN_WIDTH (TEST_PATTERN_WIDTH),
        .TIMEOUT_WIDTH      (TIMEOUT_WIDTH) 
    ) inst_handler (
        .i_clk              (i_clk),
        .i_arst_n           (inst_local_reset.o_rst),
    // UART
        .i_pc_valid         (inst_pc_interface.o_rx_valid), 
        .i_pc_rdy           (inst_pc_interface.o_tx_rdy),  
        .i_pc_data          (inst_pc_interface.o_data),
        .o_pc_data          (),
        .o_pc_rd            (),
        .o_pc_wr            (),
    // TEST - PATTERN
        .i_bank_l           (i_pattern), 
        .o_bank_p           (),
        .o_bank_p_wr        (),
    // CONTROL & STATUS
        .i_bank_s           (inst_data_router_bank_s.o_data),
        .o_bank_c           (),
        .o_bank_c_wr        (),
    // BANK ADDRESS
        .o_bank_addr        ()
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // ROUTE CONTROL - BANK (C - BANK)

    demux_8 #(
        .DATA_WIDTH (16)
    ) inst_data_router_bank_c (
        .i_data     (inst_handler.o_bank_c),
        .i_sel      (inst_handler.o_bank_addr),
        //
        .o_data_0   (o_bank_c_data_0),
        .o_data_1   (o_bank_c_data_1),
        .o_data_2   (o_bank_c_data_2),
        .o_data_3   (o_bank_c_data_3),
        .o_data_4   (o_bank_c_data_4),
        .o_data_5   (o_bank_c_data_5),
        .o_data_6   (o_bank_c_data_6),
        .o_data_7   (o_bank_c_data_7)
    );

    demux_8 #(
        .DATA_WIDTH (1)
    ) inst_write_router_bank_c (
        .i_data     (inst_handler.o_bank_c_wr),
        .i_sel      (inst_handler.o_bank_addr),
        //
        .o_data_0   (o_bank_c_wr[0]),
        .o_data_1   (o_bank_c_wr[1]),
        .o_data_2   (o_bank_c_wr[2]),
        .o_data_3   (o_bank_c_wr[3]),
        .o_data_4   (o_bank_c_wr[4]),
        .o_data_5   (o_bank_c_wr[5]),
        .o_data_6   (o_bank_c_wr[6]),
        .o_data_7   (o_bank_c_wr[7])
    );


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // ROUTE STATUS - BANK (S - BANK)

    mux_8 #(
        .DATA_WIDTH (16)
    ) inst_data_router_bank_s (
        .i_data_0    (i_bank_s_data_0),
        .i_data_1    (i_bank_s_data_1),
        .i_data_2    (i_bank_s_data_2),
        .i_data_3    (i_bank_s_data_3),
        .i_data_4    (i_bank_s_data_4),
        .i_data_5    (i_bank_s_data_5),
        .i_data_6    (i_bank_s_data_6),
        .i_data_7    (i_bank_s_data_7), 
        .i_sel       (inst_handler.o_bank_addr), 
        .o_data      ()
    );

    
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // PATTERN BANK

    assign o_pattern_addr = inst_handler.o_bank_addr;
    assign o_pattern_wr   = inst_handler.o_bank_p_wr;
    assign o_pattern      = inst_handler.o_bank_p;

endmodule

`endif /* PC_INTERFACE_TOP */
