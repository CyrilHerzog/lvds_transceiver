
/*
    Module  : LOOP_INTERFACE_HANDLER_TRX_A
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

    ToDo: handle timeout
*/

`ifndef _LOOP_INTERFACE_HANDLER_TRX_A_V_
`define _LOOP_INTERFACE_HANDLER_TRX_A_V_

module loop_interface_handler_trx_a #(
    parameter TIMEOUT_WIDTH = 4
)(
    input wire i_clk, i_arst_n,
    // CONTROL & STATUS
    input wire i_loop_enable,
    output wire o_loop_start,
    output wire o_loop_done,
    output wire o_running,
    input wire[2:0] i_pattern_num,
    // L / P - BANK CONTROL
    output wire [55:0] o_bank_l,
    output wire [2:0] o_bank_addr,
    output wire o_bank_wr,
    // TRANSCEIVER INTERFACE
    input wire i_trx_valid, i_trx_rdy,
    input wire [33:0] i_trx,
    output wire o_trx_wr, o_trx_rd
);


    localparam [9:0]    S_IDLE            = 10'b0000000001, // 0
                        S_START_LOOP      = 10'b0000000010, // 1
                        S_WAIT_TRX_READY  = 10'b0000000100, // 2
                        S_WRITE_TRX       = 10'b0000001000, // 3
                        S_START_RESPONSE  = 10'b0000010000, // 4
                        S_WAIT_TRX_VALID  = 10'b0000100000, // 5
                        S_TRX_READ_PART_1 = 10'b0001000000, // 6
                        S_TRX_READ_PART_2 = 10'b0010000000, // 7
                        S_TRX_WRITE_BANK  = 10'b0100000000, // 8
                        S_LOOP_DONE       = 10'b1000000000; // 9


    (* fsm_encoding = "user_encoding" *)
    reg [9:0] r_state = S_IDLE;
    reg [9:0] ri_state;

    // state assigment's
    assign o_running    =  ~r_state[0];
    assign o_loop_start = r_state[1];
    assign o_loop_done  = r_state[9];

    assign o_trx_wr = r_state[3];
    assign o_trx_rd = r_state[6] | r_state[8];

    assign o_bank_wr = r_state[8];


    reg [55:0] r_temp, ri_temp;
    reg [TIMEOUT_WIDTH-1:0] r_timeout, ri_timeout;

    reg[2:0] r_bank_addr, ri_bank_addr;
    reg[2:0] r_pattern_num, ri_pattern_num;
   

    wire max_bank_addr, max_pattern_num, all_dest_bytes;
    wire timeout;

    always @ (posedge i_clk, negedge i_arst_n)
        if (~i_arst_n) begin
            r_state       <= S_IDLE;
            r_bank_addr   <= 0;
            r_pattern_num <= 0;
            r_temp        <= 0;
            r_timeout     <= 0;
        end else begin
            r_state       <= ri_state;
            r_bank_addr   <= ri_bank_addr;
            r_pattern_num <= ri_pattern_num;
            r_temp        <= ri_temp;
            r_timeout     <= ri_timeout;
        end

    assign max_bank_addr   = &r_bank_addr;
    assign max_pattern_num = (r_bank_addr == ri_pattern_num); 
    assign timeout         = &r_timeout;

    always @ * begin

        ri_state       = r_state;
        ri_timeout     = r_timeout;
        ri_pattern_num = r_pattern_num;
        ri_temp        = r_temp;
        ri_bank_addr   = r_bank_addr;
    

        case (r_state)

            S_IDLE: begin
                ri_bank_addr   = 0;
                ri_pattern_num = i_pattern_num;

                if (i_loop_enable)
                    ri_state = S_START_LOOP;
            end

   
            S_START_LOOP: begin
                ri_bank_addr   = 0;
                ri_state       = S_WAIT_TRX_READY;
            end


            S_WAIT_TRX_READY: begin
                if (i_trx_rdy)
                    ri_state = S_WRITE_TRX;
            end

            S_WRITE_TRX: begin
                ri_bank_addr = r_bank_addr + 1;
                if (max_pattern_num)
                    ri_state = S_START_RESPONSE;
                else
                    ri_state = S_WAIT_TRX_READY;
            end


            S_START_RESPONSE: begin
                ri_bank_addr = 0;
                ri_state     = S_WAIT_TRX_VALID;
            end


            S_WAIT_TRX_VALID: begin
                ri_temp = {i_trx, 22'b0};
                if (i_trx_valid)
                    ri_state = S_TRX_READ_PART_1;

            end

            S_TRX_READ_PART_1: begin
                ri_state = S_TRX_READ_PART_2;
            end

            S_TRX_READ_PART_2: begin
                ri_temp = {r_temp[55:22], i_trx[33:12]};
                if (i_trx_valid)
                    ri_state = S_TRX_WRITE_BANK;

            end

            S_TRX_WRITE_BANK: begin
                ri_bank_addr = r_bank_addr + 1;

                if (max_pattern_num)
                    ri_state = S_LOOP_DONE;
                else
                    ri_state = S_WAIT_TRX_VALID;

            end


            S_LOOP_DONE: begin
                if (i_loop_enable)
                    ri_state = S_START_LOOP;
                else
                    ri_state = S_IDLE;
            end

            default: begin
                ri_state = S_IDLE;
            end

        endcase

    end

    assign o_bank_addr = r_bank_addr;
    assign o_bank_l    = r_temp;


endmodule

`endif /* LOOP_INTERFACE_HANDLER_TRX_A */

            

            