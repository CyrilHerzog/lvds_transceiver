

/*
    Module  : PHYSICAL_IOB_WORD_ALIGNER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _PHYSICAL_IOB_TAB_MONITOR_V_
`define _PHYSICAL_IOB_TAB_MONITOR_V_

`include "src/hdl/cdc/async_reset.v"

module physical_iob_tab_monitor #(
    parameter SERDES_WIDTH    = 4,
    parameter WAIT_COMP_WIDTH = 4  // wait counter before compare iserdes with monitor iserdes 
)(
    input wire i_clk, 
    input wire i_arst_n,
    input wire i_enable,
    input wire [SERDES_WIDTH-1:0] i_serdes_master,
    input wire [SERDES_WIDTH-1:0] i_serdes_monitor,
    input wire [4:0] i_init_delay_tabs,
    input wire [4:0] i_init_edge_tabs,
    output wire [4:0] o_master_delay_tabs,
    output wire [4:0] o_monitor_delay_tabs,
    output wire o_delay_tabs_update,
    output wire o_run,
    output wire o_fail
);

    ///////////////////////////////////////////////////////////////////////////////////////////////
    // LOCAL RESET
    wire local_arst_n;

    async_reset #(
        .STAGES   (2),
        .INIT     (1'b0),
        .RST_VAL  (1'b0)
    ) inst_async_reset (
        .i_clk    (i_clk), 
        .i_rst_n  (i_arst_n),
        .o_rst    (local_arst_n)
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // INPUT

    reg r_enable_monitor;
    wire enable_monitor;
    reg[SERDES_WIDTH-1:0] r_serdes_master_i;
    reg[SERDES_WIDTH-1:0] r_serdes_monitor_i;

    always@ (posedge i_clk, negedge local_arst_n)
        if (~local_arst_n) begin
            r_enable_monitor   <= 1'b0;
            r_serdes_master_i  <= {SERDES_WIDTH{1'b0}};
            r_serdes_monitor_i <= {SERDES_WIDTH{1'b0}};
        end else begin
            r_enable_monitor   <= i_enable;
            r_serdes_master_i  <= i_serdes_master;
            r_serdes_monitor_i <= ~i_serdes_monitor; // negative
        end
    
    assign enable_monitor = r_enable_monitor;

    ////////////////////////////////////////////////////////////////////////////////////////////////
    // MONITOR - FSM

    localparam [9:0]  S_IDLE        = 10'b0000000001, // 0
                      S_INIT        = 10'b0000000010, // 1
                      S_WAIT_1      = 10'b0000000100, // 2
                      S_COMPARE_1   = 10'b0000001000, // 3
                      S_FLAG_LEFT   = 10'b0000010000, // 4
                      S_INC_WINDOW  = 10'b0000100000, // 5
                      S_WAIT_2      = 10'b0001000000, // 6
                      S_COMPARE_2   = 10'b0010000000, // 7
                      S_FLAG_RIGHT  = 10'b0100000000, // 8
                      S_DEC_WINDOW  = 10'b1000000000; // 9
                

    (* fsm_encoding = "user_encoding" *)
    reg[9:0] r_state = S_IDLE;
    reg[9:0] ri_state;


    reg[4:0] r_master_delay_tabs, ri_master_delay_tabs;
    reg[4:0] r_monitor_delay_tabs, ri_monitor_delay_tabs;
    reg[4:0] r_edge_window_tabs, ri_edge_window_tabs;

    reg[WAIT_COMP_WIDTH-1:0] r_wait_time, ri_wait_time;

    // compare master with monitor serdes
    wire serdes_comp;
    assign serdes_comp = (r_serdes_master_i == r_serdes_monitor_i);

    reg r_monitoring_run;
    wire ri_monitoring_run;

    reg r_delay_tabs_update;
    wire ri_delay_tabs_update;


    always@(posedge i_clk, negedge local_arst_n)
        if (~local_arst_n) begin
            r_state              <= S_IDLE;
            r_master_delay_tabs  <= 5'b00000;
            r_monitor_delay_tabs <= 5'b00000;
            r_edge_window_tabs   <= 5'b00000;
            //
            r_monitoring_run     <= 1'b0;
            r_delay_tabs_update  <= 1'b0;
            //
            r_wait_time          <= 0;
        end else begin
            r_state              <= ri_state;
            r_master_delay_tabs  <= ri_master_delay_tabs;
            r_monitor_delay_tabs <= ri_monitor_delay_tabs;
            r_edge_window_tabs   <= ri_edge_window_tabs;
            //
            r_monitoring_run     <= ri_monitoring_run;
            r_delay_tabs_update  <= ri_delay_tabs_update;
            //
            r_wait_time          <= ri_wait_time;
        end

    // module running
    assign ri_monitoring_run = (r_state[1] || r_monitoring_run) && ~r_state[0]; // SR
    assign o_run = r_monitoring_run;

    // debug monitoring
    assign ri_delay_tabs_update = (r_state[1] || r_state[4] || r_state[8]); 
    assign o_delay_tabs_update  = r_delay_tabs_update;


     always@* begin

        ri_state = r_state;
        //
        ri_master_delay_tabs  = r_master_delay_tabs;
        ri_monitor_delay_tabs = r_monitor_delay_tabs;
        ri_edge_window_tabs   = r_edge_window_tabs;
        //
        ri_wait_time = r_wait_time;
 
        case(r_state)

            S_IDLE: begin
                ri_master_delay_tabs  = i_init_delay_tabs;
                ri_monitor_delay_tabs = i_init_delay_tabs;
                ri_edge_window_tabs   = i_init_edge_tabs;  // alternate define a parameter to define a valid window

                if (enable_monitor)
                    ri_state = S_INIT;
            end

            S_INIT: begin
                ri_monitor_delay_tabs = r_monitor_delay_tabs - {1'b0, r_edge_window_tabs[4:1]}; // init at left edge
                ri_state              = S_WAIT_1;
            end

            S_WAIT_1: begin
                ri_wait_time = r_wait_time + 1;
                if (&r_wait_time)
                    ri_state = S_COMPARE_1;
            end

            S_COMPARE_1: begin
                if (serdes_comp)
                    ri_state = S_INC_WINDOW;
                else
                    ri_state = S_FLAG_LEFT;
            end

            S_FLAG_LEFT: begin
                ri_master_delay_tabs  = r_master_delay_tabs + 5'b00001;
                ri_monitor_delay_tabs = r_monitor_delay_tabs + 5'b00001;
                ri_state              = S_WAIT_1;
            end

            S_INC_WINDOW: begin
                ri_monitor_delay_tabs = r_monitor_delay_tabs + r_edge_window_tabs;
                if (~enable_monitor)
                    ri_state = S_IDLE;
                else 
                    ri_state = S_WAIT_2;
            end

            S_WAIT_2: begin
                ri_wait_time = r_wait_time + 1;
                if (&r_wait_time)
                    ri_state = S_COMPARE_2;
            end

            S_COMPARE_2: begin
                if (serdes_comp)
                    ri_state = S_DEC_WINDOW;
                else
                    ri_state = S_FLAG_RIGHT;
            end

            S_FLAG_RIGHT: begin
               ri_master_delay_tabs  = r_master_delay_tabs - 5'b00001;
               ri_monitor_delay_tabs = r_monitor_delay_tabs - 5'b00001;
                ri_state              = S_WAIT_2;
            end

            S_DEC_WINDOW: begin
                ri_monitor_delay_tabs = r_monitor_delay_tabs - r_edge_window_tabs;
                if (~enable_monitor)
                    ri_state = S_IDLE;
                else 
                    ri_state = S_WAIT_1;
            end

            default: begin
                ri_state = S_IDLE;
            end

        endcase
    end

    assign o_master_delay_tabs  = r_master_delay_tabs;
    assign o_monitor_delay_tabs = r_monitor_delay_tabs;

endmodule

`endif /* PHYSICAL_IOB_TAB_MONITOR */