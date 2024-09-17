/*
    Module  : UART_TB
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`include "src/hdl/uart/include/uart_defines.vh"

`timescale 1ns/1ns

module uart_tb;

reg sim_clk, sim_arst_n;
reg sim_wr, sim_rd;
reg[7:0] sim_data;
reg [7:0] gen_data [8:0];

integer byte_count;


initial 
    begin
    sim_clk     = 1'b0;
        forever
        #5 sim_clk = ~sim_clk;
    end


// Dumpfile und Dumpvars für GtkWave
initial begin
    $dumpfile("sim/icarus/uart.vcd");
    $dumpvars(0, uart_tb);
end


initial
begin
    sim_arst_n = 1'b0; 
    sim_wr     = 1'b0;
    sim_rd     = 1'b0;
    sim_data   = 8'b0;

    #100 sim_arst_n = 1'b1;

    byte_count = 0;

    // write data
    while (byte_count < 8) begin
        gen_data[byte_count] = $random;
        sim_data = gen_data [byte_count];
        $display("data: gen_data = %h", sim_data);
        wait (dut_uart_transceiver.o_tx_rdy);
        @(posedge sim_clk) sim_wr = 1'b1;
        @(posedge sim_clk) sim_wr = 1'b0;
        #10
        byte_count = byte_count + 1;
    end

    byte_count = 0;         
            
    // read data
    while (byte_count < 8) begin
        wait (dut_uart_transceiver.o_rx_valid);
        if (gen_data[byte_count] === dut_uart_transceiver.o_data) begin
            $display("test passed: send = %h, receive = %h", gen_data[byte_count], dut_uart_transceiver.o_data);
        end else begin
            $display("test failed: send = %h, receive = %h", gen_data[byte_count], dut_uart_transceiver.o_data);
        end
        @(posedge sim_clk) sim_rd = 1'b1;
        @(posedge sim_clk) sim_rd = 1'b0;
        #10
        byte_count = byte_count + 1;
    end

    #100 $finish;
end






uart_transceiver #(
    .F_CLK          (100_000_000), 
    .BAUDRATE       (115200), 
    .DATA_WIDTH     (8), 
    .STOP_BITS      (`STOP_BITS_ONE), 
    .PARITY         (`PARITY_ODD),
    .FIFO_TX_ADDR_WIDTH   (8),
    .FIFO_RX_ADDR_WIDTH   (8)
) dut_uart_transceiver (
    .i_clk          (sim_clk),
    .i_arst_n       (sim_arst_n),
    .i_rx           (dut_uart_transceiver.o_tx),
    .o_tx           (),
    .i_rd           (sim_rd),
    .i_wr           (sim_wr),
    .i_data         (sim_data),
    .o_data         (),
    .o_rx_valid     (),
    .o_tx_rdy       (),
    .o_err_state    (),
    .o_err          ()
);



endmodule