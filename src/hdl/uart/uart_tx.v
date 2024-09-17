/*
    Module  : UART_TX
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`ifndef _UART_TX_V_
`define _UART_TX_V_

`include "src/hdl/uart/include/uart_defines.vh"


module uart_tx #(
    parameter F_CLK      = 50_000_000,
    parameter BAUDRATE   = 9600,
    parameter DATA_WIDTH = 8,
    parameter STOP_BITS  = `STOP_BITS_ONE,
    parameter PARITY     = `PARITY_NONE
)(
    input wire i_clk, i_arst_n,
    input wire i_tx_en,
    input wire [DATA_WIDTH-1:0] i_data,
    output wire o_tx,
    output wire o_busy, o_done
);


    // parameter check
    initial begin
        if (STOP_BITS < 1 || STOP_BITS > 3) 
            $fatal(1, "ERROR: PARAMETER STOP_BITS must be between 1 or 3");

        if (PARITY < 1 || PARITY > 3) 
            $fatal(1, "ERROR: PARAMETER PARITY must be between 1 or 3");
    end


    // parity generator
    wire parity_bit;

   generate
    if (PARITY != `PARITY_NONE) begin
        if (PARITY == `PARITY_ODD)
            assign parity_bit = ~^i_data;
        else
            assign parity_bit = ^i_data; 
    end
    else begin
        assign parity_bit = 1'b0; 
    end
    endgenerate

    // [START_BIT, DATA_BITS, PARITY_BIT]
    localparam FRAME_WIDTH = DATA_WIDTH + 2 + ((PARITY != `PARITY_NONE) ? 1 : 0);
    localparam BAUD_DIV    = F_CLK / BAUDRATE;


    // fsm
    localparam [5:0]  S_IDLE  = 6'b000001, // 0
                      S_START = 6'b000010, // 1
                      S_FRAME = 6'b000100, // 2
                      S_SHIFT = 6'b001000, // 3
                      S_WAIT  = 6'b010000, // 4
                      S_DONE  = 6'b100000; // 5

    (* fsm_encoding = "user_encoding" *)
    reg[5:0] r_state = S_IDLE;
    reg[5:0] ri_state;

    assign o_busy = ~r_state[0]; // S_IDLE
    assign o_done = r_state[5]; // S_DONE 


    // baud-counter
    reg [$clog2(BAUD_DIV-1)-1:0] r_baud; 
    wire [$clog2(BAUD_DIV-1)-1:0] ri_baud;
    wire baud_flag, wait_flag, baud_clr;

    assign baud_clr = (r_state[0] | r_state[3]); // S_IDLE or S_SHIFT
    
    // piso
    reg [FRAME_WIDTH-1:0] r_piso;
    wire [FRAME_WIDTH-1:0] ri_piso;
    wire piso_load, piso_shift, piso_empty;
    

    assign piso_shift = r_state[3]; // S_SHIFT 
    assign piso_load  = r_state[1]; // S_START

    // output
    reg r_tx;
    wire ri_tx; 
    wire tx_sel;
    
    assign tx_sel = (r_state[2] | r_state[3]); // S_FRAME or S_SHIFT 
    

    
    always @(posedge i_clk, negedge i_arst_n) begin
        if (~i_arst_n) begin
            r_state <= S_IDLE;
            r_baud  <= 0;
            r_piso  <= 0;
            r_tx    <= 1'b1;
        end else begin
            // state register
            r_state <= ri_state;
            // data register's
            r_baud  <= ri_baud;
            r_piso  <= ri_piso;
            // output
            r_tx    <= ri_tx;
        end
    end
    

    // baud-counter
    assign ri_baud = (baud_clr) ? 0 : r_baud + 1;
    assign baud_flag = (r_baud == (BAUD_DIV-1)) ? 1'b1 : 1'b0;

    assign wait_flag = (STOP_BITS == `STOP_BITS_ONE) ? 1'b1 :
                       (STOP_BITS == `STOP_BITS_ONE_POINT_FIVE && r_baud == ((BAUD_DIV / 2) -1)) ? 1'b1 :
                       (STOP_BITS == `STOP_BITS_TWO && r_baud == (BAUD_DIV-1)) ? 1'b1 :
                       1'b0;

    // piso
    assign ri_piso = (piso_load) ? (PARITY == `PARITY_NONE) ? {1'b0, i_data, 1'b1} : {1'b0, i_data, parity_bit, 1'b1} :
                    (piso_shift) ? {r_piso[FRAME_WIDTH-2:0], 1'b0} : r_piso;

    assign piso_empty = (r_piso == (1'b1 << (FRAME_WIDTH-1))); // no data if stop bit in last position
    

    // FSM - control signals
    always @* begin

        ri_state = r_state;

        case (r_state)

            S_IDLE: begin
                if (i_tx_en) 
                    ri_state = S_START;
            end

            S_START: begin
                ri_state = S_FRAME;
            end

            S_FRAME: begin
                if (baud_flag) 
                    ri_state = S_SHIFT;
            end

            S_SHIFT: begin
                if (piso_empty)
                    ri_state = S_WAIT;
                else
                    ri_state = S_FRAME;
            end

            S_WAIT: 
                if (wait_flag)
                    ri_state = S_DONE;
                

            S_DONE: begin
                ri_state = S_IDLE;
            end

            default: begin
                ri_state = S_IDLE;
            end
               
        endcase
    end

    assign ri_tx = (tx_sel) ? r_piso[FRAME_WIDTH-1] : 1'b1;
    assign o_tx  = r_tx;

endmodule

`endif /* UART_TX */