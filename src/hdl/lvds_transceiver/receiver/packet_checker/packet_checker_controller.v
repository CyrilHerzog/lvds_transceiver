/*
    Module  : PACKET_CHECKER_CONTROLLER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _PACKET_CHECKER_CONTROLLER_V_
`define _PACKET_CHECKER_CONTROLLER_V_

`include "src/hdl/global_functions.vh"
//
`include "src/hdl/cdc/async_reset.v"

module packet_checker_controller #(
    parameter TLP_ID_WIDTH         = 2,
    parameter NUM_TLP_HEADER_BYTES = 1,
    parameter NUM_TLP_BYTES        = 8,
    parameter NUM_DLLP_BYTES       = 2
)(
    input wire i_clk, i_arst_n,
    //
    input wire i_tlp_rdy,
    output wire o_tlp_wr,
    //
    input wire i_dllp_rdy, // not used 
    output wire o_dllp_wr,
    //
    input wire i_k_start_tlp,
    input wire i_k_start_dllp,
    input wire i_k_stop,
    input wire i_k_skp_n,
    input wire i_crc_ok,
    output wire o_crc_init,
    //
    // tlp- temporary storage
    output wire o_tlp_temp_wr,
    output wire[TLP_ID_WIDTH-1:0] o_tlp_temp_wr_addr,
    output wire[TLP_ID_WIDTH-1:0] o_tlp_temp_rd_addr,
    // handle tlp - temporary storage
    input wire i_tr_result_valid,
    input wire [((TLP_ID_WIDTH + 1) * 3) - 1:0] i_tr_result,
    output wire[TLP_ID_WIDTH:0] o_tr_result,  // {{valid}, num_frame}
    output wire o_tr_result_wr,
    output wire o_tr_result_rd,
    //
    output wire[TLP_ID_WIDTH:0] o_id_result,
    output wire o_id_result_wr
);
 
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
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


    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // TRANSFER - FSM
    localparam [7:0] S_TR_IDLE         = 8'b00000001, // 0
                     S_TR_START_DLLP   = 8'b00000010, // 1
                     S_TR_RECV_DLLP    = 8'b00000100, // 2
                     S_TR_WRITE_DLLP   = 8'b00001000, // 3
                     S_TR_START_TLP    = 8'b00010000, // 4
                     S_TR_RECV_TLP     = 8'b00100000, // 5
                     S_TR_WRITE_TLP    = 8'b01000000, // 6
                     S_TR_WRITE_RESULT = 8'b10000000; // 7

    (* fsm_encoding = "user_encoding" *)            
    reg [7:0] r_tr_state = S_TR_IDLE;
    reg [7:0] ri_tr_state;


    assign o_crc_init = r_tr_state[0];     // S_TR_IDLE
    assign o_dllp_wr  = r_tr_state[3];     // S_TR_WRITE_DLLP

    assign o_tlp_temp_wr  = r_tr_state[6]; // S_TR_WRITE_TLP
    assign o_tr_result_wr = r_tr_state[7]; // S_TR_WRITE_INFO

    
    localparam BYTE_CNT_WIDTH = $clog2(`fun_max(NUM_TLP_BYTES, NUM_DLLP_BYTES)-1);
    reg [BYTE_CNT_WIDTH:0] r_tr_byte_cnt;
    reg [BYTE_CNT_WIDTH:0] ri_tr_byte_cnt;
    //
    wire tr_bytes_done, tr_frame_valid, tr_max_frame, tr_frame_ovf;

    reg[TLP_ID_WIDTH:0] r_tr_frame_num, ri_tr_frame_num;
    reg[TLP_ID_WIDTH:0] r_tr_result, ri_tr_result;

    reg[TLP_ID_WIDTH-1:0] r_tlp_temp_wr_addr, ri_tlp_temp_wr_addr;
   
    always@ (posedge i_clk, negedge local_reset_n)
        if (~local_reset_n) begin
            r_tr_state         <= S_TR_IDLE;
            r_tr_byte_cnt      <= 0;
            r_tr_frame_num     <= 0;
            r_tr_result        <= 0;
            //
            r_tlp_temp_wr_addr <= {TLP_ID_WIDTH{1'b0}};
        end else begin
            r_tr_state         <= ri_tr_state;
            r_tr_byte_cnt      <= ri_tr_byte_cnt;
            r_tr_frame_num     <= ri_tr_frame_num;
            r_tr_result        <= ri_tr_result;
            //
            r_tlp_temp_wr_addr <= ri_tlp_temp_wr_addr;
        end


    assign tr_bytes_done  = (r_tr_byte_cnt == 0);
    assign tr_frame_valid = (i_crc_ok && i_k_stop); // pre-check => only valid with check of length and id-number 
    assign tr_frame_ovf   = r_tr_frame_num[TLP_ID_WIDTH];

 
    always@ * begin
        
        ri_tr_state         = r_tr_state;
        ri_tr_byte_cnt      = r_tr_byte_cnt;
        ri_tr_frame_num     = r_tr_frame_num;
        ri_tr_result        = r_tr_result;
        ri_tlp_temp_wr_addr = r_tlp_temp_wr_addr;
 

        case (r_tr_state)

            S_TR_IDLE: begin
                if (i_k_start_dllp) 
                    ri_tr_state = S_TR_START_DLLP;
                else if (i_k_start_tlp) 
                    ri_tr_state = S_TR_START_TLP;
            end
        
        // DLLP
            S_TR_START_DLLP: begin
                ri_tr_byte_cnt  = NUM_DLLP_BYTES - 1;
                if (i_k_skp_n)
                    ri_tr_state = S_TR_RECV_DLLP;
            end

            S_TR_RECV_DLLP: begin
                ri_tr_byte_cnt = r_tr_byte_cnt - {{BYTE_CNT_WIDTH{1'b0}}, i_k_skp_n};
                if (tr_bytes_done && tr_frame_valid)
                    ri_tr_state = S_TR_WRITE_DLLP;
                else if (tr_bytes_done && ~tr_frame_valid)
                    ri_tr_state = S_TR_IDLE; 
            end

            S_TR_WRITE_DLLP: begin
                ri_tr_state = S_TR_IDLE; 
            end

        // TLP
            S_TR_START_TLP: begin
                ri_tr_byte_cnt  = NUM_TLP_BYTES - (NUM_TLP_HEADER_BYTES + 1);
                ri_tr_frame_num = 0;
                 if (i_k_skp_n)
                    ri_tr_state = S_TR_RECV_TLP;
            end

            S_TR_RECV_TLP: begin
                ri_tr_byte_cnt = r_tr_byte_cnt - {{BYTE_CNT_WIDTH{1'b0}}, i_k_skp_n};
                ri_tr_result   = {1'b0, {TLP_ID_WIDTH{1'b1}}};
                if (tr_frame_ovf)
                    ri_tr_state = S_TR_WRITE_RESULT;
                else if (tr_bytes_done)  
                    ri_tr_state = S_TR_WRITE_TLP;
            end


            S_TR_WRITE_TLP: begin // write in temporary buffer
                ri_tr_byte_cnt      = NUM_TLP_BYTES - (NUM_TLP_HEADER_BYTES + 2);
                ri_tr_frame_num     = r_tr_frame_num + 1;
                ri_tr_result        = {tr_frame_valid, r_tr_frame_num[TLP_ID_WIDTH-1:0]};
                ri_tlp_temp_wr_addr = r_tlp_temp_wr_addr + 1;
                if (i_k_stop)
                    ri_tr_state = S_TR_WRITE_RESULT;
                else
                    ri_tr_state = S_TR_RECV_TLP;
            end

            S_TR_WRITE_RESULT: begin // save crc & frame result's together with tlp header 
                ri_tr_state = S_TR_IDLE;
            end
        
            default: begin
                // default stage
                ri_tr_state = S_TR_IDLE;
            end
            
        endcase

    end

    assign o_tr_result = r_tr_result;
    //
    assign o_tlp_temp_wr_addr = r_tlp_temp_wr_addr;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // PROCESS - FSM
    
    localparam [7:0] S_PROC_IDLE         = 8'b00000001, // 0
                     S_PROC_CHECK        = 8'b00000010, // 1
                     S_PROC_DISCARD_NACK = 8'b00000100, // 2
                     S_PROC_DISCARD_ACK  = 8'b00001000, // 3
                     S_PROC_ACCEPT       = 8'b00010000, // 4
                     S_PROC_WAIT_TLP_RDY = 8'b00100000, // 5
                     S_PROC_WRITE_TLP    = 8'b01000000, // 6
                     S_PROC_WRITE_RESULT = 8'b10000000; // 7

    (* fsm_encoding = "user_encoding" *)
    reg[7:0] r_proc_state = S_PROC_IDLE;
    reg[7:0] ri_proc_state;

    assign o_tlp_wr       = r_proc_state[6]; // S_PROC_WRITE_TLP
    assign o_tr_result_rd = r_proc_state[1]; // S_PROC_CHECK
    assign o_id_result_wr = r_proc_state[7]; // S_PROC_WRITE_STATUS
    


    reg[TLP_ID_WIDTH-1:0] r_tlp_temp_rd_addr, ri_tlp_temp_rd_addr;

    reg[TLP_ID_WIDTH:0] r_proc_frame_id_ref, ri_proc_frame_id_ref;
    reg[TLP_ID_WIDTH:0] r_proc_frame_id_header, ri_proc_frame_id_header;
    reg[TLP_ID_WIDTH:0] r_proc_frame_num_header, ri_proc_frame_num_header;
    reg[TLP_ID_WIDTH-1:0] r_proc_frame_num_tr, ri_proc_frame_num_tr;
    reg r_proc_valid_tr, ri_proc_valid_tr;

    // result after process-fsm => {ack/nack, ref_id}
    reg[TLP_ID_WIDTH:0] r_proc_id_result, ri_proc_id_result;
    
    wire proc_frames_done, proc_tr_ack;
    
    always@(posedge i_clk, negedge local_reset_n)
        if (~local_reset_n) begin
            r_proc_state            <= S_PROC_IDLE;
            r_proc_frame_id_ref     <= 0;
            r_proc_frame_id_header  <= 0;
            r_proc_frame_num_tr     <= 0;
            r_proc_frame_num_header <= 0;
            r_proc_valid_tr         <= 1'b0;
            r_proc_id_result        <= 0;
            r_tlp_temp_rd_addr      <= {TLP_ID_WIDTH{1'b0}};
        end else begin
            r_proc_state            <= ri_proc_state;
            r_proc_frame_id_ref     <= ri_proc_frame_id_ref;
            r_proc_frame_id_header  <= ri_proc_frame_id_header;
            r_proc_frame_num_tr     <= ri_proc_frame_num_tr;
            r_proc_frame_num_header <= ri_proc_frame_num_header;
            r_proc_valid_tr         <= ri_proc_valid_tr;
            r_proc_id_result        <= ri_proc_id_result;
            r_tlp_temp_rd_addr      <= ri_tlp_temp_rd_addr;
        end

    // transfer valid => crc_ok & stop_detect & (tr_frame_num == header_frame_num) & (header_id <= ref_id)
    assign proc_tr_ack      = (r_proc_valid_tr && ({1'b0, r_proc_frame_num_tr} == r_proc_frame_num_header) && (r_proc_frame_id_header <= r_proc_frame_id_ref));  
    assign proc_frames_done = (r_proc_frame_num_tr == 0);

    always @ * begin

        ri_proc_state            = r_proc_state;
        ri_proc_frame_id_ref     = r_proc_frame_id_ref;
        ri_proc_frame_id_header  = r_proc_frame_id_header;
        ri_proc_frame_num_tr     = r_proc_frame_num_tr;
        ri_proc_frame_num_header = r_proc_frame_num_header;
        ri_proc_valid_tr         = r_proc_valid_tr;
        ri_proc_id_result        = r_proc_id_result;
        ri_tlp_temp_rd_addr      = r_tlp_temp_rd_addr;

        case (r_proc_state)

            S_PROC_IDLE: begin
                // save {(crc_ok & stop_ok), tr_frame_num,  tlp_header_num}
                {ri_proc_valid_tr, ri_proc_frame_num_tr, ri_proc_frame_num_header} = i_tr_result[(3 * (TLP_ID_WIDTH + 1))-1:(TLP_ID_WIDTH + 1)];
                // save header
                ri_proc_frame_id_header = i_tr_result[TLP_ID_WIDTH:0];
                if (i_tr_result_valid)
                    ri_proc_state = S_PROC_CHECK;
            end

            S_PROC_CHECK: begin
                if (proc_tr_ack) 
                    ri_proc_state = S_PROC_ACCEPT; 
                else
                    ri_proc_state = S_PROC_DISCARD_NACK; 
            end

            S_PROC_DISCARD_NACK: begin
                ri_proc_id_result    = {1'b0, r_proc_frame_id_ref[TLP_ID_WIDTH-1:0]}; // {nack, ref_id}
                ri_proc_frame_num_tr = r_proc_frame_num_tr - 1;
                ri_tlp_temp_rd_addr  = r_tlp_temp_rd_addr + 1;
                if (proc_frames_done)
                    ri_proc_state = S_PROC_WRITE_RESULT;
            end 

            S_PROC_DISCARD_ACK: begin
                ri_tlp_temp_rd_addr  = r_tlp_temp_rd_addr + 1;
                //
                ri_proc_state = S_PROC_WRITE_RESULT;
            end 



            S_PROC_ACCEPT: begin
                ri_proc_id_result       = {1'b1, r_proc_frame_id_header[TLP_ID_WIDTH-1:0]}; // {ack, frame_id}
                ri_proc_frame_id_header = r_proc_frame_id_header + 1;
                if (r_proc_frame_id_ref > r_proc_frame_id_header)
                    ri_proc_state = S_PROC_DISCARD_ACK;
                else
                    ri_proc_state = S_PROC_WAIT_TLP_RDY;
            end

            S_PROC_WAIT_TLP_RDY: begin
                if (i_tlp_rdy)
                    ri_proc_state = S_PROC_WRITE_TLP;
            end


            S_PROC_WRITE_TLP: begin
                ri_proc_frame_id_ref = r_proc_frame_id_ref + 1;
                ri_tlp_temp_rd_addr = r_tlp_temp_rd_addr + 1;
                //
                ri_proc_state = S_PROC_WRITE_RESULT;
            end

            S_PROC_WRITE_RESULT: begin
                ri_proc_frame_num_tr = r_proc_frame_num_tr - 1;
                if (~proc_frames_done && r_proc_valid_tr)
                    ri_proc_state = S_PROC_ACCEPT;
                else
                    ri_proc_state  = S_PROC_IDLE;
            end

            default: begin
                ri_proc_state = S_PROC_IDLE;
            end

        endcase
    end

assign o_id_result = r_proc_id_result;
//
assign o_tlp_temp_rd_addr = r_tlp_temp_rd_addr;


endmodule

`endif /* PACKET_CHECKER_CONTROLLER */