 /*
    Module  : LOOP_INTERFACE_HANDLER_TRX_B
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/

`ifndef _LOOP_INTERFACE_HANDLER_TRX_B_V_
`define _LOOP_INTERFACE_HANDLER_TRX_B_V_

module loop_interface_handler_trx_b (
    input wire i_clk, i_arst_n,
    // TRANSCEIVER INTERFACE
    input wire i_trx_valid, i_trx_rdy,
    input wire [55:0] i_trx,
    output wire [33:0] o_trx,
    output wire o_trx_wr, o_trx_rd
);

    localparam [6:0] S_IDLE              = 7'b0000001, // 0
                     S_READ_PART_1       = 7'b0000010, // 1
                     S_WAIT_READY_PART_1 = 7'b0000100, // 2
                     S_WRITE_PART_1      = 7'b0001000, // 3
                     S_READ_PART_2       = 7'b0010000, // 4
                     S_WAIT_READY_PART_2 = 7'b0100000, // 5
                     S_WRITE_PART_2      = 7'b1000000; // 6

    (* fsm_encoding = "user_encoding" *)
    reg[6:0] r_state = S_IDLE;
    reg[6:0] ri_state;

    // assign output to state
    assign o_trx_rd = r_state[4];

    reg[33:0] r_temp, ri_temp;


    always @ (posedge i_clk, negedge i_arst_n)
        if (~i_arst_n) begin
            r_state   <= S_IDLE;
            r_temp    <= 0;
        end else begin
            r_state   <= ri_state;
            r_temp    <= ri_temp;
        end



    always @ * begin

        ri_state = r_state;
        ri_temp  = r_temp;
    
        case (r_state)

            S_IDLE: begin
                if (i_trx_valid)
                    ri_state = S_READ_PART_1;
            end

            S_READ_PART_1: begin
                ri_temp = i_trx[55:22]; // first 34 bit
                ri_state = S_WAIT_READY_PART_1;
            end

            S_WAIT_READY_PART_1: begin
                if (i_trx_rdy)
                    ri_state = S_WRITE_PART_1;
            end

            S_WRITE_PART_1: begin
                ri_state = S_READ_PART_2;
            end

            S_READ_PART_2: begin
                ri_temp = {i_trx[21:0], 12'b0};
                ri_state = S_WAIT_READY_PART_2;
            end

            S_WAIT_READY_PART_2: begin
                if (i_trx_rdy)
                    ri_state = S_WRITE_PART_2;
            end

            S_WRITE_PART_2: begin
                ri_state = S_IDLE;
            end

            default: begin
                ri_state = S_IDLE;
            end
        endcase
    end

    assign o_trx = r_temp;

// **************************************************************************
// glitch-free write port

    reg r_wr_trx;
    wire ri_wr_trx;

    always@ (posedge i_clk, negedge i_arst_n)
        if (~i_arst_n)
            r_wr_trx <= 1'b0;
        else
            r_wr_trx <= ri_wr_trx;

    assign ri_wr_trx = ri_state[3] | ri_state[6];

    assign o_trx_wr = r_wr_trx;

endmodule

`endif /* LOOP_INTERFACE_HANDLER_TRX_B */
