 /*
    Module  : CRC_TB
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 20.12.2023
    
*/



`timescale 1ns/1ns


module crc_tb;

    reg sim_clk;
    reg sim_arst_n;
    reg sim_init, sim_calc;
    reg [7:0] sim_data_in;


    integer k;
    reg [7:0] sim_frame [7:0]; 

    initial begin
        $dumpfile("sim/icarus/crc.vcd");
        $dumpvars(0, crc_tb);
    end


    

    initial begin
        sim_clk = 1'b1;
            forever
                #5 sim_clk = ~sim_clk;
        end

    initial 
    begin
    #0      sim_arst_n    = 1'b0;
            sim_data_in   = 8'b0;
            k             = 0;
            sim_init      = 1'b1;
            sim_calc      = 1'b0; 
    #100    sim_arst_n    = 1'b1;
    #20     sim_init      = 1'b0;
            @(posedge sim_clk) sim_calc = 1'b1;
            while (k < 7) begin
                sim_frame[k] = $random;
                @(posedge sim_clk) sim_data_in = sim_frame[k];
                k = k + 1;
            end
            @(posedge sim_clk) sim_calc = 1'b0;
            sim_frame[7] = dut_crc_8.o_crc;
    #200    k = 0;
            @(posedge sim_clk) sim_init = 1'b1;
            @(posedge sim_clk) sim_init = 1'b0; 
            while (k < 8) begin
                @(posedge sim_clk) sim_data_in = sim_frame[k]; sim_calc = 1'b1;
                k = k + 1;
            end
            @(posedge sim_clk) sim_calc = 1'b0;
            @(posedge sim_clk) // next cycle
            if (dut_crc_8.o_crc === 0)
                $display("Test passed: crc = %h", dut_crc_8.o_crc);
            else
                $display("Test failed: crc = %h", dut_crc_8.o_crc);


    #1000  $finish;
    end

    crc_8 #(
        .POLY     (8'b00000111),
        .INIT     (8'b00000000)
    ) dut_crc_8 (
        .i_clk    (sim_clk),
        .i_arst_n (sim_arst_n),
        .i_init   (sim_init),
        .i_calc   (sim_calc),
        .i_data   (sim_data_in),
        .o_crc    ()
    );


    endmodule

