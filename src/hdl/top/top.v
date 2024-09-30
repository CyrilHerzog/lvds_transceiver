
/*
    Module  : TOP
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`include "src/hdl/uart/include/uart_defines.vh"
//
`include "src/hdl/top/clock_source/clock_source_pll.v"
`include "src/hdl/top/clock_source/clock_source_mmcm.v"
//
`include "src/hdl/cdc/synchronizer.v"
`include "src/hdl/cdc/async_reset.v"

//
`include "src/hdl/test_core/test_core_top.v"
`include "src/hdl/divers/simple_filter.v"
`include "src/hdl/divers/sync_fifo.v" // only for substitute transceiver's


`include "src/hdl/lvds_transceiver/lvds_transceiver_top.v"





module top(
    // ONBOARD CLOCK
    input wire GCLK,
    // TEST - CORE
    input wire JA3,  // UART RX
    output wire JA2, // UART TX
    // FMC CLOCK
    input wire FMC_CLK0_N, FMC_CLK0_P,
    output wire FMC_CLK1_N, FMC_CLK1_P,
    // TRANSCEIVER A (SOURCE)
    input wire FMC_LA07_P, FMC_LA07_N,  // RX
    output wire FMC_LA04_P, FMC_LA04_N, // TX
    output wire FMC_LA02_N, FMC_LA02_P, // CLOCK
    // TRANSCEIVER B (SINK)
    input wire FMC_LA00_CC_N, FMC_LA00_CC_P, // CLOCK
    input wire FMC_LA03_P, FMC_LA03_N,       // RX
    output wire FMC_LA08_P, FMC_LA08_N,      // TX
    // STATUS LED
    output wire LD0, LD1, LD2, LD3, LD4, LD5, LD6, LD7
 
);

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    // PLL - CLOCK SOURCE

    clock_source_pll inst_pll 
    ( 
        // ONBOARD CLOCK
        .i_gclk             (GCLK),
        // PS (TESTCORE) CLOCK  
        .o_bufg_clk_166     (),
        // TRX FMC CLOCK
        .o_fmc_clk_50_p     (FMC_CLK1_P),
        .o_fmc_clk_50_n     (FMC_CLK1_N),
        //
        .o_locked           ()
    );


    //////////////////////////////////////////////////////////////////////////////////////////////////////
    // MMCM - CLOCK SOURCE (ONLY MMCM CAN DRIVE BUFIO)

    clock_source_mmcm inst_mmcm (
        .i_fmc_clk_50_p     (FMC_CLK0_P),
        .i_fmc_clk_50_n     (FMC_CLK0_N),
        // TRX PHYSICAL LAYER CLOCK
        .o_bufio_clk_600    (),
        .o_bufr_clk_200     (),
        .o_bufr_clk_120     (),
        // TRX LINK LAYER CLOCK
        .o_bufg_clk_120     (),
        // IDLEAYE CNTRL CLOCK
        .o_bufg_clk_200     (),
        .o_bufg_clk_300     (),
        .o_locked           ()
    );


    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    // LOCAL RESET

    async_reset #(
        .STAGES  (6),
        .INIT    (1'b0),
        .RST_VAL (1'b0)
    ) inst_rst_test_core (
        .i_clk   (inst_pll.o_bufg_clk_166),
        .i_rst_n (inst_pll.o_locked),
        .o_rst   ()
    );

    async_reset #(
        .STAGES  (4),
        .INIT    (1'b0),
        .RST_VAL (1'b0)
    ) inst_rst_trx (
        .i_clk   (inst_mmcm.o_bufr_clk_120),
        .i_rst_n (inst_mmcm.o_locked),
        .o_rst   ()
    );





    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    // TEST - CORE

    synchronizer #(
        .STAGES   (2),
        .INIT     (1'b1)
    ) inst_sync_uart_rx (
        .i_clk    (inst_pll.o_bufg_clk_166),
        .i_arst_n (1'b1),
        .i_async  (JA3),
        .o_sync   () 
    );

    simple_filter #(
        .FILTER_WIDTH (6),
        .INIT_VAL     (1'b1)
    ) inst_filter_uart_rx (
        .i_clk      (inst_pll.o_bufg_clk_166), 
        .i_arst_n   (1'b1),
        .i_raw      (inst_sync_uart_rx.o_sync),
        .o_filter   ()
    );

  
    test_core_top #(
        .CLK_FREQUENCY              (166_666_666),
        .UART_BAUDRATE              (115200),
        .UART_STOP_BITS             (`STOP_BITS_ONE),
        .UART_PARITY                (`PARITY_EVEN),
        .UART_FIFO_TX_ADDR_WIDTH    (6),
        .UART_FIFO_RX_ADDR_WIDTH    (6)
    ) inst_test_core (
        // UART INTERFACE
        .i_clk                      (inst_pll.o_bufg_clk_166),
        .i_arst_n                   (inst_rst_test_core.o_rst),
        .i_pc_rx                    (inst_filter_uart_rx.o_filter),
        .o_pc_tx                    (JA2),
        .o_pc_err                   (),
        // TRANSCEIVER A
        //
        // LOOP - PATTERN
        .i_trx_a_data_rdy           (inst_transceiver_a.o_tlp_rdy), //~inst_sim_tx_56.o_full
        .i_trx_a_data_valid         (inst_transceiver_a.o_tlp_valid), //~inst_sim_rx_34.o_empty
        .i_trx_a_data_o             (inst_transceiver_a.o_tlp),  //inst_sim_rx_34.o_data
        .o_trx_a_data_i             (),
        .o_trx_a_data_wr            (),
        .o_trx_a_data_rd            (),
        // CONTROL & MONITOR  
        .i_trx_a_edge_tabs          (inst_transceiver_a.o_mon_edge_tabs),
        .i_trx_a_delay_tabs         (inst_transceiver_a.o_mon_delay_tabs),
        .o_trx_a_wr_delay_tabs      (),
        .o_trx_a_delay_tabs         (),
        // 
        .o_trx_a_test_flags         (), // 8 bit => BIT0 = ACK_STATUS, BIT1 = TLP_CRC_TEST, BIT2 = DLLP_CRC_TEST
        // TRANSCEIVER B
        //
        // LOOP - PATTERN
        .i_trx_b_data_rdy           (inst_transceiver_b.o_tlp_rdy), //~inst_sim_rx_34.o_full
        .i_trx_b_data_valid         (inst_transceiver_b.o_tlp_valid), //~inst_sim_tx_56.o_empty
        .i_trx_b_data_o             (inst_transceiver_b.o_tlp), //inst_sim_tx_56.o_data
        .o_trx_b_data_i             (),
        .o_trx_b_data_wr            (),
        .o_trx_b_data_rd            (),
        // CONTROL & MONITOR  
        .i_trx_b_edge_tabs          (inst_transceiver_b.o_mon_edge_tabs),
        .i_trx_b_delay_tabs         (inst_transceiver_b.o_mon_delay_tabs),
        .o_trx_b_wr_delay_tabs      (),
        .o_trx_b_delay_tabs         (),
        //
        .o_trx_b_test_flags         (), // 8 bit => BIT0 = ACK_STATUS, BIT1 = TLP_CRC_TEST, BIT2 = DLLP_CRC_TEST
        //
        .i_status_monitor           ({7'b0, inst_transceiver_b.o_mon_status_rply, 7'b0, inst_transceiver_a.o_mon_status_rply})
    );

    /*
    // SUBSTITUTE TRANSCEIVER
    sync_fifo #(
        .DATA_WIDTH (34),
        .ADDR_WIDTH (3)
    ) inst_sim_rx_34 (
        .i_clk      (inst_pll.o_bufg_clk_166),
        .i_arst_n   (1'b1),
        .i_wr       (inst_test_core.o_trx_b_data_wr),
        .i_rd       (inst_test_core.o_trx_a_data_rd),
        .i_data     (inst_test_core.o_trx_b_data_i),
        .o_data     (),
        .o_full     (),
        .o_empty    ()
    );

    sync_fifo #(
        .DATA_WIDTH (56),
        .ADDR_WIDTH (3)
    ) inst_sim_tx_56 (
        .i_clk      (inst_pll.o_bufg_clk_166),
        .i_arst_n   (1'b1),
        .i_wr       (inst_test_core.o_trx_a_data_wr),
        .i_rd       (inst_test_core.o_trx_b_data_rd),
        .i_data     (inst_test_core.o_trx_a_data_i),
        .o_data     (),
        .o_full     (),
        .o_empty    ()
    );
    */


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////


    // DELAY - CONTROL
    IDELAYCTRL inst_delay_control (      
	    .REFCLK	    (inst_mmcm.o_bufg_clk_300), // 300 MHz = 52ps / 200 MHz = 78ps
	    .RST		(1'b0),
	    .RDY		()
    );



    // TRANSCEIVER A (SOURCE)
    lvds_transceiver_top #(
        .SIMULATION_ENABLE      (0),
        .CTRL_MON_ENABLE        (1),
        .IDELAYE_REF_FREQ       (300),
        //
        .CONNECTION_TYPE        (0),    // SOURCE
        .TLP_TX_WIDTH           (56),
        .TLP_RX_WIDTH           (34),
        .TLP_ID_WIDTH           (3),
        .TLP_BUFFER_TYPE        (1),    // ASYNCHRONOUS FIFO
        .TLP_BUFFER_ADDR_WIDTH  (4),
        .CRC_POLY               (8'h07),             
        .CRC_INIT               (8'hff)
    ) inst_transceiver_a (
        .i_sys_clk_120          (inst_mmcm.o_bufg_clk_120), 
        .i_sys_arst_n           (inst_rst_trx.o_rst),
        //
        // TLP
        .i_tlp_wr_clk           (inst_pll.o_bufg_clk_166),
        .i_tlp_rd_clk           (inst_pll.o_bufg_clk_166),
        .i_tlp_wr               (inst_test_core.o_trx_a_data_wr),
        .i_tlp_rd               (inst_test_core.o_trx_a_data_rd),
        .i_tlp                  (inst_test_core.o_trx_a_data_i),
        .o_tlp                  (),
        .o_tlp_rdy              (),
        .o_tlp_valid            (),
        //
        //
        // PHYSICAL  
        .i_phys_clk_600_p       (inst_mmcm.o_bufio_clk_600),
        .i_phys_clk_600_n       (1'b0),
        .i_phys_clk_200         (inst_mmcm.o_bufr_clk_200),
        .i_phys_clk_120         (inst_mmcm.o_bufr_clk_120),
        .i_phys_rx_p            (FMC_LA07_P), 
        .i_phys_rx_n            (FMC_LA07_N),
        .o_phys_clk_600_p       (FMC_LA02_P),
        .o_phys_clk_600_n       (FMC_LA02_N),
        .o_phys_tx_p            (FMC_LA04_P),
        .o_phys_tx_n            (FMC_LA04_N),
        ///////////////////////////////////////////////////////////////
        // CONTROL & MONITOR
        .i_ctrl_mon_clk         (inst_pll.o_bufg_clk_166),
        .i_ctrl_mon_arst_n      (inst_rst_test_core.o_rst),
        // LINK 
        .i_ctrl_pls_crc_dllp    (inst_test_core.o_trx_a_test_flags[2]),
        .i_ctrl_pls_crc_tlp     (inst_test_core.o_trx_a_test_flags[1]),
        .i_ctrl_pls_status_ack  (inst_test_core.o_trx_a_test_flags[0]),
        .o_mon_status_rply      (),
        // PHYSICAL
        .i_ctrl_tab_delay_wr    (1'b0),
        .i_ctrl_tab_delay       (5'b00000),
        .o_mon_edge_tabs        (),
        .o_mon_delay_tabs       ()
    );

    // TRANSCEIVER B (SINK)
    lvds_transceiver_top #(
        .SIMULATION_ENABLE      (0),
        .CTRL_MON_ENABLE        (1),
        .IDELAYE_REF_FREQ       (300),
        //
        .CONNECTION_TYPE        (1),    // SINK
        .TLP_TX_WIDTH           (34),
        .TLP_RX_WIDTH           (56),
        .TLP_ID_WIDTH           (3),
        .TLP_BUFFER_TYPE        (1),    // ASYNCHRONOUS FIFO
        .TLP_BUFFER_ADDR_WIDTH  (4),
        .CRC_POLY               (8'h07),             
        .CRC_INIT               (8'hff)
    ) inst_transceiver_b (
        .i_sys_clk_120          (inst_mmcm.o_bufg_clk_120), 
        .i_sys_arst_n           (inst_rst_trx.o_rst),
        //
        // TLP
        .i_tlp_wr_clk           (inst_pll.o_bufg_clk_166),
        .i_tlp_rd_clk           (inst_pll.o_bufg_clk_166),
        .i_tlp_wr               (inst_test_core.o_trx_b_data_wr),
        .i_tlp_rd               (inst_test_core.o_trx_b_data_rd),
        .i_tlp                  (inst_test_core.o_trx_b_data_i),
        .o_tlp                  (),
        .o_tlp_rdy              (),
        .o_tlp_valid            (),
        //
        // PHYSICAL 
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
        ////////////////////////////////////////////////////////////////
        // CONTROL & MONITOR
        .i_ctrl_mon_clk         (inst_pll.o_bufg_clk_166),
        .i_ctrl_mon_arst_n      (inst_rst_test_core.o_rst),
        // LINK
        .i_ctrl_pls_crc_dllp    (inst_test_core.o_trx_b_test_flags[2]),
        .i_ctrl_pls_crc_tlp     (inst_test_core.o_trx_b_test_flags[1]),
        .i_ctrl_pls_status_ack  (inst_test_core.o_trx_b_test_flags[0]),
        .o_mon_status_rply      (),
        // PHYSICAL
        .i_ctrl_tab_delay_wr    (1'b0),
        .i_ctrl_tab_delay       (5'b00000),
        .o_mon_edge_tabs        (),
        .o_mon_delay_tabs       ()
    );


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // STATUS - LED

    assign LD0 = 1'b0;
    assign LD1 = 1'b0;
    assign LD2 = 1'b0;
    assign LD3 = 1'b0;
    assign LD4 = 1'b0;
    assign LD5 = 1'b0;
    assign LD6 = 1'b0;
    assign LD7 = 1'b0;


endmodule
    