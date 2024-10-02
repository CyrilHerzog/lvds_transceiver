 /*
    Module  : TEST_CORE_TB
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`include "src/hdl/uart/include/uart_defines.vh"
`include "src/hdl/uart/uart_transceiver.v"
//
`include "src/hdl/divers/sync_fifo.v"
`include "src/hdl/divers/simple_filter.v"
//
`include "src/hdl/lvds_transceiver/receiver/physical/physical_iob_clk_div.v"
`include "src/hdl/lvds_transceiver/lvds_transceiver_top.v"
//
`include "src/hdl/cdc/synchronizer.v"



`timescale 1ps/1ps

module test_core_tb;

reg sim_clk_166, sim_arst_n;
reg sim_pc_wr, sim_pc_rd;
reg[7:0] sim_pc_data_in;
reg [7:0] gen_data [55:0];
reg [7:0] pc_rcv_data [1:0];

reg[2:0] sim_pattern_num;
reg[1:0] sim_loop_mode;


integer byte_count;


localparam SINGLE_WRITE = 8'b00100000;
localparam MULTI_WRITE  = 8'b00110000;

localparam SINGLE_READ  = 8'b00000000;
localparam MULTI_READ   = 8'b00010000;

localparam WRITE_BANK_P = 8'b00001000;
localparam READ_BANK_L  = 8'b00001000;

localparam SINGLE_LOOP     = 2'b01;
localparam CONTINUOUS_LOOP = 2'b10;

// Test
localparam TEST_PATTERN_NUM = 3'b111;           // change between 0 - 7
localparam TEST_LOOP_MODE   = SINGLE_LOOP;      // change to single (2'b01) or continuous (2'b10)



initial begin
        sim_clk_166 = 1'b0;
        forever
        #3000 sim_clk_166 = ~sim_clk_166;
    end






  


// Dumpfile und Dumpvars für GtkWave
initial begin
    $dumpfile("sim/icarus/test_core.vcd");
    $dumpvars(0, test_core_tb);
end

initial 
    begin
    #0        sim_arst_n      = 1'b0; 
              sim_pc_rd       = 1'b0;
              sim_pc_wr       = 1'b0;
              byte_count      = 0;
              sim_pattern_num = TEST_PATTERN_NUM;
              sim_loop_mode   = TEST_LOOP_MODE;
    #100000   sim_arst_n      = 1'b1;
              sim_pc_data_in  = 0; 
             
        
            /* address:
            Bank C:  (control bank)                                                                         
            0 : loop control    (start / stop pattern - loop)       
                                BIT0 = start loop (single run)
                                BIT1 = start loop (continuous run)
                                BIT2 = stop loop  (continuous run)

            1 : pattern_num     (num of patterns which are transferred in loop => 0 - 7) 0 = 1 pattern / 7 = 8 pattern
                                {13'bx, pattern_num[2:0]}  
            2 : test tab delay transceiver a (5 bits) => {11'bx, tab_delay[4:0]}
            3 : test tab delay transceiver b (5 bits) => {11'bx, tab_delay[4:0]}
            4 : reserve
            5 : reserve
            6 : reserve
            7 : echo        (linked with address 7 of bank s)
                            {echo_byte[0], echo_byte[1]}

            Bank S:  (status bank)
            0 : loop status     (module status bits)           BIT0 = loop running, 
            1 : loop_cycle      (numer of clock cycles for the last loop pass)
            2 : edge tabs transceiver a
            3 : delay tabs transceiver a
            4 : edge tabs transceiver b
            5 : delay tabs transceiver b
            6 : reserve
            7 : echo                   (linked with control - bank address 7)


            Bank P: (pattern bank) => only write
            0 - 7 : 56 bit Test - pattern

            Bank L (loop bank) => only read
            0 - 7 : 56 bit test - pattern

            */
