/*
    Module  : UART_RX
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`ifndef _UART_RX_V_
`define _UART_RX_V_

`include "src/hdl/uart/include/uart_defines.vh"


module uart_rx #(
    parameter F_CLK      = 50_000_000,
    parameter BAUDRATE   = 9600,
    parameter DATA_WIDTH = 8,
    parameter STOP_BITS  = `STOP_BITS_ONE,
    parameter PARITY     = `PARITY_NONE
)(
    input wire i_clk, i_arst_n,
    input wire i_rx,
    output wire [DATA_WIDTH-1:0] o_data,
    output wire o_data_valid,
    output wire o_frame_err, o_parity_err

);


    // parameter check
    initial begin
        if (PARITY < 1 || PARITY > 3) 
            $fatal("ERROR: PARAMETER PARITY must be between 1 or 3");

        if (STOP_BITS < 1 || STOP_BITS > 3) 
            $fatal("ERROR: PARAMETER STOP_BITS must be between 1 or 3");

        if (DATA_WIDTH < 2) 
            $fatal("ERROR: PARAMETER DATA_WIDTH must be have a minimum of 2");
    end

    // [DATA_BITS, PARITY_BIT]
    localparam FRAME_WIDTH = DATA_WIDTH + ((PARITY != `PARITY_NONE) ? 1 : 0);
    localparam BAUD_DIV    = F_CLK / BAUDRATE;

    
    // fsm
    localparam [12:0] S_IDLE         = 13'b0000000000001, // 0
                      S_START        = 13'b0000000000010, // 1
                      S_START_WAIT   = 13'b0000000000100, // 2
                      S_DATA         = 13'b0000000001000, // 3
                      S_SHIFT        = 13'b0000000010000, // 4
                      S_DATA_WAIT    = 13'b0000000100000, // 5
                      S_STOP_CHECK   = 13'b0000001000000, // 6
                      S_STOP_WAIT    = 13'b0000010000000, // 7
                      S_STOP         = 13'b0000100000000, // 8
                      S_PARITY       = 13'b0001000000000, // 9
                      S_DONE         = 13'b0010000000000, // 10
                      S_FRAME_ERROR  = 13'b0100000000000, // 11
                      S_PARITY_ERROR = 13'b1000000000000; // 12

    (* fsm_encoding = "user_encoding" *)
    reg[12:0] r_state = S_IDLE;
    reg[12:0] ri_state;
    
    assign o_data_valid = r_state[10]; // S_DONE
    assign o_frame_err  = r_state[11]; // S_FRAME_ERROR
    assign o_parity_err = r_state[12]; // S_PARITY_ERROR

    // baud-counter
    reg [$clog2(BAUD_DIV-1)-1:0] r_baud; 
    wire [$clog2(BAUD_DIV-1)-1:0] ri_baud;
    wire baud_flag, wait_flag, baud_clr;

    assign baud_clr = (r_state[0] | r_state[2] | r_state[4] | r_state[6] | r_state[8]); // S_IDLE, S_START_WAIT, S_SHIFT, S_STOP_CHECK, S_STOP

    // sipo
    reg [FRAME_WIDTH-1:0] r_sipo;
    wire [FRAME_WIDTH-1:0] ri_sipo;
    wire sipo_shift;

    assign sipo_shift = r_state[4]; // S_SHIFT

    // bit-counter
    reg [$clog2(FRAME_WIDTH)-1:0] r_bit;
    wire [$clog2(FRAME_WIDTH)-1:0] ri_bit;
    wire bit_clr, bit_up;
    wire data_flag, stop_flag;

    assign bit_clr = (r_state[0] | r_state[5]); // S_IDLE , S_DATA_WAIT
    assign bit_up  = (r_state[4] | r_state[8]); // S_SHIFT, S_STOP

    // parity generator
    wire parity_bit;
    wire parity_ok;

    generate
    if (PARITY != `PARITY_NONE) begin
        if (PARITY == `PARITY_ODD)
            assign parity_bit = ~^r_sipo[FRAME_WIDTH-1:1];
        else
            assign parity_bit = ^r_sipo[FRAME_WIDTH-1:1];
    end
    else begin
        assign parity_bit = 1'b0; 
    end
    endgenerate
    
    assign parity_ok = (PARITY == `PARITY_NONE) ? 1'b1 : ~(parity_bit ^ r_sipo[0]);


    always @(posedge i_clk, negedge i_arst_n) begin
        if (~i_arst_n) begin
            r_state <= S_IDLE;
            r_baud  <= 0;
            r_sipo  <= 0;
            r_bit   <= 0;
        end else begin
            // state register
            r_state <= ri_state;
            // data register's
            r_baud  <= ri_baud;
            r_sipo  <= ri_sipo;
            r_bit   <= ri_bit;
        end
    end
    
    // baud-counter
    assign ri_baud   = (baud_clr) ? 0 : r_baud + 1;
    assign baud_flag = (r_baud == (BAUD_DIV-1))      ? 1'b1 : 1'b0; 
    assign wait_flag = (r_baud == (BAUD_DIV / 2) -1) ? 1'b1 : 1'b0; // baud rate x2
    
    // sipo
    assign ri_sipo = (sipo_shift) ? {r_sipo[FRAME_WIDTH-2:0], i_rx} : r_sipo;
                                                       
    
    // bit-counter
    assign ri_bit = (bit_clr) ? 0 : (bit_up) ? r_bit + 1 : r_bit;
    assign data_flag = (r_bit == FRAME_WIDTH-1) ? 1'b1 : 1'b0;
    assign stop_flag = (r_bit == STOP_BITS-1) ? 1'b1 : 1'b0; 

    // FSM - comb
    always @* begin

        ri_state = r_state;

        case (r_state)

            S_IDLE: begin
                if (~i_rx) 
                    ri_state = S_START;
            end

            S_START: begin
                if (wait_flag)
                    ri_state = S_START_WAIT;
            end

            S_START_WAIT: begin
                ri_state = S_DATA;
            end
      

            S_DATA: begin
                if (baud_flag)
                    ri_state = S_SHIFT;
            end
                
            S_SHIFT: begin
                if (data_flag)
                    ri_state = S_DATA_WAIT;
                else
                    ri_state = S_DATA;
            end


            S_DATA_WAIT: begin
                if (baud_flag)
                    ri_state = S_STOP_CHECK;
            end

            S_STOP_CHECK: begin
                if (~i_rx)
                    ri_state = S_FRAME_ERROR;
                else
                    ri_state = S_STOP_WAIT;
            end                    

            S_STOP_WAIT: begin
                if (wait_flag)
                    ri_state = S_STOP;
            end

            S_STOP: begin
                if (stop_flag)
                    ri_state = S_PARITY;
                else
                    ri_state = S_STOP_WAIT;
            end
            

            S_PARITY: begin
                if (parity_ok)
                    ri_state = S_DONE;
                else
                    ri_state = S_PARITY_ERROR;
            end
                
            S_DONE: begin
                ri_state = S_IDLE;
            end

            S_FRAME_ERROR: begin
                if (i_rx)
                    ri_state = S_IDLE;
            end

            S_PARITY_ERROR: begin
                if (i_rx)
                    ri_state = S_IDLE;
            end

            default: begin
                ri_state = S_IDLE;
            end
                               
        endcase
    end

    assign o_data = (PARITY == `PARITY_NONE) ? r_sipo : r_sipo[FRAME_WIDTH-1:1];

endmodule

`endif /* UART_RX */