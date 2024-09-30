

/*
    Module  : PACKET_GENERATOR_CONTROLLER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/



`ifndef _TRANSMITTER_PACKET_GENERATOR_CONTROLLER_V_
`define _TRANSMITTER_PACKET_GENERATOR_CONTROLLER_V_

`include "src/hdl/global_functions.vh"
//
`include "src/hdl/cdc/async_reset.v"

module packet_generator_controller #(
    parameter TLP_ID_WIDTH         = 2,
    parameter NUM_TLP_HEADER_BYTES = 1,
    parameter NUM_TLP_BYTES        = 8,
    parameter NUM_DLLP_BYTES       = 2
)(
    input wire i_clk, i_arst_n,
    input wire i_tlp_valid, 
    input wire i_dllp_valid,
    output wire o_tlp_ack,
    output wire o_dllp_ack,
    //
    input wire i_tlp_start,
    input wire i_tlp_stop,
    input wire i_tlp_rply_start,
    input wire i_tlp_id_ack,
    output wire o_tlp_rply_act,
    output wire o_tlp_id_all_ack,
    output wire o_tlp_id_wait_ack,
    output wire o_crc_init,
    output wire o_crc_calc,
    output wire o_sel_rply,
    output wire o_rply_id_set,
    output wire o_rply_wr,
    output wire o_rply_rd,
    output wire o_frame_load,
    output wire o_sel_dllp,
    output wire o_packet_run,
    output wire o_packet_stop,   
    // 
    output wire[((TLP_ID_WIDTH + 1) << 1)-1:0] o_tlp_header,
    output wire [TLP_ID_WIDTH-1:0] o_rply_id,
    output wire [TLP_ID_WIDTH-1:0] o_tlp_id_nack,
    output wire [TLP_ID_WIDTH-1:0] o_tlp_id_ack
);


    //////////////////////////////////////////////////////////////////////////////////////////////////////
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

    //////////////////////////////////////////////////////////////////////////////////////////////////////
    // ID - GENERATOR

    reg [TLP_ID_WIDTH:0] r_tlp_id_nack, r_tlp_id_ack;
    wire [TLP_ID_WIDTH:0] ri_tlp_id_nack, ri_tlp_id_ack;

    reg r_tlp_id_wait_ack, r_tlp_id_all_ack;
    wire ri_tlp_id_wait_ack, ri_tlp_id_all_ack;

    reg r_rply_enable, r_tlp_enable;
    wire ri_rply_enable, ri_tlp_enable;
    wire wr_tlp_id_nack, rply_done;


    always@ (posedge i_clk, negedge local_reset_n)
        if (~local_reset_n) begin
            r_tlp_id_nack     <= 0;
            r_tlp_id_ack      <= 0;
            r_rply_enable     <= 1'b0;
            r_tlp_enable      <= 1'b0;
            r_tlp_id_all_ack  <= 1'b1;
            r_tlp_id_wait_ack <= 1'b0;
        end else begin
            r_tlp_id_nack     <= ri_tlp_id_nack;
            r_tlp_id_ack      <= ri_tlp_id_ack;
            r_rply_enable     <= ri_rply_enable;
            r_tlp_enable      <= ri_tlp_enable;
            r_tlp_id_all_ack  <= ri_tlp_id_all_ack;
            r_tlp_id_wait_ack <= ri_tlp_id_wait_ack;
        end

  
    // tlp id nack/ack mechanism => fifo pointer logic 
    assign ri_tlp_id_nack = (wr_tlp_id_nack && ~r_tlp_id_wait_ack) ? r_tlp_id_nack + 1 : r_tlp_id_nack;
    assign ri_tlp_id_ack = (i_tlp_id_ack && ~r_tlp_id_all_ack) ? r_tlp_id_ack + 1 : r_tlp_id_ack;

    assign ri_tlp_id_all_ack  = (ri_tlp_id_nack == ri_tlp_id_ack);
    assign ri_tlp_id_wait_ack = (ri_tlp_id_nack[TLP_ID_WIDTH] ^ ri_tlp_id_ack[TLP_ID_WIDTH]) & 
                                (ri_tlp_id_nack[TLP_ID_WIDTH-1:0] == ri_tlp_id_ack[TLP_ID_WIDTH-1:0]);   


    assign ri_rply_enable = (i_tlp_rply_start | r_rply_enable) & ~rply_done;
    assign o_tlp_rply_act = r_rply_enable; // replay is activate

    assign o_tlp_id_nack = r_tlp_id_nack[TLP_ID_WIDTH-1:0];
    assign o_tlp_id_ack  = r_tlp_id_ack[TLP_ID_WIDTH-1:0];
    //
    assign o_tlp_id_all_ack  = r_tlp_id_all_ack;
    assign o_tlp_id_wait_ack = r_tlp_id_wait_ack;
    
    assign ri_tlp_enable = (i_tlp_start | r_tlp_enable) && ~(i_tlp_stop | r_rply_enable);
    
    //
    wire tlp_enable; 
    assign tlp_enable = (i_tlp_valid && r_tlp_enable && ~r_tlp_id_wait_ack);  
    

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // FSM

    localparam MAX_MSG_BYTES  = `fun_max(NUM_TLP_BYTES, NUM_DLLP_BYTES);  
    
    localparam [13:0] S_IDLE       = 14'b00000000000001, // 0
                     S_START_DLLP  = 14'b00000000000010, // 1
                     S_START_TLP   = 14'b00000000000100, // 2
                     S_PREP_RPLY   = 14'b00000000001000, // 3
                     S_START_RPLY  = 14'b00000000010000, // 4
                     S_SEND_DLLP   = 14'b00000000100000, // 5
                     S_SEND_TLP    = 14'b00000001000000, // 6
                     S_RELOAD_TLP  = 14'b00000010000000, // 7
                     S_SEND_RPLY   = 14'b00000100000000, // 8
                     S_RELOAD_RPLY = 14'b00001000000000, // 9
                     S_TLP_DONE    = 14'b00010000000000, // 10
                     S_RPLY_DONE   = 14'b00100000000000, // 11
                     S_WAIT        = 14'b01000000000000, // 12
                     S_STOP        = 14'b10000000000000; // 13

    
    (* fsm_encoding = "user_encoding" *)
    reg [13:0] r_state = S_IDLE;
    reg [13:0] ri_state;

    assign wr_tlp_id_nack = (r_state[2] | r_state[7]); // S_START_TLP, S_RELOAD_TLP
    assign rply_done      = r_state[11]; // S_REPLY_DONE

    // output's
    assign o_crc_init = r_state[0];     // S_IDLE
    assign o_crc_calc = |r_state[11:5]; // S_SEND_DLLP, S_SEND_TLP, S_RELOAD_TLP, S_SEND_RPLY, S_RELOAD_RPLY, S_TLP_DONE, S_RPLY_DONE

    assign o_sel_rply    = (r_state[8] | r_state[9]); // S_SEND_RPLY, S_RELOAD_RPLY
    assign o_rply_rd     = (r_state[8] | r_state[9]); // S_SEND_RPLY, S_RELOAD_RPLY
    assign o_rply_id_set = (r_state[2] | r_state[4] | r_state[7] | r_state[9]); // S_START_TLP, S_START_RPLY, S_RELOAD_TLP, S_RELOAD_RPLY

    assign o_tlp_ack  = (r_state[2] | r_state[7]); // S_START_TLP, S_RELOAD_TLP
    assign o_dllp_ack = r_state[1]; // S_START_DLLP
    assign o_sel_dllp = r_state[1]; // S_START_DLLP

    assign o_frame_load  = (r_state[1] | r_state[2] | r_state[4] | r_state[7] | r_state[9]); // S_START_DLLP, S_START_TLP, S_START_RPLY, S_RELOAD_TLP, S_RELOAD_RPLY
    assign o_packet_stop = r_state[13]; // S_STOP
    assign o_packet_run  = ~(|r_state[4:0] | r_state[13]); // => |r_state[12:5]; 


    reg [$clog2(MAX_MSG_BYTES-1):0] r_byte_cnt;
    reg [$clog2(MAX_MSG_BYTES-1):0] ri_byte_cnt;

    reg[TLP_ID_WIDTH:0] r_tlp_id, ri_tlp_id;
    reg [TLP_ID_WIDTH-1:0] r_frame_cnt, ri_frame_cnt; // r_tlp_id
    reg[TLP_ID_WIDTH:0] r_tlp_id_rply, ri_tlp_id_rply; // with extra bit for equal with pointer logic

    wire reload_flag, done_flag;
    wire replay_enable;

    always@ (posedge i_clk, negedge local_reset_n)
        if (~local_reset_n) begin
            r_state       <= S_IDLE;
            r_tlp_id      <= 0;
            r_tlp_id_rply <= 0;
            r_byte_cnt    <= 0;
            r_frame_cnt   <= 0;
        end else begin
            r_state       <= ri_state;
            r_tlp_id      <= ri_tlp_id;
            r_tlp_id_rply <= ri_tlp_id_rply;
            r_byte_cnt    <= ri_byte_cnt;
            r_frame_cnt   <= ri_frame_cnt;
        end

    assign reload_flag = (r_byte_cnt == (NUM_TLP_BYTES-(NUM_TLP_HEADER_BYTES + 2)));
    assign done_flag   = (r_byte_cnt == (NUM_TLP_BYTES-2));

    assign replay_enable = (r_rply_enable & ~(r_tlp_id_rply == r_tlp_id_nack)); 

    always@ * begin
        
        ri_state       = r_state;

        ri_tlp_id      = r_tlp_id;
        ri_tlp_id_rply = r_tlp_id_rply;
        ri_byte_cnt    = r_byte_cnt;
        ri_frame_cnt   = r_frame_cnt;

        case (r_state)

            S_IDLE: begin
                ri_byte_cnt    = 0;
                ri_frame_cnt   = 0;
                ri_tlp_id      = r_tlp_id_nack;
                ri_tlp_id_rply = r_tlp_id_nack[TLP_ID_WIDTH-1:0];
        
                if (i_dllp_valid) 
                    ri_state = S_START_DLLP;
                else if (r_rply_enable) 
                    ri_state = S_PREP_RPLY;
                else if (tlp_enable)
                    ri_state = S_START_TLP;

            end

            S_START_DLLP: begin
                ri_state = S_SEND_DLLP;
            end

            S_START_TLP: begin
                ri_frame_cnt   = r_frame_cnt + 1;
                ri_tlp_id_rply = r_tlp_id_rply + 1;              
                ri_state       = S_SEND_TLP;
            end

            S_PREP_RPLY: begin 
                ri_tlp_id      = r_tlp_id_ack;
                ri_tlp_id_rply = r_tlp_id_ack[TLP_ID_WIDTH-1:0];
                ri_state       = S_START_RPLY;
            end

            S_START_RPLY: begin
                ri_frame_cnt   = r_frame_cnt + 1;
                ri_tlp_id_rply = r_tlp_id_rply + 1;
                ri_state       = S_SEND_RPLY;
            end


            S_SEND_DLLP: begin
                ri_byte_cnt = r_byte_cnt + 1;
 
                if (r_byte_cnt == NUM_DLLP_BYTES-1)
                    ri_state = S_WAIT;   
            end

            S_SEND_TLP: begin
                ri_byte_cnt = r_byte_cnt + 1;
                
                if (reload_flag && tlp_enable)
                    ri_state = S_RELOAD_TLP;
                else if (done_flag)
                    ri_state = S_TLP_DONE;               
            end

            S_RELOAD_TLP: begin
                ri_byte_cnt    = 0;
                ri_frame_cnt   = r_frame_cnt + 1;
                ri_tlp_id_rply = ri_tlp_id_rply + 1;
                ri_state       = S_SEND_TLP;
                
            end

            
            S_SEND_RPLY: begin
                ri_byte_cnt = r_byte_cnt + 1;

                if (reload_flag && replay_enable)
                    ri_state = S_RELOAD_RPLY;
                if (done_flag)
                    ri_state = S_RPLY_DONE;
            end 

            S_RELOAD_RPLY: begin
                ri_byte_cnt    = 0;
                ri_frame_cnt   = r_frame_cnt + 1;
                ri_tlp_id_rply = r_tlp_id_rply + 1;
                ri_state       = S_SEND_RPLY;
            end

            S_TLP_DONE: begin
                ri_state = S_WAIT;           
            end

            S_RPLY_DONE: begin
                ri_state = S_WAIT; 
            end

            S_WAIT: begin
                ri_state = S_STOP; 
            end

            S_STOP: begin
                ri_state = S_IDLE;
            end

            default: begin
                // default 
                ri_state = S_IDLE;
            end
            
        endcase

    end


    assign o_tlp_header = {1'b0, r_frame_cnt, r_tlp_id};
    assign o_rply_id    = r_tlp_id_rply[TLP_ID_WIDTH-1:0];   

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // OUTPUT BUFFER

    reg r_rply_wr;
    wire ri_rply_wr;

    always@ (posedge i_clk, negedge local_reset_n)
        if (~local_reset_n)
            r_rply_wr <= 1'b0;
        else
            r_rply_wr <= ri_rply_wr;

    assign ri_rply_wr = (ri_state[6] | ri_state[7]); // S_SEND_TLP, S_RELOAD_TLP
    assign o_rply_wr  = r_rply_wr;

endmodule

`endif /* PACKET_GENERATOR_CONTROLLER */