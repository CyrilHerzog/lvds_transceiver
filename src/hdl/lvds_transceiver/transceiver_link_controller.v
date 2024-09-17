
/*
    Module  : TRANSCEIVER_LINK_CONTROLLER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

    info:
    cal timeout is not handled => it will be assumed that a windows will always be found
    You may have to experiment with the times, as calibration will be distorted if a transceiver sends a DLLP too early

    replay - start is currently deactivated, because it is not tested
    it may be necessary to wait a while after a replay to avoid unnecessary resending

    if reinitialization is necessary, the remote station must not send a DLLP. One possibility would be to use a 
    watchdog signal to put the remote station into the initial state

    defining additional dllp instructions (handshaking) could be an alternative to a timer control logic

    ToDo:
    create some status signal's for better monitoring of the transceiver status, e.g is_connect, is_disconnect .....

*/


`ifndef _TRANSCEIVER_LINK_CONTROLLER_V_
`define _TRANSCEIVER_LINK_CONTROLLER_V_

`include "src/hdl/cdc/async_reset.v"

module transceiver_link_controller #(
    parameter TLP_ID_WIDTH = 4
)(
    input wire i_clk, i_arst_n,
    // TRANSMITTER
    input wire i_tx_dllp_rdy,
    output wire [15:0] o_tx_dllp,
    output wire o_tx_dllp_wr,
    //
    output wire o_tx_start,
    output wire o_tx_stop,
    output wire o_tx_rply,
    //
    input wire i_tx_ack_req,
    input wire[TLP_ID_WIDTH-1:0] i_tx_ack_id,
    output wire o_tx_id_ack,
    //
    // RECEIVER
    input wire i_rx_dllp_valid,
    input wire[15:0] i_rx_dllp,
    output wire o_rx_dllp_rd,
    //
    input wire i_rx_tlp_rdy,
    input wire i_rx_id_result_valid,
    input wire[TLP_ID_WIDTH:0] i_rx_id_result,
    output wire o_rx_id_result_rd,
    //
    // PHYSICAL
    input wire i_phys_cal_done,
    input wire i_phys_cal_fail,
    output wire o_phys_cal_start,
    //
    // STATUS
    output wire o_status_init_done,
    output wire o_status_init_fail,
    output wire o_status_connect
);


    ////////////////////////////////////////////////////////////////////////////////////////
    // LOCAL RESET
    wire local_reset_n;

    async_reset #(
        .STAGES   (2),
        .INIT     (1'b0),
        .RST_VAL  (1'b0)
    ) inst_local_reset (
        .i_clk    (i_clk), 
        .i_rst_n  (i_arst_n),
        .o_rst    (local_reset_n)
    );



    ///////////////////////////////////////////////////////////////////////////////////////
    // FSM

    // state definition
    localparam [16:0]  S_INIT           = 17'b00000000000000001, // 0
                       S_CAL            = 17'b00000000000000010, // 1
                       S_JUMP           = 17'b00000000000000100, // 2
                       S_ENTRY_STATUS   = 17'b00000000000001000, // 3
                       S_ENTRY_RX_DLLP  = 17'b00000000000010000, // 4
                       S_ENTRY_RX       = 17'b00000000000100000, // 5
                       S_ENTRY_TX       = 17'b00000000001000000, // 6
                       S_SEND_STATUS    = 17'b00000000010000000, // 7
                       S_READ_DLLP      = 17'b00000000100000000, // 8
                       S_READ_ID_STATUS = 17'b00000001000000000, // 9
                       S_CHECK_ACK_ID   = 17'b00000010000000000, // 10
                       S_CHECK_DLLP_RDY = 17'b00000100000000000, // 11
                       S_WRITE_DLLP     = 17'b00001000000000000, // 12
                       S_TX_TLP_START   = 17'b00010000000000000, // 13
                       S_TX_TLP_STOP    = 17'b00100000000000000, // 14
                       S_TX_TLP_ID_ACK  = 17'b01000000000000000, // 15
                       S_TX_TLP_REPLAY  = 17'b10000000000000000; // 16
                  
    (* fsm_encoding = "user_encoding" *)
    reg[16:0] r_state = S_INIT;
    reg[16:0] ri_state;

    // assign state's to transmitter
    assign o_tx_dllp_wr      = r_state[12];     // S_WRITE_DLLP
    assign o_tx_id_ack       = r_state[15];     // S_TX_TLP_ID_ACK
    assign o_tx_start        = r_state[13];     // S_TX_TLP_START
    assign o_tx_stop         = r_state[14];     // S_TX_TLP_STOP
    assign o_tx_rply         = 1'b0;            // S_TLP_REPLAY    => link with r_state[16]     
    // assign state's to receiver
    assign o_rx_id_result_rd = r_state[9];      // S_READ_ID_STATUS
    assign o_rx_dllp_rd      = r_state[8];      // S_READ_DLLP
    assign o_phys_cal_start  = r_state[1];      // S_CAL

    //
    reg[15:0] r_dllp_rx, ri_dllp_rx;
    reg[15:0] r_dllp_tx, ri_dllp_tx;
    //
    reg[1:0] r_jump_sel = 2'b00;
    reg[1:0] ri_jump_sel;
    //
    reg[12:0] r_status_timer;
    wire[12:0] ri_status_timer;
    //reg[15:0] r_nack_timer;
    //wire[15:0] ri_nack_timer;
    //
    wire en_status_update;
    reg r_update_status;
    wire ri_update_status;
    //
    wire run_up_done;
    //
    reg r_rx_tlp_rdy;
    wire rx_tlp_rdy_change;
    //
    //reg r_ack_timeout;
    //wire ri_ack_timeout;
    //reg[1:0] r_ack_attempts, ri_ack_attempts;

   
    always@ (posedge i_clk, negedge local_reset_n)
        if (~local_reset_n) begin
            r_state         <= S_INIT;
            r_dllp_tx       <= 16'b0;
            r_dllp_rx       <= 16'b0;
            r_jump_sel      <= 2'b00;
            //
            r_status_timer  <= 13'b0;
            //r_nack_timer    <= 16'b0;
            r_update_status <= 1'b0;
            //
            r_rx_tlp_rdy    <= 1'b0;
            //
            //r_ack_timeout   <= 1'b0;
            //r_ack_attempts  <= 2'b00;
        end else begin
            r_state         <= ri_state;
            r_dllp_tx       <= ri_dllp_tx;
            r_dllp_rx       <= ri_dllp_rx;
            r_jump_sel      <= ri_jump_sel;
            //
            r_status_timer  <= ri_status_timer;
            //r_nack_timer    <= ri_nack_timer;
            r_update_status <= ri_update_status;
            //
            r_rx_tlp_rdy    <= i_rx_tlp_rdy;
            //
            //r_ack_timeout   <= ri_ack_timeout;
            //r_ack_attempts  <= ri_ack_attempts;
        end

    assign rx_tlp_rdy_change = r_rx_tlp_rdy ^ i_rx_tlp_rdy;
    // 
    assign ri_status_timer  = (r_state[1]) ? 16'h0000 : r_status_timer + 1; // reset by state S_CAL
    assign run_up_done      = &r_status_timer[7:0];
    //
    assign en_status_update = (&r_status_timer || rx_tlp_rdy_change);
    assign ri_update_status = (en_status_update || r_update_status) && ~(r_state[7] || r_state[1]); // reset by state S_STATUS_SEND and S_CAL
    //
    //assign ri_nack_timer  = (r_state[15]) ? 16'h0000 : ((i_tx_ack_req) ? r_nack_timer + 1 : r_nack_timer);
    //assign ri_ack_timeout = (&r_nack_timer || r_ack_timeout) && ~r_state[16]; 


    always@* begin
        
        ri_state = r_state;
        //
        ri_jump_sel = r_jump_sel;
        ri_dllp_tx  = r_dllp_tx;
        ri_dllp_rx  = r_dllp_rx;
        //
        //ri_ack_attempts = r_ack_attempts;

        case (r_state)

            S_INIT: begin
                // 
                // ri_ack_attempts = 2'b00;
                // run-up
                if (run_up_done)   
                    ri_state = S_CAL;
            end

            S_CAL: begin
                // tab-cal, word-aligning
                if (i_phys_cal_fail)
                    ri_state = S_INIT;
                else if (i_phys_cal_done)
                    ri_state = S_JUMP;
            end

            // SCHEDULER
            S_JUMP: begin
                ri_jump_sel = r_jump_sel + 2'b01;
                //
                case (r_jump_sel)
                    2'b00: ri_state = S_ENTRY_STATUS;
                    2'b01: ri_state = S_ENTRY_RX_DLLP;
                    2'b10: ri_state = S_ENTRY_RX;
                    2'b11: ri_state = S_ENTRY_TX;
                endcase
            end
         
            ////////////////////////////////////////////////////////////////////////////////////////////////////////
            // DLLP STATUS - BITS
            S_ENTRY_STATUS: begin
                //
                if (r_update_status)
                    ri_state = S_SEND_STATUS;
                else
                    ri_state = S_JUMP;
            end

            S_SEND_STATUS: begin 
                ri_dllp_tx = {7'b0000000, i_rx_tlp_rdy, 8'b00000000}; 
                ri_state   = S_CHECK_DLLP_RDY;
            end
        

            ///////////////////////////////////////////////////////////////////////////////////////////////////////
            // DLLP DECODE
            S_ENTRY_RX_DLLP: begin
                ri_dllp_rx = i_rx_dllp;
                //
                if (i_rx_dllp_valid)
                    ri_state = S_READ_DLLP;
                else
                    ri_state = S_JUMP;
            end

            S_READ_DLLP: begin
                case({r_dllp_rx[15], r_dllp_rx[8]})
                    2'b00: ri_state = S_TX_TLP_STOP;
                    2'b01: ri_state = S_TX_TLP_START;
                    2'b10: ri_state = S_TX_TLP_REPLAY;
                    2'b11: ri_state = S_TX_TLP_ID_ACK;
                endcase
            end

            
            ////////////////////////////////////////////////////////////////////////////////////////////////////////
            // READ RECEIVER STATUS => GENERATE DLLP ACK/NACK
            S_ENTRY_RX: begin
                ri_dllp_tx = {7'b1000000, i_rx_id_result[TLP_ID_WIDTH], 4'b0, i_rx_id_result[TLP_ID_WIDTH-1:0]};
                if (i_rx_id_result_valid)
                    ri_state = S_READ_ID_STATUS;
                else
                    ri_state = S_JUMP;
            end

            S_READ_ID_STATUS: begin
                ri_state = S_CHECK_DLLP_RDY;
            end

            ////////////////////////////////////////////////////////////////////////////////////////////////////////
            // TRANSMITTER CONTROL => CHECK STATUS & ACK/NACK
            S_ENTRY_TX: begin
                if (1'b0) // add ack timeout here => r_ack_timeout
                    ri_state = S_TX_TLP_REPLAY;
                else
                    ri_state = S_JUMP;
            end

            S_TX_TLP_START: begin 
                ri_state = S_JUMP;
            end

            S_TX_TLP_STOP: begin
                ri_state = S_JUMP;
            end

            S_CHECK_ACK_ID: begin
                if (r_dllp_rx[TLP_ID_WIDTH-1:0] == i_tx_ack_id)
                    ri_state = S_TX_TLP_ID_ACK; 
                else
                    ri_state = S_TX_TLP_REPLAY;
            end

            S_TX_TLP_ID_ACK: begin
                ri_state = S_JUMP;
            end

            S_TX_TLP_REPLAY: begin
                // ri_ack_attempts = {r_ack_attempts[0], 1'b1};
                // if (&r_ack_attempts)
                //  ri_state = S_INIT;
                ri_state = S_JUMP;
            end

        
            //////////////////////////////////////////////////////////////////////////////////////////////////////
            // WRITE DLLP 
            S_CHECK_DLLP_RDY: begin
                if (i_tx_dllp_rdy)
                    ri_state = S_WRITE_DLLP;
            end

            S_WRITE_DLLP: begin
                ri_state = S_JUMP;
            end

            default: begin
                ri_state = S_INIT;
            end
        endcase
    end

    assign o_tx_dllp = r_dllp_tx;
    

endmodule
    
`endif /* TRANSCEIVER_LINK_CONTROLLER */            


            


