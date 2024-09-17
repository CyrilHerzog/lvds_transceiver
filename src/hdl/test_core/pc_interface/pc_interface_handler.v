 /*
    Module  : PC_INTERFACE_HANDLER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/
 
 
`include "src/hdl/global_functions.vh"


`ifndef _PC_INTERFACE_HANDLER_V_
`define _PC_INTERFACE_HANDLER_V_

 module pc_interface_handler #(
    parameter TEST_PATTERN_WIDTH    = 56,
    parameter TIMEOUT_WIDTH         = 4 
 )(
    input wire i_clk, i_arst_n,
    // UART
    input wire i_pc_valid, 
    input wire i_pc_rdy, 
    input wire [7:0] i_pc_data,
    output wire [7:0] o_pc_data,
    output wire o_pc_rd, o_pc_wr,
    // TEST PATTERN
    input wire [TEST_PATTERN_WIDTH-1:0] i_bank_l,
    output wire [TEST_PATTERN_WIDTH-1:0] o_bank_p,
    output wire o_bank_p_wr,
    // CONTROL & STATUS
    input wire [15:0] i_bank_s,
    output wire [15:0] o_bank_c,
    output wire o_bank_c_wr,
    // BANK ADDRESS 
    output wire[2:0] o_bank_addr
 );

   localparam integer MAX_BANK_WIDTH = `fun_max(16, TEST_PATTERN_WIDTH);
   localparam integer PC_SHIFT_BYTES = `fun_sizeof_byte(MAX_BANK_WIDTH);
   localparam integer PC_SHIFT_WIDTH = PC_SHIFT_BYTES << 3;
   localparam integer PATTERN_BYTES  = `fun_sizeof_byte(TEST_PATTERN_WIDTH);


    localparam [10:0] S_IDLE         = 11'b00000000001, // 0
                     S_CMD_DECODE    = 11'b00000000010, // 1
                     S_BANK_SEL      = 11'b00000000100, // 2
                     S_SEL_BANK_P    = 11'b00000001000, // 3
                     S_SEL_BANK_CS   = 11'b00000010000, // 4
                     S_WAIT_PC_VALID = 11'b00000100000, // 5
                     S_WAIT_PC_READY = 11'b00001000000, // 6
                     S_READ_PC       = 11'b00010000000, // 7
                     S_WRITE_PC      = 11'b00100000000, // 8
                     S_WRITE_BANK    = 11'b01000000000, // 9
                     S_READ_BANK     = 11'b10000000000; // 10


    (* fsm_encoding = "user_encoding" *)
    reg [10:0] r_state = S_IDLE;
    reg [10:0] ri_state;
    
    assign o_pc_wr = r_state[8];                     
    assign o_pc_rd = r_state[1] | r_state[7];

    reg [TIMEOUT_WIDTH-1:0] r_timeout, ri_timeout;

    reg[PC_SHIFT_WIDTH-1:0] r_pc_shift_in, ri_pc_shift_in;
    reg[PC_SHIFT_WIDTH-1:0] r_pc_shift_out, ri_pc_shift_out;

    reg[$clog2(PC_SHIFT_BYTES-1):0] r_byte_cnt, ri_byte_cnt;
    reg[3:0] r_bank_addr, ri_bank_addr; 

    reg[1:0] r_rw_cmd, ri_rw_cmd;
    
    wire timeout, max_addr;
    wire bytes_done;
    wire sel_p_bank;
    wire wr_enable, inc_enable;

    always@(posedge i_clk, negedge i_arst_n)
        if (~i_arst_n) begin
            r_state        <= S_IDLE;
            r_timeout      <= 0;
            r_pc_shift_in  <= 0;
            r_pc_shift_out <= 0;
            r_bank_addr    <= 0;
            r_byte_cnt     <= 0;
            r_rw_cmd       <= 0;
        end else begin
            r_state        <= ri_state;
            r_timeout      <= ri_timeout;
            r_pc_shift_in  <= ri_pc_shift_in;
            r_pc_shift_out <= ri_pc_shift_out;
            r_bank_addr    <= ri_bank_addr;
            r_byte_cnt     <= ri_byte_cnt;
            r_rw_cmd       <= ri_rw_cmd;
        end

    
    //assign timeout    = &r_timeout;     
    assign timeout = 1'b0;
    assign max_addr   = &r_bank_addr[2:0];
    assign bytes_done = (r_byte_cnt == 0);
    assign sel_p_bank = r_bank_addr[3];

    assign wr_enable  = r_rw_cmd[1];
    assign inc_enable = r_rw_cmd[0] & ~max_addr;
    
  
    always @* begin

        // default
        ri_state        = r_state;
        ri_timeout      = r_timeout;
        ri_pc_shift_in  = r_pc_shift_in;
        ri_pc_shift_out = r_pc_shift_out;
        ri_bank_addr    = r_bank_addr;
        ri_byte_cnt     = r_byte_cnt;
        ri_rw_cmd       = r_rw_cmd;

        case (r_state) 

            S_IDLE: begin
                // data_path
                ri_timeout = 0;
                ri_pc_shift_in = {r_pc_shift_in[PC_SHIFT_WIDTH-8:0], i_pc_data};

                if (i_pc_valid)
                    ri_state = S_CMD_DECODE;

            end

          
            S_CMD_DECODE: begin
                ri_bank_addr = r_pc_shift_in[3:0];
                ri_rw_cmd    = r_pc_shift_in[5:4];
                ri_state     = S_BANK_SEL;
            end

            S_BANK_SEL: begin
                if (sel_p_bank)
                    ri_state = S_SEL_BANK_P;
                else
                    ri_state = S_SEL_BANK_CS;
            end

   
            S_SEL_BANK_P: begin
                ri_byte_cnt     = PATTERN_BYTES - 1;
                ri_pc_shift_out = i_bank_l;
                if (wr_enable)
                    ri_state = S_WAIT_PC_VALID;
                else
                    ri_state = S_WAIT_PC_READY;

            end

            S_SEL_BANK_CS: begin
                ri_pc_shift_out = {i_bank_s, 40'b0};
                ri_byte_cnt = 1;
                if (wr_enable)
                    ri_state = S_WAIT_PC_VALID;
                else
                    ri_state = S_WAIT_PC_READY;
            end


            S_WAIT_PC_VALID: begin
                // data path
                ri_timeout = r_timeout + 1;
                // next state
                if (timeout)
                    ri_state = S_IDLE;
                else if (i_pc_valid)
                    ri_state = S_READ_PC;
            end


            S_READ_PC: begin
                ri_pc_shift_in = {r_pc_shift_in[PC_SHIFT_WIDTH-8:0], i_pc_data};
                ri_byte_cnt    = r_byte_cnt - 1;
                ri_timeout = 0;
                if (bytes_done)
                    ri_state = S_WRITE_BANK;
                else
                    ri_state = S_WAIT_PC_VALID;
            end


            S_WRITE_BANK: begin
                ri_bank_addr = r_bank_addr + 1;
                if (inc_enable)
                    ri_state = S_BANK_SEL;
                else 
                    ri_state = S_IDLE;
            end

            S_WAIT_PC_READY: begin
                if (i_pc_rdy)
                    ri_state = S_WRITE_PC;
            end


            S_WRITE_PC: begin
                ri_pc_shift_out = {r_pc_shift_out[PC_SHIFT_WIDTH-8:0], 8'b0};
                ri_byte_cnt = r_byte_cnt - 1;
                if (bytes_done)
                    ri_state = S_READ_BANK;
                else
                    ri_state = S_WAIT_PC_READY;
            end

            S_READ_BANK: begin
                ri_bank_addr = r_bank_addr + 1;
                if (inc_enable)
                    ri_state = S_BANK_SEL;
                else
                    ri_state = S_IDLE;

            end

            default: begin
                ri_state = S_IDLE;

            end

        endcase

    end

    assign o_bank_addr = r_bank_addr[2:0];
    assign o_bank_p    = r_pc_shift_in[TEST_PATTERN_WIDTH-1:0];
    assign o_bank_c    = r_pc_shift_in[15:0];

    assign o_pc_data = r_pc_shift_out[PC_SHIFT_WIDTH-1:PC_SHIFT_WIDTH-8];

/////////////////////////////////////////////////////////////////////////////////////////////////////
// GLITCH - FREE WRITE PORT

    reg r_wr_bank_p, r_wr_bank_c;
    wire ri_wr_bank_p, ri_wr_bank_c;

    always @ (posedge i_clk, negedge i_arst_n)
        if (~i_arst_n) begin
            r_wr_bank_p <= 1'b0;
            r_wr_bank_c <= 1'b0;
        end else begin
            r_wr_bank_p <= ri_wr_bank_p;
            r_wr_bank_c <= ri_wr_bank_c;
        end

    assign ri_wr_bank_p = (ri_state == S_WRITE_BANK) & sel_p_bank;
    assign ri_wr_bank_c = (ri_state == S_WRITE_BANK) & ~sel_p_bank;

    assign o_bank_p_wr = r_wr_bank_p;
    assign o_bank_c_wr = r_wr_bank_c;             
        

       
endmodule

`endif /* PC_INTERFACE_HANDLER */