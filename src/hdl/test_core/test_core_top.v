
 /*
    Module  : TEST_CORE_TOP
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`ifndef _TEST_CORE_TOP_V_
`define _TEST_CORE_TOP_V_

`include "src/hdl/test_core/pc_interface/pc_interface_top.v"
`include "src/hdl/test_core/loop_interface/loop_interface_top.v"
//
`include "src/hdl/divers/sr_ff.v"
`include "src/hdl/divers/register.v"
`include "src/hdl/divers/sync_dual_port_ram.v"
//
`include "src/hdl/cdc/async_reset.v"


module test_core_top #(
    // UART
    parameter CLK_FREQUENCY           = 100_000_000,
    parameter UART_BAUDRATE           = 115200,
    parameter UART_STOP_BITS          = `STOP_BITS_ONE,
    parameter UART_PARITY             = `PARITY_NONE,
    parameter UART_FIFO_TX_ADDR_WIDTH = 8,
    parameter UART_FIFO_RX_ADDR_WIDTH = 8
) (
    input wire i_clk, i_arst_n,
    // UART INTERFACE
    input wire i_pc_rx,
    output wire o_pc_tx, 
    output wire o_pc_err,
    // TRANSCEIVER A
    //
    // LOOP - PATTERN
    input wire i_trx_a_data_rdy, i_trx_a_data_valid,
    input wire[33:0] i_trx_a_data_o,
    output wire [55:0] o_trx_a_data_i,
    output wire o_trx_a_data_wr, o_trx_a_data_rd,
    // CONTROL & MONITOR 
    input wire [4:0] i_trx_a_edge_tabs,
    input wire [4:0] i_trx_a_delay_tabs,
    output wire o_trx_a_wr_delay_tabs,
    output wire [4:0] o_trx_a_delay_tabs,
    // TRANSCEIVER B
    //
    // LOOP - PATTERN
    input wire i_trx_b_data_rdy, i_trx_b_data_valid,
    input wire[55:0] i_trx_b_data_o,
    output wire [33:0] o_trx_b_data_i,
    output wire o_trx_b_data_wr, o_trx_b_data_rd,
    // CONTROL & MONITOR 
    input wire [4:0] i_trx_b_edge_tabs,
    input wire [4:0] i_trx_b_delay_tabs,
    output wire o_trx_b_wr_delay_tabs,
    output wire [4:0] o_trx_b_delay_tabs
 );

    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
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



    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // PC_INTERFACE 

    pc_interface_top #(
        .CLK_FREQUENCY           (CLK_FREQUENCY),
        .UART_BAUDRATE           (UART_BAUDRATE),
        .UART_STOP_BITS          (UART_STOP_BITS),
        .UART_PARITY             (UART_PARITY),
        .UART_FIFO_TX_ADDR_WIDTH (UART_FIFO_TX_ADDR_WIDTH),
        .UART_FIFO_RX_ADDR_WIDTH (UART_FIFO_RX_ADDR_WIDTH),
        .TEST_PATTERN_WIDTH      (56)
    ) inst_pc_interface_top (
        .i_clk                   (i_clk),
        .i_arst_n                (inst_local_reset.o_rst),
        // PC INTERFACE (UART)
        .i_pc_rx                 (i_pc_rx),
        .o_pc_tx                 (o_pc_tx),
        .o_pc_err                (o_pc_err),
        // TEST PATTERN INTERFACE
        .i_pattern               (inst_bank_l.o_data_b), // read from bank l (loop)
        .o_pattern_wr            (),
        .o_pattern_addr          (),
        .o_pattern               (), // write to bank p (pattern)
        // CONTROL BANK INTERFACE
        .o_bank_c_wr             (), // write port (0 - 7)
        .o_bank_c_data_0         (), // control bits 
        .o_bank_c_data_1         (), // pattern number
        .o_bank_c_data_2         (), // sim tab delay transceiver a
        .o_bank_c_data_3         (), // sim tab delay transceiver b
        .o_bank_c_data_4         (), // reserve
        .o_bank_c_data_5         (), // reserve
        .o_bank_c_data_6         (), // reserve
        .o_bank_c_data_7         (), // uart echo
        // STATUS BANK INTERFACE
        .i_bank_s_data_0         ({15'b0, inst_loop_interface_top.o_loop_run}),
        .i_bank_s_data_1         (inst_loop_interface_top.o_loop_cycle),
        .i_bank_s_data_2         ({11'b0, inst_bank_s_trx_a_edge_tabs.o_data}), // edge tabs transceiver a
        .i_bank_s_data_3         ({11'b0, inst_bank_s_trx_a_tab_delay_i.o_data}), // delay tabs transceiver a
        .i_bank_s_data_4         ({11'b0, inst_bank_s_trx_b_edge_tabs.o_data}), // edge tabs transceiver b
        .i_bank_s_data_5         ({11'b0, inst_bank_s_trx_b_tab_delay_i.o_data}), // delay tabs transceiver b
        .i_bank_s_data_6         (16'b0), // reserve
        .i_bank_s_data_7         (inst_bank_c_echo.o_data)
    );


    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOOP - INTERFACE
    loop_interface_top inst_loop_interface_top (
        .i_clk          (i_clk),
        .i_arst_n       (inst_local_reset.o_rst),
        // CONTROL & STATUS
        .i_loop_enable  (inst_bank_c_single_loop.o_q || inst_bank_c_continuous_loop.o_q), 
        .o_loop_run     (),
        .o_loop_done    (),
        .o_loop_timeout (),
        .o_loop_cycle   (),
        //
        .i_pattern_num  (inst_bank_c_pattern_num.o_data),
        .o_pattern_wr   (),
        .o_pattern_addr (),
        .o_pattern      (),
        // TRANSCEIVER_A
        .i_trx_a_rdy    (i_trx_a_data_rdy),
        .i_trx_a_valid  (i_trx_a_data_valid),
        .i_trx_a        (i_trx_a_data_o),
        .o_trx_a_wr     (o_trx_a_data_wr),
        .o_trx_a_rd     (o_trx_a_data_rd),
        // TRANSCEIVER_B
        .i_trx_b_rdy    (i_trx_b_data_rdy),
        .i_trx_b_valid  (i_trx_b_data_valid),
        .i_trx_b        (i_trx_b_data_o),
        .o_trx_b        (o_trx_b_data_i),
        .o_trx_b_wr     (o_trx_b_data_wr),
        .o_trx_b_rd     (o_trx_b_data_rd)
    );


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // REGISTER ASSIGN CONTROL BANK (C - BANK)

    // ENABLE SINGLE - LOOP
    sr_ff inst_bank_c_single_loop ( 
        .i_clk      (i_clk),
        .i_arst_n   (inst_local_reset.o_rst),
        .i_s        (inst_pc_interface_top.o_bank_c_data_0[0] && inst_pc_interface_top.o_bank_c_wr[0]),
        .i_r        (inst_loop_interface_top.o_loop_run || inst_loop_interface_top.o_loop_timeout),
        .o_q        (),
        .o_qn       ()
    );

    // ENABLE CONTINUOUS - LOOP
    sr_ff inst_bank_c_continuous_loop ( 
        .i_clk      (i_clk),
        .i_arst_n   (inst_local_reset.o_rst),
        .i_s        (inst_pc_interface_top.o_bank_c_data_0[1] && inst_pc_interface_top.o_bank_c_wr[0]),
        .i_r        ((inst_pc_interface_top.o_bank_c_data_0[2] && inst_pc_interface_top.o_bank_c_wr[0]) || inst_loop_interface_top.o_loop_timeout),
        .o_q        (),
        .o_qn       ()
    );

    
    // PATTERN NUM (0 - 7)
    register #(
        .DATA_WIDTH (3)
    ) inst_bank_c_pattern_num ( 
        .i_clk      (i_clk),
        .i_arst_n   (inst_local_reset.o_rst),
        .i_wr       (inst_pc_interface_top.o_bank_c_wr[1]),
        .i_clr      (1'b0),
        .i_data     (inst_pc_interface_top.o_bank_c_data_1[2:0]),
        .o_data     ()
    );

    // DELAY TRANSCEIVER A
    register #(
        .DATA_WIDTH (1)
    ) inst_bank_c_trx_a_wr_tab_delay ( 
        .i_clk      (i_clk),
        .i_arst_n   (inst_local_reset.o_rst),
        .i_wr       (1'b1),
        .i_clr      (1'b0),
        .i_data     (inst_pc_interface_top.o_bank_c_wr[2]),
        .o_data     (o_trx_a_wr_delay_tabs)
    );

    register #(
        .DATA_WIDTH (5)
    ) inst_bank_c_trx_a_tab_delay_o ( 
        .i_clk      (i_clk),
        .i_arst_n   (inst_local_reset.o_rst),
        .i_wr       (inst_pc_interface_top.o_bank_c_wr[2]),
        .i_clr      (1'b0),
        .i_data     (inst_pc_interface_top.o_bank_c_data_2[4:0]),
        .o_data     (o_trx_a_delay_tabs)
    );


    // DELAY TRANSCEIVER B
    register #(
        .DATA_WIDTH (1)
    ) inst_bank_c_trx_b_wr_tab_delay ( 
        .i_clk      (i_clk),
        .i_arst_n   (inst_local_reset.o_rst),
        .i_wr       (1'b1),
        .i_clr      (1'b0),
        .i_data     (inst_pc_interface_top.o_bank_c_wr[3]),
        .o_data     (o_trx_b_wr_delay_tabs)
    );

    register #(
        .DATA_WIDTH (5)
    ) inst_bank_c_trx_b_tab_delay_o ( 
        .i_clk      (i_clk),
        .i_arst_n   (inst_local_reset.o_rst),
        .i_wr       (inst_pc_interface_top.o_bank_c_wr[3]),
        .i_clr      (1'b0),
        .i_data     (inst_pc_interface_top.o_bank_c_data_3[4:0]),
        .o_data     (o_trx_b_delay_tabs)
    );


    // ECHO 
    register #(
        .DATA_WIDTH (16)
    ) inst_bank_c_echo ( 
        .i_clk      (i_clk),
        .i_arst_n   (inst_local_reset.o_rst),
        .i_wr       (inst_pc_interface_top.o_bank_c_wr[7]),
        .i_clr      (1'b0),
        .i_data     (inst_pc_interface_top.o_bank_c_data_7),
        .o_data     ()
    );


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // STATUS - BANK (S - BANK) 

    // TRANSCEIVER A
    register #(
        .DATA_WIDTH (5)
    ) inst_bank_s_trx_a_edge_tabs ( 
        .i_clk      (i_clk),
        .i_arst_n   (inst_local_reset.o_rst),
        .i_wr       (1'b1),
        .i_clr      (1'b0),
        .i_data     (i_trx_a_edge_tabs),
        .o_data     ()
    );

    register #(
        .DATA_WIDTH (5)
    ) inst_bank_s_trx_a_tab_delay_i ( 
        .i_clk      (i_clk),
        .i_arst_n   (inst_local_reset.o_rst),
        .i_wr       (1'b1),
        .i_clr      (1'b0),
        .i_data     (i_trx_a_delay_tabs),
        .o_data     ()
    );

    // TRANSCEIVER A
    register #(
        .DATA_WIDTH (5)
    ) inst_bank_s_trx_b_edge_tabs ( 
        .i_clk      (i_clk),
        .i_arst_n   (inst_local_reset.o_rst),
        .i_wr       (1'b1),
        .i_clr      (1'b0),
        .i_data     (i_trx_b_edge_tabs),
        .o_data     ()
    );

    register #(
        .DATA_WIDTH (5)
    ) inst_bank_s_trx_b_tab_delay_i ( 
        .i_clk      (i_clk),
        .i_arst_n   (inst_local_reset.o_rst),
        .i_wr       (1'b1),
        .i_clr      (1'b0),
        .i_data     (i_trx_b_delay_tabs),
        .o_data     ()
    );




    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // PATTERN - BANK (P - BANK)

    sync_dual_port_ram #(
        .DATA_WIDTH  (56),
        .ADDR_WIDTH  (3)
    ) inst_bank_p (
        .i_clk       (i_clk),
        .i_wr        (inst_pc_interface_top.o_pattern_wr),
        .i_addr_a    (inst_pc_interface_top.o_pattern_addr),
        .i_addr_b    (inst_loop_interface_top.o_pattern_addr),
        .i_data      (inst_pc_interface_top.o_pattern),
        .o_data_a    (),  
        .o_data_b    () // link to transceiver a
    );

    // LOOP - BANK (L - BANK)
    sync_dual_port_ram #(
        .DATA_WIDTH  (56),
        .ADDR_WIDTH  (3)
    ) inst_bank_l (
        .i_clk       (i_clk),
        .i_wr        (inst_loop_interface_top.o_pattern_wr),
        .i_addr_a    (inst_loop_interface_top.o_pattern_addr),
        .i_addr_b    (inst_pc_interface_top.o_pattern_addr),
        .i_data      (inst_loop_interface_top.o_pattern),
        .o_data_a    (), 
        .o_data_b    () // link to pc interface
    );


    //////////////////////////////////////////////////////////////////////////////////////////////
    // SEL PATTERN SOURCE (P / L - BANK) FOR TRANSCEIVER A TLP - INPUT
    sr_ff inst_sel_p_bank ( 
        .i_clk      (i_clk),
        .i_arst_n   (inst_local_reset.o_rst),
        .i_s        (inst_loop_interface_top.o_loop_done),
        .i_r        (~inst_loop_interface_top.o_loop_run),
        .o_q        (),
        .o_qn       ()
    );

    // MUX 2X1 => TRANSCEIVER A
    assign o_trx_a_data_i = (inst_sel_p_bank.o_q) ? inst_bank_l.o_data_a : inst_bank_p.o_data_b;

  


endmodule

`endif /* TEST_CORE_TOP */
    