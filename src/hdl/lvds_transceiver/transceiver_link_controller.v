
/*
    Module  : TRANSCEIVER_LINK_CONTROLLER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`ifndef _TRANSCEIVER_LINK_CONTROLLER_V_
`define _TRANSCEIVER_LINK_CONTROLLER_V_

`include "src/hdl/global_functions.vh"
//
`include "src/hdl/cdc/async_reset.v"


module transceiver_link_controller #(
    parameter TLP_ID_WIDTH       = 3
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
    output wire o_status_connect
);

    //
    localparam TLP_ID_WIDTH_PADDING  = `fun_padding_bits(TLP_ID_WIDTH);


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
    localparam [17:0]  S_INIT           = 18'b000000000000000001, // 0
                       S_CAL            = 18'b000000000000000010, // 1
                       S_WAIT           = 18'b000000000000000100, // 2
                       S_JUMP           = 18'b000000000000001000, // 3
                       S_ENTRY_STATUS   = 18'b000000000000010000, // 4
                       S_ENTRY_RX_DLLP  = 18'b000000000000100000, // 5
                       S_ENTRY_RX       = 18'b000000000001000000, // 6
                       S_ENTRY_TX       = 18'b000000000010000000, // 7
                       S_SEND_STATUS    = 18'b000000000100000000, // 8
                       S_READ_DLLP      = 18'b000000001000000000, // 9
                       S_READ_ID_STATUS = 18'b000000010000000000, // 10
                       S_CHECK_ACK_ID   = 18'b000000100000000000, // 11
                       S_CHECK_DLLP_RDY = 18'b000001000000000000, // 12
                       S_WRITE_DLLP     = 18'b000010000000000000, // 13
                       S_TX_TLP_START   = 18'b000100000000000000, // 14
                       S_TX_TLP_STOP    = 18'b001000000000000000, // 15
                       S_TX_TLP_ID_ACK  = 18'b010000000000000000, // 16
                       S_TX_TLP_REPLAY  = 18'b100000000000000000; // 17
                  
    (* fsm_encoding = "user_encoding" *)
    reg[17:0] r_state = S_INIT;
    reg[17:0] ri_state;

    // assign state's to transmitter
    assign o_tx_dllp_wr      = r_state[13];     // S_WRITE_DLLP
    assign o_tx_id_ack       = r_state[16];     // S_TX_TLP_ID_ACK
    assign o_tx_start        = r_state[14];     // S_TX_TLP_START
    assign o_tx_stop         = r_state[15];     // S_TX_TLP_STOP
    assign o_tx_rply         = r_state[17];     // S_TLP_REPLAY     
    // assign state's to receiver
    assign o_rx_id_result_rd = r_state[10];     // S_READ_ID_STATUS
    assign o_rx_dllp_rd      = r_state[9];      // S_READ_DLLP
    assign o_phys_cal_start  = r_state[1];      // S_CAL
    // status
    assign o_state_init      = r_state[0];      // S_INIT

    //
    reg[15:0] r_dllp_rx, ri_dllp_rx;
    reg[15:0] r_dllp_tx, ri_dllp_tx;
    //
    reg[1:0] r_jump_sel = 2'b00;
    reg[1:0] ri_jump_sel;
    //
    reg[12:0] r_time_ticks, ri_time_ticks;
    reg[10:0] r_nack_ticks;
    wire[10:0] ri_nack_ticks;
    //
    reg r_update_status;
    wire ri_update_status;
    //
    reg r_rx_tlp_rdy;
    wire rx_tlp_rdy_change;
    //
    reg r_ack_timeout;
    wire ri_ack_timeout;
    //
    reg r_status_connect;
    wire ri_status_connect;



    always@ (posedge i_clk, negedge local_reset_n)
        if (~local_reset_n) begin
            r_state           <= S_INIT;
            r_dllp_tx         <= 16'b0;
            r_dllp_rx         <= 16'b0;
            r_jump_sel        <= 2'b00;
            //
            r_time_ticks      <= 13'b0;
            r_nack_ticks      <= 3'b0;
            //
            r_update_status   <= 1'b0;
            r_ack_timeout     <= 1'b0;
            //
            r_rx_tlp_rdy      <= 1'b0;
            //
            r_status_connect  <= 1'b0;
        end else begin
            r_state           <= ri_state;
            r_dllp_tx         <= ri_dllp_tx;
            r_dllp_rx         <= ri_dllp_rx;
            r_jump_sel        <= ri_jump_sel;
            //
            r_time_ticks      <= ri_time_ticks;
            r_nack_ticks      <= ri_nack_ticks;
            //
            r_update_status   <= ri_update_status;
            r_ack_timeout     <= ri_ack_timeout;
            //
            r_rx_tlp_rdy      <= i_rx_tlp_rdy;
            //
            r_status_connect  <= ri_status_connect;
        end

    // connect
    assign ri_status_connect = (r_state[9] || r_status_connect) && ~r_state[0];
    assign o_status_connect  = r_status_connect;

    // ack/nack - timeout
    assign ri_nack_ticks  = (r_state[16] || r_state[17]) ? 9'b0 : ((i_tx_ack_req) ? r_nack_ticks + 1 : r_nack_ticks);
    assign ri_ack_timeout = (&r_nack_ticks || r_ack_timeout) && ~r_state[17];

    // sending a status dllp
    assign rx_tlp_rdy_change = r_rx_tlp_rdy ^ i_rx_tlp_rdy; // status has change
    assign ri_update_status = (rx_tlp_rdy_change || r_update_status) && ~(r_state[8] || r_state[2]);


    always@* begin
        
        ri_state = r_state;
        //
        ri_jump_sel = r_jump_sel;
        ri_dllp_tx  = r_dllp_tx;
        ri_dllp_rx  = r_dllp_rx;
        //
        ri_time_ticks = r_time_ticks;

        case (r_state)

            S_INIT: begin
                // run-up
                ri_time_ticks = r_time_ticks + 1;
                if (&r_time_ticks[8:0])    
                    ri_state = S_CAL;
            end

        
            // if you implement re-initialize => 
            //"physical done" will immediately be "true" because it is delayed by the synchronizer
            // solution => use a handshake pulse synchronizer
            S_CAL: begin
                ri_time_ticks = 0;
                // tab-cal, word-aligning
                if (i_phys_cal_fail)
                    ri_state = S_INIT;
                else if (i_phys_cal_done) 
                    ri_state = S_WAIT;
            end

            S_WAIT: begin
                ri_time_ticks = r_time_ticks + 1;
                if (&r_time_ticks)
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
                ri_time_ticks = r_time_ticks + 1;
                //
                if (r_update_status || r_time_ticks[4])
                    ri_state = S_SEND_STATUS;
                else
                    ri_state = S_JUMP;
            end

            S_SEND_STATUS: begin 
                ri_time_ticks = 0;
                ri_dllp_tx    = {7'b0000000, i_rx_tlp_rdy, 8'b00000000}; // you can use more status bits if you want
                ri_state      = S_CHECK_DLLP_RDY;
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
                    2'b11: ri_state = S_CHECK_ACK_ID;
                endcase
            end

            
            ////////////////////////////////////////////////////////////////////////////////////////////////////////
            // READ RECEIVER STATUS => GENERATE DLLP ACK/NACK
            S_ENTRY_RX: begin
                ri_dllp_tx = {7'b1000000, i_rx_id_result[TLP_ID_WIDTH], {TLP_ID_WIDTH_PADDING{1'b0}}, i_rx_id_result[TLP_ID_WIDTH-1:0]};
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
                if (r_ack_timeout)
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
                    ri_state = S_JUMP;
            end

            S_TX_TLP_ID_ACK: begin
                ri_state = S_JUMP; //S_TX_TLP_START;
            end

            S_TX_TLP_REPLAY: begin
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


            


