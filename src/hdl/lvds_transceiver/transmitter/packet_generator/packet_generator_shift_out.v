/*
    Module  : PACKET_GENERATOR_SHIFT_OUT
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`ifndef _PACKET_GENERATOR_SHIFT_OUT_V_
`define _PACKET_GENERATOR_SHIFT_OUT_V_

`include "src/hdl/global_functions.vh"

module packet_generator_shift_out #(
    parameter DLLP_FRAME_WIDTH = 2,
    parameter TLP_FRAME_WIDTH  = 8
)(
    input wire i_clk,
    input wire[DLLP_FRAME_WIDTH-1:0] i_dllp_frame,
    input wire[TLP_FRAME_WIDTH-1:0] i_tlp_frame,
    input wire load_frame,
    input wire sel_dllp,
    output wire[7:0] o_byte
);

    // the messages (dllp or tlp) will be broken up into bytes
    localparam DLLP_BYTES = `fun_sizeof_byte(DLLP_FRAME_WIDTH);
    localparam TLP_BYTES  = `fun_sizeof_byte(TLP_FRAME_WIDTH); 
    localparam MUX_STAGES = `fun_max(DLLP_BYTES, TLP_BYTES);   


    // ***********************************************************************************************************************
    // generate multiplexer-register stages

    reg [7:0] r_mux_stage [0:(MUX_STAGES-1)];      
    wire [7:0] ri_mux_stage [0:(MUX_STAGES-1)];
    

    integer k;

    initial begin
        // clear stages
        for (k = 0; k < MUX_STAGES; k = k + 1) begin
            r_mux_stage[k] = 0;
        end
    end

    always @ (posedge i_clk) begin
        for (k=0; k < MUX_STAGES; k = k + 1) begin  
            r_mux_stage[k] <= ri_mux_stage[k];
        end        
    end
    genvar i;
    generate
    // size of tlp-frame is higher than size of dllp-frame 
    if (TLP_BYTES > DLLP_BYTES) begin
        assign ri_mux_stage[0] = i_tlp_frame[7:0];
        for (i=1; i < TLP_BYTES; i = i + 1) begin
            if (i < (TLP_BYTES - DLLP_BYTES))
                assign ri_mux_stage[i] = (load_frame) ? i_tlp_frame[(7 + (i * 8)) : (i * 8)] : r_mux_stage[i-1];
            else
                assign ri_mux_stage[i] = (load_frame) ? ((sel_dllp) ? i_dllp_frame[(7 + ((i-(TLP_BYTES - DLLP_BYTES)) * 8)) :
                                         ((i-(TLP_BYTES - DLLP_BYTES)) * 8)] : i_tlp_frame[(7 + (i * 8)) : (i * 8)]) : r_mux_stage[i-1];
        end
    // size of dllp-frame is higher than size of tlp-frame 
    end else if (DLLP_BYTES > TLP_BYTES) begin
        assign ri_mux_stage[0] = i_dllp_frame[7:0];
        for (i=1; i < DLLP_BYTES; i = i + 1) begin
            if (i < (DLLP_BYTES - TLP_BYTES))
                assign ri_mux_stage[i] = (load_frame) ? i_dllp_frame[(7 + (i * 8)) : (i * 8)] : r_mux_stage[i-1];
            else
                assign ri_mux_stage[i] = (load_frame) ? ((sel_dllp) ? i_dllp_frame[(7 + (i * 8)) : (i * 8)] : i_tlp_frame[(7 + ((i-(DLLP_BYTES - TLP_BYTES)) * 8)) :
                                         ((i-(DLLP_BYTES - TLP_BYTES)) * 8)]) : r_mux_stage[i-1];
        end
    // size of tlp-frame is equal to the size of dllp-frame
    end else begin
        assign ri_mux_stage[0] = (load_frame) ? i_dllp_frame[7:0] : i_tlp_frame[7:0];
        for (i=1; i < TLP_BYTES; i = i + 1) begin
            assign ri_mux_stage[i] = (load_frame) ? ((sel_dllp) ? i_dllp_frame[(7 + (i * 8)) : (i * 8)] : i_tlp_frame[(7 + (i * 8)) : (i * 8)]) : r_mux_stage[i-1];
        end
    end
    endgenerate

    // assign output-byte
    assign o_byte = r_mux_stage[MUX_STAGES-1];

endmodule

`endif /* PACKET_GENERATOR_SHIFT_OUT */