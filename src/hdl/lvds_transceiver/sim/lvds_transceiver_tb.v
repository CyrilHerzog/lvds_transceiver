`timescale 1ps/1ps


`include "src/hdl/lvds_transceiver/receiver/physical/physical_iob_clk_div.v"

module lvds_transceiver_tb;

    
    reg sim_clk_120_arst_n; 
    reg sim_clk_200_arst_n;
    reg sim_clk_600_p;
    wire sim_clk_600_n;
    reg sim_sys_clk_120;
    reg sim_tlp_clk;
    reg sim_sys_arst_n;
    reg sim_cal_start;
    reg[4:0] sim_delay_tabs;
  
    reg sim_trx_a_tlp_wr, sim_trx_a_tlp_rd;
    reg sim_trx_b_tlp_wr, sim_trx_b_tlp_rd;
    reg[55:0] sim_trx_a_tlp_i;
    reg[33:0] sim_trx_b_tlp_i;

    reg sim_test;

    integer write_count_trx_a;
    integer read_count_trx_a;
    integer write_count_trx_b;
    integer read_count_trx_b;

    initial begin
        $dumpfile("sim/icarus/lvds_transceiver.vcd");
        $dumpvars(0, lvds_transceiver_tb);
    end


    



    initial begin
        sim_clk_600_p = 1'b0;
            forever
                #833 sim_clk_600_p = ~sim_clk_600_p;
    end

    assign sim_clk_600_n = ~sim_clk_600_p;


    initial begin
        sim_sys_clk_120 = 1'b0;
            forever
                #4166 sim_sys_clk_120 = ~sim_sys_clk_120;
    end

    initial begin
        sim_tlp_clk = 1'b0;
            forever
                #3000 sim_tlp_clk = ~sim_tlp_clk;
    end

 
    

    initial begin
    #0      sim_clk_120_arst_n = 1'b0;
            sim_clk_200_arst_n = 1'b0;
            sim_sys_arst_n     = 1'b0;  
            sim_cal_start      = 1'b0;   
            sim_delay_tabs     = 5'b00111;
            sim_trx_a_tlp_wr   = 1'b0;
            sim_trx_a_tlp_rd   = 1'b0;
            sim_trx_b_tlp_wr   = 1'b0;
            sim_trx_b_tlp_rd   = 1'b0;
            sim_trx_a_tlp_i    = 56'b0;
            sim_trx_b_tlp_i    = 34'b0;
            sim_test           = 1'b0;
    #10000  sim_clk_120_arst_n = 1'b1;
            sim_clk_200_arst_n = 1'b1;
            sim_sys_arst_n     = 1'b1;
    #10000  sim_clk_120_arst_n = 1'b0;
            sim_clk_200_arst_n = 1'b0;
            sim_sys_arst_n     = 1'b0;
    #100000 sim_clk_120_arst_n = 1'b1;
            sim_clk_200_arst_n = 1'b1;
            sim_sys_arst_n     = 1'b1;
            sim_cal_start      = 1'b1;

    wait (dut_transceiver_a.o_status_connect && dut_transceiver_b.o_status_connect);
    // start with control test - flags
    //
    #100000
    @(posedge sim_tlp_clk) sim_test = 1'b1;
    @(posedge sim_tlp_clk) sim_test = 1'b0;

    #200000000
    $display("o_trx_a_mon_edge_tabs: %d, o_trx_b_mon_edge_tabs: %d",
            dut_transceiver_a.o_mon_edge_tabs, dut_transceiver_b.o_mon_edge_tabs);

    $finish;
    end


    initial begin : write_process_trx_a
        #200000
        write_count_trx_a = 0;
        forever begin
            sim_trx_a_tlp_i = $random;
            wait(dut_transceiver_a.o_tlp_rdy);
            @(posedge sim_tlp_clk) sim_trx_a_tlp_wr = 1'b1;
            @(posedge sim_tlp_clk) sim_trx_a_tlp_wr = 1'b0;
            write_count_trx_a = write_count_trx_a + 1;
            #100
            $display("write data trx a: = %h", sim_trx_a_tlp_i);
            if (write_count_trx_a >= 20)
                disable write_process_trx_a;
        end
    end

    initial begin : write_process_trx_b
        #200000
        write_count_trx_b = 0;
        forever begin
            sim_trx_b_tlp_i = $random;
            wait(dut_transceiver_b.o_tlp_rdy);
            @(posedge sim_tlp_clk) sim_trx_b_tlp_wr = 1'b1;
            @(posedge sim_tlp_clk) sim_trx_b_tlp_wr = 1'b0;
            write_count_trx_b = write_count_trx_b + 1;
            #100
            $display("write data trx b: = %h", sim_trx_b_tlp_i);
            if (write_count_trx_b >= 20)
                disable write_process_trx_b;
        end
    end

    initial begin : read_process_trx_b
        read_count_trx_b = 0;
        forever begin
            wait(dut_transceiver_b.o_tlp_valid);
            $display("read data trx b: = %h", dut_transceiver_b.o_tlp);
            @(posedge sim_tlp_clk) sim_trx_b_tlp_rd = 1'b1;
            @(posedge sim_tlp_clk) sim_trx_b_tlp_rd = 1'b0;
            read_count_trx_b = read_count_trx_b + 1;
            #10000
            if (read_count_trx_b >= 20)
                disable read_process_trx_b;
        end
    end

    initial begin : read_process_trx_a
        read_count_trx_a = 0;
        forever begin
            wait(dut_transceiver_a.o_tlp_valid);
            $display("read data trx a: = %h", dut_transceiver_a.o_tlp);
            @(posedge sim_tlp_clk) sim_trx_a_tlp_rd = 1'b1;
            @(posedge sim_tlp_clk) sim_trx_a_tlp_rd = 1'b0;
            read_count_trx_a = read_count_trx_a + 1;
            #10000
            if (read_count_trx_a >= 20)
                disable read_process_trx_a;
        end
    end



    wire FMC_LA04_P, FMC_LA04_N;
    wire FMC_LA03_P, FMC_LA03_N;
    //
    wire FMC_LA00_CC_P, FMC_LA00_CC_N;
    wire FMC_LA02_P, FMC_LA02_N;
    //
    wire FMC_LA08_P, FMC_LA08_N;
    wire FMC_LA07_P, FMC_LA07_N;

    assign FMC_LA03_P = FMC_LA04_P;
    assign FMC_LA03_N = FMC_LA04_N;

    assign FMC_LA07_P = FMC_LA08_P;
    assign FMC_LA07_N = FMC_LA08_N;

    assign FMC_LA00_CC_P = FMC_LA02_P;
    assign FMC_LA00_CC_N = FMC_LA02_N;



    physical_iob_clk_div inst_clk_div (
        .i_clk_600_p    (sim_clk_600_p), 
        .i_clk_600_n    (sim_clk_600_n),
        .o_clk_120      (),
        .o_clk_200      (),
        .o_clk_600      ()
    );



    lvds_transceiver_top #(
        .SIMULATION_ENABLE      (1),
        .CTRL_MON_ENABLE        (1),
        .IDELAYE_REF_FREQ       (300),
        //
        .CONNECTION_TYPE        (0),
        .TLP_TX_WIDTH           (56),
        .TLP_RX_WIDTH           (34),
        .TLP_ID_WIDTH           (3),
        .TLP_BUFFER_TYPE        (1),
        .TLP_BUFFER_ADDR_WIDTH  (4),
        .CRC_POLY               (8'h07),             
        .CRC_INIT               (8'hff)
    ) dut_transceiver_a (
        .i_sys_clk_120          (sim_sys_clk_120), 
        .i_sys_arst_n           (sim_sys_arst_n),
        //
        // transaction - layer
        .i_tlp_wr_clk           (sim_tlp_clk),
        .i_tlp_rd_clk           (sim_tlp_clk),
        .i_tlp_wr               (sim_trx_a_tlp_wr),
        .i_tlp_rd               (sim_trx_a_tlp_rd),
        .i_tlp                  (sim_trx_a_tlp_i),
        .o_tlp                  (),
        .o_tlp_rdy              (),
        .o_tlp_valid            (),
        //
        // phys 
        .i_phys_clk_600_p       (inst_clk_div.o_clk_600),
        .i_phys_clk_600_n       (1'b0),
        .i_phys_clk_200         (inst_clk_div.o_clk_200),
        .i_phys_clk_120         (inst_clk_div.o_clk_120),
        .i_phys_rx_p            (FMC_LA07_P),
        .i_phys_rx_n            (FMC_LA07_N),
        .o_phys_clk_600_p       (FMC_LA02_P),
        .o_phys_clk_600_n       (FMC_LA02_N),
        .o_phys_tx_p            (FMC_LA04_P),
        .o_phys_tx_n            (FMC_LA04_N),
        //
        // STATUS
        .o_status_connect       (),
        //
        // CONTROL & MONITOR
        .i_ctrl_mon_clk         (sim_tlp_clk),
        .i_ctrl_mon_arst_n      (sim_sys_arst_n),
        // LINK
        .i_ctrl_pls_crc_dllp    (1'b0), 
        .i_ctrl_pls_crc_tlp     (1'b0), 
        .i_ctrl_pls_status_ack  (1'b0), // acknowledge status
        .o_mon_status_rply      (), // hold and reset by ack
        // PHYSICAL
        .i_ctrl_tab_delay_wr    (1'b0),
        .i_ctrl_tab_delay       (5'b00000),
        .o_mon_edge_tabs        (),
        .o_mon_delay_tabs       ()
    );


    lvds_transceiver_top #(
        .SIMULATION_ENABLE      (1),
        .CTRL_MON_ENABLE        (1),
        .IDELAYE_REF_FREQ       (300),
        //
        .CONNECTION_TYPE        (1),
        .TLP_TX_WIDTH           (34),
        .TLP_RX_WIDTH           (56),
        .TLP_ID_WIDTH           (3),
        .TLP_BUFFER_TYPE        (1),
        .TLP_BUFFER_ADDR_WIDTH  (4),
        .CRC_POLY               (8'h07),             
        .CRC_INIT               (8'hff)
    ) dut_transceiver_b (
        .i_sys_clk_120          (sim_sys_clk_120), 
        .i_sys_arst_n           (sim_sys_arst_n),
        //
        // transaction - layer
        .i_tlp_wr_clk           (sim_tlp_clk),
        .i_tlp_rd_clk           (sim_tlp_clk),
        .i_tlp_wr               (sim_trx_b_tlp_wr),
        .i_tlp_rd               (sim_trx_b_tlp_rd),
        .i_tlp                  (sim_trx_b_tlp_i),
        .o_tlp                  (),
        .o_tlp_rdy              (),
        .o_tlp_valid            (),
        //
        // phys 
        .i_phys_clk_600_p       (FMC_LA00_CC_P),
        .i_phys_clk_600_n       (FMC_LA00_CC_N),
        .i_phys_clk_200         (1'b0),
        .i_phys_clk_120         (1'b0),
        .i_phys_rx_p            (FMC_LA03_P),
        .i_phys_rx_n            (FMC_LA03_N),
        .o_phys_clk_600_p       (),
        .o_phys_clk_600_n       (),
        .o_phys_tx_p            (FMC_LA08_P),
        .o_phys_tx_n            (FMC_LA08_N),
        //
        // STATUS
        .o_status_connect       (),
        //
        // CONTROL & MONITOR
        .i_ctrl_mon_clk         (sim_tlp_clk),
        .i_ctrl_mon_arst_n      (sim_sys_arst_n),
        // LINK
        .i_ctrl_pls_crc_dllp    (1'b0), // sim_test
        .i_ctrl_pls_crc_tlp     (1'b0),
        .i_ctrl_pls_status_ack  (1'b0),
        .o_mon_status_rply      (),
        // PHYSICAL
        .i_ctrl_tab_delay_wr    (1'b0),
        .i_ctrl_tab_delay       (5'b00000),
        .o_mon_edge_tabs        (),
        .o_mon_delay_tabs       ()
    );


    endmodule