// **********************************************************************************************************************************
            // echo - check
            $display("test echo");
            // write echo data
            sim_pc_data_in = {SINGLE_WRITE | 3'b111};  // bank c address 3
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            #10

            while (byte_count < 2) begin
                gen_data[byte_count] = $random;
                sim_pc_data_in = gen_data [byte_count];
                $display("data: gen_data = %h", sim_pc_data_in);
                wait (dut_uart_transceiver_pc.o_tx_rdy);
                @(posedge sim_clk_166) sim_pc_wr = 1'b1;
                @(posedge sim_clk_166) sim_pc_wr = 1'b0;
                #10
                byte_count = byte_count + 1;
            end

            byte_count = 0;   
              
            
            // read echo data
            sim_pc_data_in = {SINGLE_READ | 3'b111}; // bank s address 3
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;


            while (byte_count < 2) begin
                wait (dut_uart_transceiver_pc.o_rx_valid);
                if (gen_data[byte_count] === dut_uart_transceiver_pc.o_data) begin
                    $display("test passed: send = %h, receive = %h", gen_data[byte_count], dut_uart_transceiver_pc.o_data);
                end else begin
                    $display("test failed: send = %h, receive = %h", gen_data[byte_count], dut_uart_transceiver_pc.o_data);
                end
                @(posedge sim_clk_166) sim_pc_rd = 1'b1;
                @(posedge sim_clk_166) sim_pc_rd = 1'b0;
                #10
                byte_count = byte_count + 1;
            end

            byte_count = 0;

// *******************************************************************************************************************************
// pattern bank
            $display("test loop");
            // write pattern data
            sim_pc_data_in = {MULTI_WRITE | WRITE_BANK_P | 3'b000}; // bank p address 0 => command address 8
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            
            $display("write  pattern");
            while (byte_count < 56 ) begin
                gen_data[byte_count] = $random;
                sim_pc_data_in = gen_data [byte_count];
                $display("data: pattern_data = %h", sim_pc_data_in);
                wait (dut_uart_transceiver_pc.o_tx_rdy);
                @(posedge sim_clk_166) sim_pc_wr = 1'b1;
                @(posedge sim_clk_166) sim_pc_wr = 1'b0;
                #5000
                byte_count = byte_count + 1;
            end

            byte_count = 0;   


      
            // valid pattern_num is between 0 - 7 => [cmd_byte, 8'bx, 5'bx, pattern_num] => max 8 * 56 bytes
            $display("write pattern num");
            sim_pc_data_in = {SINGLE_WRITE | 3'b001}; // bank c address 1
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            
            sim_pc_data_in = 8'b00000000;
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            
            sim_pc_data_in = {5'b00000, sim_pattern_num};
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;

    

            // start loop
            $display("start loop");
            sim_pc_data_in = {SINGLE_WRITE | 3'b000}; // bank c address 1
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            
            sim_pc_data_in = 8'b00000000;
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            
            sim_pc_data_in = {6'b000000, sim_loop_mode};
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;



            // check loop status
            $display("read loop status");
            sim_pc_data_in = {SINGLE_READ | 3'b000}; // bank s address 0
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;


            while (byte_count < 2) begin
                wait (dut_uart_transceiver_pc.o_rx_valid);
                pc_rcv_data[byte_count] = dut_uart_transceiver_pc.o_data;
                @(posedge sim_clk_166) sim_pc_rd = 1'b1;
                @(posedge sim_clk_166) sim_pc_rd = 1'b0;
                #5000
                byte_count = byte_count + 1;
            end

            if (pc_rcv_data[1][0] == 1'b1) begin
                $display("loop is running");
            end else begin
                $display("loop has stopped");
            end

            byte_count = 0;

            // stop loop (has only an effect by starts a continuous loop)
            $display("stop loop");
            sim_pc_data_in = {SINGLE_WRITE | 3'b000};
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            
            sim_pc_data_in = 8'b00000000;
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            
            sim_pc_data_in = 8'b00000100;
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;



            // check loop status after stopped loop
            $display("read loop status");
            sim_pc_data_in = {SINGLE_READ | 3'b000}; // bank s address 1
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;


            while (byte_count < 2) begin
                wait (dut_uart_transceiver_pc.o_rx_valid);
                pc_rcv_data[byte_count] = dut_uart_transceiver_pc.o_data;
                @(posedge sim_clk_166) sim_pc_rd = 1'b1;
                @(posedge sim_clk_166) sim_pc_rd = 1'b0;
                #5000
                byte_count = byte_count + 1;
            end

            if (pc_rcv_data[1][0] == 1'b1) begin
                $display("loop is running");
            end else begin
                $display("loop has stopped");
            end

            byte_count = 0;
        


            // read from bank l 
            $display("read pattern");
            sim_pc_data_in = {MULTI_READ | READ_BANK_L | 3'b000};
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            

            while (byte_count < 56) begin
                wait (dut_uart_transceiver_pc.o_rx_valid);
                if (gen_data[byte_count] === dut_uart_transceiver_pc.o_data) begin
                    $display("test passed: send = %h, receive = %h", gen_data[byte_count], dut_uart_transceiver_pc.o_data);
                end else begin
                    $display("test failed: send = %h, receive = %h", gen_data[byte_count], dut_uart_transceiver_pc.o_data);
                end
                @(posedge sim_clk_166) sim_pc_rd = 1'b1;
                @(posedge sim_clk_166) sim_pc_rd = 1'b0;
                #5000
                byte_count = byte_count + 1;
            end

            byte_count = 0;
            

            // read loop cycle  
            $display("read cycle");
            sim_pc_data_in = {SINGLE_READ | 3'b001}; // bank s address 1
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;


            while (byte_count < 2) begin
                wait (dut_uart_transceiver_pc.o_rx_valid);
                gen_data[byte_count] = dut_uart_transceiver_pc.o_data;
                @(posedge sim_clk_166) sim_pc_rd = 1'b1;
                @(posedge sim_clk_166) sim_pc_rd = 1'b0;
                #5000
                byte_count = byte_count + 1;
            end

             $display("num cycles for single transfer: loop_cycle = %d", {gen_data[0], gen_data[1]});

            byte_count = 0;
            //
        
        

// ***************************************************************************************************************************************************
// TEST DELAY
          
            $display("test write delay - transceiver a");
            // write delay value
            sim_pc_data_in = {SINGLE_WRITE | 3'b010}; // bank c address 2
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            #10
            // delay value is an 5 bit from 0 - 31 value => [cmd_byte, 8'bx, 3'bx, delay_value]
            while (byte_count < 2) begin
                gen_data[byte_count] = $random;
                sim_pc_data_in = gen_data [byte_count];
                wait (dut_uart_transceiver_pc.o_tx_rdy);
                @(posedge sim_clk_166) sim_pc_wr = 1'b1;
                @(posedge sim_clk_166) sim_pc_wr = 1'b0;
                #10
                byte_count = byte_count + 1;
            end

            // check the last 5 bits of delay value
            wait(dut_test_core.o_trx_a_delay_tabs != 5'b00000);
            if (gen_data[1][4:0] === dut_test_core.o_trx_a_delay_tabs) begin
                $display("test passed: send = %h, delay = %h", gen_data[1][4:0], dut_test_core.o_trx_a_delay_tabs);
            end else begin
                $display("test failed: send = %h, delay = %h", gen_data[1][4:0], dut_test_core.o_trx_a_delay_tabs);
            end

            byte_count = 0;

            $display("test write delay - transceiver b");
            // write delay value
            sim_pc_data_in = {SINGLE_WRITE | 3'b011}; // bank c address 2
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;
            #10
            // delay value is an 5 bit from 0 - 31 value => [cmd_byte, 8'bx, 3'bx, delay_value]
            while (byte_count < 2) begin
                gen_data[byte_count] = $random;
                sim_pc_data_in = gen_data [byte_count];
                wait (dut_uart_transceiver_pc.o_tx_rdy);
                @(posedge sim_clk_166) sim_pc_wr = 1'b1;
                @(posedge sim_clk_166) sim_pc_wr = 1'b0;
                #10
                byte_count = byte_count + 1;
            end

            // check the last 5 bits of delay value
            wait(dut_test_core.o_trx_b_delay_tabs != 5'b00000);
            if (gen_data[1][4:0] === dut_test_core.o_trx_b_delay_tabs) begin
                $display("test passed: send = %h, delay = %h", gen_data[1][4:0], dut_test_core.o_trx_b_delay_tabs);
            end else begin
                $display("test failed: send = %h, delay = %h", gen_data[1][4:0], dut_test_core.o_trx_b_delay_tabs);
            end

            byte_count = 0;


            // read delay / edge - tabs
            $display("read edge and delay tabs");
            sim_pc_data_in = {MULTI_READ | 3'b010}; // bank s address 2
            wait (dut_uart_transceiver_pc.o_tx_rdy);
            @(posedge sim_clk_166) sim_pc_wr = 1'b1;
            @(posedge sim_clk_166) sim_pc_wr = 1'b0;


            while (byte_count < 8) begin
                wait (dut_uart_transceiver_pc.o_rx_valid);
                gen_data[byte_count] = dut_uart_transceiver_pc.o_data;
                @(posedge sim_clk_166) sim_pc_rd = 1'b1;
                @(posedge sim_clk_166) sim_pc_rd = 1'b0;
                #5000
                byte_count = byte_count + 1;
            end

            if (gen_data[1][4:0] === 5'd10) begin
                $display("test passed: transceiver a - edge tabs = %d", gen_data[1][4:0]);
            end else begin
                $display("test failed: transceiver a - edge tabs = %d", gen_data[1][4:0]);
            end

            if (gen_data[3][4:0] === 5'd13) begin
                $display("test passed: transceiver a - delay tabs = %d", gen_data[3][4:0]);
            end else begin
                $display("test failed: transceiver a - delay tabs = %d", gen_data[3][4:0]);
            end

            if (gen_data[5][4:0] === 5'd11) begin
                $display("test passed: transceiver b - edge tabs = %d", gen_data[5][4:0]);
            end else begin
                $display("test failed: transceiver b - edge tabs = %d", gen_data[5][4:0]);
            end

            if (gen_data[7][4:0] === 5'd14) begin
                $display("test passed: transceiver b - delay tabs = %d", gen_data[7][4:0]);
            end else begin
                $display("test failed: transceiver b - delay tabs = %d", gen_data[7][4:0]);
            end


            byte_count = 0;


       
    $finish;
            
    end


//////////////////////////////////////////////////////////////////////////////////////////
// PC - PYTHON
uart_transceiver #(
    .F_CLK          (166_666_666), 
    .BAUDRATE       (115200), 
    .DATA_WIDTH     (8), 
    .STOP_BITS      (`STOP_BITS_ONE), 
    .PARITY         (`PARITY_EVEN),
    .FIFO_TX_ADDR_WIDTH (8),
    .FIFO_RX_ADDR_WIDTH (8)
) dut_uart_transceiver_pc (
    .i_clk          (sim_clk_166),
    .i_arst_n       (sim_arst_n),
    .i_rx           (dut_test_core.o_pc_tx),
    .o_tx           (),
    .i_rd           (sim_pc_rd),
    .i_wr           (sim_pc_wr),
    .i_data         (sim_pc_data_in),
    .o_data         (),
    .o_rx_valid     (),
    .o_tx_rdy       (),
    .o_err_state    (),
    .o_err          ()
);



/////////////////////////////////////////////////////////////////////////////////////////////
// FPGA 

synchronizer #(
    .STAGES  (2),
    .INIT    (1'b1)
) dut_sync_uart_rx (
    .i_clk   (sim_clk_166),
    .i_async (dut_uart_transceiver_pc.o_tx),
    .o_sync  () 
);

simple_filter #(
    .FILTER_WIDTH (6),
    .INIT_VAL     (1'b1)
) dut_filter_uart_rx (
    .i_clk      (sim_clk_166), 
    .i_arst_n   (sim_arst_n),
    .i_raw      (dut_sync_uart_rx.o_sync),
    .o_filter   ()
);

test_core_top #(
    .CLK_FREQUENCY           (166_666_666),
    .UART_BAUDRATE           (115200),
    .UART_STOP_BITS          (`STOP_BITS_ONE),
    .UART_PARITY             (`PARITY_EVEN),
    .UART_FIFO_TX_ADDR_WIDTH (6),
    .UART_FIFO_RX_ADDR_WIDTH (6)
) dut_test_core (
    // UART INTERFACE
    .i_clk                   (sim_clk_166),
    .i_arst_n                (sim_arst_n),
    .i_pc_rx                 (dut_filter_uart_rx.o_filter),
    .o_pc_tx                 (),
    .o_pc_err                (),
    // TRANSCEIVER A
    //
    // LOOP - PATTERN
    .i_trx_a_data_rdy        (~dut_sim_tx_56.o_full),
    .i_trx_a_data_valid      (~dut_sim_rx_34.o_empty),
    .i_trx_a_data_o          (dut_sim_rx_34.o_data), 
    .o_trx_a_data_i          (),
    .o_trx_a_data_wr         (),
    .o_trx_a_data_rd         (),
    // CONTROL & MONITOR 
    .i_trx_a_edge_tabs       (5'd10),
    .i_trx_a_delay_tabs      (5'd13),
    .o_trx_a_wr_delay_tabs   (),
    .o_trx_a_delay_tabs      (),
    // TRANSCEIVER B
    //
    // LOOP - PATTERN
    .i_trx_b_data_rdy       (~dut_sim_rx_34.o_full),
    .i_trx_b_data_valid     (~dut_sim_tx_56.o_empty),
    .i_trx_b_data_o         (dut_sim_tx_56.o_data),
    .o_trx_b_data_i         (),
    .o_trx_b_data_wr        (),
    .o_trx_b_data_rd        (),
    // CONTROL & MONITOR 
    .i_trx_b_edge_tabs       (5'd11),
    .i_trx_b_delay_tabs      (5'd14),
    .o_trx_b_wr_delay_tabs   (),
    .o_trx_b_delay_tabs      ()
);


// ***********************************************************************************************
// substitute transceiver interface by two synchronous fifo

    sync_fifo #(
        .DATA_WIDTH (34),
        .ADDR_WIDTH (3)
    ) dut_sim_rx_34 (
        .i_clk      (sim_clk_166),
        .i_arst_n   (sim_arst_n),
        .i_wr       (dut_test_core.o_trx_b_data_wr),
        .i_rd       (dut_test_core.o_trx_a_data_rd),
        .i_data     (dut_test_core.o_trx_b_data_i),
        .o_data     (),
        .o_full     (),
        .o_empty    ()
    );

    sync_fifo #(
        .DATA_WIDTH (56),
        .ADDR_WIDTH (3)
    ) dut_sim_tx_56 (
        .i_clk      (sim_clk_166),
        .i_arst_n   (sim_arst_n),
        .i_wr       (dut_test_core.o_trx_a_data_wr),
        .i_rd       (dut_test_core.o_trx_b_data_rd),
        .i_data     (dut_test_core.o_trx_a_data_i),
        .o_data     (),
        .o_full     (),
        .o_empty    ()
    );


endmodule

