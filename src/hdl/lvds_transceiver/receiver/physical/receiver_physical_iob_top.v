

/*
    Module  : RECEIVER_PHYSICAL_IOB_TOP
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _RECEIVER_PHYSICAL_IOB_TOP_V_
`define _RECEIVER_PHYSICAL_IOB_TOP_V_

`include "src/hdl/lvds_transceiver/include/lvds_transceiver_defines.vh"

// source from xilinx xapp
`include "src/hdl/lvds_transceiver/receiver/physical/xapp/decoder_8b10b.v"


// 
`include "src/hdl/lvds_transceiver/receiver/physical/physical_iob_iserdes.v"
`include "src/hdl/lvds_transceiver/receiver/physical/physical_iob_gearbox_6_10.v"
`include "src/hdl/lvds_transceiver/receiver/physical/physical_iob_word_aligner.v"
`include "src/hdl/lvds_transceiver/receiver/physical/physical_iob_init_tab_cal.v"
`include "src/hdl/lvds_transceiver/receiver/physical/physical_iob_tab_monitor.v"

// cdc
`include "src/hdl/cdc/synchronizer.v"
`include "src/hdl/cdc/async_reset.v" 



module receiver_physical_iob_top #(
    parameter ENABLE_ISERDESE1  = 0,
    parameter ENABLE_TEST_DELAY = 0,
    parameter IDELAYE_REF_FREQ  = 200
) ( 
    input wire i_clk_120, i_clk_120_arst_n,
    // clk_120
    input wire i_cal_start,
    output wire o_cal_done,
    output wire o_cal_fail,
    output wire o_packet_k_en,
    output wire[7:0] o_packet_byte,
    //
    input wire i_clk_200, i_clk_200_arst_n,
    // clk_200
    input wire [4:0] i_ctrl_delay_tabs,
    output wire[4:0] o_mon_edge_tabs,
    output wire[4:0] o_mon_delay_tabs,
    output wire o_mon_delay_tabs_wr,
    //
    input wire i_clk_600,
    input wire i_rx_p,
    input wire i_rx_n
);
    //////////////////////////////////////////////////////////////////////////////////////////////////
    // RESET
    wire local_clk_120_rst;
    wire local_clk_200_rst;

    async_reset #(
        .STAGES     (2),
        .INIT       (1'b0),
        .RST_VAL    (1'b0)
    ) inst_phys_120_reset (
        .i_clk      (i_clk_120), 
        .i_rst_n    (i_clk_120_arst_n),
        .o_rst      (local_clk_120_rst)
    );

    async_reset #(
        .STAGES     (2),
        .INIT       (1'b0),
        .RST_VAL    (1'b0)
    ) inst_phys_200_reset (
        .i_clk      (i_clk_200), 
        .i_rst_n    (i_clk_200_arst_n),
        .o_rst      (local_clk_200_rst)
    );


    
    ////////////////////////////////////////////////////////////////////////////////
    // ISERDES - INPUT
    wire ibufds_rx_o_p;
    wire ibufds_rx_o_n;

    IBUFDS_DIFF_OUT #(
       .IOSTANDARD    ("LVDS_25"), 
	   .IBUF_LOW_PWR  ("FALSE"),
       .DIFF_TERM     ("TRUE")
	) inst_ibufds_rx (
	   .I    (i_rx_p),
	   .IB   (i_rx_n),
	   .O    (ibufds_rx_o_p),
	   .OB   (ibufds_rx_o_n)
    );

    wire[4:0] ri_master_delay, ri_monitor_delay;
    reg[4:0] r_master_delay, r_monitor_delay;

    // MASTER
    physical_iob_iserdes #(
        .ENABLE_ISERDESE1  (ENABLE_ISERDESE1),
        .ENABLE_TEST_DELAY (ENABLE_TEST_DELAY),
        .IDELAYE_REF_FREQ  (IDELAYE_REF_FREQ)
    ) inst_iserdes_master (
        // CLK 200
	    .i_clk_200         (i_clk_200),
        .i_clk_200_arst_n  (local_clk_200_rst),
        .i_delay_val       (r_master_delay),
        .i_test_delay_val  (i_ctrl_delay_tabs),
        .o_data            (),
        // CLK 600
        .i_clk_600         (i_clk_600),
	    .i_rx              (ibufds_rx_o_p)
    );

    // MONITOR
    physical_iob_iserdes #(
        .ENABLE_ISERDESE1  (ENABLE_ISERDESE1),
        .ENABLE_TEST_DELAY (ENABLE_TEST_DELAY),
        .IDELAYE_REF_FREQ  (IDELAYE_REF_FREQ)
    ) inst_iserdes_monitor (
        // CLK 200
	    .i_clk_200         (i_clk_200),
        .i_clk_200_arst_n  (local_clk_200_rst),
        .i_delay_val       (r_monitor_delay),
        .i_test_delay_val  (i_ctrl_delay_tabs),
        .o_data            (),
        // CLK 600
        .i_clk_600         (i_clk_600),
	    .i_rx              (ibufds_rx_o_n)
    );

   
    /////////////////////////////////////////////////////////////////////////////
    // DELAY - CONTROLLER

    // INITIAL - CAL
    physical_iob_init_tab_cal #(
        .SERDES_WIDTH   (6),
        .FILTER_WIDTH   (8),
        .STARTUP_WIDTH  (4)
    ) inst_tab_cal (
        .i_clk          (i_clk_200), 
        .i_arst_n       (local_clk_200_rst),
        .i_start        (i_cal_start), 
        .i_serdes       (inst_iserdes_master.o_data),
        .o_delay_tabs   (),
        .o_edge_tabs    (),
        .o_run          (),
        .o_fail         (),
        .o_done         ()
    );


    // WINDOW - MONITORING
    physical_iob_tab_monitor #(
        .SERDES_WIDTH         (6),
        .WAIT_COMP_WIDTH      (4)
    ) inst_tab_monitor (
        .i_clk                (i_clk_200),
        .i_arst_n             (local_clk_200_rst),
        .i_enable             (inst_tab_cal.o_done),
        .i_serdes_master      (inst_iserdes_master.o_data),
        .i_serdes_monitor     (inst_iserdes_monitor.o_data),
        .i_init_delay_tabs    (inst_tab_cal.o_delay_tabs),
        .i_init_edge_tabs     (inst_tab_cal.o_edge_tabs),
        .o_master_delay_tabs  (),
        .o_monitor_delay_tabs (),
        .o_delay_tabs_update  (),
        .o_run                (),
        .o_fail               ()
    );


    // MUX
    assign ri_master_delay  = (inst_tab_monitor.o_run) ? inst_tab_monitor.o_master_delay_tabs : inst_tab_cal.o_delay_tabs;
    //assign ri_master_delay  = inst_tab_cal.o_delay_tabs;   // deactivate monitoring adjust tab delay
    assign ri_monitor_delay = inst_tab_monitor.o_monitor_delay_tabs;
    always@(posedge i_clk_200, negedge local_clk_200_rst)
        if (~local_clk_200_rst) begin
            r_master_delay  <= 5'b00000;
            r_monitor_delay <= 5'b00000;
        end else begin
            r_master_delay  <= ri_master_delay;
            r_monitor_delay <= ri_monitor_delay;
        end

    //////////////////////////////////////////////////////////////////////////
    // GEARBOX (6 BIT TO 10 BIT)

    physical_iob_gearbox_6_10 inst_gearbox (
        .i_wr_clk       (i_clk_200), 
        .i_wr_arst_n    (i_clk_200_arst_n),
        .i_rd_clk       (i_clk_120),
        .i_rd_arst_n    (i_clk_120_arst_n),
        .i_slipbits     (inst_word_aligner.o_slipbits),
        .i_wr_data      (inst_iserdes_master.o_data),
        .o_rd_data      ()
    );

    /////////////////////////////////////////////////////////////////////////
    // WORD - ALIGNING (BITSLIP - OPERATION)

    // SYNCHRONIZER TAB-CAL - DONE - PHYS_CLK_200 <=> PHYS_CLK_120
    synchronizer #(
        .STAGES   (2),
        .INIT     (1'b0)
    ) inst_sync_aligning_start (
        .i_clk    (i_clk_120),
        .i_arst_n (local_clk_120_rst),
        .i_async  (inst_tab_cal.o_done), 
        .o_sync   () 
    );

    physical_iob_word_aligner inst_word_aligner (
        .i_clk          (i_clk_120),
        .i_arst_n       (local_clk_120_rst),
        .i_start        (inst_sync_aligning_start.o_sync), 
        .i_data         (inst_gearbox.o_rd_data),
        .o_slipbits     (),
        .o_run          (),
        .o_fail         (),
        .o_done         ()
    );


    /////////////////////////////////////////////////////////////////////////
    // DECODER 8B10B
    decoder_8b10b #(
        .C_HAS_CODE_ERR   (0),
        .C_HAS_DISP_ERR   (0),
        .C_HAS_DISP_IN    (0),
        .C_HAS_ND         (0),
        .C_HAS_SYM_DISP   (0),
        .C_HAS_RUN_DISP   (0),
        .C_SINIT_DOUT     (0),
        .C_SINIT_KOUT     (0),
        .C_SINIT_RUN_DISP (0)
    ) inst_8b10b_dec (
        .clk              (i_clk_120),
        .din              (inst_gearbox.o_rd_data),
        .dout             (o_packet_byte),
        .kout             (o_packet_k_en),
        .ce               (1'b1),
        .disp_in          (1'b0),
        .sinit            (1'b0),
        .code_err         (),
        .disp_err         (),
        .nd               (),
        .run_disp         (),
        .sym_disp         ()
    );


    /////////////////////////////////////////////////////////////////////////
    // STATUS & MONITOR

    // CAL DONE
    assign o_cal_done = inst_word_aligner.o_done; // init-tab-cal & word-aligning done

    // SYNCHRONIZER TAB-CAL - FAIL - PHYS_CLK_200 <=> PHYS_CLK_120
    synchronizer #(
        .STAGES   (2),
        .INIT     (1'b0)
    ) inst_sync_tab_cal_fail (
        .i_clk    (i_clk_120),
        .i_arst_n (local_clk_120_rst),
        .i_async  (inst_tab_cal.o_fail), 
        .o_sync   () 
    );

    // CAL FAIL
    assign o_cal_fail = (inst_sync_tab_cal_fail.o_sync || inst_word_aligner.o_fail); // sum-error

    // MONITORING TABS
    assign o_mon_edge_tabs     = inst_tab_cal.o_edge_tabs;
    assign o_mon_delay_tabs    = inst_tab_monitor.o_master_delay_tabs;
    assign o_mon_delay_tabs_wr = inst_tab_monitor.o_delay_tabs_update;

endmodule

`endif /* RECEIVER_PHYSICAL_IOB_TOP */