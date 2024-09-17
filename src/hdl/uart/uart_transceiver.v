/*
    Module  : UART_TRANSCEIVER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`ifndef _UART_TRANSCEIVER_V_
`define _UART_TRANSCEIVER_V_

`include "src/hdl/uart/include/uart_defines.vh"
//
`include "src/hdl/uart/uart_tx.v"
`include "src/hdl/uart/uart_rx.v"
//
`include "src/hdl/divers/sr_ff.v"
`include "src/hdl/divers/sync_fifo.v"


module uart_transceiver #(
    parameter F_CLK              = 100_000_000,
    parameter BAUDRATE           = 9600,
    parameter DATA_WIDTH         = 8,
    parameter STOP_BITS          = `STOP_BITS_ONE,
    parameter PARITY             = `PARITY_NONE,
    parameter FIFO_TX_ADDR_WIDTH = 8,
    parameter FIFO_RX_ADDR_WIDTH = 8
) (
    input wire i_clk, i_arst_n,
    input wire i_rx,
    input wire i_rd, i_wr,
    input wire [DATA_WIDTH-1:0] i_data,
    output wire o_tx,
    output wire [DATA_WIDTH-1:0] o_data,
    output wire o_rx_valid, o_tx_rdy,
    output wire [2:0] o_err_state,
    output wire o_err
);


    uart_rx #(
        .F_CLK          (F_CLK), 
        .BAUDRATE       (BAUDRATE), 
        .DATA_WIDTH     (DATA_WIDTH), 
        .STOP_BITS      (STOP_BITS), 
        .PARITY         (PARITY)
    ) inst_uart_rx (
        .i_clk          (i_clk),
        .i_arst_n       (i_arst_n),
        .i_rx           (i_rx),
        .o_data         (),
        .o_data_valid   (),
        .o_frame_err    (),
        .o_parity_err   ()
    );    


    sync_fifo #(
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     (FIFO_RX_ADDR_WIDTH)
    ) inst_sync_fifo_rx (
        .i_clk          (i_clk),
        .i_arst_n       (i_arst_n),
        .i_wr           (inst_uart_rx.o_data_valid),
        .i_rd           (i_rd),
        .i_data         (inst_uart_rx.o_data),
        .o_data         (o_data),
        .o_full         (),
        .o_empty        ()
    );

    assign o_rx_valid = ~inst_sync_fifo_rx.o_empty; 

    uart_tx #(
        .F_CLK          (F_CLK), 
        .BAUDRATE       (BAUDRATE), 
        .DATA_WIDTH     (8), 
        .STOP_BITS      (STOP_BITS), 
        .PARITY         (PARITY)
    ) inst_uart_tx (
        .i_clk          (i_clk),
        .i_arst_n       (i_arst_n),
        .i_tx_en        (~inst_sync_fifo_tx.o_empty),
        .i_data         (inst_sync_fifo_tx.o_data),
        .o_tx           (o_tx),
        .o_busy         (),
        .o_done         ()
    );

    sync_fifo #(
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     (FIFO_TX_ADDR_WIDTH)
    ) inst_sync_fifo_tx (
        .i_clk          (i_clk),
        .i_arst_n       (i_arst_n),
        .i_wr           (i_wr),
        .i_rd           (inst_uart_tx.o_done),
        .i_data         (i_data),
        .o_data         (),
        .o_full         (),
        .o_empty        ()
    );

    assign o_tx_rdy = ~inst_sync_fifo_tx.o_full;

    // generate error status => only receive errors, because it is
    // not handle with control signals
    // [0] parity error [1] frame error [2] rx lost error
    
    // set when frame-error / reset when transfer is valid
    sr_ff inst_frame_err_ff (
        .i_clk          (i_clk),
        .i_arst_n       (i_arst_n),
        .i_s            (inst_uart_rx.o_frame_err),
        .i_r            (inst_uart_rx.o_data_valid),
        .o_q            (o_err_state[0]),
        .o_qn           ()
    );

    // set when parity-error / reset when transfer is valid
    sr_ff inst_parity_err_ff (
        .i_clk          (i_clk),
        .i_arst_n       (i_arst_n),
        .i_s            (inst_uart_rx.o_parity_err),
        .i_r            (inst_uart_rx.o_data_valid),
        .o_q            (o_err_state[1]),
        .o_qn           ()
    );

    // set when receive fifo is full and new data is coming
    // reset when fifo is not full
    wire rx_lost_err = (inst_sync_fifo_rx.o_full && inst_uart_rx.o_data_valid);  

    sr_ff inst_rx_lost_err_ff (
        .i_clk          (i_clk),
        .i_arst_n       (i_arst_n),
        .i_s            (rx_lost_err),
        .i_r            (~inst_sync_fifo_rx.o_full),
        .o_q            (o_err_state[2]),
        .o_qn           ()
    );

    // sum - error
    assign o_err = |o_err_state;


endmodule

`endif /* UART_TRANSCEIVER */

