 /*
    Module  : Testbench Test-Core 
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 15.01.2024

    ToDo => Implement / Test timeout error 
         => use tasks for repetition process 

*/

`include "src/hdl/uart/include/uart_defines.vh"
`include "src/hdl/test_core/include/test_core_defines.vh"


`timescale 1ps/1ps

module top_tb;

reg sim_clk_120, sim_arst_n;
reg sim_clk_300, sim_clk_600, sim_clk_166;
reg sim_pc_wr, sim_pc_rd;
reg[7:0] sim_pc_data_in;
reg [7:0] gen_data [28:0];



localparam time TIMEOUT = 7000000000;

integer time_pre;
integer byte_count;


initial begin
    sim_clk_120 = 1'b1;
    sim_clk_300 = 1'b1;
    sim_clk_600 = 1'b1;
    sim_clk_166 = 1'b1;
    end



initial begin
            forever
                #4166 sim_clk_120 = ~sim_clk_120;
    end

    initial begin
            forever
                #1666 sim_clk_300 = ~sim_clk_300;
    end

    initial begin
            forever
                #833 sim_clk_600 = ~sim_clk_600;
    end

    initial begin
            forever
                #3000 sim_clk_166 = ~sim_clk_166;
    end

// Dumpfile und Dumpvars für GtkWave
initial begin
    $dumpfile("sim/icarus/top.vcd");
    $dumpvars(0, top_tb);
end

initial 
    begin
    #0        sim_arst_n     = 1'b0; 
              sim_pc_rd      = 1'b0;
              sim_pc_wr      = 1'b0;
              time_pre       = 0;
              byte_count     = 0;
    #10000    sim_arst_n        = 1'b1;
    #10000    sim_arst_n        = 1'b0;
    #100000   sim_arst_n        = 1'b1;
              sim_pc_data_in = 0; 
        
            // check echo
            $display("test - GET_ECHO_CMD");
            sim_pc_data_in = `GET_ECHO_CMD;
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            sim_pc_data_in = $random;
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            wait (dut_uart_transceiver_pc.o_rx_valid)
            if (sim_pc_data_in === dut_uart_transceiver_pc.o_data) begin
                $display("test passed: send = %h, resceive = %h", sim_pc_data_in, dut_uart_transceiver_pc.o_data);
            end else begin
                $display("test failed: send = %h, resceive = %h", sim_pc_data_in, dut_uart_transceiver_pc.o_data);
            end
            #10000
            @(posedge sim_clk_166) sim_pc_rd = 1'b1;
            @(posedge sim_clk_166) sim_pc_rd = 1'b0;

            #5000;
        /*    
            // check delay write
            $display("test - SET_DELAY_CMD");
            sim_pc_data_in = `SET_DELAY_CMD;
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk) sim_pc_wr = 1'b1;
            @(posedge sim_clk) sim_pc_wr = 1'b0;
            sim_pc_data_in = 31; // max delay
            wait (dut_uart_transceiver_pc.o_tx_rdy)
            @(posedge sim_clk) sim_pc_wr = 1'b1;
            @(posedge sim_clk) sim_pc_wr = 1'b0;
            time_pre = $time;
            while (!dut_test_core.o_wr_tab_delay && ($time - time_pre < TIMEOUT)) begin
                #5000;
            end
            if (dut_test_core.o_wr_tab_delay) begin
                if (sim_pc_data_in[4:0] === dut_test_core.o_tab_delay) begin
                    $display("test passed: send = %h, delay = %h", sim_pc_data_in, dut_test_core.o_tab_delay);
                end else begin
                    $display("test failed: send = %h, delay = %h", sim_pc_data_in, dut_test_core.o_tab_delay);
                end
            end else begin
                $display("test failed: timeout error");
                $finish;
            end
            #500;
*/
            // write data
            $display("test - WRITE_DEST_CMD");
            sim_pc_data_in = `WRITE_DEST_CMD;
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            sim_pc_data_in = 0; // dummy
            wait (dut_uart_transceiver_pc.o_tx_rdy)
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;

            // write random data
            byte_count = 0;
            while (byte_count < 28) begin
                gen_data[byte_count] = $random;
                sim_pc_data_in = gen_data [byte_count];
                $display("data: gen_data = %h", sim_pc_data_in);
                wait (dut_uart_transceiver_pc.o_tx_rdy);
                @(posedge sim_clk_166) sim_pc_wr = 1'b1;
                @(posedge sim_clk_166) sim_pc_wr = 1'b0;
                #10000
                byte_count = byte_count + 1;
            end

/*
            time_pre = $time;
            while (!dut_top.LD0 && ($time - time_pre < TIMEOUT)) begin
                #5000;
            end
*/
            #5000;
            // start loop
            $display("test - LOOP_START_CMD");
            sim_pc_data_in = `START_LOOP_CMD;
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            sim_pc_data_in = 0; // dummy
            wait (dut_uart_transceiver_pc.o_tx_rdy)
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            time_pre = $time;
            
            while (!dut_top.LD1 && ($time - time_pre < TIMEOUT)) begin
                #5000;
            end
            
            
            if (dut_top.LD1) begin
                $display("test passed: loop_enable = %b", dut_top.LD1);
            end else begin
                $display("test failed: timeout error");
                $finish;
            end

            #5000;
            // check loop stop
            $display("test - LOOP_STOP_CMD");
            sim_pc_data_in = `STOP_LOOP_CMD;
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            sim_pc_data_in = 0; // dummy
            wait (dut_uart_transceiver_pc.o_tx_rdy)
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            time_pre = $time;
            
            while (dut_top.LD1 && ($time - time_pre < TIMEOUT)) begin
                #5000;
            end
            
            if (!dut_top.LD1) begin
                $display("test passed: loop_enable = %b", dut_top.LD1);
            end else begin
                $display("test failed: timeout error");
                $finish;
            end

            #5000

            // read data
            $display("test - READ_SRC_CMD");
            sim_pc_data_in = `READ_SRC_CMD;
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            sim_pc_data_in = 0; // dummy
            wait (dut_uart_transceiver_pc.o_tx_rdy)
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;

            
            byte_count = 0;
            while (byte_count < 28) begin
                time_pre = $time;
                
                while (!dut_uart_transceiver_pc.o_rx_valid && ($time - time_pre < TIMEOUT)) begin
                    #5000;
                end
                
                if (dut_uart_transceiver_pc.o_rx_valid) begin
                    if (gen_data[byte_count] === dut_uart_transceiver_pc.o_data)
                        $display("test passed: gen_data = %h, received data = %h", gen_data[byte_count], dut_uart_transceiver_pc.o_data);
                    else
                        $display("test failed: gen_data = %h, received data = %h", gen_data[byte_count], dut_uart_transceiver_pc.o_data);
                end else begin
                    $display("test failed: timeout error");
                    $finish;
                end
                // read next data
                @(posedge sim_clk_166) sim_pc_rd = 1'b1;
                @(posedge sim_clk_166) sim_pc_rd = 1'b0;
                byte_count = byte_count + 1;
                #10000;
            end

            // read cycle's
            $display("test - READ_CYCLE_CMD");
            sim_pc_data_in = `READ_CYCLE_CMD;
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            sim_pc_data_in = 0; // dummy
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            wait (dut_uart_transceiver_pc.o_rx_valid)
            if (sim_pc_data_in < 200) begin
                $display("test passed: cycles = %d", dut_uart_transceiver_pc.o_data);
            end else begin
                $display("test failed: cycles = %d", dut_uart_transceiver_pc.o_data);
            end
            #10000
            @(posedge sim_clk_166) sim_pc_rd = 1'b1;
            @(posedge sim_clk_166) sim_pc_rd = 1'b0;
            #5000

    $finish;
            
    end



    uart_transceiver #(
        .F_CLK              (166_666_667), 
        .BAUDRATE           (11520000), 
        .DATA_WIDTH         (8), 
        .STOP_BITS          (`STOP_BITS_ONE), 
        .PARITY             (`PARITY_ODD),
        .FIFO_TX_ADDR_WIDTH (8),
        .FIFO_RX_ADDR_WIDTH (8)
    ) dut_uart_transceiver_pc (
        .i_clk              (sim_clk_166),
        .i_arst_n           (sim_arst_n),
        .i_rx               (dut_top.JA2),
        .o_tx               (),
        .i_rd               (sim_pc_rd),
        .i_wr               (sim_pc_wr),
        .i_data             (sim_pc_data_in),
        .o_data             (),
        .o_rx_valid         (),
        .o_tx_rdy           (),
        .o_err_state        (),
        .o_err              ()
    );

    top dut_top (
        .sim_clk_120    (sim_clk_120),
        .sim_clk_300    (sim_clk_300),
        .sim_clk_600    (sim_clk_600),
        .sim_clk_166    (sim_clk_166),
        .GCLK           (sim_clk_120), 
        .sim_arst_n     (sim_arst_n),
        .JA3            (dut_uart_transceiver_pc.o_tx),
        .FMC_CLK0_N     (dut_top.FMC_CLK1_N),
        .FMC_CLK0_P     (dut_top.FMC_CLK1_P),
        .FMC_LA04_N     (dut_top.FMC_LA03_N),
        .FMC_LA04_P     (dut_top.FMC_LA03_P),
        .FMC_LA00_CC_N  (dut_top.FMC_LA02_N),
        .FMC_LA00_CC_P  (dut_top.FMC_LA02_P),
        .JA2            (),
        .LD0            (),
        .LD1            (),
        .FMC_CLK1_N     (),
        .FMC_CLK1_P     (),
        .FMC_LA02_N     (),
        .FMC_LA02_P     (),
        .FMC_LA03_N     (),
        .FMC_LA03_P     ()
    );

endmodule

