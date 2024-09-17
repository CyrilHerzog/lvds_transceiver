
`timescale 1ns/1ns

module cdc_tb;

    reg sim_rd_clk, sim_wr_clk;
    reg sim_rd_arst_n, sim_wr_arst_n;
    reg sim_rd, sim_wr;
    reg [8:0] sim_data_in;


    integer read_count, write_count;

    initial begin
        $dumpfile("sim/icarus/cdc.vcd");
        $dumpvars(0, cdc_tb);
    end


    

    initial begin
        sim_rd_clk = 1'b1;
            forever
                #4167 sim_rd_clk = ~sim_rd_clk;
        end

    initial begin
        sim_wr_clk = 1'b1;
            forever
                #4100 sim_wr_clk = ~sim_wr_clk;
        end



    initial begin
        #0 sim_wr_arst_n = 1'b1;
           sim_rd_arst_n = 1'b1;
           sim_rd        = 1'b0;
           sim_wr        = 1'b0;
           sim_data_in   = {1'b1, 8'h7c};

        #100000 sim_wr_arst_n = 1'b0;
               sim_rd_arst_n = 1'b0;

        #100000 sim_wr_arst_n = 1'b1;
               sim_rd_arst_n = 1'b1;

        #10000000 $finish;
    end


    initial begin : write_process
        #2000000
        write_count = 0;
        forever begin
            #10
            @(posedge sim_wr_clk);
            sim_data_in = $random;
            write_count = write_count + 1;
            $display("write data: = %h", sim_data_in);
            if (write_count >= 40) // Limit to 100 writes
                disable write_process;
        end
    end

    initial begin : read_process
        read_count = 0;
        forever begin
            #10
            @(posedge sim_rd_clk);
            $display("read data: = %h", dut_elastic_buffer.o_data);
            read_count = read_count + 1;
            if (read_count >= 40) // Limit to 100 reads
                disable read_process;
        end
    end



elastic_buffer #(
    .DATA_WIDTH     (9),
    .ADDR_WIDTH     (4)
) dut_elastic_buffer (
    .i_wr_clk       (sim_wr_clk), 
    .i_wr_arst_n    (sim_wr_arst_n),
    .i_rd_clk       (sim_rd_clk),
    .i_rd_arst_n    (sim_rd_arst_n),
    .i_data         (sim_data_in),
    .o_data         ()
);

endmodule