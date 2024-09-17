/*
    Module  : PHYSICAL_IOB_INIT_TAB_CAL
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _PHYSICAL_IOB_INIT_TAB_CAL_V_
`define _PHYSICAL_IOB_INIT_TAB_CAL_V_

`include "src/hdl/cdc/async_reset.v"

module physical_iob_init_tab_cal #(
    parameter SERDES_WIDTH   = 4, 
    parameter STARTUP_WIDTH  = 8, 
    parameter FILTER_WIDTH   = 8 
)(
    input wire i_clk, 
    input wire i_arst_n,
    input wire i_start,
    input wire [SERDES_WIDTH-1:0] i_serdes,
    output wire [4:0] o_delay_tabs,
    output wire [4:0] o_edge_tabs,
    output wire o_run,
    output wire o_done,
    output wire o_fail
);

    //////////////////////////////////////////////////////////////////////////////////////
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

    ////////////////////////////////////////////////////////////////////////////////////////
    // INPUT 

    reg r_start;
    wire start_flag; 
    reg[SERDES_WIDTH-1:0] r_serdes_i;

    always@ (posedge i_clk, negedge local_arst_n)
        if (~local_arst_n) begin
            r_start    <= 1'b0;
            r_serdes_i <= {SERDES_WIDTH{1'b0}};
        end else begin
            r_start    <= i_start;
            r_serdes_i <= i_serdes;
        end

    assign start_flag = i_start & ~r_start; // p-flag
    
    //////////////////////////////////////////////////////////////////////////////////////
    // SAMPLE FSM => find valid window and check sample point is stable over filter-time

    localparam [14:0] S_IDLE       = 15'b000000000000001, // 0
                      S_CAL_INIT   = 15'b000000000000010, // 1 
                      S_SAMPLE_S1  = 15'b000000000000100, // 2
                      S_SAMPLE_S2  = 15'b000000000001000, // 3
                      S_SAMPLE_S3  = 15'b000000000010000, // 4
                      S_SAMPLE_S4  = 15'b000000000100000, // 5
                      S_SAMPLE_S5  = 15'b000000001000000, // 6
                      S_SAMPLE_S6  = 15'b000000010000000, // 7
                      S_SAMPLE_S7  = 15'b000000100000000, // 8
                      S_SAMPLE_S8  = 15'b000001000000000, // 9
                      S_SAMPLE_S9  = 15'b000010000000000, // 10
                      S_SAMPLE_S10 = 15'b000100000000000, // 11
                      S_SAMPLE_S11 = 15'b001000000000000, // 12
                      S_CAL_DONE   = 15'b010000000000000, // 13
                      S_CAL_FAIL   = 15'b100000000000000; // 14
                    

    (* fsm_encoding = "user_encoding" *)
    reg[14:0] r_state = S_IDLE;
    reg[14:0] ri_state;

    //
    reg[STARTUP_WIDTH-1:0] r_wait_init, ri_wait_init;
    reg[FILTER_WIDTH-1:0] r_filter_shift, ri_filter_shift;
    //
    reg[(SERDES_WIDTH << 1)-1:0] r_sample_shift, ri_sample_shift;
    //
    // RD+ [xxxxxx xxxxxx|xx xxxxxx xx|xxxx xxxxxx], RD- [xxxxxx xxxxxx|xx xxxxxx xx|xxxx xxxxxx] 
    reg[1:0] r_loop_cnt, ri_loop_cnt;

    reg r_sample_diff;
    wire ri_sample_diff, trig_sample_diff; 
    // samples are different between two sampling point's
    assign ri_sample_diff = |(r_sample_shift[(SERDES_WIDTH << 1)-1:SERDES_WIDTH] ^ r_sample_shift[SERDES_WIDTH-1:0]);
    
    
    wire sample_valid; 
    // check possible samples => xx0011, xx1100, xx1001, xx0110, xx1010, xx0101
    assign sample_valid = (~^r_sample_shift[SERDES_WIDTH-1:0] & |r_sample_shift[SERDES_WIDTH-1:0]);

    reg r_window_valid;
    wire ri_window_valid;

    reg[4:0] r_tab_delay, ri_tab_delay;
    reg[4:0] r_edge_tabs;
    wire[4:0] ri_edge_tabs;

    

    //
    reg r_edge_left, r_edge_right;
    wire ri_edge_left, ri_edge_right;

    //
    reg r_cal_run, r_cal_done, r_cal_fail;
    wire ri_cal_run, ri_cal_done, ri_cal_fail;
    

    always@ (posedge i_clk, negedge local_arst_n)
        if (~local_arst_n) begin
            r_state        <= S_IDLE;
            r_wait_init    <= {STARTUP_WIDTH{1'b0}};
            r_sample_shift <= {(SERDES_WIDTH << 1){1'b0}};
            r_filter_shift <= {FILTER_WIDTH{1'b0}};
            r_tab_delay    <= 5'b00000;
            r_edge_tabs    <= 5'b00000;
            r_loop_cnt     <= 2'b00;
            //
            r_window_valid <= 1'b0;
            r_sample_diff  <= 1'b0;
            r_edge_left    <= 1'b0;
            r_edge_right   <= 1'b0;
            //
            r_cal_run      <= 1'b0;
            r_cal_done     <= 1'b0;
            r_cal_fail     <= 1'b0;
        end else begin
            r_state        <= ri_state;
            r_wait_init    <= ri_wait_init;
            r_sample_shift <= ri_sample_shift;
            r_filter_shift <= ri_filter_shift;
            r_tab_delay    <= ri_tab_delay;
            r_edge_tabs    <= ri_edge_tabs;
            r_loop_cnt     <= ri_loop_cnt;
            // 
            r_window_valid <= ri_window_valid;
            r_sample_diff  <= ri_sample_diff;
            r_edge_left    <= ri_edge_left;
            r_edge_right   <= ri_edge_right;
            //
            r_cal_run      <= ri_cal_run;
            r_cal_done     <= ri_cal_done;
            r_cal_fail     <= ri_cal_fail;
        end

    // found valid sample window 
    assign ri_window_valid = (r_state[6] || r_window_valid) && ~r_state[1]; // SR

    // edge detect
    assign trig_sample_diff = ri_sample_diff && ~r_sample_diff; // p-flag
    assign ri_edge_left  = ((r_window_valid && trig_sample_diff) || r_edge_left) && ~r_state[1]; // SR
    assign ri_edge_right = ((r_edge_left && trig_sample_diff) || r_edge_right) && ~r_state[1]; // SR

    // edge tabs
    assign ri_edge_tabs = (r_state[1]) ? 5'b00000 : (r_state[6] && r_edge_left && ~r_edge_right) ? r_edge_tabs + 5'b00001 : r_edge_tabs;

    // cal-state
    assign ri_cal_done = (r_state[13] || r_cal_done) && ~r_state[1]; // SR
    assign ri_cal_fail = (r_state[14] || r_cal_fail) && ~r_state[1]; // SR
    assign ri_cal_run  = (r_state[1] || r_cal_run) && ~r_state[0]; // SR

    assign o_run  = r_cal_run;
    assign o_done = r_cal_done;
    assign o_fail = r_cal_fail;
    

 
    always@* begin

        ri_state = r_state;
        //
        ri_wait_init    = r_wait_init;
        ri_sample_shift = r_sample_shift;
        ri_filter_shift = r_filter_shift;
        ri_tab_delay    = r_tab_delay;
        ri_loop_cnt     = r_loop_cnt;
        

        case(r_state)

            S_IDLE: begin
                if (start_flag)
                    ri_state = S_CAL_INIT;
            end

            S_CAL_INIT: begin
                ri_tab_delay = 5'b00000;
                ri_wait_init = r_wait_init + 1;
                // startup after set init-tab delay
                if (&r_wait_init)
                    ri_state = S_SAMPLE_S1;
            end
          
            S_SAMPLE_S1: begin // sample serdes input
                ri_sample_shift = {r_sample_shift[SERDES_WIDTH-1:0], r_serdes_i};
                ri_state        = S_SAMPLE_S2;
            end

            S_SAMPLE_S2: begin // update filter
                ri_filter_shift = {r_filter_shift[FILTER_WIDTH-2:0], ~ri_sample_diff};
                ri_state        = S_SAMPLE_S3;
            end

            S_SAMPLE_S3: begin // check filter
                ri_loop_cnt     = r_loop_cnt + 2'b01;

                if (&r_filter_shift)
                    ri_state = S_SAMPLE_S4;
                else
                    ri_state = S_SAMPLE_S6;
            end


            S_SAMPLE_S4: begin // check sample window
                if (sample_valid || r_window_valid) 
                    ri_state = S_SAMPLE_S5;
                else
                    ri_state = S_SAMPLE_S8;
            end

            S_SAMPLE_S5: begin // stable + window valid
                ri_tab_delay = r_tab_delay + 5'b00001;

                if (&r_tab_delay) // overrun => no edge detect
                    ri_state = S_CAL_FAIL;
                else if (r_loop_cnt[0])
                    ri_state = S_SAMPLE_S10;
                else
                    ri_state = S_SAMPLE_S1;
            end

            S_SAMPLE_S6: begin // not stable
                if (r_edge_right) // edge right
                    ri_state = S_CAL_DONE;
                else
                    ri_state = S_SAMPLE_S7;
            end

            S_SAMPLE_S7: begin // wait
                if (r_loop_cnt[0])
                    ri_state = S_SAMPLE_S10;
                else
                    ri_state = S_SAMPLE_S1;
            end

            S_SAMPLE_S8: begin // wait
                ri_state = S_SAMPLE_S9;
            end

            S_SAMPLE_S9: begin // change window
                if (r_loop_cnt[0])
                    ri_state = S_SAMPLE_S10;
                else
                    ri_state = S_SAMPLE_S1;
            end

            S_SAMPLE_S10: begin
                ri_state = S_SAMPLE_S11;
            end

            S_SAMPLE_S11: begin
                ri_state = S_SAMPLE_S3;
            end

            S_CAL_DONE: begin
                ri_tab_delay = r_tab_delay - {1'b0,r_edge_tabs[4:1]}; // center => initial tabs - 0.5 * bit tabs
                ri_state     = S_IDLE;
            end

            S_CAL_FAIL: begin
                ri_state = S_IDLE;
            end

            default: begin // default
                ri_state = S_IDLE;
            end

        endcase

    end

    //
    assign o_edge_tabs = r_edge_tabs;
    assign o_delay_tabs = r_tab_delay;


endmodule

`endif /* PHYSICAL_IOB_INIT_TAB_CAL */



