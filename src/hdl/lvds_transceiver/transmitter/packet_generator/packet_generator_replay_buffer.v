/*
    Module  : PACKET_GENERATOR_REPLAY_BUFFER
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`ifndef _PACKET_GENERATOR_REPLAY_BUFFER_V_
`define _PACKET_GENERATOR_REPLAY_BUFFER_V_

`include "src/hdl/global_functions.vh"

module packet_generator_replay_buffer #(
    parameter FRAME_WIDTH = 56,
    parameter ID_WIDTH    = 3
)(
    input wire i_clk, i_arst_n,
    input wire i_set_id,
    input wire i_wr, i_rd,
    input wire[7:0] i_byte,
    input wire[ID_WIDTH-1:0] i_id,
    output wire[7:0] o_byte
);

    // CALC MEMORY RESSOURCE
    localparam FRAME_BYTES = `fun_sizeof_byte(FRAME_WIDTH);
    localparam BUFFER_SIZE = (FRAME_BYTES * (2**ID_WIDTH));
    

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // ADDRESS - LUT
    wire [$clog2(BUFFER_SIZE-1):0] id_addr_lut [(2**ID_WIDTH)-1:0];

    generate
        genvar i;
        for (i = 0; i < (2**ID_WIDTH); i = i + 1) begin
            assign id_addr_lut[i] = FRAME_BYTES * i;
        end
    endgenerate

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // BUFFER ADDRESS - POINTER
    reg[$clog2(BUFFER_SIZE-1):0] r_buffer_addr;
    wire[$clog2(BUFFER_SIZE-1):0] ri_buffer_addr;
    wire addr_inc;

    always@ (posedge i_clk, negedge i_arst_n)
        if (~i_arst_n) 
            r_buffer_addr <= 0;
        else
            r_buffer_addr <= ri_buffer_addr;
    
    assign addr_inc = (i_wr || i_rd);
    assign ri_buffer_addr = (i_set_id) ? id_addr_lut[i_id] : (addr_inc) ? r_buffer_addr + 1'b1 : r_buffer_addr;

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // BUFFER MEMORY
    reg [7:0] replay_buffer [BUFFER_SIZE-1:0];

    always@ (posedge i_clk)
        if (i_wr)
            replay_buffer[r_buffer_addr] <= i_byte;
        

    assign o_byte = replay_buffer[r_buffer_addr];

endmodule

`endif /* PACKET_GENERATOR_REPLAY_BUFFER */